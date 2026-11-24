class RPGData extends Object
	config(TitanRPGPlayerData)
	PerObjectConfig;

//Player name is the object name
var config string ID; //owner GUID ("Bot" for bots)

var config int LV; //level
var config float XP; //experience
var config int PA, XN; //points available, experience needed

var config array<string> AB; //ability aliases (mapped to class refs in RPGPlayerReplicationInfo)
var config array<int> AL; //ability levels

var config array<string> WP; //weapon class names with recorded kills
var config array<int> WK; //lifetime kills per weapon in WP

var config array<string> MP; //summoned monster class names with recorded kills
var config array<int> MK; //lifetime kills per monster in MP

var config array<class<Monster> > DM; //discovered monsters (permanent summon list)
var config array<string> DN; //display name per discovered monster in DM

var config array<class<Monster> > CM; //monsters spawned from a friendly monster pickup, not yet discovered
var config array<int> CK; //kills per candidate in CM

//AI
var config string AI;
var config int AA;

defaultproperties
{
}
