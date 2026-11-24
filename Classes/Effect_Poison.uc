class Effect_Poison extends RPGEffect;

enum EPoisonMode
{
	PM_Absolute, //drain an absolute amount of health per time unit (AbsDrainPerLevel)
	PM_Percentage, //drain a percentage of the current health per time unit (PercDrainPerLevel)
	PM_Curve //use the TitanRPG curve (BasePercentage and Curve)
};
var EPoisonMode PoisonMode;

var float BasePercentage;
var float Curve;

var int AbsDrainPerLevel;
var float PercDrainPerLevel;

var int MinHealth; //cannot drain below this

var bool bAbsoluteDamage;

//Health is changed directly below, so the stock damage path (and its number) is not used
function ShowPoisonNumber(int Amount)
{
	if(EffectCauser != None)
		class'RPGRules'.static.Instance(Level).SpawnDamageNumber(Amount, Instigator, EffectCauser);
}

state Activated
{
	function Timer()
	{
		local RPGPlayerReplicationInfo CauserRPRI;
		local int PoisonDamage;
		local int OldHealth;

		Super.Timer();

		switch(PoisonMode)
		{
			case PM_Absolute:
				PoisonDamage = AbsDrainPerLevel * Modifier;
				break;
				
			case PM_Percentage:
				PoisonDamage = Modifier * PercDrainPerLevel * Instigator.Health;
				break;
				
			case PM_Curve:
				PoisonDamage = float(Instigator.Health) * (Curve ** (Modifier - 1.0f) * BasePercentage);
				break;
		}
	
		if(PoisonDamage > 0 && !(Instigator.Controller != None && Instigator.Controller.bGodMode))
		{
			if(MinHealth > 0)
			{
				OldHealth = Instigator.Health;
				Instigator.Health = Max(MinHealth, Instigator.Health - PoisonDamage);
				ShowPoisonNumber(OldHealth - Instigator.Health);
			}
			else if(PoisonDamage >= Instigator.Health)
			{
				//Kill
				Instigator.TakeDamage(PoisonDamage, EffectCauser.Pawn, Instigator.Location, vect(0, 0, 0), class'DamTypePoison');
			}
			else
			{
				Instigator.Health -= PoisonDamage;
				ShowPoisonNumber(PoisonDamage);
			}
			
			if(EffectCauser != None && EffectCauser != Instigator.Controller)
			{
				CauserRPRI = class'RPGPlayerReplicationInfo'.static.GetFor(EffectCauser);
				if(CauserRPRI != None)
				{
					CauserRPRI.AwardExperience(class'RPGRules'.static.Instance(Level).GetDamageEXP(
						PoisonDamage, EffectCauser.Pawn, Instigator));
				}
			}
		}
	}
}

defaultproperties
{
	xEmitterClass=class'FX_PoisonSmoke'
	EffectMessageClass=class'EffectMessage_Poison'
	
	PoisonMode=PM_Curve
}
