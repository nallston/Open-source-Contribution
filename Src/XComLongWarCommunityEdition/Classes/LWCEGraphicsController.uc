class LWCEGraphicsController extends Actor
    implements(XComProjectileEventListener);

function Init()
{
    // Called when the level inits; entities may not be spawned yet
}

function LoadInit()
{
    local XComLevelActor kLevelActor;
    local XGVolume kVolume;

    // Called when the level inits after load; entities may not be spawned yet.
    // Units are reloaded but they don't have pawns.

    foreach AllActors(class'XGVolume', kVolume)
    {
        AddVolumeLighting(kVolume);
    }

    // TODO: still need to add lights for static fires on levels and other light sources; the logging
    // below is to help identify those
/*
    `LWCE_LOG_CLS("----- Dumping level actor info -----");

    foreach AllActors(class'XComLevelActor', kLevelActor)
    {
        `LWCE_LOG_CLS(kLevelActor @ kLevelActor.ObjectArchetype.Name @ kLevelActor.Location);
    }
*/
}

simulated function OnUnitLoaded(XGUnit kUnit)
{
    AddUnitLighting(kUnit);
}

simulated function OnUnitSpawned(XGUnit kUnit)
{
    AddUnitLighting(kUnit);
}

simulated function OnVolumeSpawned(XGVolume kVolume)
{
    AddVolumeLighting(kVolume);
}

simulated function Projectile_OnDealDamage(XComProjectile kProjectile)
{
}

simulated function Projectile_OnInit(XComProjectile kProjectile)
{
    local int iCharType;
    local PointLightComponent kPointLightComp;

    iCharType = kProjectile.m_kFiredFromUnit.GetCharacter().m_kChar.iType;

    // TODO: not sure how to do this in an inheritance-safe way
    // Probably want to use the weapon info like so:
    //     iWeaponId = `LWCE_TWEAPON_FROM_XG(kProjectile.GetGameWeapon()).iItemId;
    if (kProjectile.MyDamageType == class'XComDamageType_Plasma')
    {
        kPointLightComp = new(kProjectile.Mesh) class'PointLightComponent';
        //kPointLightComp.CastShadows = true;
        //kPointLightComp.CastDynamicShadows = true;
        //kPointLightComp.CastStaticShadows = true;
        //kPointLightComp.LightAffectsClassification = LAC_DYNAMIC_AND_STATIC_AFFECTING;
        // TODO move values to config
        kPointLightComp.LightColor.R = 124;
        kPointLightComp.LightColor.G = 239;
        kPointLightComp.LightColor.B = 161;

        switch (iCharType)
        {
            case eChar_Muton:
                kPointLightComp.Brightness = 1.75;
                kPointLightComp.Radius = 512.0;
                break;
            case eChar_Mechtoid:
            case eChar_Mechtoid_Alt:
            case eChar_MutonElite:
                kPointLightComp.Brightness = 2.25;
                kPointLightComp.Radius = 768.0;
                break;
            default:
                kPointLightComp.Brightness = 1.5;
                kPointLightComp.Radius = 384.0;
                break;
        }

        kProjectile.Mesh.AttachComponent(kPointLightComp, 'Bone01');

        `LWCE_LOG_CLS("Original projectile speed: " $ kProjectile.Speed);
        kProjectile.Speed *= 0.2;
    }
    else if (kProjectile.MyDamageType == class'XComDamageType_Laser')
    {
        `LWCE_LOG_CLS("Projectile appears to be laser");

        kPointLightComp = new(kProjectile.Mesh) class'PointLightComponent';
        kPointLightComp.Brightness = 1.5;
        kPointLightComp.LightColor.R = 124;
        kPointLightComp.LightColor.G = 239;
        kPointLightComp.LightColor.B = 161;
        kPointLightComp.Radius = 384.0;

        kProjectile.Mesh.AttachComponent(kPointLightComp, 'Bone01');
    }
}

simulated function Projectile_OnShutdown(XComProjectile kProjectile)
{
    local PointLightComponent kPointLightComp;

    // Find any custom lights we've added and disable them
    foreach kProjectile.Mesh.AttachedComponents(class'PointLightComponent', kPointLightComp)
    {
        // Don't mess with the light that's built in to the projectile
        if (kPointLightComp == kProjectile.ProjectileLightComponent)
        {
            continue;
        }

        // Remove the lights we've added manually so they disappear and can be GC'd
        // while the projectile returns to its pool
        if (kPointLightComp != none)
        {
            kPointLightComp.SetEnabled(false);
            kPointLightComp.DetachFromAny();
        }
    }
}

