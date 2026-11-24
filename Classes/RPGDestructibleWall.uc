//=============================================================================
// RPGDestructibleWall.
// A destructible barrier that auto-sizes itself to fill the gap at the spot it
// is spawned into. Composed of small RPGWallSegment tiles so it conforms to
// irregular gaps. Monsters are redirected to shoot it; bots hop over it.
//=============================================================================
class RPGDestructibleWall extends StaticMeshActor
	placeable;

var() int SegmentHealth;	// health given to each individual tile
var() class<Emitter> DestroyedEffectClass;
var() Sound DestroyedSound;
var() float DestroyedVolume;	// volume of the destroyed sound for each tile
var() bool bAutoFit;			// if true, resize/recenter to the surrounding gap on spawn
var() float MaxTraceDistance;	// how far to search for floor/ceiling/side walls
var() float FitMargin;			// shrink the fitted footprint by this many units per side
var() float DefaultOpenDistance;	// assumed reach when a direction's trace finds nothing
var() float MinWallSpacing;	// a new wall aborts its spawn if another wall exists within this distance
var() float SegmentSizeFactor;	// final size of each tile as a fraction of the auto-fit pitch
var() float WallThicknessFactor;	// depth of each tile as a fraction of its square face edge
var() float ArcBulgeFactor;	// 0 keeps the wall straight; otherwise it bows forward by this fraction of its chord
var() float MinFitScale;
var() float MaxFitScale;
var() float MaxHeightToFloorRatio;	// caps wall height to this multiple of the local floor distance
var() float MaxWallHeight;		// hard absolute ceiling on wall height
var() float MaxWallLength;		// hard absolute ceiling on overall wall length, in Unreal units
var() int MaxRowsPerColumn;	// hard cap on tile rows per column
var() int MaxColumns;		// hard cap on tile columns
var() float WallLifetime;	// wall expires after this many seconds
var() bool bAttractsMonsters;	// if true, periodically redirects nearby monsters into shooting the wall
var() float MinAttackRange;	// AI closer than this won't be redirected to shoot a real enemy
var() float WallMinAttackRange;	// same idea as MinAttackRange but for wall targets
var() float BotAggroRadius;	// bots within this range of the wall are checked for the jump-over behavior
var() float MonsterAggroRadius;	// monsters within this range are redirected to attack the wall
var() float BotJumpTriggerRange;	// bots within this range of a blocking segment try to jump over it
var() float BotScanInterval;	// how often (seconds) to look for AI to target the wall
// Hosted on the visible segments rather than this hidden manager, since hidden actors'
// ambient sound plays flat with no distance falloff.
var() Sound WallHumSound;
var() float WallHumRadius;
var() byte WallHumVolume;
var() ESoundOcclusion WallHumOcclusion;
var bool bDestroyed;
var array<RPGWallSegment> Segments;	// tiles that make up the visible/blocking wall
var int ActiveSegments;	// how many tiles are currently intact
var array<Controller> PendingDoubleJumps;	// bots mid-jump, waiting for the apex to add the second boost
var float SpawnTime;	// Level.TimeSeconds when this wall spawned, for WallLifetime expiry
var() float ShockTouchMargin;	// extra clearance, in units, that still counts as a monster touching a segment
var int ShockDamage;	// damage per shock pulse; 0 means the wall isn't electrified
var float ShockInterval;	// seconds between shock pulses
var float NextShockTime;	// Level.TimeSeconds of the next shock pulse
var Pawn ShockInstigator;	// pawn credited with shock damage

replication
{
	reliable if (Role == ROLE_Authority)
		bDestroyed;
}

event PostBeginPlay()
{
	Super.PostBeginPlay();

	if (IsAnotherWallTooClose())
	{
		Destroy();
		return;
	}

	// This actor is just a size/position manager; the segments are what players see and shoot.
	bHidden = True;
	SetCollision(false, false, false);

	if (Role == ROLE_Authority)
	{
		SpawnTime = Level.TimeSeconds;

		if (bAutoFit)
			FitToGap();

		if (bAttractsMonsters)
			SetTimer(BotScanInterval, false);
	}
}

