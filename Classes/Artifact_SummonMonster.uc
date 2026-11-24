class Artifact_SummonMonster extends ArtifactBase_Summon;

struct MonsterTypeStruct
{
	var class<Monster> MonsterClass;
	var string DisplayName;
	//Range that each manual spawn's cost and cooldown is rolled from
	var int CostMin, CostMax;
	var int CooldownMin, CooldownMax;
};
var config array<MonsterTypeStruct> MonsterTypes;

const MSG_MaxMonsters = 0x1000;

var localized string MsgMaxMonsters, SelectionTitle;

replication
{
	reliable if(Role == ROLE_Authority)
		ClientReceiveMonsterType;
}

static function string GetMessageString(int Msg, optional int Value, optional Object Obj)
{
	switch(Msg)
	{
		case MSG_MaxMonsters:
			return default.MsgMaxMonsters;
	
		default:
			return Super.GetMessageString(Msg, Value, Obj);
	}
}

function GiveTo(Pawn Other, optional Pickup Pickup)
{
	Super.GiveTo(Other, Pickup);
	RefreshMonsterTypes();
}

function RefreshMonsterTypes()
{
	local int i;

	for(i = 0; i < MonsterTypes.Length; i++)
		ClientReceiveMonsterType(i, MonsterTypes[i]);
}

simulated function ClientReceiveMonsterType(int i, MonsterTypeStruct M)
{
    if(Role < ROLE_Authority) {
        if(i == 0)
            MonsterTypes.Length = 0;

        MonsterTypes[i] = M;
    }
}

function bool CanActivate()
{
	if(SelectedOption < 0)
		CostPerSec = 0; //no cost until selection

	if(!Super.CanActivate())
		return false;
	
	if(InstigatorRPRI != None && !InstigatorRPRI.CanSummonMonster())
	{
		Msg(MSG_MaxMonsters);
		return false;
	}
	
	return true;
}

function Actor SpawnActor(class<Actor> SpawnClass, vector SpawnLoc, rotator SpawnRot)
{
	local FriendlyMonsterController C;
	local Monster M;
	
	M = Monster(Super.SpawnActor(SpawnClass, SpawnLoc, SpawnRot));
	if(M != None)
	{
		if(M.Controller != None)
			M.Controller.Destroy();

		C = Spawn(class'FriendlyMonsterController',,, SpawnLoc, Instigator.Rotation);
		C.Possess(M);
		C.SetMaster(Instigator.Controller);
		
		if(InstigatorRPRI != None)
			InstigatorRPRI.AddMonster(M);
	}
	return M;
}

static function int RollRange(int Min, int Max)
{
	if(Max <= Min)
		return Min;
	return Min + Rand(Max - Min + 1);
}

//Each manual spawn rolls its own cost and cooldown
function OnSelection(int i)
{
	CostPerSec = RollRange(MonsterTypes[i].CostMin, MonsterTypes[i].CostMax);
	Cooldown = RollRange(MonsterTypes[i].CooldownMin, MonsterTypes[i].CooldownMax);
	SpawnActorClass = MonsterTypes[i].MonsterClass;
}

simulated function string GetSelectionTitle()
{
	return SelectionTitle;
}

simulated function int GetNumOptions()
{
	return MonsterTypes.Length;
}

simulated function string GetOption(int i)
{
	return MonsterTypes[i].DisplayName;
}

//Lowest possible cost, since the real cost is rolled on selection
simulated function int GetOptionCost(int i) {
	return MonsterTypes[i].CostMin;
}

simulated function string GetOptionCostText(int i) {
	if(MonsterTypes[i].CostMax > MonsterTypes[i].CostMin)
		return MonsterTypes[i].CostMin $ "-" $ MonsterTypes[i].CostMax;
	return string(MonsterTypes[i].CostMin);
}

function int SelectBestOption() {
    local Controller C;
    local int i, best;
    
    C = Instigator.Controller;
    if(C != None) {
        //Most expensive affordable option, ties broken at random
        best = -1;
        for(i = 0; i < MonsterTypes.Length; i++) {
            if(C.Adrenaline >= MonsterTypes[i].CostMin && (best < 0 || MonsterTypes[i].CostMin > MonsterTypes[best].CostMin || (MonsterTypes[i].CostMin == MonsterTypes[best].CostMin && FRand() < 0.5))) {
                best = i;
            }
        }
        return best;
    } else {
        return Super.SelectBestOption();
    }
}

defaultproperties
{
	SelectionTitle="Pick a monster to summon:"
	MsgMaxMonsters="You cannot spawn any more monsters at this time."

	bSelection=true

	ArtifactID="MonsterSummon"
	Description="Summons a friendly monster of your choice."
	ItemName="Summoning Charm"
	PickupClass=Class'ArtifactPickup_MonsterSummon'
	IconMaterial=Texture'TitanRPG_DorianV1.ArtifactIcons.MonsterSummon'
	HudColor=(B=96,G=64,R=192)
	CostPerSec=0
	Cooldown=0
}
