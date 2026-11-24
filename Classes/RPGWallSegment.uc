//=============================================================================
// RPGWallSegment.
// A single tile that makes up part of an RPGDestructibleWall. Has its own
// health, so it can be shot out to leave a hole in the wall.
//=============================================================================
class RPGWallSegment extends StaticMeshActor
	placeable;

var RPGDestructibleWall ParentWall;
var() int MaxHealth;
var int Health;
var() class<Emitter> DestroyedEffectClass;
var() Sound DestroyedSound;
var() float DestroyedVolume;
var bool bDestroyed;
var bool bFloorAnchored;	// bottom-row tiles rest on the real floor rather than another segment, and never fall
var() float ProbeDistance;	// how far to probe for the next tile up/down the column; set by the wall to the real row pitch
var float NetScaleX;	// Actor doesn't replicate DrawScale3D, so the wall sends the tile's real scale here (as floats; a replicated vector never reached clients)
var float NetScaleYZ;
var int NetYaw;	// Rotation isn't reliably replicated for static tiles, so the yaw the wall gave the tile is sent here
var rotator LockedRot;	// yaw-only rotation the wall gave this tile; a falling tile is held to it so it drops straight down


replication
{
	reliable if (Role == ROLE_Authority)
		Health, bDestroyed, NetScaleX, NetScaleYZ, NetYaw;
}

simulated event PostNetBeginPlay()
{
	Super.PostNetBeginPlay();
	ApplyNetScale();
}

simulated event PostNetReceive()
{
	Super.PostNetReceive();
	ApplyNetScale();
}

simulated function ApplyNetScale()
{
	local vector S3D;
	local rotator R;

	if (NetScaleX > 0 && NetScaleYZ > 0)
	{
		S3D.X = NetScaleX;
		S3D.Y = NetScaleYZ;
		S3D.Z = NetScaleYZ;
		SetDrawScale3D(S3D);
	}
	if (Role < ROLE_Authority)
	{
		R.Yaw = NetYaw;
		SetRotation(R);
	}
}

event PostBeginPlay()
{
	Super.PostBeginPlay();

	Health = MaxHealth;

	// Periodically re-verify support in case an event-driven notification is missed.
	SetTimer(0.5, true);
}

event TakeDamage(int Damage, Pawn EventInstigator, vector HitLocation, vector Momentum, class<DamageType> DamageType)
{
	if (bDestroyed || !bCanBeDamaged)
		return;

	Health -= Damage;

	if (Health <= 0)
		BlowUp();
}

function BlowUp()
{
	if (bDestroyed)
		return;

	bDestroyed = True;
	bCanBeDamaged = False;
	bProjTarget = False;
	bHidden = True;
	SetCollision(false, false, false);

	if (DestroyedEffectClass != None)
		Spawn(DestroyedEffectClass,,, Location, Rotation);

	if (DestroyedSound != None)
		PlaySound(DestroyedSound, SLOT_None, DestroyedVolume,, 512.0,, true);

	if (ParentWall != None)
		ParentWall.NotifySegmentDestroyed(self);

	// Whatever was resting on top of us just lost its support; let it fall now.
	NotifySupportAbove();
}

// How far to probe up/down for the neighboring tile in the same column.
function float SegmentProbeDist()
{
	if (ProbeDistance > 0)
		return ProbeDistance;

	return CollisionHeight * 2 + 4;
}

// Re-checks the tile directly above, so a broken support chain cascades up the column.
// Depth guards against runaway recursion.
function NotifySupportAbove(optional int Depth)
{
	local vector HitLocation, HitNormal;
	local Actor HitActor;

	if (Depth >= 100)
		return;

	HitActor = Trace(HitLocation, HitNormal, Location + vect(0,0,1) * SegmentProbeDist(), Location, true, vect(4,4,4));
	if (RPGWallSegment(HitActor) != None)
		RPGWallSegment(HitActor).CheckSupport(Depth + 1);
}

// Falls only if no other intact segment is directly beneath it.
function CheckSupport(optional int Depth)
{
	local vector HitLocation, HitNormal;
	local Actor HitActor;

	if (bDestroyed)
		return;

	if (bFloorAnchored)
	{
		SetPhysics(PHYS_None);
		return;
	}

	HitActor = Trace(HitLocation, HitNormal, Location - vect(0,0,1) * SegmentProbeDist(), Location, true, vect(4,4,4));

	// A pawn pressed against the wall can block this probe; that says nothing about our support.
	if (Pawn(HitActor) != None)
		return;

	// A segment that is itself already falling is not solid support.
	if (RPGWallSegment(HitActor) != None && !RPGWallSegment(HitActor).bDestroyed && RPGWallSegment(HitActor).Physics == PHYS_None)
	{
		SetPhysics(PHYS_None);
		return;
	}

	SetPhysics(PHYS_Falling);
	NotifySupportAbove(Depth + 1);
}

event Timer()
{
	CheckSupport();
}

// Falling physics can rotate the tile; hold it to the wall's yaw so it drops straight down.
event Tick(float DeltaTime)
{
	Super.Tick(DeltaTime);

	if (Role == ROLE_Authority && Physics == PHYS_Falling && Rotation != LockedRot)
		SetRotation(LockedRot);
}

defaultproperties
{
     MaxHealth=50
     StaticMesh=StaticMesh'DemoMeshes.SmoothCube_01'
     Skins(0)=FinalBlend'XEffectMat.Shield.Shield3rdFB'
     AmbientGlow=255
     bUnlit=True
     bStatic=False
     bWorldGeometry=False
     bNoDelete=False
     bNetNotify=True
     bCanBeDamaged=True
     bBlockActors=True
     bBlockPlayers=True
     bCollideActors=True
     bCollideWorld=True
     bProjTarget=True
     bShadowCast=False
     bUseDynamicLights=True
     RemoteRole=ROLE_SimulatedProxy
}
