//=============================================================================
// FriendlyPawnPlayerReplicationInfo.uc
// Copyright (C) 2020 0xC0ncord <concord@fuwafuwatime.moe>
//
// This program is free software; you can redistribute and/or modify
// it under the terms of the Open Unreal Mod License version 1.1.
//=============================================================================

class FriendlyPawnPlayerReplicationInfo extends PlayerReplicationInfo;

defaultproperties
{
    bIsSpectator=True
    bBot=True
    bWelcomed=True
    bNetNotify=False
}
