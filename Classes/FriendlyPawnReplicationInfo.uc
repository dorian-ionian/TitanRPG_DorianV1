class FriendlyPawnReplicationInfo extends ReplicationInfo;

var Pawn Pawn;
var PlayerReplicationInfo Master;

var Interaction_Global Interaction; //client

var bool bMonster;      //summoned monster, drawn as "Owner's Tier Monster"
var int MonsterTier;    //Monster Proficiency tier, 0 = none
var string MonsterDisplayName; //from MonsterNameTable, resolved on the server

replication
{
	reliable if(Role == ROLE_Authority && bNetInitial)
		Master, Pawn;

	reliable if(Role == ROLE_Authority)
		bMonster, MonsterTier, MonsterDisplayName;
}

simulated event PostNetBeginPlay()
{
	local int i;
	local PlayerController PC;

	Super.PostNetBeginPlay();
	
	if(Level.NetMode != NM_DedicatedServer)
	{
		PC = Level.GetLocalPlayerController();
		if(PC != None)
		{
			for(i = 0; i < PC.Player.LocalInteractions.Length; i++)
			{
				if(PC.Player.LocalInteractions[i].IsA('Interaction_Global'))
				{
					Interaction = Interaction_Global(PC.Player.LocalInteractions[i]);
					Interaction.AddFriendlyPawn(Self);
					break;
				}
			}
		}
	}
}

simulated event Tick(float dt)
{
	local PlayerController PC;
	local int i;

	Super.Tick(dt);

	if(Role == ROLE_Authority)
	{
		if(Master == None || Pawn == None || Pawn.Health <= 0)
			Destroy();
	}
	else if(Interaction == None && Level.NetMode != NM_DedicatedServer)
	{
		//The global interaction may not have existed yet when this actor
		//replicated (e.g. joining a game in progress), so retry until it
		//is found - otherwise this friendly pawn would never be registered
		//and would show up as an enemy in the awareness ability.
		PC = Level.GetLocalPlayerController();
		if(PC != None)
		{
			for(i = 0; i < PC.Player.LocalInteractions.Length; i++)
			{
				if(PC.Player.LocalInteractions[i].IsA('Interaction_Global'))
				{
					Interaction = Interaction_Global(PC.Player.LocalInteractions[i]);
					Interaction.AddFriendlyPawn(Self);
					Disable('Tick');
					break;
				}
			}
		}
	}
}

simulated event Destroyed()
{
	if(Interaction != None)	
		Interaction.RemoveFriendlyPawn(Self);

	Super.Destroyed();
}

defaultproperties
{
	NetUpdateFrequency=1.00
}
