//Burning flames on a pawn. Replicated like FX_PoisonSmoke so clients see them; xEmitter's defaults would hide them from clients.
class FX_BurnFlames extends xEmitter;

//Toggled on every hit; clients spawn a burst of flames when it changes
var bool bBurstToggle;

var int BurstParticles;

replication
{
	reliable if(bNetDirty && Role == ROLE_Authority)
		bBurstToggle;
}

simulated function PostNetReceive()
{
	if(Level.NetMode != NM_DedicatedServer)
		mStartParticles = BurstParticles;
}

function AddBurst()
{
	bBurstToggle = !bBurstToggle;
	mStartParticles = BurstParticles;
}

defaultproperties
{
	BurstParticles=20
	bNetNotify=True
	RemoteRole=ROLE_SimulatedProxy
	bNetTemporary=False
	bSuspendWhenNotVisible=False
	mRegen=True
	mStartParticles=10
	mRegenRange(0)=45.000000
	mRegenRange(1)=45.000000
	mLifeRange(0)=0.400000
	mLifeRange(1)=0.700000
	mPosDev=(X=24.000000,Y=24.000000,Z=32.000000)
	mSpeedRange(0)=0.000000
	mSpeedRange(1)=0.000000
	mMassRange(0)=-1.000000
	mMassRange(1)=-1.200000
	mSpinRange(0)=-15.000000
	mSpinRange(1)=15.000000
	mSizeRange(0)=12.000000
	mSizeRange(1)=28.000000
	mGrowthRate=-10.000000
	mAttenKa=0.500000
	mNumTileColumns=4
	mNumTileRows=4
	AmbientSound=Sound'GeneralAmbience.firefx11'
	SoundVolume=160
	SoundRadius=32.000000
	Skins(0)=Texture'EmitterTextures.MultiFrame.LargeFlames'
	Style=STY_Translucent
}
