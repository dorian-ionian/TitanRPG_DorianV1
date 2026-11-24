class Ability_WallPlacer extends RPGAbility;

// Replaces the stock Translocator with an RPGWallPlacer while owned. Higher levels
// allow more walls alive at once.
function ModifyPawn(Pawn Other) {
	local TransLauncher Stock;
	local RPGWallPlacer Placer;
	local bool bSelect;

	Super.ModifyPawn(Other);

	GrantWallVariants(Other);

	Placer = RPGWallPlacer(Other.FindInventoryType(class'RPGWallPlacer'));
	if(Placer != None) {
		Placer.MaxWalls = AbilityLevel;
		return;
	}

	Stock = TransLauncher(Other.FindInventoryType(class'TransLauncher'));
	if(Stock != None) {
		bSelect = (Stock == Other.Weapon);
		Stock.Destroy();
	}

	Placer = Other.Spawn(class'RPGWallPlacer', Other);
	if(Placer != None) {
		Placer.MaxWalls = AbilityLevel;
		Placer.GiveTo(Other);

		if(bSelect) {
			Other.PendingWeapon = Placer;
			Other.ChangedWeapon();
		}
	}
}

// Grants every wall type artifact and the demolish artifacts. The Wall Placer uses whichever wall type is selected.
function GrantWallVariants(Pawn Other) {
	class'Util'.static.GiveInventory(Other, class'Artifact_WallLowCover');
	class'Util'.static.GiveInventory(Other, class'Artifact_WallTough');
	class'Util'.static.GiveInventory(Other, class'Artifact_WallThick');
	class'Util'.static.GiveInventory(Other, class'Artifact_WallSingleColumn');
	class'Util'.static.GiveInventory(Other, class'Artifact_WallCurved');
	class'Util'.static.GiveInventory(Other, class'Artifact_WallHalfDome');
	class'Util'.static.GiveInventory(Other, class'Artifact_DemolishLastWall');
	class'Util'.static.GiveInventory(Other, class'Artifact_DemolishAllWalls');
}

defaultproperties {
	AbilityName="Wall Placer"
	Description="Replaces your Translocator with a wall placer. Fire the beacon, then fire again to raise a segmented destructible barrier at its location. Monsters will attack the wall, and bots can hop over it. Higher levels allow more walls at once. Select a wall type artifact to choose the wall shape you build."
	StartingCost=5
	CostAddPerLevel=0
	MaxLevel=3
	Category=class'AbilityCategory_Engineer'
}
