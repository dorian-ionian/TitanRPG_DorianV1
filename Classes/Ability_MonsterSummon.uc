class Ability_MonsterSummon extends RPGAbility
	DependsOn(Artifact_SummonMonster);

var config float MonsterSkill;

//Kills with a summoned monster class needed before it is discovered
var config int DiscoverKills;
//Range of the random adrenaline cost and cooldown rolled on each manual spawn
var config int DiscoverCostMin, DiscoverCostMax;
var config int DiscoverCooldownMin, DiscoverCooldownMax;

//True while the monster class is still listed in FriendlyMonsterPickup.PossibleTypes
static function bool IsPickupMonster(class<Monster> MonsterClass)
{
	local int i;

	for(i = 0; i < class'FriendlyMonsterPickup'.default.PossibleTypes.Length; i++)
	{
		if(class'FriendlyMonsterPickup'.default.PossibleTypes[i] == MonsterClass)
			return true;
	}
	return false;
}

//Copies a player's discovered monsters and their cost/cooldown ranges into the summon artifact, most recently discovered first.
//Monsters removed from FriendlyMonsterPickup stay in the player's data but are not offered.
static function FillArtifact(Artifact_SummonMonster Artifact, RPGPlayerReplicationInfo RPRI)
{
	local int i, n;
	local Artifact_SummonMonster.MonsterTypeStruct M;

	Artifact.MonsterTypes.Length = 0;
	if(RPRI == None || RPRI.DataObject == None)
		return;

	n = RPRI.DataObject.DM.Length;
	for(i = 0; i < n; i++)
	{
		M.MonsterClass = RPRI.DataObject.DM[n - 1 - i];
		if(!IsPickupMonster(M.MonsterClass))
			continue;

		M.DisplayName = RPRI.DataObject.DN[n - 1 - i];
		M.CostMin = default.DiscoverCostMin;
		M.CostMax = default.DiscoverCostMax;
		M.CooldownMin = default.DiscoverCooldownMin;
		M.CooldownMax = default.DiscoverCooldownMax;
		Artifact.MonsterTypes[Artifact.MonsterTypes.Length] = M;
	}
}

function ModifyPawn(Pawn Other)
{
	local Artifact_SummonMonster Artifact;
	local bool bSelect;
	
	Super.ModifyPawn(Other);
	
	Artifact = Artifact_SummonMonster(Other.FindInventoryType(class'Artifact_SummonMonster'));
	if(Artifact != None)
	{
		bSelect = (Artifact == Other.SelectedItem);
		Artifact.Destroy();
	}
	
	if(!bSelect)
		bSelect = (Other.SelectedItem == None);
	
	Artifact = Other.Spawn(class'Artifact_SummonMonster');
	if(Artifact != None)
	{
		Artifact.bCanBeTossed = false;
		FillArtifact(Artifact, class'RPGPlayerReplicationInfo'.static.GetFor(Other.Controller));
		Artifact.GiveTo(Other);
		
		if(bSelect)
			Other.SelectedItem = Artifact;
	}
}

function ModifyMonster(Monster M, Pawn Master)
{
	MonsterController(M.Controller).InitializeSkill(MonsterSkill);
}

defaultproperties
{
	StatusIconClass=class'StatusIcon_Monsters'

	MonsterSkill=2
	AbilityName="Monster Discovery"
	Description="Summon friendly monsters you have discovered.|Spawn a random monster from a friendly monster pickup and get kills with it to discover that monster permanently. Discovery requires this ability."
	StartingCost=10
	CostAddPerLevel=5
	MaxLevel=3
	DiscoverKills=3
	DiscoverCostMin=10
	DiscoverCostMax=75
	DiscoverCooldownMin=5
	DiscoverCooldownMax=10
	Category=class'AbilityCategory_Monsters'
}