event Destroyed()
{
	DestroySegments();
	Super.Destroyed();
}

// True if another already-existing wall is within MinWallSpacing of this one.
function bool IsAnotherWallTooClose()
{
	local RPGDestructibleWall W;

	foreach AllActors(class'RPGDestructibleWall', W)
	{
		if (W != self && VSize(W.Location - Location) < MinWallSpacing)
			return true;
	}
	return false;
}

// Traces like Trace(), but skips over hits on our own tiles or other walls,
// continuing toward the real end point so fitting near existing walls measures the real gap.
function float TraceDistance(vector Start, vector Dir, float MaxDist, vector Extent, float DefaultDist)
{
	local vector CurStart, HitLocation, HitNormal;
	local float Traveled, Budget;
	local Actor HitActor;
	local int Iterations;

	CurStart = Start;
	Budget = MaxDist;

	while (Iterations < 8 && Budget > 0)
	{
		HitActor = Trace(HitLocation, HitNormal, CurStart + Dir * Budget, CurStart, true, Extent);
		if (HitActor == None)
			return DefaultDist;

		Traveled += VSize(HitLocation - CurStart);

		if (RPGWallSegment(HitActor) == None && RPGDestructibleWall(HitActor) == None)
			return Traveled;

		Budget -= VSize(HitLocation - CurStart) + 1;
		CurStart = HitLocation + Dir * 1;
		Iterations++;
	}

	return DefaultDist;
}

// Direction of the arc's tangent at Along. Straight walls return SideDir; curved walls bow
// forward (Fwd) by Sag at the middle and meet the chord at the ends.
function vector ArcDir(vector SideDir, vector Fwd, float Along, float HalfWidth, float Sag)
{
	local float U, Slope;

	if (Sag == 0 || HalfWidth <= 0)
		return SideDir;

	U = FClamp(Along / HalfWidth, -1, 1);
	Slope = -2 * Sag * U / HalfWidth;
	return Normal(SideDir + Fwd * Slope);
}

