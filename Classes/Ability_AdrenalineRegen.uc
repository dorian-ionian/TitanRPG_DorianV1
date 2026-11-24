class Ability_AdrenalineRegen extends RPGAbility;

//Level lines are rebuilt from the config values so they match ModifyPawn and BonusPerLevel
simulated function string DescriptionText()
{
	local int lv;
	local string amount;

	amount = class'Util'.static.FormatFloat(BonusPerLevel);
	LevelDescription.Length = MaxLevel;
	for(lv = 0; lv < MaxLevel; lv++)
		LevelDescription[lv] = "At level" @ string(lv + 1) @ "you get" @ amount @ "adrenaline every" @ string(MaxLevel - lv) @ "second(s).";

	return Super.DescriptionText();
}

function ModifyPawn(Pawn Other)
{
	Super.ModifyPawn(Other);
	
	SetTimer((MaxLevel - AbilityLevel) + 1, true);
}

function Timer()
{
	if(Instigator == None || Instigator.Health <= 0)
	{
		SetTimer(0.0f, false);
		return;
	}

	if(!Instigator.InCurrentCombo() &&
		!class'RPGArtifact'.static.HasActiveArtifact(Instigator))
	{
		RPRI.Controller.AwardAdrenaline(BonusPerLevel); //BonusPerLevel is a constant
	}
}

defaultproperties
{
	BonusPerLevel=1
	AbilityName="Adrenal Drip"
	Description="Slowly drips adrenaline into your system."
	StartingCost=10
	CostAddPerLevel=5
	MaxLevel=3
	Category=class'AbilityCategory_Adrenaline'
}
