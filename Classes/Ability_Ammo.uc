class Ability_Ammo extends RPGAbility;

var bool bSuicided;

//FragOps-style custom weapons keep their mag capacity in the WEAPON class
//default AmmoCharge (FOGiveAmmo/FillToInitialAmmo read it and AddAmmo caps
//at it). Class defaults are shared by every player, so the stock values come
//from RPGRules (recorded once) - recording them per ability instance let a
//second Arsenal owner take the first owner's raised value as its "original"
//and stack on top of it.

function RPGRules GetRPGRules()
{
	return class'RPGRules'.static.Instance(Level);
}

function int GetBaseAmmoCharge(class<Weapon> WeaponClass, int Mode)
{
	local RPGRules Rules;

	if(WeaponClass == None || Mode < 0 || Mode > 1)
		return 0;

	if(WeaponClass.default.AmmoCharge[Mode] <= 0)
		return 0; //this fire mode has no ammo

	Rules = GetRPGRules();
	if(Rules == None)
		return WeaponClass.default.AmmoCharge[Mode];

	return Rules.GetOriginalAmmoCharge(WeaponClass, Mode);
}

function SetWeaponChargeMax(class<Weapon> WeaponClass, int Mode, int NewMax)
{
	if(WeaponClass != None && Mode >= 0 && Mode <= 1
		&& WeaponClass.default.AmmoCharge[Mode] > 0
		&& NewMax > WeaponClass.default.AmmoCharge[Mode])
	{
		WeaponClass.default.AmmoCharge[Mode] = NewMax;
	}
}

function ModifyGrantedWeaponAmmo(class<Weapon> WeaponClass, out int Ammo1, out int Ammo2)
{
	local int i, StartingAmmo, BaseCharge;
	local float Factor;
	local class<Ammunition> AmmoClass[2];
	local Ability_MaxAmmo MaxAmmoAbility;

	if(!bSuicided) {
		Factor = (1.0 + AbilityLevel * BonusPerLevel);

		//resolve ammo from the fire mode defaults OR the weapon class
		//defaults - same convention as Ability_MaxAmmo/AmmoRegen so custom
		//weapons that declare AmmoClass directly on the weapon class get
		//their starting ammo boosted too
		for(i = 0; i < 2; i++) {
			AmmoClass[i] = class'Util'.static.ResolveWeaponAmmoClassFor(WeaponClass, i);
		}
		
		if(AmmoClass[0] != None) {
			StartingAmmo = int(float(AmmoClass[0].default.InitialAmount) * Factor);
			if(Ammo1 >= 0 && Ammo1 < StartingAmmo) {
				Ammo1 = StartingAmmo;
			}
		}
		
		if(AmmoClass[1] != None && AmmoClass[1] != AmmoClass[0]) {
			StartingAmmo = int(float(AmmoClass[1].default.InitialAmount) * Factor);
			if(Ammo2 >= 0 && Ammo2 < StartingAmmo) {
				Ammo2 = StartingAmmo;
			}
		}

		//FragOps-style weapons grant their mag from the class default
		//AmmoCharge (FOGiveAmmo/FillToInitialAmmo) and AddAmmo caps there,
		//so the AmmoClass boost above never reaches the mag. Raise the class
		//default AND pass the boosted mag through Ammo1/Ammo2 so grants fill
		//bigger. If the player also owns Ability_MaxAmmo, use ITS tracking of
		//the ORIGINAL charge - otherwise Arsenal would compound on MaxAmmo's
		//raised capacity, and MaxAmmo's spawn clamp (mag == raised default at
		//first switch) would clamp the Arsenal boost away entirely.
		if(RPRI != None)
			MaxAmmoAbility = Ability_MaxAmmo(RPRI.GetAbility(class'Ability_MaxAmmo'));

		for(i = 0; i < 2; i++) {
			if(MaxAmmoAbility != None)
				BaseCharge = MaxAmmoAbility.GetBaseAmmoCharge(WeaponClass, i);
			else
				BaseCharge = GetBaseAmmoCharge(WeaponClass, i);

			if(BaseCharge > 0) {
				StartingAmmo = int(float(BaseCharge) * Factor);
				if(MaxAmmoAbility != None)
					MaxAmmoAbility.SetWeaponChargeMax(WeaponClass, i, StartingAmmo);
				else
					SetWeaponChargeMax(WeaponClass, i, StartingAmmo);

				if(i == 0) {
					if(Ammo1 >= 0 && Ammo1 < StartingAmmo) {
						Ammo1 = StartingAmmo;
					}
				} else if(Ammo2 >= 0 && Ammo2 < StartingAmmo) {
					Ammo2 = StartingAmmo;
				}
			}
		}
	}
	
	Super.ModifyGrantedWeaponAmmo(WeaponClass, Ammo1, Ammo2);
}

function bool PreventDeath(Pawn Killed, Controller Killer, class<DamageType> DamageType, vector HitLocation, bool bAlreadyPrevented)
{
	bSuicided = (Killed.Controller == Killer || Killed.Controller == None);

	return Super.PreventDeath(Killed, Killer, DamageType, HitLocation, bAlreadyPrevented);
}

simulated function string DescriptionText() {
	return repl(Super.DescriptionText(), "$1", class'Util'.static.FormatPercent(BonusPerLevel));
}

defaultproperties {
	AbilityName="Arsenal"
	StatName="Ammo Bonus"
	Description="Increases the ammunition for any weapon at spawn by $1 per level. If the weapon is re-granted from Denial or similar and its ammo count is below that value, it will be stocked up to it.||This ability has no effect if you suicided in your previous spawn."
	MaxLevel=10
	StartingCost=5
	BonusPerLevel=0.05
	Category=class'AbilityCategory_Weapons'
}
