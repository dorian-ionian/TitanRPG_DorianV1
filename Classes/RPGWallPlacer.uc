//=============================================================================
// RPGWallPlacer.
// A Translocator variant granted by Ability_WallPlacer. Firing tosses a beacon
// like the standard Translocator; firing the second mode while the beacon is out
// conjures an RPGDestructibleWall at the beacon's location instead of teleporting.
//=============================================================================
class RPGWallPlacer extends TransLauncher;

var() class<RPGDestructibleWall> WallClass;
var() int MaxWalls;	// hard cap on how many walls this weapon's owner may have alive at once

// Counts this weapon's own still-alive walls, so Translocate() can refuse to
// spawn another once MaxWalls is reached.
function int CountWalls()
{
	local RPGDestructibleWall W;
	local int Count;

	foreach AllActors(class'RPGDestructibleWall', W)
	{
		if (W.Owner == self)
			Count++;
	}

	return Count;
}

// Returns the wall type of the wall variant artifact the owner has selected, or
// WallClass when no variant is selected.
function class<RPGDestructibleWall> GetWallClass()
{
	local ArtifactBase_WallVariant Variant;

	if (Pawn(Owner) != None)
	{
		Variant = ArtifactBase_WallVariant(Pawn(Owner).SelectedItem);
		if (Variant != None && Variant.WallClass != None)
			return Variant.WallClass;
	}

	return WallClass;
}

// Demolishes this weapon's walls: all of them when bAll, otherwise only the newest.
// Returns how many walls were demolished.
function int DemolishWalls(bool bAll)
{
	local RPGDestructibleWall W, Newest;
	local int Count;

	foreach AllActors(class'RPGDestructibleWall', W)
	{
		if (W.Owner != self || W.bDestroyed)
			continue;

		if (bAll)
		{
			W.Demolish();
			Count++;
		}
		else if (Newest == None || W.SpawnTime > Newest.SpawnTime)
		{
			Newest = W;
		}
	}

	if (!bAll && Newest != None)
	{
		Newest.Demolish();
		Count = 1;
	}

	return Count;
}

defaultproperties
{
     WallClass=class'RPGDestructibleWall'
     MaxWalls=2
     AmmoChargeF=3.000000
     RepAmmo=3
     AmmoChargeMax=3.000000
     AmmoChargeRate=0.100000
     FireModeClass(1)=Class'RPGWallPlacerFire'
     PickupClass=None
     ItemName="Wall Placer"
     Description="A modified Translocator. Firing tosses a beacon just like the standard translocator; firing again while it's deployed raises a destructible barrier at the beacon's location instead of teleporting you there."
}
