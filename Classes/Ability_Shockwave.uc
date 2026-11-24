class Ability_Shockwave extends RPGAbility;

//Health fraction at or below which a hit triggers the shockwave
var config float TriggerFraction;
//Radius in which nearby enemies are pushed away at level 1
var config float Radius;
//Extra radius per level above 1
var config float RadiusPerLevel;
//Seconds between shockwaves at level 1
var config float Cooldown;
//Seconds removed from the cooldown per level above 1
var config float CooldownPerLevel;
//Push momentum added per level
var config float PushPerLevel;

var float LastTriggerTime;

function float CurrentRadius()
{
	return Radius + RadiusPerLevel * float(AbilityLevel - 1);
}

function float CurrentCooldown()
{
	return Cooldown - CooldownPerLevel * float(AbilityLevel - 1);
}

function AdjustPlayerDamage(out int Damage, int OriginalDamage, Pawn Injured, Pawn InstigatedBy, vector HitLocation, out vector Momentum, class<DamageType> DamageType)
{
	local Pawn P;
	local vector Dir;
	local float Remaining;

	if(Injured == None || Injured.Health <= 0 || Level.TimeSeconds - LastTriggerTime < CurrentCooldown())
		return;

	Remaining = float(Injured.Health - Damage);
	if(Remaining <= 0.0 || Remaining > Injured.HealthMax * TriggerFraction)
		return;

	LastTriggerTime = Level.TimeSeconds;

	foreach Injured.RadiusActors(class'Pawn', P, CurrentRadius())
	{
		if(P == Injured || P.Health <= 0)
			continue;

		if(Injured.Controller != None && P.Controller != None && Injured.Controller.SameTeamAs(P.Controller))
			continue;

		Dir = Normal(P.Location - Injured.Location);
		Dir.Z = FMax(Dir.Z, 0.2);
		P.TakeDamage(0, Injured, P.Location, Normal(Dir) * PushPerLevel * float(AbilityLevel), class'DamageType');
	}
}

simulated function string DescriptionText()
{
	return repl(Super.DescriptionText(), "$1", class'Util'.static.FormatPercent(TriggerFraction));
}

defaultproperties
{
	AbilityName="Shockwave"
	Description="When a hit leaves you at or below $1 health, you blast nearby enemies away from you. Each extra level pushes them harder and farther, and shortens the cooldown."
	MaxLevel=5
	StartingCost=5
	CostAddPerLevel=5
	TriggerFraction=0.25
	Radius=400.0
	RadiusPerLevel=50.0
	Cooldown=30.0
	CooldownPerLevel=5.0
	PushPerLevel=150000.0
	Category=class'AbilityCategory_Damage'
}
