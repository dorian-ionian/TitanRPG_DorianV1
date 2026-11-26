/*
	FINALLY getting rid of RPGWeapon. This is the future.
*/
class RPGWeaponModifier extends RPGBase
	Config(TitanRPG);

//Weapon
var Weapon Weapon;
var class<Weapon> WeaponClass; //FIX: for re-acquiring after DMN-style weapon instance churn
var RPGPlayerReplicationInfo RPRI;
var bool bActive;

//Modifier level
var config int MinModifier, MaxModifier;
var config bool bCanHaveZeroModifier;

var int Modifier;

//Bonus
var config float DamageBonus, BonusPerLevel;

//Visual
var bool bIdentified;
var Material ModifierOverlay;

//Client Sync
var Sync_OverlayMaterial SyncThirdPerson;
var Weapon CachedSpriteWeapon; //HasSpriteDisplay result for CachedSpriteWeapon, so Tick doesn't recheck it every frame
var bool bCachedSprite;

var int ClientModifier;
var bool bClientIdentified; //checked client-side
var bool bResetPendingWeapon; //fixes PipedSwitchWeapon
var int LastFireMask; //fire edge detection for the WeaponFire hook

//Item name
var localized string PatternPos, PatternNeg;

//AI
var float AIRatingBonus;
var array<class<DamageType> > CountersDamage;
var array<class<RPGWeaponModifier> > CountersModifier;

//Restrictions
var config array<class<Weapon> > ForbiddenWeaponTypes;
var config bool bAllowForSpecials; //inventory groups 0 (super weapons) and 10 (xloc)
var bool bCanThrow;

//Description
var bool bOmitModifierInName;
var localized string DamageBonusText;
var string Description;

replication{
    reliable if(Role == ROLE_Authority && bNetInitial)
        Weapon;

    reliable if(Role == ROLE_Authority && bNetDirty)
        Modifier, bIdentified;
    
	reliable if(Role == ROLE_Authority)
		ClientReceiveBaseConfig, ClientSetFirstPersonOverlay, ClientSetActive, ClientRestore;
}

static function bool AllowedFor(class<Weapon> WeaponType, optional Pawn Other) {
    local int i;

    for(i = 0; i < class'MutTitanRPG'.default.DisallowModifiersFor.Length; i++) {
        if(ClassIsChildOf(WeaponType, class'MutTitanRPG'.default.DisallowModifiersFor[i])) {
            return false;
        }
    }

	if(!default.bAllowForSpecials &&
		(
			WeaponType.default.InventoryGroup == 0 || //Super weapons
			WeaponType.default.InventoryGroup == 10 || //Translocator
			WeaponType.default.InventoryGroup == 15 //Ball Launcher
		)
	) {
		return false;
	}

    for(i = 0; i < default.ForbiddenWeaponTypes.Length; i++) {
        if(ClassIsChildOf(WeaponType, default.ForbiddenWeaponTypes[i])) {
            return false;
        }
    }
    
	return true;
}

function Weapon GetWeapon() {
	return Weapon;
}

function class<Weapon> GetWeaponClass() {
	return WeaponClass;
}

function bool IsIdentified() {
	return bIdentified;
}

function Material GetOverlay() {
	return ModifierOverlay;
}

function ApplyTo(Weapon W) {
	Class.static.Modify(W, Modifier, true, true);
}

