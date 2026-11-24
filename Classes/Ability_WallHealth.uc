class Ability_WallHealth extends RPGAbility;

// Raises the health of every segment of a newly built wall. The wall has already
// spawned its segments by the time this runs, so the segments are scaled directly.
function ModifyWall(RPGDestructibleWall W, Pawn Other) {
	local RPGWallSegment Seg;
	local float Scale;
	local int i;

	Scale = 1.0 + float(AbilityLevel) * BonusPerLevel;
	W.SegmentHealth = int(float(W.SegmentHealth) * Scale);

	for(i = 0; i < W.Segments.Length; i++) {
		Seg = W.Segments[i];
		if(Seg != None) {
			Seg.MaxHealth = int(float(Seg.MaxHealth) * Scale);
			Seg.Health = int(float(Seg.Health) * Scale);
		}
	}
}

simulated function string DescriptionText() {
	return Repl(Super.DescriptionText(), "$1", class'Util'.static.FormatPercent(BonusPerLevel));
}

defaultproperties {
	AbilityName="Reinforced Walls"
	Description="Increases the health of your newly built walls by $1 per level."
	BonusPerLevel=0.10
	StartingCost=2
	CostAddPerLevel=0
	MaxLevel=5
	RequiredAbilities(0)=(AbilityClass=class'Ability_WallPlacer',Level=1)
	Category=class'AbilityCategory_Engineer'
}
