//
// Global message for a summoned monster dying of old age
//
//	RelatedPRI_1 is the player who summoned the monster.
//	OptionalObject is the monster class.
//

class LocalMessage_OldAge extends LocalMessage;

static function string GetString(
	optional int Switch,
	optional PlayerReplicationInfo RelatedPRI_1,
	optional PlayerReplicationInfo RelatedPRI_2,
	optional Object OptionalObject
	)
{
	local string Name, MonsterName;

	if (RelatedPRI_1 == None)
		Name = class'LocalMessage_LevelUp'.Default.SomeoneString;
	else
		Name = RelatedPRI_1.PlayerName;

	MonsterName = class'MonsterNameTable'.static.GetDisplayName(class<Monster>(OptionalObject));
	return Name$"'s "$MonsterName$" has died of old age!";
}

defaultproperties
{
	bIsSpecial=True
	bFadeMessage=True
	StackMode=SM_Down
	PosY=0.220000
	DrawColor=(B=0,G=215,R=255,A=255)
}
