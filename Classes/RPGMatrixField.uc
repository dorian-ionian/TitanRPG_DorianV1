//Causes a Matrix effect in a certain area
class RPGMatrixField extends Info placeable;

var Controller Creator;
var float Radius, Multiplier;
var array<name> Ignore;

//Projectile sweep runs on this interval instead of every frame
var float ScanInterval, NextScanTime;

delegate OnMatrix(RPGMatrixField Field, Projectile Proj, float Multiplier);

event PostBeginPlay() {
    Super.PostBeginPlay();
    
    Creator = Controller(Owner);
}

function bool IgnoreProjectile(Projectile Proj) {
    local int i;
    
    for(i = 0; i < Ignore.Length; i++) {
        if(Proj.IsA(Ignore[i])) {
            return true;
        }
    }
    
    return false;
}

event Tick(float dt) {
    local Projectile Proj;

    Super.Tick(dt);

    if(Level.TimeSeconds < NextScanTime) {
        return;
    }
    NextScanTime = Level.TimeSeconds + ScanInterval;
    
    foreach CollidingActors(class'Projectile', Proj, Radius) {
        if(Proj.Tag == 'Matrix') {
            continue;
        }
        
        if(IgnoreProjectile(Proj)) {
            continue;
        }
        
        if(Proj.Instigator != None) {
            if(!class'DevoidEffect_Matrix'.static.CanBeApplied(Proj.Instigator, Creator)) {
                continue;
            }
        }
        
        OnMatrix(Self, Proj, Multiplier);
        
        Proj.Tag = 'Matrix';
        class'Util'.static.ModifyProjectileSpeed(Proj, Multiplier, 'Matrix', class'FX_MatrixTrail');
    }
}

defaultproperties {
    Radius=768
    Multiplier=0.5
    ScanInterval=0.2
}
