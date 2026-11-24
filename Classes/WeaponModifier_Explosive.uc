class WeaponModifier_Explosive extends RPGWeaponModifier;

#exec OBJ LOAD FILE=EpicParticles.utx

var localized string ExplosiveText;

var config float SplashRadius;
var config float SplashPerLevel; //fraction of the hit damage per modifier level

var bool bExploding; //splash hits go through NetDamage again, don't chain
var float LastBlastTime;
var float BlastInterval; //limits the blast effect on rapid fire weapons

function AdjustTargetDamage(out int Damage, int OriginalDamage, Pawn Injured, Pawn InstigatedBy, vector HitLocation, out vector Momentum, class<DamageType> DamageType)
{
	local Pawn P;
	local int SplashDamage;

	Super.AdjustTargetDamage(Damage, OriginalDamage, Injured, InstigatedBy, HitLocation, Momentum, DamageType);

	if(Damage <= 0 || bExploding || InstigatedBy == None)
		return;

	SplashDamage = int(float(Damage) * SplashPerLevel * Modifier);
	if(SplashDamage <= 0)
		return;

	Identify();

	if(Level.TimeSeconds - LastBlastTime >= BlastInterval)
	{
		LastBlastTime = Level.TimeSeconds;
		Spawn(class'FX_ExplosionRelay',,, HitLocation);
	}

	bExploding = true;
	foreach VisibleCollidingActors(class'Pawn', P, SplashRadius, HitLocation)
	{
		if(P != Injured && P.Health > 0 && !class'Util'.static.SameTeamCP(InstigatedBy.Controller, P))
			P.TakeDamage(SplashDamage, InstigatedBy, P.Location, vect(0, 0, 0), DamageType);
	}
	bExploding = false;
}

simulated function BuildDescription()
{
	Super.BuildDescription();
	AddToDescription(ExplosiveText);
}

defaultproperties
{
	BlastInterval=0.25
	ExplosiveText="explodes on hit"
	SplashRadius=160.00
	SplashPerLevel=0.20
	DamageBonus=0
	BonusPerLevel=0
	MinModifier=1
	MaxModifier=5
	bCanHaveZeroModifier=False
	ModifierOverlay=Material'EpicParticles.FlameRingShader'
	PatternPos="$W of Explosive"
	AIRatingBonus=0.025
}
