//=============================================================================
// RPGDamageText: floating damage number shown to the player who dealt the damage.
// Spawned by RPGRules on the server, owned by that player's controller so only
// their client receives it. RPGInteraction draws it. LifeSpan removes it on both sides.
//=============================================================================
class RPGDamageText extends Actor;

var int Amount;
var vector Spot;
var Pawn Victim;
var float SpawnTime;
var bool bDebugLog;
var float ScatterX, ScatterY; //screen offset, set on each client so numbers don't stack

replication
{
	reliable if (Role == ROLE_Authority)
		Amount, Spot, Victim, bDebugLog;
}

simulated function PostBeginPlay()
{
	Super.PostBeginPlay();
	SpawnTime = Level.TimeSeconds;
	ScatterX = (FRand() * 2.0 - 1.0) * 60.0;
	ScatterY = (FRand() * 2.0 - 1.0) * 24.0;
}

simulated function PostNetReceive()
{
	if (bDebugLog && Level.NetMode != NM_DedicatedServer && Amount > 0)
		Log("Received damage number" @ Amount @ "at" @ Level.TimeSeconds, 'RPGDamage');
}

defaultproperties
{
	bNetTemporary=True
	RemoteRole=ROLE_SimulatedProxy
	bOnlyRelevantToOwner=True
	bHidden=True
	// Longer than the 1.6 s the number is drawn, so the server does not destroy it before the client receives it.
	LifeSpan=3.5
}
