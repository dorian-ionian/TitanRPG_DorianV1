//
// Message for a player reaching a new weapon mastery tier
//
//	RelatedPRI_1 is the player who reached the tier.
//	Switch is the index into Ability_WeaponProficiency.MasteryTiers.
//	OptionalObject is the weapon class.
//

class LocalMessage_MasteryTier extends LocalMessage;

var(Message) localized string IsNowString, WithString;

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

// Switch is the mastery tier index, so tier number = Switch + 1.
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
	local string Name, TierTitle, WeaponName;

	BaseColor = class'HUD'.Default.WhiteColor;
	BaseColor.A = Canvas.DrawColor.A;
	TierCol = class'Ability_WeaponProficiency'.static.GetTierColor(Switch + 1);
	TierCol.A = BaseColor.A;

	if (RelatedPRI_1 == None)
		Name = class'LocalMessage_LevelUp'.Default.SomeoneString;
	else
		Name = RelatedPRI_1.PlayerName;

	TierTitle = MessageString;
	if(TierTitle == "" && Switch >= 0 && Switch < class'Ability_WeaponProficiency'.Default.TierTitles.Length)
		TierTitle = class'Ability_WeaponProficiency'.Default.TierTitles[Switch];
	if(OptionalObject != None)
		WeaponName = class<Weapon>(OptionalObject).Default.ItemName;
	X = Canvas.CurX;
	Y = Canvas.CurY;
	DrawPart(Canvas, X, Y, Name$Default.IsNowString, BaseColor);
	DrawPart(Canvas, X, Y, TierTitle, TierCol);
	DrawPart(Canvas, X, Y, Default.WithString$WeaponName$"!", BaseColor);
}

static function string GetString(
	optional int Switch,
	optional PlayerReplicationInfo RelatedPRI_1,
	optional PlayerReplicationInfo RelatedPRI_2,
	optional Object OptionalObject
	)
{
	local string Name, TierTitle, WeaponName;

	if (RelatedPRI_1 == None)
		Name = class'LocalMessage_LevelUp'.Default.SomeoneString;
	else
		Name = RelatedPRI_1.PlayerName;

	TierTitle = "";
	if(Switch >= 0 && Switch < class'Ability_WeaponProficiency'.Default.TierTitles.Length)
		TierTitle = class'Ability_WeaponProficiency'.Default.TierTitles[Switch];
	if(OptionalObject != None)
		WeaponName = class<Weapon>(OptionalObject).Default.ItemName;

	return Name$Default.IsNowString$TierTitle$Default.WithString$WeaponName$"!";
}

defaultproperties
{
	IsNowString=" is now "
	WithString=" with "
	bIsSpecial=True
	bComplexString=True
	bFadeMessage=True
	StackMode=SM_Down
	PosY=0.220000
	DrawColor=(B=0,G=215,R=255,A=255)
}
