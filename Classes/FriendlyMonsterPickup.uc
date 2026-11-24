class FriendlyMonsterPickup extends TournamentPickUp config(TitanRPG) placeable;

var() config array<class<Monster> > PossibleTypes;

var localized string MsgMaxMonsters;
var float LastLimitMessageTime; //throttles the limit message so it doesn't spam every frame

function float DetourWeight(Pawn Other, float PathWeight) {
    return MaxDesireability / PathWeight;
}

event float BotDesireability(Pawn Bot) {
    return MaxDesireability;
}

auto state Pickup {
    function Touch(Actor Other) {
        local Pawn P;
        local vector Off;
        local Monster M;
        local FriendlyMonsterController C;
        local class<Monster> Type;
        local int Tries;
        local RPGPlayerReplicationInfo RPRI;
        
        if(ValidTouch(Other) && PossibleTypes.Length > 0) {
            P = Pawn(Other);
            Type = PossibleTypes[Rand(PossibleTypes.Length)];
            
            RPRI = class'RPGPlayerReplicationInfo'.static.GetFor(P.Controller);
            
            //Per-player summon limit - don't consume the pickup, but tell the player
            if(RPRI != None && RPRI.Monsters.Length >= RPRI.MaxMonsters)
            {
                if(Level.TimeSeconds - LastLimitMessageTime > 3.0)
                {
                    LastLimitMessageTime = Level.TimeSeconds;
                    
                    if(PlayerController(P.Controller) != None)
                        PlayerController(P.Controller).ClientMessage(MsgMaxMonsters);
                }
                return;
            }
            
            while(M == None && Tries < 25) {
                Tries++;
                
                Off = VRand() * 2.5 * (P.CollisionRadius * P.DrawScale + Type.default.CollisionRadius * Type.default.DrawScale);
                Off.Z = 32;
                
                M = P.Spawn(Type, P.Controller,, P.Location + Off, rotator(Off));
                if(M != None) {
                    if(M.Controller != None)
                        M.Controller.Destroy();

                    C = Spawn(class'FriendlyMonsterController',,, M.Location, M.Rotation);
                    C.Possess(M);
                    C.SetMaster(P.Controller);
                    
                    if(RPRI != None) {
                        RPRI.AddMonster(M); //tracks the monster towards the player's summon limit
                        RPRI.NoteMonsterSpawn(Type); //counts toward discovering this monster type
                    }
                    
                    break;
                }
            }
            
            AnnouncePickup(P);
            SetRespawn();
        }
    }
}

defaultproperties {
    PickupMessage="Companion "
    MsgMaxMonsters="You cannot spawn any more monsters at this time."
    RespawnTime=60
    MaxDesireability=0.9
    RemoteRole=ROLE_DumbProxy
    AmbientGlow=128
    CollisionRadius=32.000000
    CollisionHeight=23.000000
    Mass=10.000000
    Physics=PHYS_Rotating
    RotationRate=(Yaw=24000)
    DrawScale=0.03125
    PickupSound=sound'PickupSounds.AdrenelinPickup'
    PickupForce="AdrenelinPickup"  // jdf
    DrawType=DT_StaticMesh
    StaticMesh=StaticMesh'TitanRPG_DorianV1.Pokeball.PokeballStatic' //pokemans!
    ScaleGlow=0.6
    CullDistance=+5500.0
}
