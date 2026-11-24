//=============================================================================
// RPGPillEffect: applies one timed rainbow pill effect to a controller's pawn.
// Saved pawn stats are restored on expiry, death or respawn.
//=============================================================================
class RPGPillEffect extends Info config(TitanRPG);

var config float RedDamageScale;            // Red: outgoing damage multiplier
var config float OrangeSpeedScale;          // Orange: ground speed multiplier
var config float YellowShieldPerSecond;     // Yellow: shield gained per second
var config float GreenHealthPerSecond;      // Green: health regenerated per second
var config float BlueJumpScale;             // Blue: jump height multiplier
var config float IndigoAdrenalinePerSecond; // Indigo: adrenaline gained per second
var config float VioletHealthScale;         // Violet: max health multiplier

var Controller Ctrl;
var Pawn P;
var byte EffectType;
var float EndTime;
var float VioletHealthBonus;

// Effect indices: 0 Red, 1 Orange, 2 Yellow, 3 Green, 4 Blue, 5 Indigo, 6 Violet

function Start(Controller C, byte Type, float Duration)
{
	Ctrl = C;
	P = C.Pawn;
	EffectType = Type;
	EndTime = Level.TimeSeconds + Duration;

	if (P != None)
	{
		switch (EffectType)
		{
			case 0: P.DamageScaling *= RedDamageScale; break;
			case 1: P.GroundSpeed *= OrangeSpeedScale; break;
			case 4: P.JumpZ *= BlueJumpScale; break;
			case 6:
				VioletHealthBonus = P.HealthMax * (VioletHealthScale - 1.0);
				P.HealthMax += VioletHealthBonus;
				P.Health += int(VioletHealthBonus);
				break;
		}
	}

	SendMessage(int(Duration + 0.5));
	SetTimer(1.0, true);
}

function SendMessage(int Secs)
{
	local PlayerController PC;

	PC = PlayerController(Ctrl);
	if (PC != None)
		PC.ReceiveLocalizedMessage(class'RPGPillMessage', int(EffectType) * 1000 + Secs);
}

event Timer()
{
	local float Left;

	Left = EndTime - Level.TimeSeconds;
	if (Ctrl == None || P == None || Ctrl.Pawn != P || P.Health <= 0 || Left <= 0)
	{
		Expire();
		return;
	}

	switch (EffectType)
	{
		case 2:
			if (xPawn(P) != None)
				xPawn(P).AddShieldStrength(int(YellowShieldPerSecond));
			break;
		case 3:
			P.Health += int(GreenHealthPerSecond);
			if (P.Health > P.HealthMax)
				P.Health = P.HealthMax;
			break;
		case 5:
			Ctrl.AwardAdrenaline(IndigoAdrenalinePerSecond);
			break;
	}

	SendMessage(int(Left + 0.5));
}

function Expire()
{
	if (P != None)
	{
		switch (EffectType)
		{
			case 0: P.DamageScaling /= RedDamageScale; break;
			case 1: P.GroundSpeed /= OrangeSpeedScale; break;
			case 4: P.JumpZ /= BlueJumpScale; break;
			case 6:
				P.HealthMax -= VioletHealthBonus;
				if (P.Health > P.HealthMax)
					P.Health = P.HealthMax;
				break;
		}
	}

	SendMessage(0);
	SetTimer(0, false);
	Destroy();
}

static function string PillColorName(byte Type)
{
	switch (Type)
	{
		case 0: return "Red";
		case 1: return "Orange";
		case 2: return "Yellow";
		case 3: return "Green";
		case 4: return "Blue";
		case 5: return "Indigo";
		case 6: return "Violet";
	}
	return "";
}

static function string PillDescription(byte Type)
{
	switch (Type)
	{
		case 0: return "+" $ int((class'RPGPillEffect'.default.RedDamageScale - 1.0) * 100) $ "% damage";
		case 1: return "+" $ int((class'RPGPillEffect'.default.OrangeSpeedScale - 1.0) * 100) $ "% speed";
		case 2: return "+" $ int(class'RPGPillEffect'.default.YellowShieldPerSecond) $ " shield/sec";
		case 3: return "+" $ int(class'RPGPillEffect'.default.GreenHealthPerSecond) $ " health/sec";
		case 4: return "+" $ int((class'RPGPillEffect'.default.BlueJumpScale - 1.0) * 100) $ "% jump";
		case 5: return "+" $ int(class'RPGPillEffect'.default.IndigoAdrenalinePerSecond) $ " adrenaline/sec";
		case 6: return "+" $ int((class'RPGPillEffect'.default.VioletHealthScale - 1.0) * 100) $ "% max health";
	}
	return "";
}

static function Color PillColor(byte Type)
{
	local Color C;

	C.A = 255;
	switch (Type)
	{
		case 0: C.R = 255; C.G = 40;  C.B = 40;  break;
		case 1: C.R = 255; C.G = 140; C.B = 0;   break;
		case 2: C.R = 255; C.G = 230; C.B = 0;   break;
		case 3: C.R = 40;  C.G = 220; C.B = 60;  break;
		case 4: C.R = 40;  C.G = 120; C.B = 255; break;
		case 5: C.R = 140; C.G = 80;  C.B = 255; break;
		case 6: C.R = 238; C.G = 130; C.B = 238; break;
		default: C.R = 255; C.G = 255; C.B = 255; break;
	}
	return C;
}

defaultproperties
{
	RedDamageScale=1.500000
	OrangeSpeedScale=1.350000
	YellowShieldPerSecond=10.000000
	GreenHealthPerSecond=5.000000
	BlueJumpScale=1.600000
	IndigoAdrenalinePerSecond=1.000000
	VioletHealthScale=1.500000
}
