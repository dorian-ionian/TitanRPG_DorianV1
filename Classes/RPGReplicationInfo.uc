class RPGReplicationInfo extends ReplicationInfo;

const MAX_ARTIFACTS = 63;

var int NumAbilities;
var class<RPGArtifact> Artifacts[MAX_ARTIFACTS];
var bool bShowMonsterLevel; //server: whether floating monster level labels are enabled

//Client
var Interaction Interaction;
var Interaction MonsterLevelInteraction;

replication
{
	reliable if(Role == ROLE_Authority && bNetInitial)
		Artifacts, NumAbilities, bShowMonsterLevel;
}

static function RPGReplicationInfo Get(LevelInfo Level)
{
	local RPGReplicationInfo RRI;
	
	foreach Level.DynamicActors(class'RPGReplicationInfo', RRI)
		return RRI;
	
	return None;
}

simulated function ClientSetup(PlayerController PC)
{
	Interaction = PC.Player.InteractionMaster.AddInteraction(
		string(class'Interaction_Global'), PC.Player);

	//Monster level labels (only when the server has them enabled)
	if(bShowMonsterLevel)
	{
		MonsterLevelInteraction = PC.Player.InteractionMaster.AddInteraction(
			string(class'Interaction_MonsterLevel'), PC.Player);
	}
}

simulated event PostNetBeginPlay()
{
	Super.PostNetBeginPlay();

	if(Role < ROLE_Authority && Interaction == None)
		ClientSetup(Level.GetLocalPlayerController());
}

simulated event Tick(float dt)
{
	local PlayerController PC;

	//Keep retrying until the global interaction exists on this client.
	//The local player controller may not be available during initial
	//replication (e.g. joining a game in progress), in which case
	//ClientSetup was never called and Interaction_Global would be missing
	//for the whole session - breaking friendly-pawn detection for the
	//awareness abilities.
	if(Interaction == None)
	{
		PC = Level.GetLocalPlayerController();
		if(PC != None)
		{
			ClientSetup(PC);
			if(Interaction != None)
				Disable('Tick');
		}
	}
	else
	{
		Disable('Tick');
	}
}

simulated event Destroyed()
{
	if(Interaction != None)
		Interaction.Master.RemoveInteraction(Interaction);
	
	if(MonsterLevelInteraction != None)
		MonsterLevelInteraction.Master.RemoveInteraction(MonsterLevelInteraction);
	
	Interaction = None;
	MonsterLevelInteraction = None;
	Super.Destroyed();
}

defaultproperties
{
}
