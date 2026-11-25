class FriendlyPawnReplicationInfo extends ReplicationInfo;

var Pawn Pawn;
var PlayerReplicationInfo Master;

var Interaction_Global Interaction; //client

var bool bMonster;      //summoned monster, drawn as "Owner's Tier Monster"
var int MonsterTier;    //Monster Proficiency tier, 0 = none
var string MonsterTierTitle; //tier word from the server's ini, resolved on the server
var string MonsterDisplayName; //from MonsterNameTable, resolved on the server

//Server-only chat: the pet checks in with its owner and announces kills
var int PetKills;
var float NextCheckInTime;
var float NextKillChatTime;
var bool bLowHealthSaid;
var float ChatMinInterval;
var float ChatRandomInterval;

replication
{
	reliable if(Role == ROLE_Authority && bNetInitial)
		Master, Pawn;

	reliable if(Role == ROLE_Authority)
		bMonster, MonsterTier, MonsterTierTitle, MonsterDisplayName;
}

event PostBeginPlay()
{
	Super.PostBeginPlay();

	if(Role == ROLE_Authority)
		NextCheckInTime = Level.TimeSeconds + 30.0 + FRand() * 30.0;
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
		//A dead summon's body is removed shortly after it dies
		if(Pawn != None && Pawn.Health <= 0 && Pawn.LifeSpan == 0)
			Pawn.LifeSpan = 2.0;

		if(Master == None || Pawn == None || Pawn.Health <= 0)
			Destroy();
		else if(bMonster)
			ServerChatter();
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

function ServerChatter()
{
	local int Pct;
	local float Frac;

	if(Level.TimeSeconds >= NextCheckInTime)
	{
		NextCheckInTime = Level.TimeSeconds + ChatMinInterval + FRand() * ChatRandomInterval;
		CheckIn();
	}

	Frac = float(Pawn.Health) / float(Max(1, Pawn.HealthMax));
	if(Frac < 0.3)
	{
		if(!bLowHealthSaid)
		{
			bLowHealthSaid = true;
			Pct = int(100.0 * Frac + 0.5);
			SayLine("Hey " $ Master.PlayerName $ ", I'm badly hurt at " $ Pct $ "% HP. Heal me!");
		}
	}
	else if(Frac > 0.5)
	{
		bLowHealthSaid = false;
	}
}

function CheckIn()
{
	local int Pct;
	local string Status;

	Pct = int(100.0 * float(Pawn.Health) / float(Max(1, Pawn.HealthMax)) + 0.5);
	if(Pct >= 75)
		Status = "Hey " $ Master.PlayerName $ ", feeling strong at " $ Pct $ "% HP.";
	else if(Pct >= 40)
		Status = "Hey " $ Master.PlayerName $ ", still in it at " $ Pct $ "% HP.";
	else
		Status = "Hey " $ Master.PlayerName $ ", barely hanging on at " $ Pct $ "% HP!";

	if(PetKills == 1)
		Status = Status @ "I've got 1 kill so far.";
	else if(PetKills > 1)
		Status = Status @ "I've got" @ PetKills @ "kills so far.";

	SayLine(Status);
}

//Called by the pet's controller when this pet makes a kill
function AddKill(Pawn Victim)
{
	local string VictimName;

	PetKills++;

	if(Level.TimeSeconds < NextKillChatTime)
		return;

	NextKillChatTime = Level.TimeSeconds + 8.0;

	if(Victim != None)
		VictimName = class'MonsterNameTable'.static.GetDisplayName(Victim.Class);
	if(VictimName == "")
		VictimName = "something";

	SayLine("Got one: " $ VictimName $ ". That's " $ PetKills $ " so far.");
}

//Sends a line from this pet to every player, prefixed with the pet's name
function SayLine(string Line)
{
	local Controller C;
	local string Msg;

	if(Master == None)
		return;

	Msg = MonsterDisplayName $ ": " $ Line;

	for(C = Level.ControllerList; C != None; C = C.NextController)
	{
		if(PlayerController(C) != None)
			PlayerController(C).ClientMessage(Msg, 'Event');
	}
}

defaultproperties
{
	NetUpdateFrequency=1.00
	ChatMinInterval=60.0
	ChatRandomInterval=60.0
}
