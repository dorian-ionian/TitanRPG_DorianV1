class Ability_DodgeSpeed extends RPGAbility;

var config float DodgeZFraction; //dodge height bonus per level, as a fraction of BonusPerLevel

function ModifyPawn(Pawn Other)
{
	Super.ModifyPawn(Other);
	
	if(Other.IsA('xPawn'))
	{
		xPawn(Other).DodgeSpeedFactor = Other.default.DodgeSpeedFactor * (1.0 + BonusPerLevel * float(AbilityLevel));
		xPawn(Other).DodgeSpeedZ = Other.default.DodgeSpeedZ * (1.0 + DodgeZFraction * BonusPerLevel * float(AbilityLevel));
	}
}

simulated function string DescriptionText()
{
	return repl(
		repl(Super.DescriptionText(), "$1", class'Util'.static.FormatPercent(BonusPerLevel)),
		"$2", class'Util'.static.FormatPercent(BonusPerLevel * DodgeZFraction));
}

defaultproperties
{
	AbilityName="Power Dodge"
	StatName="Dodge Speed Bonus"
	Description="Increases your dodge speed by $1 per level (dodge height by $2 per level)."
	MaxLevel=10
	StartingCost=5
	BonusPerLevel=0.05
	DodgeZFraction=0.5
	Category=class'AbilityCategory_Movement'
}
