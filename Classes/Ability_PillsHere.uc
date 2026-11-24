class Ability_PillsHere extends RPGAbility;

// Returns the multiplier applied to a pill's effect duration for this controller.
static function float GetDurationScale(Controller C)
{
	local RPGPlayerReplicationInfo RPRI;
	local int Level;

	if (C == None)
		return 1.0;

	RPRI = class'RPGPlayerReplicationInfo'.static.GetFor(C);
	if (RPRI == None)
		return 1.0;

	Level = RPRI.HasAbility(class'Ability_PillsHere');
	return 1.0 + float(Level) * class'Ability_PillsHere'.default.BonusPerLevel;
}

simulated function string DescriptionText()
{
	return repl(Super.DescriptionText(), "$1", class'Util'.static.FormatPercent(BonusPerLevel));
}

defaultproperties
{
	AbilityName="Pills Here!"
	Description="Increases the duration of all pill effects by $1 per level."
	MaxLevel=20
	StartingCost=5
	BonusPerLevel=0.05
	Category=class'AbilityCategory_Misc'
}
