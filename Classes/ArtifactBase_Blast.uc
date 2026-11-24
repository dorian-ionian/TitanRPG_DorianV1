class ArtifactBase_Blast extends RPGArtifact
	abstract
    HideDropDown;

var config class<Blast> BlastClass;

var config int AIHealthMin, AIMinTargets;
var config bool bFriendly;

function BotWhatNext(Bot Bot)
{
	if(
		!HasActiveArtifact(Instigator) &&
		Bot.Adrenaline >= CostPerSec &&
		Instigator.Health >= AIHealthMin && //should survive until then
		CountNearbyEnemies(BlastClass.default.Radius, bFriendly) >= AIMinTargets
	)
	{
		Activate();
	}
}

function Blast SpawnBlast()
{
	local vector StartTrace, TraceEnd, HitLocation, HitNormal;
	local rotator ViewRot;
	local Actor HitActor;

	if (Instigator == None || Instigator.Controller == None)
	{
		return None;
	}

	ViewRot = Instigator.GetViewRotation();
	StartTrace = Instigator.Location + Instigator.EyePosition();
	TraceEnd = StartTrace + (Vector(ViewRot) * 10000);
	HitActor = Trace(HitLocation, HitNormal, TraceEnd, StartTrace, True);

	if (HitActor != None)
	{
		return Spawn(BlastClass, Instigator.Controller,, HitLocation, ViewRot);
	}

	return Spawn(BlastClass, Instigator.Controller,, TraceEnd, ViewRot);
}

function bool DoEffect()
{
	local Blast Blast;

	Blast = SpawnBlast();
	
	return (Blast != None);
}

defaultproperties
{
	bChargeUp=True

	AIHealthMin=50
	AIMinTargets=2
	bFriendly=False
	
	bAllowInVehicle=False
	bCanBeTossed=False
	
	MaxUses=1
}
