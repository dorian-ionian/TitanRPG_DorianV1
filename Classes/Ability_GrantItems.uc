//Base class for hard-coded "grant items on spawn" abilities.
//
//Replaces the old ini-driven RPGConfigAbility modules (2026-08-19): the granted
//item classes are stored as plain strings and resolved at runtime via
//DynamicLoadObject, because some of the referenced packages (ChaosUT, DMNWeapons,
//FragOps, KFMod, RFSystem, ROWeapons, XMPWeapons) are not present on the build
//machine and cannot be resolved at compile time.
//
//Resolution happens server-side only, BEFORE Super.PostBeginPlay() so the base
//class can pass every resolved class through BaseMutator.GetInventoryClass()
//(same code path the generated config abilities used). Clients receive the
//GrantItem entries through the standard ClientReceiveGrantedItem replication.
class Ability_GrantItems extends RPGAbility abstract;

var array<string> GrantItemNames;

simulated event PostBeginPlay()
{
	local int i;
	local class<Inventory> InvClass;

	if(Role == ROLE_Authority)
	{
		for(i = 0; i < GrantItemNames.Length; i++)
		{
			InvClass = class<Inventory>(DynamicLoadObject(GrantItemNames[i], class'Class'));
			if(InvClass != None)
			{
				//IMPORTANT: struct arrays do NOT auto-grow in this engine -
				//GrantItem[GrantItem.Length] = ... silently fails out of bounds,
				//leaving the array empty and the ability granting NOTHING.
				//Must grow Length explicitly before filling (RPGConfigAbility pattern).
				GrantItem.Length = GrantItem.Length + 1;
				GrantItem[GrantItem.Length - 1].Level = 1;
				GrantItem[GrantItem.Length - 1].InventoryClass = InvClass;
			}
			else
			{
				Log("WARNING: Could not resolve granted item class:" @ GrantItemNames[i], 'TitanRPG');
			}
		}
		Log(AbilityName @ "will grant" @ GrantItem.Length @ "item(s)", 'TitanRPG');
	}

	Super.PostBeginPlay();
}

defaultproperties
{
}