// Traces up/down and to both sides to find the overall gap, then re-traces floor and
// ceiling per column so stepped or sloped terrain produces a wall that hugs the real boundary.
function FitToGap()
{
	local vector SideDir, TraceExtent, GapCenter;
	local vector TileLoc, SegScale3D, ColCenter, P, NextP, TileDir;
	local float AlongP;
	local plane Bounds;
	local float BaseSize;
	local float FloorDist, CeilingDist, LeftDist, RightDist;
	local float GapWidth, EstGapHeight, EstEdge, GridBottomZ;
	local float ColFloorDist, ColCeilingDist, ColGapHeight, HeightScale, TileScale, TileEdge;
	local int NumCols, NumRows, ColRows, Col, Row, TotalSegments, ScaledHumVolume;
	local RPGWallSegment NewSegment;
	local rotator TileRot, ColRot;
	local vector Fwd;
	local float ArcHalf, ArcSag;
	local int YawOff;
	local float FloorZ, CeilZ, ColBottomZ, HalfTile;
	local int RowsUp;
	local vector WallHit, WallHitNormal;

	DestroySegments();

	// Tiles stay upright: only yaw is used, so the aim pitch of the placer doesn't tilt them.
	TileRot.Pitch = 0;
	TileRot.Yaw = Rotation.Yaw;
	TileRot.Roll = 0;

	// Derive the mesh's real unscaled size from its render bounds.
	Bounds = GetRenderBoundingSphere();
	BaseSize = Bounds.W * 1.1547; // side length of a cube circumscribed by this sphere

	if (BaseSize < 1.0)
		BaseSize = 128.0;

	TraceExtent = vect(8,8,8);

	FloorDist = TraceDistance(Location, vect(0,0,-1), MaxTraceDistance, TraceExtent, DefaultOpenDistance);
	CeilingDist = TraceDistance(Location, vect(0,0,1), MaxTraceDistance, TraceExtent, DefaultOpenDistance);

	SideDir = Normal(vector(TileRot) Cross vect(0,0,1));

	RightDist = TraceDistance(Location, SideDir, MaxTraceDistance, TraceExtent, DefaultOpenDistance);
	LeftDist = TraceDistance(Location, -SideDir, MaxTraceDistance, TraceExtent, DefaultOpenDistance);

	LeftDist  = FMax(0, LeftDist - FitMargin);
	RightDist = FMax(0, RightDist - FitMargin);
	GapWidth = LeftDist + RightDist;

	FloorDist   = FMax(0, FloorDist - FitMargin);
	CeilingDist = FMax(0, CeilingDist - FitMargin);

	GapWidth = FMax(GapWidth, BaseSize * MinFitScale);
	GapWidth = FMin(GapWidth, MaxWallLength);

	NumRows = Max(1, MaxRowsPerColumn);

	// Estimate the column count from the overall gap, then re-derive each column's real edge
	// and pack columns using only that real edge, so gaps between columns stay exact.
	EstGapHeight = FMin(FMax(FloorDist + CeilingDist, BaseSize * MinFitScale), MaxWallHeight);
	EstEdge = FClamp(EstGapHeight / NumRows / BaseSize, MinFitScale, MaxFitScale) * BaseSize;
	NumCols = Min(Max(1, int(GapWidth / EstEdge + 0.5)), MaxColumns);

	// Each tile plays the hum, scaled down by the tile count so overlapping copies don't stack loud.
	TotalSegments = Max(1, NumCols * NumRows);
	ScaledHumVolume = Max(1, WallHumVolume / TotalSegments);

	// Never recenter away from Location; the wall lands exactly where it was placed.
	GapCenter = Location;

	// One tile size for the whole wall, so every column shares the same grid and rows line up.
	TileScale = EstEdge / BaseSize;
	TileEdge = EstEdge;
	SegScale3D.X = TileScale * WallThicknessFactor;
	SegScale3D.Y = TileScale;
	SegScale3D.Z = TileScale;

	// Shared row grid, anchored at the bottom of a full-height wall centered on Location.
	GridBottomZ = Location.Z - NumRows * TileEdge * 0.5;

	Fwd = vector(TileRot);
	ArcHalf = NumCols * EstEdge * 0.5;
	ArcSag = ArcBulgeFactor * NumCols * EstEdge;

	// Columns are laid end to end along the arc: each tile starts where the previous one ends,
	// so joints meet with no gaps or overlaps. P is the current left edge, on the arc.
	P = GapCenter - SideDir * ArcHalf;

	for (Col = 0; Col < NumCols; Col++)
	{
		// Aim the tile along the arc at its midpoint; refine once using the actual chord.
		AlongP = (P - GapCenter) dot SideDir;
		TileDir = ArcDir(SideDir, Fwd, AlongP + TileEdge * 0.5, ArcHalf, ArcSag);
		NextP = P + TileDir * TileEdge;
		TileDir = ArcDir(SideDir, Fwd, AlongP + ((NextP - P) dot SideDir) * 0.5, ArcHalf, ArcSag);
		NextP = P + TileDir * TileEdge;

		ColCenter = P + TileDir * (TileEdge * 0.5);
		YawOff = Rotator(TileDir).Yaw - Rotator(SideDir).Yaw;
		ColRot.Pitch = 0;
		ColRot.Yaw = (TileRot.Yaw + YawOff) & 65535;
		ColRot.Roll = 0;
		P = NextP;

		// Skip columns the wall's center can't see past map geometry, so tiles never sink into a wall.
		HalfTile = TileEdge * 0.5 * SegmentSizeFactor;
		if (Trace(WallHit, WallHitNormal, Location, ColCenter, false, vect(1,1,1) * HalfTile) != None)
			continue;

		// Re-trace floor/ceiling at this column's own position.
		ColFloorDist = TraceDistance(ColCenter, vect(0,0,-1), MaxTraceDistance, TraceExtent, DefaultOpenDistance);
		ColCeilingDist = TraceDistance(ColCenter, vect(0,0,1), MaxTraceDistance, TraceExtent, DefaultOpenDistance);

		ColFloorDist   = FMax(0, ColFloorDist - FitMargin);
		ColCeilingDist = FMax(0, ColCeilingDist - FitMargin);

		// Limit reach relative to the floor beneath, so a tall atrium or ledge doesn't spawn a huge stack.
		ColCeilingDist = FMin(ColCeilingDist, FMax(ColFloorDist, BaseSize) * MaxHeightToFloorRatio);
		ColFloorDist   = FMin(ColFloorDist, FMax(ColCeilingDist, BaseSize) * MaxHeightToFloorRatio);

		// Hard absolute cap on total height.
		HeightScale = ColFloorDist + ColCeilingDist;
		if (HeightScale > MaxWallHeight && HeightScale > 0)
		{
			HeightScale = MaxWallHeight / HeightScale;
			ColFloorDist   *= HeightScale;
			ColCeilingDist *= HeightScale;
		}

		ColGapHeight   = FMax(ColFloorDist + ColCeilingDist, BaseSize * MinFitScale);

		// A pillar or prop can collapse one column's trace far below the wall's real gap.
		// Only a drastic collapse (under half) is treated as an obstruction glitch.
		if (ColGapHeight < EstGapHeight * 0.5)
			ColGapHeight = EstGapHeight;

		// Rows stay on the shared grid, but a column's bottom row never sinks below its floor
		// and its top row never rises above its ceiling.
		FloorZ = ColCenter.Z - ColFloorDist;
		CeilZ  = ColCenter.Z + ColCeilingDist;
		ColBottomZ = GridBottomZ;
		if (FloorZ > ColBottomZ)
		{
			RowsUp = int((FloorZ - GridBottomZ) / TileEdge + 0.999);
			ColBottomZ = GridBottomZ + RowsUp * TileEdge;
		}

		ColRows = Min(Max(int(ColGapHeight / TileEdge + 0.5), 1), NumRows);
		ColRows = Min(ColRows, Max(int((CeilZ - ColBottomZ) / TileEdge), 0));

		for (Row = 0; Row < ColRows; Row++)
		{
			TileLoc = ColCenter;
			TileLoc.Z = ColBottomZ + (Row + 0.5) * TileEdge;

			NewSegment = Spawn(class'RPGWallSegment',,, TileLoc, ColRot);
			if (NewSegment != None)
			{
				NewSegment.SetRotation(ColRot);
				NewSegment.LockedRot = ColRot;
				NewSegment.NetYaw = ColRot.Yaw;
				NewSegment.ParentWall = self;
				NewSegment.MaxHealth = SegmentHealth;
				NewSegment.Health = SegmentHealth;
				NewSegment.DestroyedEffectClass = DestroyedEffectClass;
				NewSegment.DestroyedSound = DestroyedSound;
				NewSegment.DestroyedVolume = DestroyedVolume;
				NewSegment.NetScaleX = SegScale3D.X * SegmentSizeFactor;
				NewSegment.NetScaleYZ = SegScale3D.Y * SegmentSizeFactor;
				NewSegment.SetDrawScale3D(SegScale3D * SegmentSizeFactor);
				NewSegment.SetCollisionSize(TileEdge * 0.5 * SegmentSizeFactor, TileEdge * 0.5 * SegmentSizeFactor);
				// Probe reach uses the real row pitch, not the possibly shrunken collision size.
				NewSegment.ProbeDistance = TileEdge + 4;
				NewSegment.bFloorAnchored = (Row == 0);
				NewSegment.CheckSupport();

				if (WallHumSound != None)
				{
					NewSegment.AmbientSound = WallHumSound;
					NewSegment.SoundRadius = WallHumRadius;
					NewSegment.SoundVolume = ScaledHumVolume;
					NewSegment.SoundOcclusion = WallHumOcclusion;
				}

				Segments[Segments.Length] = NewSegment;
			}
		}

	}

	ActiveSegments = Segments.Length;
}

