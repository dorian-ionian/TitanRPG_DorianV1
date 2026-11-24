//=============================================================================
// RPGPillMessage: HUD countdown for the active rainbow pill effect.
// Switch = EffectType * 1000 + seconds left. RPGPillEffect re-sends it each second.
//=============================================================================
class RPGPillMessage extends LocalMessage;

static function string GetString(
	optional int Switch,
	optional PlayerReplicationInfo RelatedPRI_1,
	optional PlayerReplicationInfo RelatedPRI_2,
	optional Object OptionalObject
)
{
	local byte Type;
	local int Secs;

	Type = byte(Switch / 1000);
	Secs = Switch % 1000;
	if (Secs <= 0)
		return "";

	return class'RPGPillEffect'.static.PillColorName(Type) @ "pill:" @ Secs $ "s  " $ class'RPGPillEffect'.static.PillDescription(Type);
}

static function Color GetColor(
	optional int Switch,
	optional PlayerReplicationInfo RelatedPRI_1,
	optional PlayerReplicationInfo RelatedPRI_2
)
{
	return class'RPGPillEffect'.static.PillColor(byte(Switch / 1000));
}

defaultproperties
{
	bIsUnique=True
	bIsConsoleMessage=False
	bFadeMessage=False
	DrawPivot=DP_UpperRight
	PosX=0.950000
	PosY=0.770000
	Lifetime=2
	DrawColor=(B=255,G=255,R=255,A=255)
}
