class Effect_Weaken extends RPGEffect;

#exec OBJ LOAD FILE=AWGlobal.utx

var config float DamageTakenPerLevel;

//called by RPGRules.NetDamage on the injured pawn
function AdjustPlayerDamage(out int Damage)
{
	if(Damage > 0)
		Damage = Round(float(Damage) * (1.0 + DamageTakenPerLevel * Modifier));
}

defaultproperties
{
	DamageTakenPerLevel=0.05
	bHarmful=True
	bAllowOnTeammates=False
	bAllowOnEnemies=True

	EffectOverlay=Material'AWGlobal.FinalChrome14'
}