function DestroySegments()
{
	local int i;

	for (i = 0; i < Segments.Length; i++)
	{
		if (Segments[i] != None)
			Segments[i].Destroy();
	}
	Segments.Length = 0;
}

// Blows up every intact tile. Each tile reports back, so the wall removes itself once all are down.
function Demolish()
{
	local int i;

	for (i = 0; i < Segments.Length; i++)
	{
		if (Segments[i] != None && !Segments[i].bDestroyed)
			Segments[i].BlowUp();
	}
}

// Called by a segment once it's blown up. When every tile is down, the wall removes itself
// on the next timer tick, so the segment that triggered this isn't destroyed mid-call.
function NotifySegmentDestroyed(RPGWallSegment Seg)
{
	ActiveSegments--;

	if (ActiveSegments <= 0 && !bDestroyed)
	{
		bDestroyed = True;

		if (Role == ROLE_Authority)
			SetTimer(0.1, false);
	}
}

event Timer()
{
	if (bDestroyed)
	{
		Destroy();
		return;
	}

	if (bAttractsMonsters)
		AttractNearbyAI();

	if (ShockDamage > 0 && Level.TimeSeconds >= NextShockTime)
	{
		ShockNearbyMonsters();
		NextShockTime = Level.TimeSeconds + ShockInterval;
	}

	ScheduleTimer();
}

