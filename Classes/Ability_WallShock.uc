class Ability_WallShock extends RPGAbility;

var config float DamagePerLevel;	// damage per shock pulse for each ability level
var config float ShockInterval;	// seconds between shock pulses

// Electrifies a newly spawned wall. The wall then damages enemy monsters near it on each pulse.
function ModifyWall(RPGDestructibleWall W, Pawn Other) {
	local float Dmg;

	Dmg = float(AbilityLevel) * DamagePerLevel;
	W.EnableShock(int(Dmg), ShockInterval, Other);
}

simulated function string DescriptionText() {
	return Repl(Super.DescriptionText(), "$1", string(int(DamagePerLevel)));
}

defaultproperties {
	AbilityName="Electrified Walls"
Description="Electrifies your newly built walls, shocking monsters that touch them for $1 damage per level."
	DamagePerLevel=10
	ShockInterval=1.0
	StartingCost=2
	CostAddPerLevel=0
	MaxLevel=5
	RequiredAbilities(0)=(AbilityClass=class'Ability_WallPlacer',Level=1)
	Category=class'AbilityCategory_Engineer'
}
