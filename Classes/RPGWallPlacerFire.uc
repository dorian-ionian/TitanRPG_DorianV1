//=============================================================================
// RPGWallPlacerFire.
// Replaces TransRecall's teleport-to-beacon behavior with spawning an
// RPGDestructibleWall at the beacon's location, facing the player's direction.
//=============================================================================
class RPGWallPlacerFire extends TransRecall;

function Translocate()
{
	local TransBeacon Beacon;
	local RPGWallPlacer Placer;
	local rotator SpawnRot;
	local RPGDestructibleWall NewWall;
	local RPGPlayerReplicationInfo RPRI;

	Placer = RPGWallPlacer(Weapon);
	if (Placer == None || Placer.TransBeacon == None)
		return;

	Beacon = Placer.TransBeacon;

	if (Beacon.Disrupted())
	{
		if (PlayerController(Instigator.Controller) != None)
			PlayerController(Instigator.Controller).ClientPlaySound(TransFailedSound);
	}
	else if (Beacon.Physics != PHYS_None)
	{
		// Beacon is still airborne; let it come to rest first.
		if (PlayerController(Instigator.Controller) != None)
			PlayerController(Instigator.Controller).ClientPlaySound(TransFailedSound);
		return;
	}
	else if (Placer.GetWallClass() != None)
	{
		if (Placer.CountWalls() >= Placer.MaxWalls)
		{
			if (PlayerController(Instigator.Controller) != None)
			{
				PlayerController(Instigator.Controller).ClientPlaySound(TransFailedSound);
				PlayerController(Instigator.Controller).ClientMessage("You already have the maximum number of walls (" $ Placer.MaxWalls $ ").");
			}
		}
		else
		{
			// Face the way the player was facing so the wall's gap-fitting traces line up.
			SpawnRot = Instigator.Rotation;
			SpawnRot.Pitch = 0;
			SpawnRot.Roll = 0;

			// Owner is set explicitly so CountWalls() can attribute the wall to this weapon.
			// The wall destroys itself in PostBeginPlay if it's too close to another wall,
			// which makes Spawn() return None here.
			NewWall = Weapon.Spawn(Placer.GetWallClass(), Weapon,, Beacon.Location, SpawnRot);
			if (NewWall != None)
			{
				Placer.ReduceAmmo();
				RPRI = class'RPGPlayerReplicationInfo'.static.GetForPRI(Instigator.PlayerReplicationInfo);
				if (RPRI != None)
					RPRI.AddWall(NewWall);
			}
			else if (PlayerController(Instigator.Controller) != None)
				PlayerController(Instigator.Controller).ClientPlaySound(TransFailedSound);
		}
	}

	Beacon.Destroy();
	Placer.TransBeacon = None;
	Placer.ViewPlayer();
}
