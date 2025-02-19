class LWCE_XGVolumeMgr extends XGVolumeMgr;

simulated function BuildTVolumes()
{
    // TODO: not sure if suppression radius affects Danger Zone suppression or not
    // TODO: not sure if proximity mine radius is activation radius, explosion radius, or both
    // Once those things are figured out, make them config if appropriate
    BuildTVolume(eVolume_Suppression,  -1,                                            5.0,                                      576.0, eColor_Cyan,   0.20,            , eVolumeEffect_Suppression);
    BuildTVolume(eVolume_Smoke,        `LWCE_TACCFG(iSmokeGrenadeVolumeDuration),     0.0,                                      192.0, eColor_Gray,   0.20,            , eVolumeEffect_BlocksSight);
    BuildTVolume(eVolume_CombatDrugs,  `LWCE_TACCFG(iCombatDrugsVolumeDuration),      0.0,                                      192.0, eColor_Purple, 0.20,            , eVolumeEffect_BlocksSight);
    BuildTVolume(eVolume_Poison,       `LWCE_TACCFG(iAcidVolumeDuration),             0.0,                                      192.0, eColor_Green,  0.20, eShade_Dark, eVolumeEffect_Poison);
    BuildTVolume(eVolume_Fire,         `LWCE_TACCFG(iFireVolumeDuration),             `LWCE_TACCFG(fFireVolumeRadius),          192.0, eColor_Orange, 0.20,            , eVolumeEffect_Burn);
    BuildTVolume(eVolume_Proximity,    -1,                                            3.0,                                      128.0, eColor_Purple, 0.20,            ,  );
    BuildTVolume(eVolume_Spy,          `LWCE_TACCFG(iBattleScannerVolumeDuration),    `LWCE_TACCFG(fBattleScannerVolumeRadius), 192.0, eColor_Cyan,   0.20,            , eVolumeEffect_AddSight);
    BuildTVolume(eVolume_Telekinetic,  `LWCE_TACCFG(iTelekineticFieldVolumeDuration), `LWCE_TACCFG(fTelekineticFieldRadius),    192.0, eColor_Purple, 0.20, eShade_Dark, eVolumeEffect_TelekineticField);
    BuildTVolume(eVolume_Rift,         `LWCE_TACCFG(iRiftVolumeDuration),             `LWCE_TACCFG(fRiftRadius),                192.0, eColor_Purple, 0.20, eShade_Dark, eVolumeEffect_Rift);
}

simulated function BuildTVolume(EVolumeType eVolume, int iDuration, float fRadius, float fHeight, EWidgetColor eColor, float fAlpha, optional EColorShade eShade = 0, optional EVolumeEffect eEffect1, optional EVolumeEffect eEffect2)
{
    m_arrTVolumes[int(eVolume)].eType = eVolume;
    m_arrTVolumes[int(eVolume)].iDuration = iDuration;
    m_arrTVolumes[int(eVolume)].fRadius = fRadius;
    m_arrTVolumes[int(eVolume)].fHeight = fHeight;
    m_arrTVolumes[int(eVolume)].clrVolume = class'UIProtoWidget'.static.CreateColor(eColor, eShade, int(fAlpha * float(255)));
    ++m_arrTVolumes[int(eVolume)].aEffects[int(eEffect1)];
    ++m_arrTVolumes[int(eVolume)].aEffects[int(eEffect2)];
}

function XGVolume CreateVolumeByType(EVolumeType kType, Vector vCenter, optional float fRadius = -1.0, optional float fHeight = -1.0, optional int iNumTurns = -1, optional XGUnit kOwner)
{
    local XGVolume kVolume;
    local TVolume kTVolume;

    kTVolume = `TACTICALGRI.m_kBattle.m_kVolumeMgr.GetTVolume(kType);

    if (fRadius >= 0)
    {
        kTVolume.fRadius = fRadius;
    }

    if (iNumTurns >= 0)
    {
        kTVolume.iDuration = iNumTurns;
    }

    if (fHeight >= 0)
    {
        kTVolume.fHeight = fHeight;
    }

    if (kOwner != none)
    {
        kVolume = Spawn(class'LWCE_XGVolume', kOwner);
    }
    else
    {
        kVolume = Spawn(class'LWCE_XGVolume', self);
    }

    kVolume.Init(kTVolume, vCenter);

    `LWCE_MOD_LOADER.OnVolumeCreated(kVolume);

    if (kType == eVolume_Fire && class'XComWorldData'.static.GetWorldData().IsRebuildingTiles())
    {
        m_arrDelayAddVolumes.AddItem(kVolume);
        SetTickIsDisabled(false);
        SetTimer(1.0, false, 'CheckDelayAddVolumes');
    }
    else
    {
        AddVolume(kVolume);
    }

    return kVolume;
}

static function Vector TiledVolumeLocation(Vector vCenter)
{
    local bool bFloorTile;
    local int X, Y, Z;

    bFloorTile = class'XComWorldData'.static.GetWorldData().GetFloorTileForPosition(vCenter, X, Y, Z);

    if (!bFloorTile)
    {
        vCenter.Z += 64.0 * 1.50;
        bFloorTile = class'XComWorldData'.static.GetWorldData().GetFloorTileForPosition(vCenter, X, Y, Z);
    }

    if (bFloorTile)
    {
        vCenter = class'XComWorldData'.static.GetWorldData().GetPositionFromTileCoordinates(X, Y, Z);
        vCenter.Z += 64.0 * 1.10;
    }

    return vCenter;
}

function XGVolume CreateVolume(TVolume kTVolume, XGUnit kInstigator, Vector vCenter, optional XGAbility_Targeted kAbility)
{
    local XGVolume kVolume;

    if (kTVolume.eType == eVolume_Smoke || kTVolume.eType == eVolume_CombatDrugs || kTVolume.eType == eVolume_Poison)
    {
        vCenter = TiledVolumeLocation(vCenter);
    }

    kVolume = Spawn(class'LWCE_XGVolume', kInstigator);
    kVolume.Init(kTVolume, vCenter, kAbility);
    `LWCE_MOD_LOADER.OnVolumeCreated(kVolume);
    AddVolume(kVolume);
    return kVolume;
}

simulated function LoadInit()
{
    super.LoadInit();
}