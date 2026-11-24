class Interaction_Awareness extends RPGBaseInteraction;

var Interaction_Global GlobalInteraction;
var Ability_Awareness Ability;

//Top Y of each enemy's drawn stack this frame (HP text, or the bar if none), so monster labels can sit above it exactly
var Pawn StackPawn[32];
var float StackTop[32];
var int StackCount;

//Returns the stack top recorded for P this frame
function bool GetStackTop(Pawn P, out float Top) {
    local int i;

    for(i = 0; i < StackCount; i++) {
        if(StackPawn[i] == P) {
            Top = StackTop[i];
            return true;
        }
    }
    return false;
}

event Initialized() {
    local int i;
    
    Super.Initialized();

    for(i = 0; i < ViewportOwner.LocalInteractions.Length; i++) {
        if(ViewportOwner.LocalInteractions[i].IsA('Interaction_Global')) {
            GlobalInteraction = Interaction_Global(ViewportOwner.LocalInteractions[i]);
            break;
        }
    }
}

function PostRender(Canvas C) {
    local int i;
    local float FarAwayInv, Dist, ScaledDist, Height, BarH, Pct;
    local vector ScreenPos;
    local Pawn P;
    local Color BarColor;
    local float TextTop;

    StackCount = 0;

    if(Ability == None || Ability.AbilityLevel <= 0) {
        return;
    }
    
    if(ViewportOwner.Actor.Pawn == None || ViewportOwner.Actor.Pawn.Health <= 0) {
        return;
    }

    FarAwayInv = 1.0f / TeamBeaconMaxDist;

	for(i = 0; i < Ability.Enemies.Length; i++) {
        P = Ability.Enemies[i];
        if(IsPawnVisible(C, P, ScreenPos, Dist)) {
            ScaledDist = TeamBeaconMaxDist * FClamp(0.04f * P.CollisionRadius, 1.0f, 2.0f);

            if(Dist < 0.0f || Dist > 3.0f * ScaledDist) {
                continue;
            }
            
            //Draw height
            Height = P.CollisionHeight * FClamp(0.85f + Dist * 0.85f * FarAwayInv, 1.1f, 1.75f);
            
            //Offset
            ScreenPos = C.WorldToScreen(P.Location + Height * vect(0, 0, 0.75));
            
            //Bar height
            Height = SmallFontHeight * FClamp(1 - Dist / (TeamBeaconMaxDist / 2), 0.5, 1);
            
            if(P.IsA('Vehicle')) {
                Height *= 1.75;
            }
            
            BarH = 2.0f * Height;
            BarColor.A = 255;

            //Health bar
            if(P.Health > 0) {
                ScreenPos.Y -= BarH + 2;
                Pct = float(P.Health) / P.HealthMax;
                BarColor = GetHealthColor(Pct);

                DrawBar(C, ScreenPos.X, ScreenPos.Y, BarColor, Pct, 10 * Height, BarH, true);

                //Top of this pawn's stack: the HP text when drawn, otherwise the bar
                TextTop = ScreenPos.Y - 0.5 * BarH;
                if(Ability.AbilityLevel >= 2) {
                    TextTop = DrawHealthText(C, ScreenPos.X, ScreenPos.Y - 0.5 * BarH - 2, P);
                }

                if(StackCount < ArrayCount(StackPawn)) {
                    StackPawn[StackCount] = P;
                    StackTop[StackCount] = TextTop;
                    StackCount++;
                }
            }
        }
    }
}

defaultproperties {
    bVisible = true;
}