// Spawns a separate modifier for W, preferably of a different modifier class
// picked from the server's weighted list, otherwise of this class with a different level.
// Spawns directly instead of using Modify, because Modify's RemoveModifier could take this modifier's weapon.
function RPGBase CloneFor(Weapon W) {
	local Pawn P;
	local RPGWeaponModifier WM;
	local class<RPGWeaponModifier> NewClass;
	local int x, i;

	P = W.Instigator;
	if(P == None)
		P = Pawn(W.Owner);
	if(P == None)
		return None;

	NewClass = Class;
	if(RPRI != None && RPRI.RPGMut != None) {
		for(i = 0; i < 10 && NewClass == Class; i++)
			NewClass = RPRI.RPGMut.GetRandomWeaponModifier(W.Class, P, true);
	}
	if(NewClass == None)
		NewClass = Class;

	x = NewClass.static.GetRandomModifierLevel();
	if(NewClass == Class) {
		for(i = 0; i < 5 && x == Modifier; i++)
			x = GetRandomModifierLevel();
	}

	WM = P.Spawn(NewClass, W);
	if(WM != None)
		WM.SetModifier(x, true);
	return WM;
}

static function RPGWeaponModifier Modify(Weapon W, int Modifier, optional bool bIdentify, optional bool bForce) {
	local RPGWeaponModifier WM;
	local Pawn P;
	
	if(!bForce && !AllowedFor(W.class, W.Instigator))
		return None;
	
    RemoveModifier(W); //remove existing
	
	//FIX (custom weapons): fall back to the weapon owner if Instigator is
	//not set yet (custom weapon systems may spawn weapons without GiveTo)
	P = W.Instigator;
	if(P == None)
		P = Pawn(W.Owner);
	
	if(P == None)
		return None;
	
	WM = P.Spawn(default.class, W);
	if(WM != None) {
        if(Modifier == -100) {
            //Random
            Modifier = GetRandomModifierLevel();
        }

        WM.SetModifier(Modifier, bIdentify);
    }

	return WM;
}

static function RemoveModifier(Weapon W) {
    local RPGWeaponModifier WM;

    WM = GetFor(W, true);
    if(WM != None) {
        WM.Destroy();
    }
}

static function RPGWeaponModifier GetFor(Weapon W, optional bool bAny) {
	local RPGWeaponModifier WM;
	local Pawn P;
	local bool bHeld;

	if(W != None) {
		//FIX (custom weapons): fall back to the weapon owner if Instigator
		//is not set yet, same as Modify()
		P = W.Instigator;
		if(P == None)
			P = Pawn(W.Owner);
		
		if(P != None) {
			bHeld = (P.Weapon == W);
			
			//Exact instance match
			foreach P.ChildActors(class'RPGWeaponModifier', WM) {
				if(WM.Weapon == W && (bAny || ClassIsChildOf(WM.class, default.class))) {
					return WM;
				}
			}
			
			//FIX (DMN weapons): DMN destroys/recreates weapon instances (only
			//ONE live instance per class - its GiveTo destroys duplicate
			//copies), so a same-class modifier may point at a stale/replaced
			//instance. If the queried weapon is the one being held/used,
			//re-point the modifier to it so the effect follows the weapon the
			//player is actually firing. Otherwise only adopt truly-orphaned
			//refs (Weapon==None || bDeleteMe).
			foreach P.ChildActors(class'RPGWeaponModifier', WM) {
				if(WM.WeaponClass == W.class && (bAny || ClassIsChildOf(WM.class, default.class))) {
					if(WM.Weapon == W)
						continue; //handled by exact match above
					if(bHeld || WM.Weapon == None || WM.Weapon.bDeleteMe) {
						WM.Weapon = W;
						WM.Instigator = P;
						if(WM.bIdentified)
							WM.Identify(true);
						return WM;
					}
				}
			}
		}
	}
	return None;
}

static function string ConstructItemName(class<Weapon> WeaponClass, int Modifier) {
	local string NewItemName;
	local string Pattern;
    
	if(default.PatternNeg == "")
		default.PatternNeg = default.PatternPos;
	
	if(Modifier >= 0) {
		Pattern = default.PatternPos;
	} else if(Modifier < 0) {
		Pattern = default.PatternNeg;
    }
	
	NewItemName = repl(Pattern, "$W", WeaponClass.default.ItemName);
	
	if(!default.bOmitModifierInName) {
		if(Modifier > 0)
			NewItemName @= "+" $ Modifier;
		else if(Modifier < 0)
			NewItemName @= Modifier;
	}

	return NewItemName;
}

