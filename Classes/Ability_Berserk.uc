class Ability_Berserk extends RPGAbility;

//Health fraction below which the bonus starts to build; it reaches full strength at 0 health
var config float HealthThreshold;

function AdjustTargetDamage(out int Damage, int OriginalDamage, Pawn Injured, Pawn InstigatedBy, vector HitLocation, out vector Momentum, class<DamageType> DamageType)
{
	local float Missing;

	if(InstigatedBy == None || InstigatedBy.Health <= 0 || InstigatedBy.HealthMax <= 0)
		return;

	Missing = 1.0 - float(InstigatedBy.Health) / (InstigatedBy.HealthMax * HealthThreshold);
	if(Missing <= 0.0)
		return;

	Missing = FMin(Missing, 1.0);
	Damage = float(Damage) * (1.0 + float(AbilityLevel) * BonusPerLevel * Missing);
}

simulated function string DescriptionText()
{
	return repl(Super.DescriptionText(), "$1", class'Util'.static.FormatPercent(BonusPerLevel));
}

defaultproperties
{
	AbilityName="Berserk"
	Description="Below half health, the lower your health, the more damage you deal: when nearly dead, you deal $1 more damage per level."
	MaxLevel=5
	StartingCost=5
	CostAddPerLevel=5
	BonusPerLevel=0.10
	HealthThreshold=0.50
	Category=class'AbilityCategory_Damage'
}
