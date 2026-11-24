class WeaponModifier_Burning extends RPGWeaponModifier;

#exec OBJ LOAD FILE=EpicParticles.utx

var localized string BurningText;

var config float BurnDuration;
var config int BurnDamagePerLevel; //damage per second, per modifier level

function AdjustTargetDamage(out int Damage, int OriginalDamage, Pawn Injured, Pawn InstigatedBy, vector HitLocation, out vector Momentum, class<DamageType> DamageType)
{
	local Effect_Burning Burn;

	Super.AdjustTargetDamage(Damage, OriginalDamage, Injured, InstigatedBy, HitLocation, Momentum, DamageType);

	if(Damage > 0 && InstigatedBy != None)
	{
		Burn = Effect_Burning(class'Effect_Burning'.static.Create(Injured, InstigatedBy.Controller, BurnDuration, Modifier));
		if(Burn != None)
		{
			Burn.AbsDrainPerLevel = BurnDamagePerLevel;
			Identify();
			Burn.Start();
		}
	}
}

simulated function BuildDescription()
{
	Super.BuildDescription();
	AddToDescription(BurningText);
}

defaultproperties
{
	BurningText="sets targets on fire"
	BurnDuration=5.00
	BurnDamagePerLevel=5
	DamageBonus=0
	BonusPerLevel=0
	MinModifier=1
	MaxModifier=5
	bCanHaveZeroModifier=False
	ModifierOverlay=Material'EpicParticles.FireFinal'
	PatternPos="$W of Burning"
	AIRatingBonus=0.025
}
