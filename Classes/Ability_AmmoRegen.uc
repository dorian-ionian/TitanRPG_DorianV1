class Ability_AmmoRegen extends RPGAbility;

var config float RegenInterval;
var config int MinRegenPerLevel;

var MutTitanRPG RPGMut; //to avoid the nasty accessed none's at the end of a match

//last AmmoCharge values pushed to the owning client per weapon - the sync
//RPC is only sent when a value changed (FragOps-style weapons don't
//replicate their AmmoCharge to the client until the weapon fires)
var array<Weapon> SyncWeapons;
var array<int> SyncCharge0;
var array<int> SyncCharge1;

replication
{
	reliable if(Role == ROLE_Authority)
		RegenInterval, MinRegenPerLevel;

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

function SyncAmmoToClient(Weapon W)
{
	local int i;

	for(i = 0; i < SyncWeapons.Length; i++)
	{
		if(SyncWeapons[i] == W)
		{
			if(SyncCharge0[i] != W.AmmoCharge[0] || SyncCharge1[i] != W.AmmoCharge[1])
			{
				ClientSyncAmmoCharge(W, W.class.default.AmmoCharge[0], W.class.default.AmmoCharge[1], W.AmmoCharge[0], W.AmmoCharge[1]);
				SyncCharge0[i] = W.AmmoCharge[0];
				SyncCharge1[i] = W.AmmoCharge[1];
			}
			return;
		}
	}

	SyncWeapons[SyncWeapons.Length] = W;
	SyncCharge0[SyncCharge0.Length] = W.AmmoCharge[0];
	SyncCharge1[SyncCharge1.Length] = W.AmmoCharge[1];
	ClientSyncAmmoCharge(W, W.class.default.AmmoCharge[0], W.class.default.AmmoCharge[1], W.AmmoCharge[0], W.AmmoCharge[1]);
}

//The owner's Ability_MaxAmmo instance (if owned) - its raised FragOps
//capacity is the authoritative regen cap for FragOps-style weapons.
function Ability_MaxAmmo GetMaxAmmoAbility()
{
	local int i;

	if(RPRI == None)
		return None;

	for(i = 0; i < RPRI.Abilities.Length; i++)
	{
		if(RPRI.Abilities[i] != None && Ability_MaxAmmo(RPRI.Abilities[i]) != None)
			return Ability_MaxAmmo(RPRI.Abilities[i]);
	}

	return None;
}

simulated event PostBeginPlay()
{
	Super.PostBeginPlay();
	
	RPGMut = class'MutTitanRPG'.static.Instance(Level);
}

function ModifyPawn(Pawn Other)
{
	Super.ModifyPawn(Other);
	SetTimer(RegenInterval, true);
}

function int GetRegenAmountFor(class<Ammunition> AmmoClass)
{
	if(AmmoClass == None)
		return 0;

	return Max(MinRegenPerLevel * AbilityLevel, int(
		BonusPerLevel * float(AbilityLevel) * float(AmmoClass.default.MaxAmmo)));
}

function Timer()
{
	local Inventory Inv;
	local Ammunition Ammo;
	local Weapon W;
	local int Amount;
	local int Cap;
	local class<Ammunition> AC[2];
	local Ability_MaxAmmo MaxAmmoAbility;

	if(Instigator == None || Instigator.Health <= 0)
	{
		SetTimer(0.0f, false);
		return;
	}	

	//the real regen cap for FragOps-style weapons is the MaxAmmo-raised
	//capacity, not the class default (which only gets raised when the
	//weapon is held or the MaxAmmo sweep has seen it)
	MaxAmmoAbility = GetMaxAmmoAbility();
	
	for(Inv = Instigator.Inventory; Inv != None; Inv = Inv.Inventory)
	{
		W = Weapon(Inv);
		if(W != None)
		{
			//FragOps-style weapons keep their magazine in AmmoCharge even
			//when bNoAmmoInstances is False, so route them here too
			if(W.bNoAmmoInstances || W.class.default.AmmoCharge[0] > 0)
			{
				//resolve ammo the same way as Ability_MaxAmmo so custom
				//weapons (fire mode defaults OR weapon class defaults) regen
				AC[0] = class'Util'.static.ResolveWeaponAmmoClass(W, 0);
				AC[1] = class'Util'.static.ResolveWeaponAmmoClass(W, 1);
				
				if(AC[0] != None && !RPGMut.IsSuperWeaponAmmo(AC[0]))
				{
					Amount = GetRegenAmountFor(AC[0]);
					//FragOps-style weapons keep their capacity in the class
					//default AmmoCharge (default.AmmoCharge[0] > 0) and their
					//AddAmmo caps at it. Akimbo FragOps weapons override
					//AddAmmo to SET the mag to the added amount instead of
					//adding (AkimboAddAmmo), which would pin the mag at the
					//regen amount forever - add to AmmoCharge directly so
					//the mag fills like the non-akimbo weapons.
					if(W.class.default.AmmoCharge[0] > 0)
					{
						Cap = W.class.default.AmmoCharge[0];
						if(MaxAmmoAbility != None)
							Cap = MaxAmmoAbility.GetRaisedAmmoCharge(W.class, 0);
						if(Cap <= 0)
							Cap = W.class.default.AmmoCharge[0];
						W.AmmoCharge[0] = Min(W.AmmoCharge[0] + Amount, Cap);
						W.NetUpdateTime = W.Level.TimeSeconds - 1;
					}
					else
						W.AddAmmo(Amount, 0);
				}
				if(AC[1] != None && AC[1] != AC[0] && !RPGMut.IsSuperWeaponAmmo(AC[1]))
					W.AddAmmo(GetRegenAmountFor(AC[1]), 1);

				//FragOps-style weapons (capacity in the class default
				//AmmoCharge) don't replicate their AmmoCharge to the client
				//until fired - push the current counts so the HUD counter
				//shows the regen as it happens
				if(W.class.default.AmmoCharge[0] > 0 || W.class.default.AmmoCharge[1] > 0)
					SyncAmmoToClient(W);
			}
		}
		else
		{
			Ammo = Ammunition(Inv);
			if(Ammo != None && !RPGMut.IsSuperWeaponAmmo(Ammo.Class))
				Ammo.AddAmmo(GetRegenAmountFor(Ammo.class));
		}
	}
}

simulated function string DescriptionText()
{
	return Repl(
				Repl(
					Repl(Super.DescriptionText(), "$1", class'Util'.static.FormatPercent(BonusPerLevel)),
					"$2", MinRegenPerLevel),
				"$3", class'Util'.static.FormatFloat(RegenInterval));
}

defaultproperties
{
	BonusPerLevel=0.010000
	RegenInterval=3.000000
	MinRegenPerLevel=1
	
	AbilityName="Resupply"
	Description="Adds $1 of the max ammo (or at least $2) per level to each ammo type you own every $3 seconds.|Does not give ammo to superweapons or the translocator."
	StartingCost=5
	CostAddPerLevel=5
	MaxLevel=7
	Category=class'AbilityCategory_Weapons'
}