// Turns on electrification. Called by the ability once the wall has spawned.
function EnableShock(int Damage, float Interval, Pawn Who)
{
	if (Damage <= 0)
		return;

	ShockDamage = Damage;
	ShockInterval = FMax(Interval, 0.1);
	ShockInstigator = Who;
	NextShockTime = Level.TimeSeconds + ShockInterval;
	ScheduleTimer();
}

// The wall has one timer, so it runs at the sooner of its monster scan and its next shock pulse.
function ScheduleTimer()
{
	local float Delay, ShockDelay;

	Delay = -1.0;
	if (bAttractsMonsters)
		Delay = BotScanInterval;

	if (ShockDamage > 0)
	{
		ShockDelay = FMax(NextShockTime - Level.TimeSeconds, 0.05);
		if (Delay < 0.0 || ShockDelay < Delay)
			Delay = ShockDelay;
	}

	if (Delay > 0.0)
		SetTimer(Delay, false);
}

// Damages enemy monsters whose collision cylinder touches an intact segment, like a fence.
function ShockNearbyMonsters()
{
	local RPGWallSegment Seg;
	local Monster M;
	local float Reach;
	local int i;
	local bool bTouching;

	Reach = MaxWallLength + MaxWallHeight + 150.0;
	foreach DynamicActors(class'Monster', M)
	{
		if (M.Health > 0 && MonsterController(M.Controller) != None &&
			FriendlyMonsterController(M.Controller) == None && VSize(M.Location - Location) <= Reach)
		{
			bTouching = false;
			for (i = 0; i < Segments.Length && !bTouching; i++)
			{
				Seg = Segments[i];
				if (Seg != None && !Seg.bDestroyed && SegmentTouches(Seg, M))
					bTouching = true;
			}

			if (bTouching)
				M.TakeDamage(ShockDamage, ShockInstigator, M.Location, vect(0,0,0), class'DamageType');
		}
	}
}

// Cylinder-to-cylinder overlap test, the same shape the engine uses to block pawns on segments.
function bool SegmentTouches(RPGWallSegment Seg, Pawn P)
{
	local vector D;

	D = P.Location - Seg.Location;
	D.Z = 0;
	return VSize(D) <= Seg.CollisionRadius + P.CollisionRadius + ShockTouchMargin &&
		Abs(P.Location.Z - Seg.Location.Z) <= Seg.CollisionHeight + P.CollisionHeight + ShockTouchMargin;
}

