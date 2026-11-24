/*
    An Interaction for anybody joining the server, even Spectators
*/
class Interaction_Global extends RPGBaseInteraction;

var array<FriendlyPawnReplicationInfo> FriendlyPawns;

function PostRender(Canvas C) {
    local int i;
    local float FarAwayInv, Dist, ScaledDist, Scale, Height, Pct;
    local vector ScreenPos;
    local FriendlyPawnReplicationInfo FPRI;
    local Color BarColor;
    local string Text;
    local bool bMedicBars, bShowName;
    local float MedicTop;
    local int MedicLevel;

    
    FarAwayInv = 1.0f / TeamBeaconMaxDist;
    MedicLevel = GetMedicLevel();
    bMedicBars = MedicLevel > 0;

	for(i = 0; i < FriendlyPawns.Length; i++) {
        FPRI = FriendlyPawns[i];
        
        if(FPRI.Pawn != None && IsPawnVisible(C, FPRI.Pawn, ScreenPos, Dist)) {
            ScaledDist = TeamBeaconMaxDist * FClamp(0.04f * FPRI.Pawn.CollisionRadius, 1.0f, 2.0f);

            if(Dist < 0.0f || Dist > 2.0f * ScaledDist) {
                continue;
            }

			if(Dist > ScaledDist) {
                ScreenPos.Z = 0;
                if(VSize(ScreenPos) * VSize(ScreenPos) > 0.02f * Dist * Dist) {
                    continue;
                }
			}

            //Beacon scale
            Scale = FClamp(0.28f * (ScaledDist - Dist) / ScaledDist, 0.1f, 0.25f);

            //Draw height
            Height = FPRI.Pawn.CollisionHeight * FClamp(0.85f + Dist * 0.85f * FarAwayInv, 1.1f, 1.75f);
            
            //Actual beacon position
            ScreenPos = C.WorldToScreen(FPRI.Pawn.Location + Height * vect(0, 0, 1));
            ScreenPos.X -= 0.5f * TeamBeacon.USize * Scale;
            ScreenPos.Y -= 0.5f * TeamBeacon.VSize * Scale;

            //Player name, or owner, tier and monster name for summoned monsters
            Text = "";
            bShowName = Dist < TeamBeaconMaxDist && C.ClipX > 600;
            if(bShowName && !FPRI.bMonster) {
                Text = FPRI.Master.PlayerName;
            }
            
            //Draw beacon
            DrawTeamBeacon(C, ScreenPos.X, ScreenPos.Y, GetTeamBeaconColor(FPRI.Master), Scale, Text);
            if(bShowName && FPRI.bMonster) {
                //Sit above the Medic Awareness stack (its bar and HP text) when it is drawn for this pawn
                if(bMedicBars && GetMedicStackTop(FPRI.Pawn, MedicTop)) {
                    DrawMonsterBeaconLabel(C, FPRI, ScreenPos.X, MedicTop - 8.0f);
                } else {
                    DrawMonsterBeaconLabel(C, FPRI, ScreenPos.X, ScreenPos.Y - 8.0f);
                }
            }

            //Health bar (Medic Awareness draws its own, larger bar instead; summons only get it through Medic Awareness)
            if(
                !bMedicBars &&
                !FPRI.bMonster &&
                Dist < TeamBeaconMaxDist &&
                ViewportOwner.Actor.PlayerReplicationInfo != None &&
                FPRI.Master.Team == ViewportOwner.Actor.PlayerReplicationInfo.Team
            )
            {
                Height = SmallFontHeight * FClamp(1 - Dist / (TeamBeaconMaxDist / 2), 0.5, 1);
                Pct = float(FPRI.Pawn.Health) / FPRI.Pawn.HealthMax;
                
                if(Pct > 0.5) {
                    BarColor.R = byte(255.0 * FClamp(1.0 - (FPRI.Pawn.HealthMax - (FPRI.Pawn.HealthMax - FPRI.Pawn.Health) * 2) / FPRI.Pawn.HealthMax, 0, 1));
                    BarColor.G = 255;
                    BarColor.B = 0;
                } else {
                    BarColor.R = 255;
                    BarColor.G = byte(255.0 * FClamp(2.0 * FPRI.Pawn.Health / FPRI.Pawn.HealthMax, 0, 1));
                    BarColor.B = 0;
                }
                
                BarColor.A = 255;
                DrawBar(C,
                    ScreenPos.X,
                    ScreenPos.Y - SmallFontHeight - 4 - Height,
                    BarColor, Pct, 5 * Height, Height);
            }
        }
    }

    DrawPlayerMasteryTitles(C, FarAwayInv);
}