protected function AddUnitLighting(XGUnit kUnit)
{
    local int Index, iCharType;
    local PointLightComponent kPointLightComp;
    local SpotLightComponent kSpotLightComp;
    local array<name> arrBoneNames;

    iCharType = kUnit.GetCharacter().m_kChar.iType;

    switch (iCharType)
    {
        case eChar_Drone:
            // Spotlight for the drone's thruster
            kSpotLightComp = new(kUnit.m_kPawn.Mesh) class'SpotLightComponent';
            kSpotLightComp.Brightness = 1.0;
            kSpotLightComp.LightColor.R = 255;
            kSpotLightComp.LightColor.G = 165;
            kSpotLightComp.LightColor.B = 115;
            kSpotLightComp.OuterConeAngle = 22.0;

            kUnit.m_kPawn.Mesh.AttachComponent(kSpotLightComp, 'nozzle_1_b');

            break;
        case eChar_Floater:
        case eChar_FloaterHeavy:
        case eChar_Muton:
        case eChar_MutonElite: // TODO might need to be separate for more intense lighting
        case eChar_Sectoid:
        case eChar_SectoidCommander:
        case eChar_ThinMan:
            // Point light on the plasma pistol
            kPointLightComp = new(kUnit.m_kPawn.Mesh) class'PointLightComponent';
            kPointLightComp.Brightness = 1.5;
            kPointLightComp.LightColor.R = 124;
            kPointLightComp.LightColor.G = 239;
            kPointLightComp.LightColor.B = 161;
            kPointLightComp.Radius = 96.0;

            // Configure light shafts
            kPointLightComp.bRenderLightShafts = true;
            kPointLightComp.BloomScale = 1.1;
            kPointLightComp.BloomTint = kPointLightComp.LightColor;
            kPointLightComp.RadialBlurPercent = 80.0;
            kPointLightComp.OcclusionDepthRange = 50.0;

            // TODO: weapons may be held in either hand
            kUnit.m_kPawn.Mesh.AttachComponent(kPointLightComp, 'RigRArmHand');

            break;
        case eChar_Cyberdisc:
            // TODO
            // kSpotLightComp = new(kUnit.m_kPawn.Mesh) class'SpotLightComponent';
            // kSpotLightComp.Brightness = 0.8;
            // kSpotLightComp.LightColor.R = 255;
            // kSpotLightComp.LightColor.G = 255;
            // kSpotLightComp.LightColor.B = 208;
            // kSpotLightComp.OuterConeAngle = 22.0;
            // kSpotLightComp.bRenderLightShafts = true;
            // kSpotLightComp.BloomScale = 1.1;
            // kSpotLightComp.BloomTint = kSpotLightComp.LightColor;
            // kSpotLightComp.RadialBlurPercent = 80.0;
            // kSpotLightComp.OcclusionDepthRange = 50.0;

            // kUnit.m_kPawn.Mesh.AttachComponent(kSpotLightComp, 'DiscPelvisRotate_bindjoint');
            break;
        case eChar_Mechtoid:
        case eChar_Mechtoid_Alt:
            kPointLightComp = new(kUnit.m_kPawn.Mesh) class'PointLightComponent';
            kPointLightComp.Brightness = 3.5;
            kPointLightComp.LightColor.R = 30;
            kPointLightComp.LightColor.G = 255;
            kPointLightComp.LightColor.B = 30;
            kPointLightComp.Radius = 64.0;

            kPointLightComp.bRenderLightShafts = true;
            kPointLightComp.BloomScale = 1.1;
            kPointLightComp.BloomTint = kPointLightComp.LightColor;
            kPointLightComp.RadialBlurPercent = 80.0;
            kPointLightComp.OcclusionDepthRange = 50.0;

            kUnit.m_kPawn.Mesh.AttachComponent(kPointLightComp, 'upper_rail_left_b');

            kPointLightComp = new(kUnit.m_kPawn.Mesh) class'PointLightComponent';
            kPointLightComp.Brightness = 3.5;
            kPointLightComp.LightColor.R = 255;
            kPointLightComp.LightColor.G = 30;
            kPointLightComp.LightColor.B = 30;
            kPointLightComp.Radius = 64.0;

            kPointLightComp.bRenderLightShafts = true;
            kPointLightComp.BloomScale = 1.1;
            kPointLightComp.BloomTint = kPointLightComp.LightColor;
            kPointLightComp.RadialBlurPercent = 80.0;
            kPointLightComp.OcclusionDepthRange = 50.0;

            kUnit.m_kPawn.Mesh.AttachComponent(kPointLightComp, 'capacitor_right_b');

            break;
        case eChar_Seeker:
            // No lights for seekers, they're stealthy
            break;
        case eChar_ExaltOperative:
        case eChar_ExaltSniper:
        case eChar_ExaltHeavy:
        case eChar_ExaltMedic:
        case eChar_ExaltEliteOperative:
        case eChar_ExaltEliteSniper:
        case eChar_ExaltEliteHeavy:
        case eChar_ExaltEliteMedic:
            // No lights for EXALT at the moment
            break;
        case eChar_Soldier:
            // TODO add lights on soldiers based on weapon
            break;
        //case eChar_Tank:
            // TODO SHIV headlights
        //    break;
        default:
            `LWCE_LOG_CLS("Getting bone names for pawn " $ kUnit.m_kPawn);
            kUnit.m_kPawn.Mesh.GetBoneNames(arrBoneNames);

            for (Index = 0; Index < arrBoneNames.Length; Index++)
            {
                `LWCE_LOG_CLS("Bone " $ Index $ ": " $ arrBoneNames[Index]);
            }
    }
}

protected function AddVolumeLighting(XGVolume kVolume)
{
    local LWCEFireLightComponent kPointLightComp;

    if (kVolume.m_kTVolume.eType != eVolume_Fire)
    {
        return;
    }

    kPointLightComp = new(kVolume) class'LWCEFireLightComponent';
    kVolume.AttachComponent(kPointLightComp);

    kPointLightComp.Init(self);
}

static function LWCEGraphicsController GetInstance()
{
    local LWCEGraphicsController kController;

    foreach `WORLDINFO.AllActors(class'LWCEGraphicsController', kController)
    {
        return kController;
    }

    return none;
}