static function int GetRandomModifierLevel() {
	local int x;

	if(default.MinModifier == 0 && default.MaxModifier == 0)
		return 0;

	x = Rand(default.MaxModifier + 1 - default.MinModifier) + default.MinModifier;
	
	if(x == 0 && !default.bCanHaveZeroModifier)
		x = 1;
		
	return x;
}

static function int GetRandomPositiveModifierLevel(optional int Minimum) {
    local int x;

    if(default.bCanHaveZeroModifier) {
        Minimum = Max(0, Minimum);
    } else {
        Minimum = Max(1, Minimum);
    }
    
    x = Max(Minimum, default.MinModifier);

	if(default.MaxModifier <= x) {
		return default.MaxModifier; //well, what can we do?
	} else {
		return Rand(default.MaxModifier + 1 - x) + x;
    }
}

simulated event PostBeginPlay() {
    Super.PostBeginPlay();
    
    if(Role == ROLE_Authority) {
        SetWeapon(Weapon(Owner));
        if(Weapon == None) {
            Warn(Self @ "has no weapon!");
            Destroy();
        } else {
            SetOwner(Weapon.Instigator);
        }
    }
}

simulated event PostNetBeginPlay() {
	Super.PostNetBeginPlay();
	
	if(Role == ROLE_Authority) {
        SendConfig();
    }
}

//A gun in DualWield's container is never Pawn.Weapon itself; the container is. DualWield sets Hand on held guns.
function bool IsHeldByInstigator() {
    if(Instigator == None || Weapon == None)
        return false;
    if(Instigator.Weapon == Weapon)
        return true;
    return Instigator.Weapon != None && Instigator.Weapon.IsA('dw_DualWeapon') && Weapon.Hand != 0;
}

function SetWeapon(Weapon W) {
    Weapon = W;
    //FIX: guard against None so WeaponClass is never left unset (a modifier
    //with WeaponClass==None can't reacquire/re-point through DMN churn)
    if(W != None)
        WeaponClass = W.class;
    if(W != None)
        Instigator = W.Instigator;
    else
        Instigator = None;
    
    //FIX (custom weapons): guard against weapons that were never given
    if(Instigator != None && Instigator.PlayerReplicationInfo != None) {
        RPRI = class'RPGPlayerReplicationInfo'.static.GetForPRI(Instigator.PlayerReplicationInfo);
    } else {
        RPRI = None;
    }
}

function SetModifier(int x, optional bool bIdentify) {
	local bool bWasActive;
	
	bWasActive = bActive;
	if(bActive) {
		SetActive(false);
    }

	Modifier = x;
	
	if(Modifier < 0 || Modifier > MaxModifier) {
		Weapon.bCanThrow = false; //cannot throw negative or enhanced weapons
	} else {
		Weapon.bCanThrow = Weapon.default.bCanThrow && bCanThrow;
    }
	
    if(bIdentify || bIdentified) {
        Identify(true);
    }
	
	if(bWasActive) {
		SetActive(true);
    }
}

function SendConfig() {
    ClientReceiveBaseConfig(DamageBonus, BonusPerLevel);
}

simulated function ClientReceiveBaseConfig(float xDamageBonus, float xBonusPerLevel) {
    if(Role < ROLE_Authority) {
        DamageBonus = xDamageBonus;
        BonusPerLevel = xBonusPerLevel;
    }
}

