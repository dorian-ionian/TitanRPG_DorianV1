//=============================================================================
// Artifact_DemolishAllWalls.
// Active artifact granted by Ability_WallPlacer. Activating it demolishes every
// wall the owner has placed.
//=============================================================================
class Artifact_DemolishAllWalls extends RPGArtifact;

function bool DoEffect()
{
	local RPGWallPlacer Placer;

	if (Instigator == None)
		return false;

	Placer = RPGWallPlacer(Instigator.FindInventoryType(class'RPGWallPlacer'));
	if (Placer == None)
		return false;

	return Placer.DemolishWalls(true) > 0;
}

defaultproperties
{
	Cooldown=20
	CostPerSec=0
	HudColor=(B=255,G=80,R=255)
	ArtifactID="DemolishAllWalls"
	Description="Demolishes every wall you have placed."
	IconMaterial=Texture'TitanRPG_DorianV1.ArtifactIcons.selfdestruct'
	ItemName="Demolish All Walls"
}