//Player and bot pawns do not have a FriendlyPawnReplicationInfo, so their
//mastery titles are drawn by walking the pawns directly.
function DrawPlayerMasteryTitles(Canvas C, float FarAwayInv) {
    local Pawn P;
    local vector ScreenPos, TopPos;
    local float Dist;
    local string Title, Title2, Word, Word2;
    local int Tier, Tier2, MedicLevel;

    if(ViewportOwner.Actor == None || ViewportOwner.Actor.PlayerReplicationInfo == None) {
        return;
    }

    MedicLevel = GetMedicLevel();

    foreach ViewportOwner.Actor.DynamicActors(class'Pawn', P) {
        if(P == ViewportOwner.Actor.Pawn || P.PlayerReplicationInfo == None || P.bDeleteMe) {
            continue;
        }
        if(P.PlayerReplicationInfo.Team != ViewportOwner.Actor.PlayerReplicationInfo.Team) {
            continue;
        }

        if(!GetMasteryTitles(P.PlayerReplicationInfo, Title, Word, Tier, Title2, Word2, Tier2) || !IsPawnVisible(C, P, ScreenPos, Dist) || Dist > TeamBeaconMaxDist) {
            continue;
        }

        if(MedicLevel > 0) {
            //Medic Awareness stacks its bar and HP text above the beacon, so sit above that stack
            TopPos = C.WorldToScreen(P.Location + vect(0, 0, 1) * (P.CollisionHeight * FClamp(0.85f + Dist * 0.85f * FarAwayInv, 1.1f, 1.75f)));
            TopPos.Y -= GetMedicStackHeight(P, Dist, MedicLevel, C.ClipX > 600) + 6.0f;
        }
        else {
            TopPos = C.WorldToScreen(P.Location + vect(0, 0, 1) * (P.CollisionHeight + 16.0f));
            TopPos.Y -= 16.0f;
        }
        C.Font = C.MedFont;
        C.FontScaleX = 1.5f;
        C.FontScaleY = 1.5f;
        //Dual-wield: left gun on the upper line, right gun on the line nearest the head
        if(Title2 != "") {
            DrawMasteryLine(C, Title, Word, Tier, TopPos, 2);
            DrawMasteryLine(C, Title2, Word2, Tier2, TopPos, 1);
        }
        else {
            DrawMasteryLine(C, Title, Word, Tier, TopPos, 1);
        }
        C.FontScaleX = 1.0f;
        C.FontScaleY = 1.0f;
    }
}

