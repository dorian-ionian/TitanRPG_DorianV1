class WeaponModifier_Weaken extends RPGWeaponModifier;

#exec OBJ LOAD FILE=XGameShaders.utx

var localized string WeakenText;

var config float WeakenDuration;

function AdjustTargetDamage(out int Damage, int OriginalDamage, Pawn Injured, Pawn InstigatedBy, vector HitLocation, out vector Momentum, class<DamageType> DamageType)
{
	Super.AdjustTargetDamage(Damage, OriginalDamage, Injured, InstigatedBy, HitLocation, Momentum, DamageType);

	if(Damage > 0 && InstigatedBy != None && InstigatedBy != Injured)
	{
		if(class'Effect_Weaken'.static.Create(Injured, InstigatedBy.Controller, WeakenDuration, Modifier) != None)
			Identify();
	}
}

simulated function BuildDescription()
{
	Super.BuildDescription();
	AddToDescription(WeakenText);
}

defaultproperties
{
	WeakenText="weakens targets, who take more damage"
	WeakenDuration=6.00
	DamageBonus=0
	BonusPerLevel=0
	MinModifier=1
	MaxModifier=5
	bCanHaveZeroModifier=False
	ModifierOverlay=Material'XGameShaders.InvisShader'
	PatternPos="$W of Weakness"
	AIRatingBonus=0.025
}
