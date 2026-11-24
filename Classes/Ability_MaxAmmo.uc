class Ability_MaxAmmo extends RPGAbility;

var array<class<Ammunition> > ModifiedAmmoClasses;
var array<int> OriginalAmmoMax;

//FragOps-style custom weapons keep their capacity in the WEAPON class
//default AmmoCharge instead of the AmmoClass MaxAmmo - track those too
var array<class<Weapon> > ModifiedWeaponClasses;
var array<int> OriginalAmmoCharge0;
var array<int> OriginalAmmoCharge1;

//weapon instances we already clamped back to the ORIGINAL mag size after a
//grant filled them from the (raised) class default - prevents re-clamping
//and leaves legitimate refills (reloads, ammo packs, regen) untouched
var array<Weapon> InstanceAmmoClamped;

//server-side sweep interval - FragOps-style weapons only get their class
//default capacity raised inside ModifyWeapon, which runs for the HELD
//weapon (RPRI.Tick) or at ModifyPawn. Weapons that enter the inventory
//mid-round (FragOps buy menu) or are never held keep the stock capacity,
//so AmmoRegen's cap (class default AmmoCharge) never sees the MaxAmmo
//bonus. Sweep the whole inventory so every owned weapon class gets raised.
var float SweepInterval;

replication
{
	reliable if(Role == ROLE_Authority)
		ClientSyncAmmoCharge;
}

//FragOps-style weapons only re-sync their AmmoCharge to the owning client
//when the weapon fires - push the capacity (Cap) and current counts (Cur)
//directly so the HUD counter updates immediately. Cap also raises this
//client's class default so client-side fills/reloads cap at the right size.
simulated function ClientSyncAmmoCharge(Weapon W, int Cap0, int Cap1, int Cur0, int Cur1)
{
	if(W == None)
		return;

	if(Cap0 > 0 && W.class.default.AmmoCharge[0] > 0 && Cap0 > W.class.default.AmmoCharge[0])
		W.class.default.AmmoCharge[0] = Cap0;
	if(Cap1 > 0 && W.class.default.AmmoCharge[1] > 0 && Cap1 > W.class.default.AmmoCharge[1])
		W.class.default.AmmoCharge[1] = Cap1;

	if(Cur0 >= 0)
		W.AmmoCharge[0] = Cur0;
	if(Cur1 >= 0)
		W.AmmoCharge[1] = Cur1;
}

simulated event PostNetBeginPlay()
{
    Super.PostNetBeginPlay();
    RestoreAmmoDefaults();
}

simulated event PostBeginPlay()
{
    Super.PostBeginPlay();
    if(Role == ROLE_Authority)
        SetTimer(SweepInterval, true);
}

//sweep the owner's full inventory so every FragOps-style weapon class gets
//its capacity raised whether or not it's ever held
function Timer()
{
    local Inventory Inv;
    local Weapon W;

    if(Role != ROLE_Authority || Instigator == None)
        return;

    for(Inv = Instigator.Inventory; Inv != None; Inv = Inv.Inventory)
    {
        W = Weapon(Inv);
        if(W != None)
            ModifyWeapon(W);
    }
}

//Raised FragOps capacity for a weapon class WITHOUT mutating the class
//default - Ability_AmmoRegen uses this so the regen cap is the MaxAmmo
//bonus even before the sweep/held-weapon path raised the class default.
function int GetRaisedAmmoCharge(class<Weapon> WeaponClass, int Mode)
{
    local int BaseCharge;

    if(WeaponClass == None || Mode < 0 || Mode > 1)
        return 0;

    BaseCharge = GetBaseAmmoCharge(WeaponClass, Mode);
    if(BaseCharge <= 0)
        return 0;

    return Max(WeaponClass.default.AmmoCharge[Mode], int(float(BaseCharge) * (1.0 + AbilityLevel * BonusPerLevel)));
}

function int GetBaseAmmoMax(class<Ammunition> AmmoClass) {
    local int i;

    if(AmmoClass == None)
        return 0;

    for(i = 0; i < ModifiedAmmoClasses.Length; i++) {
        if(ModifiedAmmoClasses[i] == AmmoClass)
            return OriginalAmmoMax[i];
    }

    ModifiedAmmoClasses[ModifiedAmmoClasses.Length] = AmmoClass;
    OriginalAmmoMax[OriginalAmmoMax.Length] = AmmoClass.Default.MaxAmmo;
    return OriginalAmmoMax[OriginalAmmoMax.Length - 1];
}

