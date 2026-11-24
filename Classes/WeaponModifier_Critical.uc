class WeaponModifier_Critical extends RPGWeaponModifier;

#exec OBJ LOAD FILE=EpicParticles.utx

var localized string CriticalText;

var config float CritChancePerLevel;
var config float CritMultiplier;

function AdjustTargetDamage(out int Damage, int OriginalDamage, Pawn Injured, Pawn InstigatedBy, vector HitLocation, out vector Momentum, class<DamageType> DamageType)
{
	Super.AdjustTargetDamage(Damage, OriginalDamage, Injured, InstigatedBy, HitLocation, Momentum, DamageType);

	if(Damage > 0 && FRand() < CritChancePerLevel * Modifier)
	{
		Damage = int(float(Damage) * CritMultiplier);
		Identify();
	}
}

simulated function BuildDescription()
{
	Super.BuildDescription();
	AddToDescription(CriticalText, CritChancePerLevel);
}

defaultproperties
{
	CriticalText="$1 critical hit chance"
	CritChancePerLevel=0.03
	CritMultiplier=2.00
	DamageBonus=0
	BonusPerLevel=0
	MinModifier=1
	MaxModifier=5
	bCanHaveZeroModifier=False
	ModifierOverlay=Material'EpicParticles.TrueIonShader'
	PatternPos="$W of Critical"
	AIRatingBonus=0.025
}