//Monster label reads "Owner's Tier Monster" in one line: white, with only the tier word coloured
function DrawMonsterBeaconLabel(Canvas C, FriendlyPawnReplicationInfo FPRI, float X, float Y) {
    local string OwnerText, TierText, MonsterName;
    local float OwnerXL, TierXL, MonsterXL, YL;

    if(FPRI.Master == None || FPRI.Pawn == None) {
        return;
    }

    OwnerText = FPRI.Master.PlayerName $ "'s ";
    TierText = class'Ability_MonsterProficiency'.static.GetTierTitle(FPRI.MonsterTier);
    if(TierText != "") {
        TierText $= " ";
    }
    MonsterName = FPRI.MonsterDisplayName;
    if(MonsterName == "") {
        MonsterName = string(FPRI.Pawn.Class.Name);
    }

    //Same font and scale as the weapon proficiency titles; measure at scale 1 and scale the widths
    C.Font = C.MedFont;
    C.FontScaleX = 1.0f;
    C.FontScaleY = 1.0f;
    C.StrLen(OwnerText, OwnerXL, YL);
    C.StrLen(TierText, TierXL, YL);
    C.StrLen(MonsterName, MonsterXL, YL);
    OwnerXL *= 1.5f;
    TierXL *= 1.5f;
    MonsterXL *= 1.5f;
    C.FontScaleX = 1.5f;
    C.FontScaleY = 1.5f;
    //Bottom edge of the label sits at Y, so measure the real scaled height instead of assuming one
    YL *= 1.5f;
    C.DrawColor = class'HUD'.Default.WhiteColor;
    C.SetPos(X - 0.5f * (OwnerXL + TierXL + MonsterXL), Y - YL);
    C.DrawTextClipped(OwnerText);
    if(TierText != "") {
        C.DrawColor = class'Ability_WeaponProficiency'.static.GetTierColor(FPRI.MonsterTier);
        C.SetPos(X - 0.5f * (OwnerXL + TierXL + MonsterXL) + OwnerXL, Y - YL);
        C.DrawTextClipped(TierText);
    }
    C.DrawColor = class'HUD'.Default.WhiteColor;
    C.SetPos(X - 0.5f * (OwnerXL + TierXL + MonsterXL) + OwnerXL + TierXL, Y - YL);
    C.DrawTextClipped(MonsterName);
    C.FontScaleX = 1.0f;
    C.FontScaleY = 1.0f;
}

//The weapon name is drawn white and only the tier word takes the tier color
function DrawMasteryLine(Canvas C, string Title, string Word, int Tier, vector TopPos, int Row) {
    local float XL, YL, NameXL, NameYL, X;

    //Measure at scale 1: StrLen on the scaled font already changes the width, so scaling it again double counts
    C.FontScaleX = 1.0f;
    C.StrLen(Title @ Word, XL, YL);
    C.StrLen(Title $ " ", NameXL, NameYL);
    C.FontScaleX = 1.5f;
    XL *= 1.5f;
    NameXL *= 1.5f;
    //StrLen returns a bogus height for the scaled font on this canvas, so use a fixed row height
    YL = 36.0f;
    X = TopPos.X - 0.5f * XL;
    C.Style = 5; //STY_Alpha
    C.DrawColor = class'HUD'.Default.WhiteColor;
    C.SetPos(X, TopPos.Y - Row * YL);
    C.DrawTextClipped(Title $ " ");
    C.DrawColor = class'Ability_WeaponProficiency'.static.GetTierColor(Tier);
    C.SetPos(X + NameXL, TopPos.Y - Row * YL);
    C.DrawTextClipped(Word);
}

event NotifyLevelChange() {
    Super.NotifyLevelChange();
    FriendlyPawns.Length = 0;
}

function bool GetMasteryTitles(PlayerReplicationInfo PRI, out string Title, out string Word, out int Tier, out string Title2, out string Word2, out int Tier2) {
    local RPGPlayerReplicationInfo RPRI;

    Title = "";
    Word = "";
    Tier = 0;
    Title2 = "";
    Word2 = "";
    Tier2 = 0;
    RPRI = GetRPRIFor(PRI);
    if(RPRI == None || !RPRI.bHasWeaponProficiency || RPRI.HeldWeaponName == "" || RPRI.HeldWeaponTitle == "") {
        return false;
    }
    Title = RPRI.HeldWeaponName;
    Word = RPRI.HeldWeaponTitle;
    Tier = RPRI.HeldWeaponTier;
    if(RPRI.HeldWeaponName2 != "" && RPRI.HeldWeaponTitle2 != "") {
        Title2 = RPRI.HeldWeaponName2;
        Word2 = RPRI.HeldWeaponTitle2;
        Tier2 = RPRI.HeldWeaponTier2;
    }
    return true;
}