function SetAmmoClassMax(class<Ammunition> AmmoClass, int NewMax) {
    if(AmmoClass != None && NewMax > AmmoClass.Default.MaxAmmo) {
        AmmoClass.Default.MaxAmmo = NewMax;
    }
}

function int GetBaseAmmoCharge(class<Weapon> WeaponClass, int Mode) {
    local int i, Charge;

    if(WeaponClass == None || Mode < 0 || Mode > 1)
        return 0;

    Charge = WeaponClass.default.AmmoCharge[Mode];
    if(Charge <= 0)
        return 0; //this fire mode has no ammo

    for(i = 0; i < ModifiedWeaponClasses.Length; i++) {
        if(ModifiedWeaponClasses[i] == WeaponClass) {
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

function SetWeaponChargeMax(class<Weapon> WeaponClass, int Mode, int NewMax) {
    if(WeaponClass != None && Mode >= 0 && Mode <= 1
        && WeaponClass.default.AmmoCharge[Mode] > 0
        && NewMax > WeaponClass.default.AmmoCharge[Mode]) {
        WeaponClass.default.AmmoCharge[Mode] = NewMax;
    }
}

function RestoreAmmoDefaults() {
    local int i;

    for(i = 0; i < ModifiedAmmoClasses.Length; i++) {
        if(ModifiedAmmoClasses[i] != None && ModifiedAmmoClasses[i].Default.MaxAmmo > OriginalAmmoMax[i]) {
            ModifiedAmmoClasses[i].Default.MaxAmmo = OriginalAmmoMax[i];
        }
    }

    for(i = 0; i < ModifiedWeaponClasses.Length; i++) {
        if(ModifiedWeaponClasses[i] != None) {
            if(ModifiedWeaponClasses[i].default.AmmoCharge[0] > OriginalAmmoCharge0[i])
                ModifiedWeaponClasses[i].default.AmmoCharge[0] = OriginalAmmoCharge0[i];
            if(ModifiedWeaponClasses[i].default.AmmoCharge[1] > OriginalAmmoCharge1[i])
                ModifiedWeaponClasses[i].default.AmmoCharge[1] = OriginalAmmoCharge1[i];
        }
    }

    ModifiedAmmoClasses.Length = 0;
    OriginalAmmoMax.Length = 0;
    ModifiedWeaponClasses.Length = 0;
    OriginalAmmoCharge0.Length = 0;
    OriginalAmmoCharge1.Length = 0;
    InstanceAmmoClamped.Length = 0;
}

function bool WasInstanceClamped(Weapon W) {
    local int i;

    for(i = 0; i < InstanceAmmoClamped.Length; i++) {
        if(InstanceAmmoClamped[i] == W)
            return true;
    }

    return false;
}

simulated event Destroyed() {
    RestoreAmmoDefaults();
    Super.Destroyed();
}

function ModifyGrantedWeaponAmmo(class<Weapon> WeaponClass, out int Ammo1, out int Ammo2) {
    local int i, MaxAmmo;
    local float Factor;
    local class<Ammunition> AmmoClass[2];

    Factor = (1.0 + AbilityLevel * BonusPerLevel);

    //resolve ammo from the fire mode defaults OR the weapon class defaults,
    //so custom weapons that declare AmmoClass directly are handled too
    for(i = 0; i < 2; i++) {
        AmmoClass[i] = class'Util'.static.ResolveWeaponAmmoClassFor(WeaponClass, i);
    }

    if(AmmoClass[0] != None) {
        MaxAmmo = int(float(GetBaseAmmoMax(AmmoClass[0])) * Factor);
        SetAmmoClassMax(AmmoClass[0], MaxAmmo);
    }

    if(AmmoClass[1] != None && AmmoClass[1] != AmmoClass[0]) {
        MaxAmmo = int(float(GetBaseAmmoMax(AmmoClass[1])) * Factor);
        SetAmmoClassMax(AmmoClass[1], MaxAmmo);
    }

    //FragOps-style weapons keep capacity in the WEAPON class default
    //AmmoCharge - raise it so reloads, ammo packs and regen can go past the
    //old mag size (FragOps reads capacity from default.AmmoCharge). The
    //starting-ammo clamp below keeps spawns at the ORIGINAL mag size.
    for(i = 0; i < 2; i++) {
        if(GetBaseAmmoCharge(WeaponClass, i) > 0) {
            MaxAmmo = int(float(GetBaseAmmoCharge(WeaponClass, i)) * Factor);
            SetWeaponChargeMax(WeaponClass, i, MaxAmmo);
        }
    }

    //NEVER grant more starting ammo than the default: Max Ammo raises
    //CAPACITY only (ammo packs, reloads and AmmoRegen can go past the old
    //max) - spawns keep the default starting ammo. Ability_Ammo is the
    //dedicated spawn-ammo boost and its mid-range values pass through
    //untouched (clamp only applies to "no ammo given" grants).
    for(i = 0; i < 2; i++) {
        if(AmmoClass[i] != None) {
            if(i == 0) {
                if(Ammo1 <= 0) {
                    if(GetBaseAmmoCharge(WeaponClass, 0) > 0)
                        Ammo1 = GetBaseAmmoCharge(WeaponClass, 0);
                    else
                        Ammo1 = AmmoClass[0].default.InitialAmount;
                }
            }
            else if(AmmoClass[1] != AmmoClass[0]) {
                if(Ammo2 <= 0) {
                    if(GetBaseAmmoCharge(WeaponClass, 1) > 0)
                        Ammo2 = GetBaseAmmoCharge(WeaponClass, 1);
                    else
                        Ammo2 = AmmoClass[1].default.InitialAmount;
                }
            }
        }
    }

    Super.ModifyGrantedWeaponAmmo(WeaponClass, Ammo1, Ammo2);
}

function ModifyPawn(Pawn Other) {
    local Inventory Inv;
    local Weapon W;

    Super.ModifyPawn(Other);

    if(Role == ROLE_Authority && Other != None) {
        for(Inv = Other.Inventory; Inv != None; Inv = Inv.Inventory) {
            W = Weapon(Inv);
            if(W != None) {
                ModifyWeapon(W);
            }
        }
    }
}

//FragOps-style weapons fill their mag from the class default AmmoCharge on
//every grant (FOGiveTo/FOGiveAmmo, War_FOPlayer respawn code) - the first
//time this ability sees a weapon instance, clamp a grant-filled mag (exactly
//at the raised capacity) back to the ORIGINAL size so spawns and purchases
//start with default ammo. Once clamped, the instance is never clamped again,
//so reloads, ammo packs and regen can fill it up to the raised capacity.
function ModifyWeapon(Weapon W)
{
    local int i, MaxAmmo, Charge0, Charge1;
    local bool bClamped;
    local bool bRaisedAny;
    local float Factor;
    local class<Ammunition> AmmoClass[2];
    local Ammunition AmmoInst;
    local Inventory Inv;

    Super.ModifyWeapon(W);

    Factor = (1.0 + AbilityLevel * BonusPerLevel);

    //resolve ammo from the weapon's merged AmmoClass, the fire mode default
    //or the weapon class defaults - covers all custom weapon conventions
    for(i = 0; i < 2; i++) {
        AmmoClass[i] = class'Util'.static.ResolveWeaponAmmoClass(W, i);
    }

    if(AmmoClass[0] != None) {
        MaxAmmo = int(float(GetBaseAmmoMax(AmmoClass[0])) * Factor);
        if(MaxAmmo > W.MaxAmmo(0)) {
            SetAmmoClassMax(AmmoClass[0], MaxAmmo);
        }
        if(W.Instigator != None) {
            AmmoInst = Ammunition(W.Instigator.FindInventoryType(AmmoClass[0]));
            if(AmmoInst != None && AmmoInst.MaxAmmo < MaxAmmo) {
                AmmoInst.MaxAmmo = MaxAmmo;
                AmmoInst.NetUpdateTime = Level.TimeSeconds - 1;
            }
        }
    }

    if(AmmoClass[1] != None && AmmoClass[1] != AmmoClass[0]) {
        MaxAmmo = int(float(GetBaseAmmoMax(AmmoClass[1])) * Factor);
        if(MaxAmmo > W.MaxAmmo(1)) {
            SetAmmoClassMax(AmmoClass[1], MaxAmmo);
        }
        if(W.Instigator != None) {
            AmmoInst = Ammunition(W.Instigator.FindInventoryType(AmmoClass[1]));
            if(AmmoInst != None && AmmoInst.MaxAmmo < MaxAmmo) {
                AmmoInst.MaxAmmo = MaxAmmo;
                AmmoInst.NetUpdateTime = Level.TimeSeconds - 1;
            }
        }
    }

    //Chaos-style weapons keep 2+ ammo types as real Ammunition inventory
    //items (AmmoType array) - only the CURRENTLY SELECTED type matches the
    //fire mode, so raise the class default AND instance MaxAmmo for EVERY
    //ammo type the player owns. Generic: works for any classic-ammo weapon
    //regardless of how many ammo types it has.
    if(W.Instigator != None) {
        for(Inv = W.Instigator.Inventory; Inv != None; Inv = Inv.Inventory) {
            AmmoInst = Ammunition(Inv);
            if(AmmoInst != None) {
                MaxAmmo = int(float(GetBaseAmmoMax(AmmoInst.class)) * Factor);
                if(MaxAmmo > AmmoInst.class.default.MaxAmmo) {
                    SetAmmoClassMax(AmmoInst.class, MaxAmmo);
                }
                if(AmmoInst.MaxAmmo < MaxAmmo) {
                    AmmoInst.MaxAmmo = MaxAmmo;
                    AmmoInst.NetUpdateTime = Level.TimeSeconds - 1;
                }
            }
        }
    }

    //raise the weapon class default AmmoCharge as well - FragOps weapons
    //read their capacity from there (MaxAmmo/AmmoAmount/ReloadClip/AddAmmo
    //all run off default.AmmoCharge), so this makes the ability actually
    //increase mag size and reload caps for them
    for(i = 0; i < 2; i++) {
        if(GetBaseAmmoCharge(W.class, i) > 0) {
            MaxAmmo = int(float(GetBaseAmmoCharge(W.class, i)) * Factor);
            if(W.class.default.AmmoCharge[i] < MaxAmmo) {
                SetWeaponChargeMax(W.class, i, MaxAmmo);
                bRaisedAny = true;
            }
        }
    }

    //capacity raised but the mag didn't change (first sweep/switch on an
    //unheld weapon) - push capacity AND current counts so the owning
    //client's HUD max counter updates immediately
    if(bRaisedAny)
        ClientSyncAmmoCharge(W, W.class.default.AmmoCharge[0], W.class.default.AmmoCharge[1], W.AmmoCharge[0], W.AmmoCharge[1]);

    //grants (buy menu, respawn fills) put the mag at the raised class
    //default - clamp it back to the ORIGINAL size once so spawns/purchases
    //start with default ammo. Only fires when the mag is exactly at the
    //raised capacity (= grant-filled); already-clamped instances and
    //partially filled mags are left alone.
    if(Role == ROLE_Authority && W.Instigator != None && !WasInstanceClamped(W)) {
        Charge0 = GetBaseAmmoCharge(W.class, 0);
        Charge1 = GetBaseAmmoCharge(W.class, 1);

        if(Charge0 > 0 || Charge1 > 0) {
            if(Charge0 > 0 && W.AmmoCharge[0] == W.class.default.AmmoCharge[0] && W.AmmoCharge[0] > 0) {
                W.AmmoCharge[0] = Charge0;
                W.NetUpdateTime = Level.TimeSeconds - 1;
                bClamped = true;
            }
            if(Charge1 > 0 && W.AmmoCharge[1] == W.class.default.AmmoCharge[1] && W.AmmoCharge[1] > 0) {
                W.AmmoCharge[1] = Charge1;
                W.NetUpdateTime = Level.TimeSeconds - 1;
                bClamped = true;
            }
            if(bClamped) {
                //sync the clamped counts (and the raised capacity) straight
                //to the owning client - FragOps weapons don't replicate
                //their AmmoCharge until fired, so the client would show the
                //stale grant-filled count otherwise
                ClientSyncAmmoCharge(W, W.class.default.AmmoCharge[0], W.class.default.AmmoCharge[1], W.AmmoCharge[0], W.AmmoCharge[1]);
            }
            InstanceAmmoClamped[InstanceAmmoClamped.Length] = W;
        }
    }
}

simulated function string DescriptionText() {
    return repl(Super.DescriptionText(), "$1", class'Util'.static.FormatPercent(BonusPerLevel));
}

defaultproperties {
    SweepInterval=2.000000
    AbilityName="Max Ammo"
    StatName="Max Ammo Bonus"
    Description="Increases each weapon's maximum ammo by $1 per level."
    MaxLevel=20
    StartingCost=5
    BonusPerLevel=0.05
    Category=class'AbilityCategory_Weapons'
}
