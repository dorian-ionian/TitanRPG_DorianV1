class Ability_Ammo extends RPGAbility;

var bool bSuicided;

//FragOps-style custom weapons keep their mag capacity in the WEAPON class
//default AmmoCharge (FOGiveAmmo/FillToInitialAmmo read it and AddAmmo caps
//at it) - track the original values so Arsenal can raise them and restore
//them later (same convention as Ability_MaxAmmo)
var array<class<Weapon> > ModifiedWeaponClasses;
var array<int> OriginalAmmoCharge0;
var array<int> OriginalAmmoCharge1;

simulated event PostNetBeginPlay()
{
	Super.PostNetBeginPlay();
	RestoreAmmoDefaults();
}

simulated event Destroyed()
{
	RestoreAmmoDefaults();
	Super.Destroyed();
}

function int GetBaseAmmoCharge(class<Weapon> WeaponClass, int Mode)
{
	local int i, Charge;

	if(WeaponClass == None || Mode < 0 || Mode > 1)
		return 0;

	Charge = WeaponClass.default.AmmoCharge[Mode];
	if(Charge <= 0)
		return 0; //this fire mode has no ammo

	for(i = 0; i < ModifiedWeaponClasses.Length; i++)
	{
		if(ModifiedWeaponClasses[i] == WeaponClass)
		{
			if(Mode == 0)
				return OriginalAmmoCharge0[i];
			return OriginalAmmoCharge1[i];
		}
	}

	ModifiedWeaponClasses[ModifiedWeaponClasses.Length] = WeaponClass;
	OriginalAmmoCharge0[OriginalAmmoCharge0.Length] = WeaponClass.default.AmmoCharge[0];
	OriginalAmmoCharge1[OriginalAmmoCharge1.Length] = WeaponClass.default.AmmoCharge[1];
	return Charge;
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

function RestoreAmmoDefaults()
{
	local int i;

	for(i = 0; i < ModifiedWeaponClasses.Length; i++)
	{
		if(ModifiedWeaponClasses[i] != None)
		{
			if(ModifiedWeaponClasses[i].default.AmmoCharge[0] > OriginalAmmoCharge0[i])
				ModifiedWeaponClasses[i].default.AmmoCharge[0] = OriginalAmmoCharge0[i];
			if(ModifiedWeaponClasses[i].default.AmmoCharge[1] > OriginalAmmoCharge1[i])
				ModifiedWeaponClasses[i].default.AmmoCharge[1] = OriginalAmmoCharge1[i];
		}
	}

	ModifiedWeaponClasses.Length = 0;
	OriginalAmmoCharge0.Length = 0;
	OriginalAmmoCharge1.Length = 0;
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
