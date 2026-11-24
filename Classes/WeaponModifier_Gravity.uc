class WeaponModifier_Gravity extends RPGWeaponModifier;

#exec OBJ LOAD FILE=EpicParticles.utx

var localized string GravityText;

var config float PullPerLevel;

function AdjustTargetDamage(out int Damage, int OriginalDamage, Pawn Injured, Pawn InstigatedBy, vector HitLocation, out vector Momentum, class<DamageType> DamageType)
{
	local vector PullDir;

	Super.AdjustTargetDamage(Damage, OriginalDamage, Injured, InstigatedBy, HitLocation, Momentum, DamageType);

	if(Damage > 0 && InstigatedBy != None && InstigatedBy != Injured)
	{
		PullDir = InstigatedBy.Location - Injured.Location;
		PullDir.Z = 0;

		if(VSize(PullDir) > 0)
		{
			//horizontal pull towards the shooter
			Momentum = Normal(PullDir) * PullPerLevel * Modifier;
			Identify();
		}
	}
}

simulated function BuildDescription()
{
	Super.BuildDescription();
	AddToDescription(GravityText);
}

defaultproperties
{
	GravityText="pulls targets towards you"
	PullPerLevel=150.00
	DamageBonus=0
	BonusPerLevel=0
	MinModifier=1
	MaxModifier=5
	bCanHaveZeroModifier=False
	ModifierOverlay=Material'EpicParticles.IonRingShader'
	PatternPos="$W of Gravity"
	AIRatingBonus=0.025
}
