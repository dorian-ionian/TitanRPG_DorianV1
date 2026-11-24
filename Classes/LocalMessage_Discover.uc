//
// Global message for a player discovering a new summonable monster
//
//	RelatedPRI_1 is the player who discovered the monster.
//	Switch selects the colour of the monster name (see GetNameColor).
//	OptionalObject is the discovered monster class.
//

class LocalMessage_Discover extends LocalMessage;

const NAME_COLORS = 6;

static function color GetConsoleColor(PlayerReplicationInfo RelatedPRI_1)
{
	return class'HUD'.Default.WhiteColor;
}

static function color GetNameColor(int Switch)
{
	local color C;

	C.A = 255;
	switch(Switch % NAME_COLORS)
	{
		case 0: C.R = 255; C.G = 80;  C.B = 80;  return C;
		case 1: C.R = 255; C.G = 170; C.B = 0;   return C;
		case 2: C.R = 255; C.G = 255; C.B = 80;  return C;
		case 3: C.R = 80;  C.G = 255; C.B = 80;  return C;
		case 4: C.R = 80;  C.G = 200; C.B = 255; return C;
	}
	C.R = 220; C.G = 120; C.B = 255;
	return C;
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
	local color BaseColor, NameCol;
	local float X, Y;
	local string Name, MonsterName;

	BaseColor = class'HUD'.Default.WhiteColor;
	BaseColor.A = Canvas.DrawColor.A;

	NameCol = GetNameColor(Switch);
	NameCol.A = BaseColor.A;

	if (RelatedPRI_1 == None)
		Name = class'LocalMessage_LevelUp'.Default.SomeoneString;
	else
		Name = RelatedPRI_1.PlayerName;

	MonsterName = class'MonsterNameTable'.static.GetDisplayName(class<Monster>(OptionalObject));

	X = Canvas.CurX;
	Y = Canvas.CurY;
	DrawPart(Canvas, X, Y, Name$" discovered a ", BaseColor);
	DrawPart(Canvas, X, Y, MonsterName, NameCol);
	DrawPart(Canvas, X, Y, "!", BaseColor);
}

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
	return Name$" discovered a "$MonsterName$"!";
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
