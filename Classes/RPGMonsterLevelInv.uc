/*
	RPGMonsterLevelInv - attached to Invasion monsters when
	MutTitanRPG.bShowMonsterLevel is enabled. Carries the monster's display
	name and RPG level, replicated to all clients so they can draw a
	floating label above the monster (see Interaction_MonsterLevel).

	Same replication pattern as InvasionProMonsterIDInv (bAlwaysRelevant
	Inventory), which is proven to reach clients on this server.
*/
class RPGMonsterLevelInv extends Inventory;

var int MonsterLevel;
var string MonsterName;
var Pawn MyMonster;
var Vehicle MyVehicle; //set while a vehicle monster is seated; the label is drawn above it
var MutTitanRPG RPGMut; //server only, used to refresh MonsterLevel

replication
{
	reliable if(Role == ROLE_Authority)
		MonsterLevel, MonsterName, MyMonster, MyVehicle;
}

function GiveTo(Pawn Other, optional Pickup Pickup)
{
	if(Monster(Other) != None)
	{
		MyMonster = Other;
		Super.GiveTo(Other);
	}
}

function PostBeginPlay()
{
	Super.PostBeginPlay();

	//server-side cleanup only (clients never set the timer)
	if(Role == ROLE_Authority)
		SetTimer(1.0, true);
}

function Timer()
{
	if(Role != ROLE_Authority)
		return;

	if(MyMonster == None || MyMonster.Health <= 0 || MyMonster.bDeleteMe)
	{
		Destroy();
		return;
	}

	//No labels for pets/friendly monsters (any package's
	//FriendlyMonsterController - TitanRPG and InvasionPro pets both use it)
	if(MyMonster.Controller != None && MyMonster.Controller.IsA('FriendlyMonsterController'))
	{
		Destroy();
		return;
	}

	//Vehicle monsters are seated in a shell that is spawned after the marker, so track it here
	MyVehicle = MyMonster.DrivenVehicle;

	if(RPGMut != None && Monster(MyMonster) != None)
		MonsterLevel = RPGMut.GetMonsterLevel(Monster(MyMonster));
}

defaultproperties
{
	ItemName="MonsterLevel"
	bOnlyRelevantToOwner=False
	bAlwaysRelevant=True
}
