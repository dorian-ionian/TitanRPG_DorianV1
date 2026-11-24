//Replicated so that clients spawn the explosion themselves; emitters spawned on the server do not replicate
class FX_ExplosionRelay extends Actor;

simulated event Tick(float DeltaTime)
{
	Disable('Tick');
	if(Level.NetMode != NM_DedicatedServer)
		Spawn(class'XEffects.NewExplosionA',,, Location);
}

defaultproperties
{
	bReplicateMovement=True
	RemoteRole=ROLE_SimulatedProxy
	LifeSpan=2.0
	bHidden=True
}
