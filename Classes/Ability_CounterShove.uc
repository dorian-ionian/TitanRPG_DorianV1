class Ability_CounterShove extends RPGAbility;

var config float MomentumPerLevel; //fraction of the momentum returned per level
var config float MaxLevelMomentum; //fraction returned at max level
var config float VehicleMomentumPerLevel; //fraction returned per level when hit by a vehicle

simulated function string DescriptionText()
{
	return repl(
		repl(Super.DescriptionText(), "$1", class'Util'.static.FormatPercent(MomentumPerLevel)),
		"$2", class'Util'.static.FormatPercent(MaxLevelMomentum));
}

function AdjustPlayerDamage(out int Damage, int OriginalDamage, Pawn Injured, Pawn InstigatedBy, vector HitLocation, out vector Momentum, class<DamageType> DamageType)
{
	local float MomentumMod;
	
	if(VSize(Momentum) <= 0)
		return;

	if(DamageType == class'DamTypeCounterShove' || DamageType == class'DamTypeRetaliation')
		return;

	if(InstigatedBy == Injured || InstigatedBy == None || Injured.Controller.SameTeamAs(InstigatedBy.Controller))
		return;

	if(Injured.isA('Vehicle'))
	{
		MomentumMod = -(VehicleMomentumPerLevel * float(AbilityLevel));
	}
	else
    {
		if(AbilityLevel < MaxLevel)
			MomentumMod = -(MomentumPerLevel * float(AbilityLevel));
		else
			MomentumMod = -MaxLevelMomentum;
	}

	//TODO: RPGEffect
	InstigatedBy.TakeDamage(0, Injured, InstigatedBy.Location, (Momentum * Injured.Mass) * MomentumMod, class'DamTypeCounterShove');
}

defaultproperties
{
	AbilityName="Counter Shove"
	Description="Whenever you are damaged by another player, $1 of the momentum per level is also done to the player who hurt you (or $2 at max level)|Will not counter counter shove or retaliation."
	StartingCost=5
	CostAddPerLevel=5
	MaxLevel=5
	MomentumPerLevel=0.75
	MaxLevelMomentum=4.0
	VehicleMomentumPerLevel=0.0075
	ForbiddenAbilities(0)=(AbilityClass=class'Ability_IronLegs',Level=1)
    ForbiddenAbilities(1)=(AbilityClass=class'Ability_Retaliation',Level=1)
	Category=class'AbilityCategory_Damage'
}
