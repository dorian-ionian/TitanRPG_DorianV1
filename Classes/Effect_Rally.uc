class Effect_Rally extends RPGEffect;

var config int HealPerSecond;
var config float SpeedScale;

state Activated
{
	function BeginState()
	{
		Super.BeginState();
		class'Util'.static.PawnScaleSpeed(Instigator, SpeedScale);
	}

	function Timer()
	{
		Super.Timer();

		if(Instigator.Health > 0 && Instigator.Health < Instigator.HealthMax)
			Instigator.GiveHealth(HealPerSecond, Instigator.HealthMax);
	}

	function EndState()
	{
		class'Util'.static.PawnScaleSpeed(Instigator, 1.f / SpeedScale);
		Super.EndState();
	}
}

defaultproperties
{
	HealPerSecond=2
	SpeedScale=1.15
	TimerInterval=1.0

	bHarmful=False
	bAllowOnSelf=True
	bAllowOnTeammates=True
	bAllowOnEnemies=False
	bAllowOnVehicles=False
	bAllowStacking=False

	//no message or emitter: the heal timer would repeat them every second
	EffectOverlay=Shader'TitanRPG_DorianV1.Overlays.BlueShader'
	EffectSound=Sound'TitanRPG_DorianV1.SoundEffects.Heal'
}
