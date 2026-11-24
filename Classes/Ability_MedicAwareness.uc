class Ability_MedicAwareness extends RPGAbility;

//Client
var Interaction_MedicAwareness Interaction;
var array<Pawn> Teammates;

replication {
	reliable if(Role == ROLE_Authority)
		ClientCreateInteraction;
}

simulated function ClientCreateInteraction()
{
	local PlayerController PC;

    if(Level.NetMode != NM_DedicatedServer) {
        if(Interaction == None) {
            PC = Level.GetLocalPlayerController();
            if(PC == None) {
                return;
            }

            Interaction = Interaction_MedicAwareness(
                PC.Player.InteractionMaster.AddInteraction(
                    class'MutTitanRPG'.default.PackageName $ ".Interaction_MedicAwareness", PC.Player));

            Interaction.Ability = Self;
            
            SetTimer(1.0, true);
        }
    }
}

simulated function Timer() {
    local PlayerController PC;
    local Pawn P;
    local FriendlyPawnReplicationInfo FPRI;
    local int i;
    
    if(Interaction != None) {
        Teammates.Length = 0;
        
        PC = Level.GetLocalPlayerController();
        if(PC != None && PC.Pawn != None && PC.Pawn.Health > 0) {
            if(Interaction.GlobalInteraction == None) {
                //Interaction_Global may have been added after this interaction
                //was created, so look it up again.
                for(i = 0; i < PC.Player.LocalInteractions.Length; i++) {
                    if(PC.Player.LocalInteractions[i].IsA('Interaction_Global')) {
                        Interaction.GlobalInteraction = Interaction_Global(PC.Player.LocalInteractions[i]);
                        break;
                    }
                }
            }
            
            foreach DynamicActors(class'Pawn', P) {
                //Friendly monsters (summoned pets) have no PlayerReplicationInfo
                //on the client, so they are identified through the global
                //interaction's replicated friendly-pawn list instead. Show
                //them only when they belong to a player on our team.
                FPRI = None;
                if(Interaction.GlobalInteraction != None)
                    FPRI = Interaction.GlobalInteraction.GetFriendlyPawnInfo(P);
                
                if(P.IsA('Monster') && FPRI != None) {
                    if(
                        FPRI.Master != None &&
                        FPRI.Master.Team != None &&
                        PC.PlayerReplicationInfo != None &&
                        PC.PlayerReplicationInfo.Team != None &&
                        FPRI.Master.Team == PC.PlayerReplicationInfo.Team
                    ) {
                        Teammates[Teammates.Length] = P;
                    }
                    continue;
                }
            
                if(P == PC.Pawn) {
                    continue;
                }
            
                if(P.PlayerReplicationInfo == None || P.PlayerReplicationInfo.Team == None) {
                    continue;
                }
            
                if(P.GetTeamNum() == 255 || P.GetTeamNum() != PC.GetTeamNum()) {
                    continue;
                }
                
                if(P.IsA('Monster') || P.IsA('Vehicle') || P.DrivenVehicle != None) {
                    continue;
                }

                Teammates[Teammates.Length] = P;
            }
        }
    }
}

function ModifyPawn(Pawn Other) {
    Super.ModifyPawn(Other);

    if(Role == ROLE_Authority && Level.Game.bTeamGame)
        ClientCreateInteraction();
}

simulated event Destroyed() {
    if(Interaction != None) {
        Interaction.Master.RemoveInteraction(Interaction);
        Interaction = None;
    }

    Super.Destroyed();
}

defaultproperties {
	AbilityName="Medic Awareness"
	Description="Informs you of your teammates' current health by displaying a team-colored health bar above their heads."
	LevelDescription(0)="At level 1, teammates' health bars are doubled in size."
	LevelDescription(1)="At level 2, each teammate's health bar also shows their HP and health percentage."
	StartingCost=20
	CostAddPerLevel=5
	MaxLevel=2
	Category=class'AbilityCategory_Medic'
}
