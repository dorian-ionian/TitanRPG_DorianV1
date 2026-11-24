//
// Message for a player's summoned monster type reaching a new monster proficiency tier
//
//	RelatedPRI_1 is the player who reached the tier.
//	Switch is the index into Ability_MonsterProficiency.MonsterTiers.
//	OptionalObject is the summoned monster class.
//

class LocalMessage_MonsterTier extends LocalMessage;

static function color GetConsoleColor(PlayerReplicationInfo RelatedPRI_1)
{
	return class'HUD'.Default.WhiteColor;
}

static function DrawPart(Canvas C, out float X, float Y, string Text, color Col)
{
	local float W, H;

	C.DrawColor = Col;
	C.SetPos(X, Y);
	C.DrawText(Text);
	C.TextSize(Text, W, H);
	X += W;
}

static function string GetMonsterName(class<Monster> MonsterClass)
{
	return class'MonsterNameTable'.static.GetDisplayName(MonsterClass);
}

static function RenderComplexMessage(
	Canvas Canvas,
	out float XL,
	out float YL,
	optional String MessageString,
	optional int Switch,
	optional PlayerReplicationInfo RelatedPRI_1,
	optional PlayerReplicationInfo RelatedPRI_2,
	optional Object OptionalObject
	)
{
	local color BaseColor, TierCol;
	local float X, Y;
	local string Name, TierTitle, MonsterName;

	BaseColor = class'HUD'.Default.WhiteColor;
	BaseColor.A = Canvas.DrawColor.A;

	TierCol = class'Ability_WeaponProficiency'.static.GetTierColor(Switch + 1);
	TierCol.A = BaseColor.A;

	if (RelatedPRI_1 == None)
		Name = class'LocalMessage_LevelUp'.Default.SomeoneString;
	else
		Name = RelatedPRI_1.PlayerName;

	TierTitle = class'Ability_MonsterProficiency'.Default.TierTitles[Switch];
	MonsterName = GetMonsterName(class<Monster>(OptionalObject));

	X = Canvas.CurX;
	Y = Canvas.CurY;
	DrawPart(Canvas, X, Y, Name$"'s "$MonsterName$" is now a ", BaseColor);
	DrawPart(Canvas, X, Y, TierTitle, TierCol);
	DrawPart(Canvas, X, Y, "!", BaseColor);
}

static function string GetString(
	optional int Switch,
	optional PlayerReplicationInfo RelatedPRI_1,
	optional PlayerReplicationInfo RelatedPRI_2,
	optional Object OptionalObject
	)
{
	local string Name, TierTitle, MonsterName;

	if (RelatedPRI_1 == None)
		Name = class'LocalMessage_LevelUp'.Default.SomeoneString;
	else
		Name = RelatedPRI_1.PlayerName;

	TierTitle = class'Ability_MonsterProficiency'.Default.TierTitles[Switch];
	MonsterName = GetMonsterName(class<Monster>(OptionalObject));

	return Name$"'s "$MonsterName$" is now a "$TierTitle$"!";
}

defaultproperties
{
	bIsSpecial=True
	bComplexString=True
	bFadeMessage=True
	StackMode=SM_Down
	PosY=0.220000
	DrawColor=(B=0,G=215,R=255,A=255)
}
