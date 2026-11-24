//=============================================================================
// ArtifactBase_WallVariant.
// Passive artifact that sets the wall type the Wall Placer raises while this
// artifact is the selected item. Nothing is activated.
//=============================================================================
class ArtifactBase_WallVariant extends RPGArtifact
	abstract;

var class<RPGDestructibleWall> WallClass;

defaultproperties
{
	bActivatable=False
	bAllowInVehicle=False
	IconMaterial=Texture'TitanRPG_DorianV1.ArtifactIcons.Teleport'
	HudColor=(B=128,G=200,R=200)
}
