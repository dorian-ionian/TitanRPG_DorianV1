class Ability_Ambush extends RPGAbility;

//Dot product of the victim's facing and the direction to the attacker; below this the attacker counts as behind the victim
var config float RearDotLimit;

function AdjustTargetDamage(out int Damage, int OriginalDamage, Pawn Injured, Pawn InstigatedBy, vector HitLocation, out vector Momentum, class<DamageType> DamageType)
{
	local vector ToAttacker;

	if(Injured == None || InstigatedBy == None || Injured == InstigatedBy || Injured.Health <= 0)
		return;

	if(Injured.Controller != None && InstigatedBy.Controller != None && Injured.Controller.SameTeamAs(InstigatedBy.Controller))
		return;

	ToAttacker = Normal(InstigatedBy.Location - Injured.Location);
	if(Normal(vector(Injured.Rotation)) dot ToAttacker > RearDotLimit)
		return;

	Damage = float(Damage) * (1.0 + float(AbilityLevel) * BonusPerLevel);
}

simulated function string DescriptionText()
{
	return repl(Super.DescriptionText(), "$1", class'Util'.static.FormatPercent(BonusPerLevel));
}

defaultproperties
{
	AbilityName="Ambush"
	Description="You deal $1 more damage per level when you attack enemies from behind."
	MaxLevel=5
	StartingCost=5
	CostAddPerLevel=5
	BonusPerLevel=0.15
	RearDotLimit=-0.5
	Category=class'AbilityCategory_Damage'
}