//Clients don't always get the PRI's CustomReplicationInfo link for other players,
//so fall back to finding the RPRI whose replicated PRI matches.
function RPGPlayerReplicationInfo GetRPRIFor(PlayerReplicationInfo PRI) {
    local RPGPlayerReplicationInfo RPRI;

    RPRI = class'RPGPlayerReplicationInfo'.static.GetForPRI(PRI);
    if(RPRI != None) {
        return RPRI;
    }
    foreach ViewportOwner.Actor.DynamicActors(class'RPGPlayerReplicationInfo', RPRI) {
        if(RPRI.PRI == PRI) {
            return RPRI;
        }
    }
    return None;
}

//Highest Medic Awareness level the local player has, 0 if none
function int GetMedicLevel() {
    local int i, MaxLevel;
    local Interaction_MedicAwareness MA;

    for(i = 0; i < ViewportOwner.LocalInteractions.Length; i++) {
        MA = Interaction_MedicAwareness(ViewportOwner.LocalInteractions[i]);
        if(MA != None && MA.Ability != None && MA.Ability.AbilityLevel > MaxLevel) {
            MaxLevel = MA.Ability.AbilityLevel;
        }
    }
    return MaxLevel;
}

//Height above a pawn's beacon that Medic Awareness draws: the name text (if shown), the bar, and the HP text at level 2+
function float GetMedicStackHeight(Pawn P, float Dist, int MedicLevel, bool bShowText) {
    local float BarH, StackH;

    BarH = SmallFontHeight * FClamp(1 - Dist / (TeamBeaconMaxDist / 2), 0.5, 1);
    if(P.IsA('Vehicle')) {
        BarH *= 1.75f;
    }

    StackH = 2.0f * BarH + 4.0f;
    if(bShowText) {
        StackH += SmallFontHeight;
    }
    //HP text is roughly two small-font rows tall
    if(MedicLevel >= 2) {
        StackH += 2.0f + 2.0f * SmallFontHeight;
    }
    return StackH;
}

//Top Y of the Medic Awareness stack drawn for this pawn last frame; false if Medic did not draw it
function bool GetMedicStackTop(Pawn P, out float Top) {
    local int i, j;
    local Interaction_MedicAwareness MA;

    for(i = 0; i < ViewportOwner.LocalInteractions.Length; i++) {
        MA = Interaction_MedicAwareness(ViewportOwner.LocalInteractions[i]);
        if(MA == None) {
            continue;
        }
        for(j = 0; j < MA.StackCount; j++) {
            if(MA.StackPawn[j] == P) {
                Top = MA.StackTop[j];
                return true;
            }
        }
        return false;
    }
    return false;
}

function AddFriendlyPawn(FriendlyPawnReplicationInfo FPRI) {
    FriendlyPawns[FriendlyPawns.Length] = FPRI;
}

function FriendlyPawnReplicationInfo GetFriendlyPawnInfo(Pawn P) {
    local int i;

    for(i = 0; i < FriendlyPawns.Length; i++) {
        if(FriendlyPawns[i].Pawn == P) {
            return FriendlyPawns[i];
        }
    }
    return None;
}

function bool IsFriendlyPawn(Pawn P) {
    return GetFriendlyPawnInfo(P) != None;
}

function RemoveFriendlyPawn(FriendlyPawnReplicationInfo FPRI) {
    local int i;

    for(i = 0; i < FriendlyPawns.Length; i++) {
        if(FriendlyPawns[i] == FPRI) {
            FriendlyPawns.Remove(i, 1);
            break;
        }
    }
}

defaultproperties {
	bVisible=True
}
