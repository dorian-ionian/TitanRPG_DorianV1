class Ability_MonsterProficiency extends RPGAbility;

var config array<int> MonsterTiers;        //lifetime kills per summoned monster type that reach each tier
var config array<float> TierHealthBonus;   //health bonus for newly summoned monsters of that type at each tier
var config array<float> TierDamageBonus;   //damage multiplier bonus for monsters of that type at each tier
var config array<string> TierTitles;       //title word shown in the tier announcement
var config int MilestonePoints;            //stat points granted once when a monster type reaches a tier

static function int GetMonsterTier(int Kills)
{
	local int i, Tier;

	Tier = 0;
	for(i = 0; i < default.MonsterTiers.Length; i++)
	{
		if(Kills >= default.MonsterTiers[i])
			Tier = i + 1;
	}
	return Tier;
}

static function string GetTierTitle(int Tier)
{
	if(Tier < 1 || Tier > default.TierTitles.Length)
		return "";
	return default.TierTitles[Tier - 1];
}

function ModifyMonster(Monster M, Pawn Master)
{
	local int Tier;
	local float Scale;

	if(RPRI == None || M == None)
		return;

	Tier = GetMonsterTier(RPRI.GetMonsterKills(M.Class));
	if(Tier <= 0 || Tier > TierHealthBonus.Length)
		return;

	Scale = 1.0 + TierHealthBonus[Tier - 1];
	M.Health = int(float(M.Health) * Scale);
	M.SuperHealthMax = M.SuperHealthMax - M.HealthMax + M.Health;
	M.HealthMax = M.Health;
}

//Called on the master's ability for hits dealt by one of the master's summoned monsters
function AdjustMonsterDamage(out int Damage, Pawn Monster)
{
	local int Tier;
	local float Scale;

	if(RPRI == None || Monster == None)
		return;

	Tier = GetMonsterTier(RPRI.GetMonsterKills(class<Monster>(Monster.Class)));
	if(Tier <= 0 || Tier > TierDamageBonus.Length)
		return;

	Scale = 1.0 + TierDamageBonus[Tier - 1];
	Damage = int(float(Damage) * Scale);
}

simulated function string DescriptionText()
{
	local string S;

	S = repl(Super.DescriptionText(), "$1", string(int(default.TierHealthBonus[0] * 100)));
	return repl(S, "$2", string(int(default.TierDamageBonus[0] * 100)));
}

defaultproperties
{
	AbilityName="Monster Proficiency"
	Description="Monster mastery: lifetime kills by your summoned monsters of each type raise newly summoned monsters of that type by $1% health and their damage by $2% at the first tier, with larger bonuses at each higher tier. Milestones grant stat points."
	MaxLevel=1
	StartingCost=5
	CostAddPerLevel=0
	MonsterTiers(0)=10
	MonsterTiers(1)=20
	MonsterTiers(2)=35
	MonsterTiers(3)=50
	MonsterTiers(4)=75
	MonsterTiers(5)=100
	MonsterTiers(6)=150
	TierHealthBonus(0)=0.04
	TierHealthBonus(1)=0.08
	TierHealthBonus(2)=0.12
	TierHealthBonus(3)=0.16
	TierHealthBonus(4)=0.20
	TierHealthBonus(5)=0.24
	TierHealthBonus(6)=0.28
	TierDamageBonus(0)=0.02
	TierDamageBonus(1)=0.04
	TierDamageBonus(2)=0.06
	TierDamageBonus(3)=0.08
	TierDamageBonus(4)=0.10
	TierDamageBonus(5)=0.12
	TierDamageBonus(6)=0.14
	TierTitles(0)="Whelp"
	TierTitles(1)="Prowler"
	TierTitles(2)="Tracker"
	TierTitles(3)="Ravager"
	TierTitles(4)="Slayer"
	TierTitles(5)="Reaper"
	TierTitles(6)="Colossus"
	MilestonePoints=5
	RequiredAbilities(0)=(AbilityClass=class'Ability_MonsterSummon',Level=1)
	Category=class'AbilityCategory_Monsters'
}