simulated event Tick(float dt) {
    local xPawn X;
    local Inventory Inv;

	if(Role == ROLE_Authority) {
		//FIX (custom weapons): DMN-style weapons destroy/recreate their
		//weapon instances (DropFrom destroys, pickup GiveTo replaces),
		//which nulls (or leaves a stale bDeleteMe) Weapon ref. Handle BOTH
		//cases by re-acquiring a same-class weapon from the pawn. If no
		//same-class weapon exists (it was dropped), STAY DORMANT instead of
		//self-destructing - GetFor will re-attach us when a new instance
		//of the same class is picked up.
		if(Weapon == None || Weapon.bDeleteMe) {
			Weapon = None;
			if(Owner != None && Owner.IsA('Weapon')) {
				Weapon = Weapon(Owner);
			} else if(Owner != None && Pawn(Owner) != None) {
				if(Pawn(Owner).Weapon != None && Pawn(Owner).Weapon.class == WeaponClass) {
					Weapon = Pawn(Owner).Weapon;
				} else {
					for(Inv = Pawn(Owner).Inventory; Inv != None; Inv = Inv.Inventory) {
						if(Inv.IsA('Weapon') && Inv.class == WeaponClass) {
							Weapon = Weapon(Inv);
							break;
						}
					}
				}
				if(Weapon != None) {
					Instigator = Pawn(Owner);
					if(bIdentified)
						Identify(true);
				}
			}
			if(Weapon == None) {
				//Weapon is gone (dropped/destroyed) - stay dormant and wait
				//for a new same-class instance instead of self-destructing.
				SetActive(false);
				return;
			}
		}

		if(Instigator != None) {
			if(!bActive && IsHeldByInstigator()) {
				SetActive(true);
			} else if(bActive && !IsHeldByInstigator()) {
				SetActive(false);
            }
		} else if(bActive) {
			SetActive(false);
		}
		
		if(bActive) {
            //Sprite weapons (Doom) must never get an overlay: DoomWeapon copies it into a shared shader that stays white
            if(bIdentified && xPawn(Instigator) != None && !IsSpriteWeapon()) {
                X = xPawn(Instigator);
                if(X.HasUDamage()) {
                    if(Weapon.OverlayMaterial != X.UDamageWeaponMaterial) {
                        SetOverlay(X.UDamageWeaponMaterial);
                    }
                } else if(X.bInvis) {
                    if(Weapon.OverlayMaterial != X.InvisMaterial) {
                        SetOverlay(X.InvisMaterial);
                    }
                } else if(Weapon.OverlayMaterial != ModifierOverlay) {
                    SetOverlay();
                }
            }
            
            //FIX (custom weapons): stock TitanRPG never wired up the
            //WeaponFire() hook - detect fires so modifiers like
            //WeaponModifier_Infinity (identify on fire) work on any weapon
            DetectWeaponFire();
            
			RPGTick(dt);
        }
	}
    
    if(Role < ROLE_Authority || Level.NetMode == NM_Standalone) {
        if(bResetPendingWeapon) {
            bResetPendingWeapon = false;
            
            if(Instigator != None) {
                Instigator.PendingWeapon = None;
            }
        }
    
        if(Weapon != None) {
            if(bIdentified && (!bClientIdentified || Modifier != ClientModifier)) {
                ClientModifier = Modifier;
                bClientIdentified = true;
            
                ClientIdentify();
            }
        
            if(bActive) {
                if(Weapon != None) {
                    ClientRPGTick(dt);
                }
            }
        }
    }
}

function Identify(optional bool bReIdentify) {
	if(!bIdentified || bReIdentify) {
		Weapon.ItemName = ConstructItemName(Weapon.class, Modifier);
		bIdentified = true;
	}
}

simulated function ClientIdentify() {
    if(Role < ROLE_Authority) {
        Weapon.ItemName = ConstructItemName(Weapon.class, Modifier);
        Description = "";
        
        if(Instigator.Weapon == Weapon) {
            //Hud hack - force display of weapon name as if it has just been selected
            Instigator.PendingWeapon = Weapon;
            bResetPendingWeapon = true;
        }
    }
}

