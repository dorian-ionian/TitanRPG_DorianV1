class Ability_WeaponProficiency extends RPGAbility;

struct WeaponUsage
{
	var class<Weapon> WeaponClass;
	var float LastUsed;
};

var config int MasteryXP;           //bonus XP per level at full mastery of the weapon used for the kill
var config int MasteryKillCap;      //kills with one weapon needed for full mastery
var config int VarietyXP;           //bonus XP per level for each extra weapon used within the window
var config float VarietyWindow;     //seconds back to look for other weapons used
var config int MaxVarietyWeapons;   //cap on counted extra weapons
var config array<int> MasteryTiers;        //lifetime kills per weapon that reach each tier
var config array<float> TierDamageBonus;   //damage multiplier bonus with a weapon at each tier
var config array<string> TierTitles;       //title word shown after the held weapon's name at each tier
var config string NoviceTitle;             //title word shown after the held weapon's name below the first tier
var config int MilestoneXP;                //XP granted once when a weapon reaches a main tier (every 10th tier)
var config int VarietyAdrenaline;          //adrenaline for a kill with a different weapon than the last kill
var config int WeakWeaponBonusKills;       //first kills with a weapon that get the catch-up bonus
var config int WeakWeaponXP;               //bonus XP per level for each catch-up kill

var array<WeaponUsage> Usage;
var class<Weapon> LastWeapon;
var color TierColor[11];                   //title and announcement color per main tier, index 0 = Novice (not config, so it matches on every machine)

//Ten sub-tiers (I-X) share one main tier's color; index 0 = Novice
static function color GetTierColor(int Tier)
{
	return default.TierColor[Min((Tier + 9) / 10, ArrayCount(default.TierColor) - 1)];
}

//Server: packs TierTitles[Start..Start+Count-1] as "Title|" entries for ClientReceiveWeaponTitles
static function string PackTierTitles(int Start, int Count)
{
	local int i, End;
	local string Packed;

	End = Start + Count;
	if(End > default.TierTitles.Length)
		End = default.TierTitles.Length;

	for(i = Start; i < End; i++)
		Packed = Packed $ default.TierTitles[i] $ "|";

	return Packed;
}

//Client: stores a batch of weapon titles sent by the server, so mastery messages match the server's config
static function SetTierTitles(int Start, string Packed)
{
	local int i, Pos;

	i = Start;
	while(true)
	{
		Pos = InStr(Packed, "|");
		if(Pos < 0)
			break;
		if(default.TierTitles.Length <= i)
			default.TierTitles.Length = i + 1;
		default.TierTitles[i] = Left(Packed, Pos);
		Packed = Mid(Packed, Pos + 1);
		i++;
	}
}

//True if one of the weapon's fire modes deals this damage type (class defaults, so no instance is needed)
static function bool ClassUsesDamageType(class<Weapon> WClass, class<DamageType> DamageType)
{
	local int i;
	local class<WeaponFire> FM;

	//Weapon declares two fire mode slots (FireModeClass[2])
	for(i = 0; i < 2; i++)
	{
		FM = WClass.default.FireModeClass[i];
		if(FM == None)
			continue;
		if(ClassIsChildOf(FM, class'InstantFire') && class<InstantFire>(FM).default.DamageType == DamageType)
			return true;
		if(FM.default.ProjectileClass != None && FM.default.ProjectileClass.default.MyDamageType == DamageType)
			return true;
	}
	return false;
}

//The gun that dealt a hit. Dual wield's container is not a gun, so its hands are checked instead
function class<Weapon> HitGunClass(Pawn Shooter, class<DamageType> DamageType)
{
	if(Shooter == None || Shooter.Weapon == None)
		return None;
	return DualHandClass(Shooter.Weapon, DamageType, RPRI);
}

//Gun credited with a hit by W. A dual wield container is never returned: the hand whose fire mode dealt it is used, or None if neither hand is known
static function class<Weapon> DualHandClass(Weapon W, class<DamageType> DamageType, RPGPlayerReplicationInfo Stats)
{
	local class<Weapon> Left, Right;

	if(W == None)
		return None;
	if(!W.IsA('dw_DualWeapon'))
		return W.Class;

	if(W.GetPropertyText("LeftWeaponAlias") != "")
		Left = class<Weapon>(DynamicLoadObject(W.GetPropertyText("LeftWeaponAlias"), class'Class'));
	if(W.GetPropertyText("RightWeaponAlias") != "")
		Right = class<Weapon>(DynamicLoadObject(W.GetPropertyText("RightWeaponAlias"), class'Class'));

	if(Left != None && ClassUsesDamageType(Left, DamageType))
		return Left;
	if(Right != None && ClassUsesDamageType(Right, DamageType))
		return Right;

	//No hand's fire mode matches (custom damage type): credit the hand with more kills
	if(Right == None)
		return Left;
	if(Left == None)
		return Right;
	if(Stats != None && Stats.GetWeaponKills(Right) > Stats.GetWeaponKills(Left))
		return Right;
	return Left;
}

