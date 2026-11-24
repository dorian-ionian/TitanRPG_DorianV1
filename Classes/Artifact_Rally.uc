class Artifact_Rally extends RPGArtifact;

var config float RallyRadius;
var config float RefreshInterval;
var config float EffectDuration;

var float NextRallyTime;

state Activated
{
	function BeginState()
	{
		Super.BeginState();
		NextRallyTime = 0;
	}

	event Tick(float dt)
	{
		if(Instigator != None && Level.TimeSeconds >= NextRallyTime)
		{
			NextRallyTime = Level.TimeSeconds + RefreshInterval;
			RallyTeammates();
		}

		Super.Tick(dt);
	}
}

function int CountNearbyTeammates()
{
	local Controller C;
	local int n;

	for(C = Level.ControllerList; C != None; C = C.NextController)
	{
		if(
			C.bIsPlayer &&
			C.Pawn != None &&
			C.Pawn != Instigator &&
			C.Pawn.Health > 0 &&
			class'Util'.static.SameTeamCP(Instigator.Controller, C.Pawn) &&
			VSize(C.Pawn.Location - Instigator.Location) <= RallyRadius
		)
		{
			n++;
		}
	}
	return n;
}

function BotFightEnemy(Bot Bot)
{
	if(!bActive && Bot.Adrenaline >= 3 * CostPerSec * MinActivationTime && CountNearbyTeammates() > 0)
		Activate();
}

function BotWhatNext(Bot Bot)
{
	if(bActive && CountNearbyTeammates() == 0)
		Activate(); //deactivate, nobody left to rally
}

function BotLoseEnemy(Bot Bot)
{
	if(bActive)
		Activate(); //deactivate
}

function RallyTeammates()
{
	local Controller C;

	for(C = Level.ControllerList; C != None; C = C.NextController)
	{
		if(
			C.bIsPlayer &&
			C.Pawn != None &&
			C.Pawn.Health > 0 &&
			class'Util'.static.SameTeamCP(Instigator.Controller, C.Pawn) &&
			VSize(C.Pawn.Location - Instigator.Location) <= RallyRadius
		)
		{
			class'Effect_Rally'.static.Create(C.Pawn, Instigator.Controller, EffectDuration);
		}
	}
}

defaultproperties
{
	RallyRadius=768.00
	RefreshInterval=0.50
	EffectDuration=1.50
	CostPerSec=3
	MinActivationTime=1.000000
	ActivateSound=Sound'TitanRPG_DorianV1.SoundEffects.Protection'
	HudColor=(B=64,G=200,R=255)
	ArtifactID="Rally"
	Description="Heals and speeds up nearby teammates while active."
	PickupClass=Class'ArtifactPickup_Rally'
	IconMaterial=Texture'TitanRPG_DorianV1.ArtifactIcons.Globe'
	ItemName="Rally"
}