simulated function ClientRestore() {
    if(Role < ROLE_Authority) {
        Weapon.ItemName = Weapon.default.ItemName;
        
        if(Instigator.Weapon == Weapon) {
            Instigator.PendingWeapon = Weapon;
        }
    }
}

function SetActive(bool bActivate) {
	if(bActivate && !bActive) {
		StartEffect();
        ClientSetActive(true);
		
		if(bIdentified)
			SetOverlay();
	}
	else if(!bActivate && bActive) {
		StopEffect();
        ClientSetActive(false);
	}

	bActive = bActivate;
}

simulated function ClientSetActive(bool bActivate) {
    if(Role < ROLE_Authority || Level.NetMode == NM_Standalone) {
        bActive = bActivate;
        
        if(bActivate) {
            ClientStartEffect();
        } else {
            ClientStopEffect();
        }
    }
}

simulated function ClientSetFirstPersonOverlay(Material Mat) {
    Weapon.SetOverlayMaterial(Mat, 9999, true);
}

//Weapons drawn as sprites (Doom weapons) would show the overlay as a flat sprite, so they never get it
function bool HasSpriteDisplay() {
    local class<WeaponAttachment> AttachClass;

    if(Weapon == None) {
        return false;
    }

    if(Weapon.IsA('DoomWeapon')) {
        return true;
    }

    AttachClass = class<WeaponAttachment>(Weapon.AttachmentClass);
    return AttachClass != None && (AttachClass.default.DrawType == DT_Sprite || AttachClass.default.DrawType == DT_VerticalSprite);
}

function bool IsSpriteWeapon() {
    if(Weapon != CachedSpriteWeapon) {
        CachedSpriteWeapon = Weapon;
        bCachedSprite = HasSpriteDisplay();
    }
    return bCachedSprite;
}

function SetOverlay(optional Material Mat) {
    if(Mat == None) {
        Mat = ModifierOverlay;
    }

    if(HasSpriteDisplay()) {
        return;
    }

    Weapon.SetOverlayMaterial(Mat, 9999, true);
    ClientSetFirstPersonOverlay(Mat);
    
    if(SyncThirdPerson != None) {
        SyncThirdPerson.Destroy();
    }
    
    if(Weapon.ThirdPersonActor != None) {
        SyncThirdPerson = class'Sync_OverlayMaterial'.static.Sync(Weapon.ThirdPersonActor, Mat, -1, true);
    }
}

//interface
function StartEffect(); //weapon gets drawn
function StopEffect(); //weapon gets put down

simulated function ClientStartEffect();
simulated function ClientStopEffect();

simulated function PostRender(Canvas C); //called client-side by the Interaction

function RPGTick(float dt); //called only if weapon is active
simulated function ClientRPGTick(float dt);

//FIX (custom weapons): stock TitanRPG declared this hook but never called
//it. DetectWeaponFire() (called from Tick while active) fires it on the
//rising edge of each fire mode's bIsFiring, so it works on ALL weapons,
//including custom ones (e.g. DMN) whose fire modes aren't TitanRPG classes.
function WeaponFire(byte Mode); //called when weapon just fired

//Detect a fire event via fire mode edge detection and call the WeaponFire
//hook. Server-only (WeaponFire is not simulated).
function DetectWeaponFire() {
    local int i, FireMask;
    local WeaponFire WF;
    
    for(i = 0; i < Weapon.NUM_FIRE_MODES; i++) {
        WF = Weapon.GetFireMode(i);
        if(WF != None && WF.bIsFiring)
            FireMask = FireMask | (1 << i);
    }
    
    if(FireMask != LastFireMask) {
        for(i = 0; i < Weapon.NUM_FIRE_MODES; i++) {
            if((FireMask & (1 << i)) != 0 && (LastFireMask & (1 << i)) == 0)
                WeaponFire(i);
        }
        LastFireMask = FireMask;
    }
}

