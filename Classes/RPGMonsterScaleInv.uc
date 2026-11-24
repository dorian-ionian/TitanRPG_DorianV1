/*
	RPGMonsterScaleInv - server-only record of the InvasionAutoAdjustFactor
	a spawned Invasion monster rolled between InvasionAutoAdjustFactorMin and
	InvasionAutoAdjustFactorMax. Used for both its damage adjustment and its
	displayed level. Never replicated, so it costs no bandwidth.
*/
class RPGMonsterScaleInv extends Inventory;

var float Factor;

defaultproperties
{
	ItemName="MonsterScale"
	RemoteRole=ROLE_None
	bOnlyRelevantToOwner=True
}
