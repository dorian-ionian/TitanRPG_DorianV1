class Effect_Burning extends Effect_Poison;

#exec OBJ LOAD FILE=EpicParticles.utx

var FX_BurnFlames Flames;

function RemoveFlames()
{
	if(Flames != None)
	{
		Flames.Destroy();
		Flames = None;
	}
}

event Destroyed()
{
	RemoveFlames();
	Super.Destroyed();
}

function SpawnFlames()
{
	if(Flames == None && Pawn(Owner) != None)
	{
		Flames = Pawn(Owner).Spawn(class'FX_BurnFlames', Owner);
		Flames.SetBase(Pawn(Owner));
	}
}

state Activated
{
	function BeginState()
	{
		Super.BeginState();

		//Flames live as long as the effect itself (removed in Destroyed), not per state change:
		//RPGEffect.Create calls Stop() on every refresh, which would otherwise restart them on each hit
		SpawnFlames();

		if(Flames != None)
			Flames.AddBurst();
	}

	//Respawn flames if the emitter went away early, so they last exactly as long as the burn
	event Tick(float dt)
	{
		Super.Tick(dt);

		if(Duration > 0)
			SpawnFlames();
	}
}

defaultproperties
{
	PoisonMode=PM_Absolute
	AbsDrainPerLevel=5
	EffectMessageClass=class'EffectMessage_Burning'
	xEmitterClass=None
	EffectOverlay=Material'EpicParticles.FlameSphereShader'
}