function AdjustTargetDamage(out int Damage, int OriginalDamage, Pawn Injured, Pawn InstigatedBy, vector HitLocation, out vector Momentum, class<DamageType> DamageType) {
	if(DamageBonus != 0 && Modifier != 0)
		Damage += float(Damage) * Modifier * DamageBonus;
}

function AdjustPlayerDamage(out int Damage, int OriginalDamage, Pawn InstigatedBy, vector HitLocation, out vector Momentum, class<DamageType> DamageType);

function bool PreventDeath(Controller Killer, class<DamageType> DamageType, vector HitLocation, bool bAlreadyPrevented) {
	return false;
}

function bool AllowEffect(class<RPGEffect> EffectClass, Controller Causer, float Duration, float Modifier) {
	return true;
}

function float GetAIRating() {
    local RPGBot B;
    local int x;
    local float Rating;

    Rating = Weapon.GetAIRating();

    if(MaxModifier == 0) {
        Rating += AIRatingBonus;
    } else {
        Rating += AIRatingBonus * Modifier;
    }

    Rating += DamageBonus * Modifier;

    B = RPGBot(Instigator.Controller);
    if(B != None) {
        if(B.LastModifierSuffered != None) {
            for(x = 0; x < CountersModifier.Length; x++) {
                if(CountersModifier[x] == B.LastModifierSuffered) {
                    Rating *= 2.5;
                    break;
                }
            }
        }

        if(B.LastDamageTypeSuffered != None) {
            for(x = 0; x < CountersDamage.Length; x++) {
                if(CountersDamage[x] == B.LastDamageTypeSuffered) {
                    Rating *= 2.5;
                    break;
                }
            }
        }
    }
    
    return Rating;
}

simulated event Destroyed() {
    if(Role == ROLE_Authority) {
        SetActive(false);
        
        if(Weapon != None) {
            ClientRestore();
            Weapon.bCanThrow = Weapon.default.bCanThrow;
            
            if(Weapon.OverlayMaterial == ModifierOverlay) {
                Weapon.SetOverlayMaterial(None, 9999, true);
                ClientSetFirstPersonOverlay(None);
            }
        }
        
        if(SyncThirdPerson != None) {
            SyncThirdPerson.Destroy();
            
            if(Weapon != None) {
                class'Sync_OverlayMaterial'.static.Sync(Weapon.ThirdPersonActor, None, 5, true);
            }
        }
    }
    
	Super.Destroyed();
}

simulated function AddToDescription(string Format, optional float Bonus) {
	if(Description != "")
		Description $= ", ";
		
	if(Bonus != 0) {
		Description $= Repl(Format, "$1", GetBonusPercentageString(Bonus));
	} else {
		Description $= Format;
    }
}

simulated function BuildDescription() {
	if(DamageBonus != 0) {
		AddToDescription(DamageBonusText, DamageBonus);
    }
}

simulated function string GetDescription() {
	if(Description == "")
		BuildDescription();

	return Description;
}

//Helper function
simulated function string GetBonusPercentageString(float Bonus) {
	local string text;

	Bonus *= float(Modifier);
	
	if(Bonus > 0) {
		text = "+";
    }
	
	Bonus *= 100.0f;
	
	if(float(int(Bonus)) == Bonus)
		text $= int(Bonus);
	else
		text $= Bonus;
	
	text $= "%";
	
	return text;
}

defaultproperties {
	DamageBonusText="$1 damage"

	DamageBonus=0
	BonusPerLevel=0

	bCanThrow=True
	bCanHaveZeroModifier=True
	
    DrawType=DT_None
    bHidden=True
    
	bAlwaysRelevant=False
	bOnlyRelevantToOwner=True
	bOnlyDirtyReplication=False
    bReplicateInstigator=True
    bSkipActorPropertyReplication=False
	NetUpdateFrequency=4.000000
	RemoteRole=ROLE_SimulatedProxy
	
	bAllowForSpecials=True
	
	AIRatingBonus=0
}
