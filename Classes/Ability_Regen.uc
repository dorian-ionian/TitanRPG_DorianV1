class Ability_Regen extends RPGAbility;

var config float RegenInterval;

replication
{
	reliable if(Role == ROLE_Authority)
		RegenInterval;
}

simulated function string DescriptionText()
{
	return repl(
		repl(Super.DescriptionText(), "$1", class'Util'.static.FormatFloat(BonusPerLevel)),
		"$2", class'Util'.static.FormatFloat(RegenInterval));
}

function ModifyPawn(Pawn Other)
{
	Super.ModifyPawn(Other);
	SetTimer(RegenInterval, true);
}

function Timer()
{
	if(Instigator == None || Instigator.Health <= 0)
	{
		SetTimer(0.0f, false);
		return;
	}
	
	Instigator.GiveHealth(int(BonusPerLevel) * AbilityLevel, Instigator.HealthMax);
}

defaultproperties
{
	BonusPerLevel=1
	RegenInterval=1.000000

	AbilityName="Regeneration"
	Description="Heals $1 health per level every $2 second(s).|Does not heal past starting health amount."
	StartingCost=5
	CostAddPerLevel=5
	MaxLevel=6
	Category=class'AbilityCategory_Health'
}
