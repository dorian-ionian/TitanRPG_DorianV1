//=============================================================================
// Artifact_DemolishLastWall.
// Active artifact granted by Ability_WallPlacer. Activating it demolishes the
// wall the owner placed most recently.
//=============================================================================
class Artifact_DemolishLastWall extends RPGArtifact;

function bool DoEffect()
{
	local RPGWallPlacer Placer;

	if (Instigator == None)
		return false;

	Placer = RPGWallPlacer(Instigator.FindInventoryType(class'RPGWallPlacer'));
	if (Placer == None)
		return false;

	return Placer.DemolishWalls(false) > 0;
}

defaultproperties
{
	Cooldown=3
	CostPerSec=0
	HudColor=(B=255,G=160,R=60)
	ArtifactID="DemolishLastWall"
	Description="Demolishes the wall you placed most recently."
	IconMaterial=Texture'TitanRPG_DorianV1.ArtifactIcons.selfdestruct'
	ItemName="Demolish Last Wall"
}
