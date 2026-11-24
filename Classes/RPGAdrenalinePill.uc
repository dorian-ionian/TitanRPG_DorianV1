//=============================================================================
// RPGAdrenalinePill: rainbow adrenaline pills. Grants normal adrenaline and a
// timed effect (see RPGPillEffect). The base class is adrenaline only.
//=============================================================================
#exec OBJ LOAD FILE=UT2004Weapons.utx

class RPGAdrenalinePill extends AdrenalinePickup config(TitanRPG);

var config int PillDuration;   // seconds the effect lasts
var byte EffectType;           // RPGPillEffect index; 255 = no effect

function ClearPillEffect(Controller C)
{
	local RPGPillEffect E;

	foreach DynamicActors(class'RPGPillEffect', E)
	{
		if (E.Ctrl == C)
		{
			E.Expire();
			return;
		}
	}
}

auto state Pickup
{
	function Touch(Actor Other)
	{
		local Pawn P;
		local Controller C;
		local RPGPillEffect E;

		if (ValidTouch(Other))
		{
			P = Pawn(Other);
			C = P.Controller;
			if (C != None)
			{
				C.AwardAdrenaline(AdrenalineAmount);
				if (EffectType != 255)
				{
					ClearPillEffect(C);
					E = Spawn(class'RPGPillEffect');
					E.Start(C, EffectType, PillDuration * class'Ability_PillsHere'.static.GetDurationScale(C));
				}
			}
			AnnouncePickup(P);
			SetRespawn();
		}
	}
}

defaultproperties
{
	PillDuration=60
	EffectType=255
	bDynamicLight=true
	LightType=LT_Steady
	LightBrightness=200
	LightRadius=3.000000
	LightSaturation=255
}
