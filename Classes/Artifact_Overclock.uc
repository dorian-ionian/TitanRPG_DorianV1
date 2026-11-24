class Artifact_Overclock extends RPGArtifact;

var config float FireRateScale;

var Weapon AffectedWeapon;

replication
{
	reliable if(Role == ROLE_Authority)
		ClientAdjustFireRate;
}

simulated function ClientAdjustFireRate(Weapon W, float Scale)
{
	if(Role < ROLE_Authority)
		class'Util'.static.AdjustWeaponFireRate(W, Scale);
}

function BotFightEnemy(Bot Bot)
{
	if(
		!bActive &&
		Bot.bEnemyIsVisible &&
		Bot.Adrenaline >= 3 * CostPerSec * MinActivationTime &&
		FRand() < FMin(0.666667, Bot.Aggressiveness)
	)
		Activate();
}

function BotWhatNext(Bot Bot)
{
	if(bActive && (Bot.Enemy == None || !Bot.bEnemyIsVisible))
		Activate(); //deactivate
}

function BotLoseEnemy(Bot Bot)
{
	if(bActive)
		Activate(); //deactivate
}

function SetWeaponBoost(Weapon W)
{
	ClearWeaponBoost();

	if(W == None || W.IsA('dw_DualWeapon'))
		return;

	AffectedWeapon = W;
	class'Util'.static.AdjustWeaponFireRate(W, FireRateScale);
	ClientAdjustFireRate(W, FireRateScale);
}

function ClearWeaponBoost()
{
	if(AffectedWeapon != None)
	{
		class'Util'.static.AdjustWeaponFireRate(AffectedWeapon, 1.f / FireRateScale);
		ClientAdjustFireRate(AffectedWeapon, 1.f / FireRateScale);
	}

	AffectedWeapon = None;
}

state Activated
{
	function BeginState()
	{
		Super.BeginState();
		SetWeaponBoost(Instigator.Weapon);
	}

	event Tick(float dt)
	{
		//follow weapon switches
		if(Instigator != None && Instigator.Weapon != AffectedWeapon)
			SetWeaponBoost(Instigator.Weapon);

		Super.Tick(dt);
	}

	function EndState()
	{
		ClearWeaponBoost();
		Super.EndState();
	}
}

defaultproperties
{
	FireRateScale=10.0
	bAffectsHeldWeapon=True
	CostPerSec=5
	MinActivationTime=1.000000
	ActivateSound=Sound'TitanRPG_DorianV1.SoundEffects.Protection'
	HudColor=(B=0,G=160,R=255)
	ArtifactID="Overclock"
	Description="Boosts fire rate of your current weapon while active."
	PickupClass=Class'ArtifactPickup_Overclock'
	IconMaterial=Texture'TitanRPG_DorianV1.ArtifactIcons.nitroboost'
	ItemName="Overclock"
}
