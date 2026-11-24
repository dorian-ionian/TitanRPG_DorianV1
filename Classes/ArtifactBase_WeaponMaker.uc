class ArtifactBase_WeaponMaker extends ArtifactBase_DelayedUse
	abstract
    HideDropDown;

var config bool bAvoidRepetition;

var config array<class<Weapon> > ForbiddenWeaponTypes;

const MSG_UnableToGenerate = 0x0100;
const MSG_AlreadyConstructing = 0x0101;
const MSG_Broken = 0x0102;

var localized string MsgUnableToGenerate, MsgAlreadyConstructing, MsgBroken;

var Weapon OldWeapon; //the single held weapon, used by subclasses that don't handle DualWield
var array<Weapon> TargetWeapons; //held weapons to enchant: the held weapon, or both guns inside DualWield's container
var() Sound BrokenSound;

static function string GetMessageString(int Msg, optional int Value, optional Object Obj)
{
	switch(Msg)
	{
		case MSG_UnableToGenerate:
			return default.MsgUnableToGenerate;
			
		case MSG_AlreadyConstructing:
			return default.MsgAlreadyConstructing;
			
		case MSG_Broken:
			return default.MsgBroken;
	
		default:
			return Super.GetMessageString(Msg, Value);
	}
}

simulated event PostBeginPlay()
{
	Super.PostBeginPlay();

	if(Role < ROLE_Authority)
		return;
}

function bool IsForbiddenWeapon(class<Weapon> WeaponType)
{
	local int i;

	for(i = 0; i < ForbiddenWeaponTypes.Length; i++)
	{
		if(ClassIsChildOf(WeaponType, ForbiddenWeaponTypes[i]))
			return true;
	}
	return false;
}

//With DualWield, the container itself is never enchanted (that breaks the overlays of its guns).
//Instead, both guns it holds are enchanted, including akimbo copies, which DualWield marks with Hand != 0.
function CollectTargetWeapons()
{
	local Weapon W;

	TargetWeapons.Length = 0;
	if(Instigator == None || Instigator.Weapon == None)
		return;

	if(Instigator.Weapon.IsA('dw_DualWeapon'))
	{
		foreach Instigator.ChildActors(class'Weapon', W)
		{
			if(W.Hand != 0 && !W.IsA('dw_DualWeapon') && !IsForbiddenWeapon(W.class))
				TargetWeapons[TargetWeapons.Length] = W;
		}
	}
	else if(!IsForbiddenWeapon(Instigator.Weapon.class))
	{
		TargetWeapons[0] = Instigator.Weapon;
	}
}

function bool CanActivate()
{
	if(!Super.CanActivate())
		return false;

	CollectTargetWeapons();
	if(TargetWeapons.Length == 0)
	{
		OldWeapon = None;
		Msg(MSG_UnableToGenerate);
		return false;
	}

	OldWeapon = TargetWeapons[0];
	return true;
}

//Rolls a new modifier for W. Returns false if W could not get one.
function bool EnchantWeapon(Weapon W)
{
	local RPGWeaponModifier WM;
	local class<RPGWeaponModifier> OldModifier, NewModifier;
	local int x, tries;

	if(W == None || W.bDeleteMe)
		return false;

	WM = class'RPGWeaponModifier'.static.GetFor(W);
	if(WM != None)
		OldModifier = WM.class;

	for(x = 0; x < 50; x++) {
		if(bAvoidRepetition) {
			//try to generate a weapon of different magic than the old one
			for(tries = 0; tries < 50; tries++) {
				NewModifier = GetRandomWeaponModifier(W.class, Instigator);
				
				if(NewModifier == None || NewModifier != OldModifier) {
					tries = 50; //break inner loop
				}
			}
		} else {
			NewModifier = GetRandomWeaponModifier(W.class, Instigator);
		}
		
		if(NewModifier == None || NewModifier.static.AllowedFor(W.class, Instigator)) {
			break;
		}
	}
	
	if(x == 50)
		return false;

	if(NewModifier != None) {
		WM = NewModifier.static.Modify(W, NewModifier.static.GetRandomPositiveModifierLevel(), true);
	} else {
		class'RPGWeaponModifier'.static.RemoveModifier(W);
	}

	return true;
}


state Activated
{
	function bool DoEffect()
	{
		local int i;
		local bool bEnchanted;

		for(i = 0; i < TargetWeapons.Length; i++) {
			if(EnchantWeapon(TargetWeapons[i]))
				bEnchanted = true;
		}

		if(!bEnchanted) {
			Msg(MSG_UnableToGenerate);
			return false;
		}

        //Former breaking logic
        /*
		LA = Ability_LoadedArtifacts(InstigatorRPRI.GetOwnedAbility(class'Ability_LoadedArtifacts'));
		if(LA == None || !LA.ProtectArtifacts())
		{
			if(bCanBreak && Rand(3) == 0) //25% chance
			{
				Msg(MSG_Broken);
				
				if(PlayerController(Instigator.Controller) != None)
			        PlayerController(Instigator.Controller).ClientPlaySound(BrokenSound);
				
				Destroy();
			}
		}
        */
		
		return true;
	}
}

function class<RPGWeaponModifier> GetRandomWeaponModifier(class<Weapon> WeaponType, Pawn Other);

defaultproperties
{
	bAllowInVehicle=False
	bAffectsHeldWeapon=True
	MsgUnableToGenerate="Unable to enchant weapon."
	MsgAlreadyConstructing="Already enchanting a weapon."
	MsgBroken="The artifact has broken."
	ForbiddenWeaponTypes(0)=class'BallLauncher'
	ForbiddenWeaponTypes(1)=class'TransLauncher'
}