// Redirects nearby monsters at a segment only when it's actually blocking their path.
// Uses the same Focus/FireWeaponAt hook as Deco_RFShootTarget.
function AttractNearbyAI()
{
	local Controller C;
	local RPGWallSegment TargetSeg;
	local float Dist;
	local vector ToTarget;

	if (ActiveSegments <= 0)
		return;

	for (C = Level.ControllerList; C != None; C = C.NextController)
	{
		if (C.Pawn == None)
			continue;

		// Bots don't attack the wall; they hop over it if they get stuck in front of it.
		if (Bot(C) != None)
		{
			TryJumpOverWall(C);
			continue;
		}

		if (MonsterController(C) == None || FriendlyMonsterController(C) != None)
			continue;

		Dist = VSize(C.Pawn.Location - Location);
		if (Dist > MonsterAggroRadius)
			continue;

		// Ranged monsters need some distance so they don't blow themselves up on the wall.
		if (C.Pawn.Weapon != None && Dist < WallMinAttackRange)
			continue;

		if (C.Pawn.IsFiring())
			continue;

		TargetSeg = FindBlockingSegment(C);
		if (TargetSeg == None)
			continue;

		// Weapon-based CanAttack is reliable; monsters without an inventory Weapon use their own RangedAttack.
		if (C.Pawn.Weapon != None && !C.Pawn.CanAttack(TargetSeg))
			continue;

		// Melee-only monsters don't route into melee range on their own, since walls aren't on the nav mesh.
		// Drive Velocity toward the segment directly, since the AI state machine can overwrite it.
		Dist = VSize(TargetSeg.Location - C.Pawn.Location);
		if (C.Pawn.Weapon == None && Dist > C.Pawn.MeleeRange + C.Pawn.CollisionRadius + TargetSeg.CollisionRadius)
		{
			C.MoveTarget = TargetSeg;
			if (C.Pawn.Physics == PHYS_Flying)
			{
				C.Pawn.Velocity = Normal(TargetSeg.Location - C.Pawn.Location) * C.Pawn.AirSpeed;
			}
			else
			{
				ToTarget = TargetSeg.Location - C.Pawn.Location;
				ToTarget.Z = 0;
				C.Pawn.Velocity = Normal(ToTarget) * C.Pawn.GroundSpeed;
			}
		}

		C.Focus = TargetSeg;
		C.FireWeaponAt(TargetSeg);
	}
}

// Gives a bot stuck in front of the wall a running jump plus forward momentum to hop over it.
// Tick() fires the second boost near the apex of the first jump.
function TryJumpOverWall(Controller C)
{
	local RPGWallSegment TargetSeg;
	local float Dist;
	local vector ToTarget;

	if (C.Pawn.Physics != PHYS_Walking)
		return;

	if (VSize(C.Pawn.Location - Location) > BotAggroRadius)
		return;

	TargetSeg = FindBlockingSegment(C, true);
	if (TargetSeg == None)
		return;

	Dist = VSize(TargetSeg.Location - C.Pawn.Location);
	if (Dist > BotJumpTriggerRange)
		return;

	ToTarget = TargetSeg.Location - C.Pawn.Location;
	ToTarget.Z = 0;
	ToTarget = Normal(ToTarget);
	C.Pawn.Velocity.X = ToTarget.X * C.Pawn.GroundSpeed;
	C.Pawn.Velocity.Y = ToTarget.Y * C.Pawn.GroundSpeed;
	C.Pawn.DoJump(false);
	PendingDoubleJumps[PendingDoubleJumps.Length] = C;
}

// Runs every tick, since a jump's apex passes too quickly for the slower scan timer.
event Tick(float DeltaTime)
{
	local int i;
	local Controller C;

	if (Role == ROLE_Authority && !bDestroyed && WallLifetime > 0 && Level.TimeSeconds - SpawnTime >= WallLifetime)
	{
		bDestroyed = True;
		Destroy();
		return;
	}

	for (i = PendingDoubleJumps.Length - 1; i >= 0; i--)
	{
		C = PendingDoubleJumps[i];

		if (C == None || C.Pawn == None || C.Pawn.Physics != PHYS_Falling)
		{
			PendingDoubleJumps.Remove(i, 1);
			continue;
		}

		if (Abs(C.Pawn.Velocity.Z) < 100)
		{
			C.Pawn.DoDoubleJump(false);
			PendingDoubleJumps.Remove(i, 1);
		}
	}
}

