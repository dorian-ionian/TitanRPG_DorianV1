/*
	Interaction_MonsterLevel - draws a floating name + level label above
	Invasion monsters. Enabled by MutTitanRPG.bShowMonsterLevel; added
	client-side by RPGReplicationInfo.ClientSetup.
*/
class Interaction_MonsterLevel extends RPGBaseInteraction;

var Interaction_Awareness AwarenessInteraction;
var Color RedColor;

//Screen Y of the top edge of the Interaction_Awareness stack for this pawn
//(health bar, plus the HP text that sits above it). Mirrors that class's geometry.
//Mirrors Interaction_Awareness geometry for the enemy anchor P (the vehicle for vehicle monsters, otherwise the pawn)
function float GetAwarenessTop(Canvas C, Pawn P, float Dist)
{
	local vector AnchorPos;
	local float Height, BarH, XL, TextH;

	Height = P.CollisionHeight * FClamp(0.85f + Dist * 0.85f / TeamBeaconMaxDist, 1.1f, 1.75f);
	AnchorPos = C.WorldToScreen(P.Location + Height * vect(0, 0, 0.75));

	Height = SmallFontHeight * InteractionScale * FClamp(1 - Dist / (TeamBeaconMaxDist / 2), 0.5, 1);
	if(P.IsA('Vehicle'))
		Height *= 1.75;
	BarH = 2.0f * Height;

	//HP text height in the canvas font the awareness interactions draw with
	C.StrLen("100 HP (100%)", XL, TextH);

	//Bar centre sits BarH + 2 above the anchor, the HP text sits above the bar's top edge
	return AnchorPos.Y - 1.5f * BarH - 4.0f - TextH;
}

function PostRender(Canvas C)
{
	local RPGMonsterLevelInv Inv;
	local vector ScreenPos, CamLoc, D;
	local rotator CamRot;
	local float Dist, Height, XL, YL, Scale, AwareTop, RecordedTop;
	local string Text;
	local Pawn Anchor;
	local Font SavedFont;
	local int i;

	if(ViewportOwner.Actor == None)
		return;

	InteractionScale = GetInteractionScale();
	SavedFont = C.Font;

	if(AwarenessInteraction == None)
	{
		for(i = 0; i < ViewportOwner.LocalInteractions.Length; i++)
		{
			if(ViewportOwner.LocalInteractions[i].IsA('Interaction_Awareness'))
			{
				AwarenessInteraction = Interaction_Awareness(ViewportOwner.LocalInteractions[i]);
				break;
			}
		}
	}

	foreach ViewportOwner.Actor.Level.DynamicActors(class'RPGMonsterLevelInv', Inv)
	{
		if(Inv.MyMonster == None || Inv.MonsterLevel <= 0)
			continue;

		//Vehicle monsters are labelled on their vehicle shell
		Anchor = Inv.MyMonster;
		if(Inv.MyVehicle != None && Inv.MyVehicle.Health > 0)
			Anchor = Inv.MyVehicle;

		//Cheap range check before the more expensive visibility test
		C.GetCameraLocation(CamLoc, CamRot);
		D = Anchor.Location - CamLoc;
		if(D dot vector(CamRot) < 0)
			continue;
		if(VSize(D) > TeamBeaconMaxDist)
			continue;

		if(!IsPawnVisible(C, Anchor, ScreenPos, Dist))
			continue;

		if(Dist < 0.0f || Dist > TeamBeaconMaxDist)
			continue;

		//Distance-based size falloff. NOTE: FontScale is never raised
		//above 1.0 - this engine does not render text scaled up (all
		//existing UT2004 code only scales DOWN). Size comes from the
		//resolution-scaled mid-game font instead.
		Scale = FClamp(1.0f - 0.35f * Dist / TeamBeaconMaxDist, 0.7f, 1.0f);

		//Above the monster's head
		Height = Anchor.CollisionHeight * FClamp(0.85f + Dist * 0.85f / TeamBeaconMaxDist, 1.1f, 1.75f);
		ScreenPos = C.WorldToScreen(Anchor.Location + Height * vect(0, 0, 1));

		//Keep the label above the enemy awareness bar and HP text, which stack up from a lower anchor
		//Keep the label above the enemy awareness bar and HP text. Use the position the awareness
		//interaction actually drew at, falling back to the calculated geometry.
		AwareTop = GetAwarenessTop(C, Anchor, Dist);
		if(AwarenessInteraction != None && AwarenessInteraction.GetStackTop(Anchor, RecordedTop))
			AwareTop = RecordedTop;
		if(ScreenPos.Y > AwareTop - 2.0f)
			ScreenPos.Y = AwareTop - 2.0f;

		C.Style = 9; //STY_AlphaZ
		//Resolution-scaled font - same as InvasionPro's floating pet
		//names (UT2003Fonts, which TinyFont also comes from)
		C.Font = class'UT2MidGameFont'.static.GetMidGameFont(int(C.ClipX * InteractionScale));
		if(C.Font == None)
			C.Font = C.TinyFont;
		C.FontScaleX = Scale;
		C.FontScaleY = Scale;

		//Name
		Text = Inv.MonsterName;
		if(Text == "")
			Text = Inv.MyMonster.GetHumanReadableName();
		if(Text == "")
			Text = Mid(string(Inv.MyMonster.Class), InStr(string(Inv.MyMonster.Class), ".") + 1);

		C.DrawColor = RedColor;
		C.StrLen(Text, XL, YL);
		C.SetPos(ScreenPos.X - 0.5f * XL, ScreenPos.Y - 2.0f * YL);
		C.DrawText(Text);

		//Level
		Text = "Level" @ Inv.MonsterLevel;
		C.DrawColor = WhiteColor;
		C.StrLen(Text, XL, YL);
		C.SetPos(ScreenPos.X - 0.5f * XL, ScreenPos.Y - YL);
		C.DrawText(Text);

		C.FontScaleX = 1.0;
		C.FontScaleY = 1.0;
		C.Font = SavedFont;
	}
}

defaultproperties
{
	RedColor=(R=255,G=64,B=64,A=255)
	bVisible = true;
}