function ScoreKill(Controller Killed, class<DamageType> DamageType)
{
	local class<Weapon> G;
	local int i, idx, Recent, Kills;
	local float Mastery, Variety, Bonus;

	if(AbilityLevel <= 0 || Instigator == None || Instigator.Controller == None || Killed == None)
		return;
	if(Killed == Instigator.Controller || Killed.SameTeamAs(Instigator.Controller))
		return;

	G = HitGunClass(Instigator, DamageType);
	if(G == None)
		return;

	idx = -1;
	for(i = 0; i < Usage.Length; i++)
	{
		if(Usage[i].WeaponClass == G)
		{
			idx = i;
			break;
		}
	}
	if(idx == -1)
	{
		idx = Usage.Length;
		Usage.Length = idx + 1;
		Usage[idx].WeaponClass = G;
	}

	Usage[idx].LastUsed = Level.TimeSeconds;

	Recent = 0;
	for(i = 0; i < Usage.Length; i++)
	{
		if(Level.TimeSeconds - Usage[i].LastUsed <= VarietyWindow)
			Recent++;
	}

	Kills = 0;
	if(RPRI != None)
		Kills = RPRI.GetWeaponKills(G);

	Mastery = FMin(float(Kills) / float(MasteryKillCap), 1.0);
	Variety = FMin(float(Max(Recent - 1, 0)), float(MaxVarietyWeapons));

	if(Recent > 1 && LastWeapon != None && LastWeapon != G)
		Instigator.Controller.Adrenaline = FMin(Instigator.Controller.Adrenaline + float(VarietyAdrenaline), Instigator.Controller.AdrenalineMax);
	LastWeapon = G;

	Bonus = float(AbilityLevel) * (float(MasteryXP) * Mastery + float(VarietyXP) * Variety);
	if(Kills <= WeakWeaponBonusKills)
		Bonus += float(AbilityLevel * WeakWeaponXP);
	if(Bonus > 0.0 && RPRI != None)
		RPRI.AwardExperience(Bonus);
}

function AdjustTargetDamage(out int Damage, int OriginalDamage, Pawn Injured, Pawn InstigatedBy, vector HitLocation, out vector Momentum, class<DamageType> DamageType)
{
	local int Tier;

	if(InstigatedBy == None || InstigatedBy.Weapon == None || RPRI == None)
		return;

	Tier = GetMasteryTier(RPRI.GetWeaponKills(HitGunClass(InstigatedBy, DamageType)));
	if(Tier > 0 && Tier <= TierDamageBonus.Length)
		Damage = int(float(Damage) * (1.0 + TierDamageBonus[Tier - 1]));
}

function int GetMasteryTier(int Kills)
{
	local int i, Tier;

	Tier = 0;
	for(i = 0; i < MasteryTiers.Length; i++)
	{
		if(Kills >= MasteryTiers[i])
			Tier = i + 1;
	}
	return Tier;
}

simulated function bool Buy(optional int Amount)
{
	if (Role == ROLE_Authority && RPRI != None && RPRI.bTempBot)
		return false;
	return Super.Buy(Amount);
}

simulated function string DescriptionText()
{
	local string S;

	S = repl(Super.DescriptionText(), "$1", string(int(default.VarietyWindow)));
	S = repl(S, "$2", string(default.WeakWeaponXP));
	return repl(S, "$3", string(default.MasteryXP));
}

defaultproperties
{
	AbilityName="Weapon Proficiency"
	Description="Weapon mastery: lifetime kills with a weapon raise your damage with it and grant XP at each main tier. Kills with different weapons within $1 seconds give adrenaline and bonus XP. The first kills with each weapon give $2 bonus XP per level, and repeated kills with one weapon give up to $3 extra XP per level."
	MaxLevel=5
	StartingCost=5
	CostAddPerLevel=0
	MasteryXP=3
	MasteryKillCap=25
	VarietyXP=2
	VarietyWindow=60.0
	MaxVarietyWeapons=4
	MasteryTiers(0)=25
	MasteryTiers(1)=50
	MasteryTiers(2)=100
	MasteryTiers(3)=150
	MasteryTiers(4)=250
	MasteryTiers(5)=350
	MasteryTiers(6)=500
	TierDamageBonus(0)=0.02
	TierDamageBonus(1)=0.04
	TierDamageBonus(2)=0.06
	TierDamageBonus(3)=0.08
	TierDamageBonus(4)=0.10
	TierDamageBonus(5)=0.12
	TierDamageBonus(6)=0.14
	TierTitles(0)="Apprentice"
	TierTitles(1)="Journeyman"
	TierTitles(2)="Specialist"
	TierTitles(3)="Expert"
	TierTitles(4)="Veteran"
	TierTitles(5)="Champion"
	TierTitles(6)="Master"
	NoviceTitle="Novice"
	TierColor(0)=(R=255,G=255,B=255,A=255)
	TierColor(1)=(R=80,G=255,B=80,A=255)
	TierColor(2)=(R=80,G=220,B=255,A=255)
	TierColor(3)=(R=80,G=120,B=255,A=255)
	TierColor(4)=(R=180,G=80,B=255,A=255)
	TierColor(5)=(R=255,G=160,B=40,A=255)
	TierColor(6)=(R=255,G=60,B=60,A=255)
	TierColor(7)=(R=255,G=215,B=0,A=255)
	TierColor(8)=(R=255,G=105,B=180,A=255)
	TierColor(9)=(R=0,G=200,B=170,A=255)
	TierColor(10)=(R=255,G=240,B=160,A=255)
	MilestoneXP=100
	VarietyAdrenaline=5
	WeakWeaponBonusKills=5
	WeakWeaponXP=2
	Category=class'AbilityCategory_Weapons'
}