// Returns the intact segment of THIS wall blocking the controller's current path. If
// bAllowProximityFallback is set, falls back to the nearest intact segment in clear line of sight.
function RPGWallSegment FindBlockingSegment(Controller C, optional bool bAllowProximityFallback)
{
	local vector HitLocation, HitNormal;
	local RPGWallSegment Seg, Nearest;
	local float Dist, BestDist;
	local int i;

	if (C.Enemy != None)
	{
		Seg = RPGWallSegment(C.Pawn.Trace(HitLocation, HitNormal, C.Enemy.Location, C.Pawn.Location, true));
		if (Seg != None && !Seg.bDestroyed && Seg.ParentWall == self)
			return Seg;
	}

	if (C.MoveTarget != None)
	{
		Seg = RPGWallSegment(C.Pawn.Trace(HitLocation, HitNormal, C.MoveTarget.Location, C.Pawn.Location, true));
		if (Seg != None && !Seg.bDestroyed && Seg.ParentWall == self)
			return Seg;
	}

	if (C.RouteGoal != None)
	{
		Seg = RPGWallSegment(C.Pawn.Trace(HitLocation, HitNormal, C.RouteGoal.Location, C.Pawn.Location, true));
		if (Seg != None && !Seg.bDestroyed && Seg.ParentWall == self)
			return Seg;
	}

	if (!bAllowProximityFallback)
		return None;

	for (i = 0; i < Segments.Length; i++)
	{
		Seg = Segments[i];
		if (Seg == None || Seg.bDestroyed)
			continue;

		Dist = VSize(Seg.Location - C.Pawn.Location);
		if (Dist > MonsterAggroRadius || (Nearest != None && Dist >= BestDist))
			continue;

		if (C.Pawn.Trace(HitLocation, HitNormal, Seg.Location, C.Pawn.Location, true) != Seg)
			continue;

		Nearest = Seg;
		BestDist = Dist;
	}

	return Nearest;
}

defaultproperties
{
     SegmentHealth=50
     bAutoFit=True
     MaxTraceDistance=4096.000000
     FitMargin=3.000000
     DefaultOpenDistance=256.000000
     MinWallSpacing=256.000000
     SegmentSizeFactor=1.0
     WallThicknessFactor=0.25
     ArcBulgeFactor=0.0
     MinFitScale=0.1
     MaxFitScale=8.0
     MaxHeightToFloorRatio=4.0
     MaxWallHeight=128.000000
     MaxWallLength=512.000000
     MaxRowsPerColumn=5
     MaxColumns=10
     WallLifetime=300.000000
     bAttractsMonsters=True
     MinAttackRange=350.000000
     WallMinAttackRange=100.000000
     BotAggroRadius=1500.000000
     MonsterAggroRadius=3000.000000
     ShockTouchMargin=8.000000
     BotJumpTriggerRange=120.000000
     BotScanInterval=0.750000
     StaticMesh=StaticMesh'DemoMeshes.SmoothCube_01'
     DestroyedSound=Sound'WeaponSounds.BExplosion3'
     DestroyedVolume=0.15
     DestroyedEffectClass=class'XEffects.NewExplosionA'
     WallHumSound=Sound'WeaponSounds.LinkGun.BLinkGunBeam2'
     WallHumRadius=128.000000
     WallHumVolume=64
     WallHumOcclusion=OCCLUSION_BSP
     bUnlit=True
     bStatic=False
     bWorldGeometry=False
     bNoDelete=False
     bCanBeDamaged=True
     bBlockActors=False
     bBlockPlayers=False
     bCollideActors=False
     bProjTarget=False
     bShadowCast=False
     bUseDynamicLights=True
     RemoteRole=ROLE_SimulatedProxy
}
