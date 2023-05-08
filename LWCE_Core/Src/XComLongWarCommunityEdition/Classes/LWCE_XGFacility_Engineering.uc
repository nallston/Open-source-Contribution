class LWCE_XGFacility_Engineering extends XGFacility_Engineering
    dependson(LWCETypes, LWCE_XGMissionControlUI);

struct LWCE_TFoundryProject
{
    var name ProjectName;
    var int iEngineers;
    var int iMaxEngineers;
    var int iHoursLeft;
    var int iIndex;
    var bool bRush;
    var bool bNotify;
    var bool bAdjusted;
    var LWCE_TProjectCost kRebate;
    var LWCE_TProjectCost kOriginalCost;
};

struct CheckpointRecord_LWCE_XGFacility_Engineering extends CheckpointRecord_XGFacility_Engineering
{
    var array<LWCE_TFoundryProject> m_arrCEFoundryProjects;
    var array<LWCE_TItemProject> m_arrCEItemProjects;
    var array<name> m_arrCEFoundryHistory;
    var array<LWCE_TProjectCost> m_arrCEOldRebates;
};

var array<LWCE_TFoundryProject> m_arrCEFoundryProjects;
var array<LWCE_TItemProject> m_arrCEItemProjects;
var array<name> m_arrCEFoundryHistory;
var array<LWCE_TProjectCost> m_arrCEOldRebates;

var private LWCEItemTemplateManager m_kItemTemplateMgr;

function Init(bool bLoadingFromSave)
{
    BaseInit();

    m_kItems = Spawn(class'LWCE_XGItemTree');
    m_kItems.Init();

    m_kItemTemplateMgr = `LWCE_ITEM_TEMPLATE_MGR;

    if (m_arrMusingTracker.Length == 0)
    {
        m_arrMusingTracker.Add(9);
    }
}

function InitNewGame()
{
    m_iNumEngineers = class'XGTacticalGameCore'.default.NUM_STARTING_ENGINEERS;

    m_kStorage = Spawn(class'LWCE_XGStorage');
    m_kStorage.Init();
    GrantInitialStores();

    m_bRequiresAttention = true;
    m_bCanBuildFacilities = true;
    m_bCanBuildItems = true;
    m_iEngineerReminder = 45 * 24;
    m_iEleriumHalfLife = int(class'XGTacticalGameCore'.default.SW_ELERIUM_HALFLIFE);
}

// #region Functions related to facilities

function AddFacilityProject(out TFacilityProject kProject)
{
    local bool bInstaBuild, bFreeBuild;

    bInstaBuild = false;
    bFreeBuild = false;

    if (XComCheatManager(GetALocalPlayerController().CheatManager) != none)
    {
        bInstaBuild = XComCheatManager(GetALocalPlayerController().CheatManager).m_bStrategyAllFacilitiesInstaBuild;
        bFreeBuild = XComCheatManager(GetALocalPlayerController().CheatManager).m_bStrategyAllFacilitiesFree;
    }

    // TODO: currently broken; fix when moving facilities to LWCE
    kProject.iIndex = m_arrFacilityProjects.Length;
    kProject.kOriginalCost = GetFacilityProjectCost(kProject.eFacility, kProject.X, kProject.Y, kProject.Brush);
    m_arrFacilityProjects.AddItem(kProject);

    if (!bFreeBuild)
    {
        PayCost(kProject.kOriginalCost);
    }

    Base().PerformAction(eBCS_BeginConstruction, kProject.X, kProject.Y, kProject.eFacility);

    if (bInstaBuild)
    {
        UpdateFacilityProjects();
    }
}

function bool GetFacilityCostSummary(out TCostSummary kCostSummary, EFacilityType eFacility, int X, int Y, bool Brush)
{
    local LWCE_TProjectCost kCost;
    local TText txtCost;
    local XGParamTag kTag;
    local bool bCanAfford, bFreeBuild;
    local int iPower;

    kTag = XGParamTag(XComEngine(class'Engine'.static.GetEngine()).LocalizeContext.FindTag("XGParam"));
    bFreeBuild = false;

    if (XComCheatManager(GetALocalPlayerController().CheatManager) != none)
    {
        bFreeBuild = XComCheatManager(GetALocalPlayerController().CheatManager).m_bStrategyAllFacilitiesFree;
    }

    kCost = LWCE_GetFacilityProjectCost(eFacility, X, Y, bRush);
    iPower = Facility(eFacility).iPower;
    bCanAfford = true;

    if (iPower < 0 && !bFreeBuild)
    {
        kTag.IntValue0 = -iPower;
        kTag.StrValue0 = m_strCostPower;
        txtCost.StrValue = class'XComLocalizer'.static.ExpandString(m_strCostLabel);
        txtCost.iState = eUIState_Warning;

        if (-iPower > GetResource(eResource_Power) && !bFreeBuild)
        {
            bCanAfford = false;
            txtCost.iState = eUIState_Bad;
            kCostSummary.strHelp = m_strErrInsufficientPower;
        }

        kCostSummary.arrRequirements.AddItem(txtCost);
    }

    if (kCost.iStaffTypeReq != eStaff_None && !bFreeBuild)
    {
        txtCost.StrValue = m_strLabelRequires;
        txtCost.iState = eUIState_Warning;

        if (kCost.iStaffTypeReq == eStaff_Soldier)
        {
            kTag.IntValue0 = kCost.iStaffNumReq;
            txtCost.StrValue = class'XComLocalizer'.static.ExpandString(m_strCostSoldier);

            if (BARRACKS().m_iHighestRank < kCost.iStaffNumReq)
            {
                bCanAfford = false;
                txtCost.iState = eUIState_Bad;
                kCostSummary.strHelp = m_strErrInsufficientExperience;
            }
        }
        else if (kCost.iStaffTypeReq == eStaff_Scientist)
        {
            kTag.IntValue0 = kCost.iStaffNumReq;
            kTag.StrValue0 = m_strCostScientists;
            txtCost.StrValue = class'XComLocalizer'.static.ExpandString(m_strCostLabel);

            if (GetResource(eResource_Scientists) < kCost.iStaffNumReq)
            {
                bCanAfford = false;
                txtCost.iState = eUIState_Bad;
                kCostSummary.strHelp = m_strErrInsufficientScientists;
            }
        }
        else if (kCost.iStaffTypeReq == eStaff_Engineer)
        {
            kTag.IntValue0 = kCost.iStaffNumReq;
            kTag.StrValue0 = m_strCostEngineers;
            txtCost.StrValue = class'XComLocalizer'.static.ExpandString(m_strCostLabel);

            if (m_iNumEngineers < kCost.iStaffNumReq)
            {
                bCanAfford = false;
                txtCost.iState = eUIState_Bad;
                kCostSummary.strHelp = m_strErrInsufficientEngineers;
            }
        }

        kCostSummary.arrRequirements.AddItem(txtCost);
    }

    return LWCE_GetCostSummary(kCostSummary, kCost, true) && bCanAfford;
}

function TProjectCost GetFacilityProjectCost(EFacilityType eFacility, int X, int Y, bool bRushFacility)
{
    local TProjectCost kCost;

    `LWCE_LOG_DEPRECATED_CLS(GetFacilityProjectCost);

    return kCost;
}

function LWCE_TProjectCost LWCE_GetFacilityProjectCost(EFacilityType eFacility, int X, int Y, bool bRushFacility)
{
    local LWCE_TProjectCost kProjectCost;
    local LWCE_TItemQuantity kItemQuantity;
    local TFacility kFacility;

    kFacility = Facility(eFacility);
    kProjectCost.kCost.iCash = kFacility.iCash;
    kProjectCost.kCost.iElerium = kFacility.iElerium;
    kProjectCost.kCost.iAlloys = kFacility.iAlloys;

    if (eFacility == eFacility_EleriumGenerator)
    {
        kItemQuantity.ItemName = 'Item_UFOPowerSource';
        kItemQuantity.iQuantity = ItemAmount(2);
        kProjectCost.kCost.arrItems.AddItem(kItemQuantity);
    }
    else if (eFacility == eFacility_LargeRadar)
    {
        kItemQuantity.ItemName = 'Item_UFOFlightComputer';
        kItemQuantity.iQuantity = ItemAmount(2);
        kProjectCost.kCost.arrItems.AddItem(kItemQuantity);
    }
    else if (kFacility.iItemReq == eItem_HyperwaveBeacon)
    {
        kItemQuantity.ItemName = 'Item_HyperwaveBeacon';
        kItemQuantity.iQuantity = 1;
        kProjectCost.kCost.arrItems.AddItem(kItemQuantity);
    }
    else if (kFacility.iItemReq == eItem_PsiLink)
    {
        kItemQuantity.ItemName = 'Item_EtherealDevice';
        kItemQuantity.iQuantity = 1;
        kProjectCost.kCost.arrItems.AddItem(kItemQuantity);
    }
    else if (kFacility.iItemReq != 0)
    {
        kItemQuantity.ItemName = class'LWCE_XGItemTree'.static.ItemNameFromBaseID(kFacility.iItemReq);
        kItemQuantity.iQuantity = ItemAmount(1);
        kProjectCost.kCost.arrItems.AddItem(kItemQuantity);
    }

    if (eFacility == eFacility_Workshop)
    {
        kProjectCost.iStaffTypeReq = eStaff_Engineer;
        kProjectCost.iStaffNumReq = ITEMTREE().GetEngineersRequiredForNextWorkshop();
    }
    else if (eFacility == eFacility_ScienceLab)
    {
        kProjectCost.iStaffTypeReq = eStaff_Scientist;
        kProjectCost.iStaffNumReq = ITEMTREE().GetScientistsRequiredForNextLab();
    }
    else if (eFacility == eFacility_SmallRadar || eFacility == eFacility_LargeRadar)
    {
        kProjectCost.iStaffTypeReq = eStaff_Engineer;
        kProjectCost.iStaffNumReq = ITEMTREE().GetEngineersRequiredForNextUplink(eFacility);
    }

    if (bRushFacility)
    {
        kProjectCost.kCost.iCash *= 1.50;
        kProjectCost.kCost.iElerium *= 1.50;
        kProjectCost.kCost.iAlloys *= 1.50;
        kProjectCost.kCost.iMeld += 20;
    }

    return kProjectCost;
}

function OnFacilityCompleted(int iProject)
{
    if (m_arrFacilityProjects[iProject].bNotify)
    {
        m_arrOldRebates.AddItem(m_arrFacilityProjects[iProject].kRebate);
        LWCE_XGGeoscape(GEOSCAPE()).LWCE_Alert(`LWCE_ALERT('NewFacilityBuilt').AddInt(m_arrFacilityProjects[iProject].eFacility).AddInt(m_arrOldRebates.Length - 1).Build());
    }
    else
    {
        PRES().Notify(eGA_NewFacilityBuilt, m_arrFacilityProjects[iProject].eFacility);

        if (HasRebate())
        {
            PRES().Notify(eGA_WorkshopRebate, m_arrFacilityProjects[iProject].kRebate.iCash, m_arrFacilityProjects[iProject].kRebate.iAlloys, m_arrFacilityProjects[iProject].kRebate.iElerium);
        }
    }

    Base().PerformAction(eBCS_BuildFacility, m_arrFacilityProjects[iProject].X, m_arrFacilityProjects[iProject].Y, m_arrFacilityProjects[iProject].eFacility);

    switch (m_arrFacilityProjects[iProject].eFacility)
    {
        case eFacility_ScienceLab:
            STAT_AddStat(eRecap_LabsBuilt, 1);
            Achieve(AT_Theory);
            LABS().UpdateLabBonus();
            break;
        case eFacility_PsiLabs:
        case eFacility_GeneticsLab:
            LABS().UpdateLabBonus();
            break;
        case eFacility_Workshop:
            STAT_AddStat(eRecap_WorkshopsBuilt, 1);
            Achieve(AT_AndPractice);
            break;
        case eFacility_DeusEx:
            STAT_SetStat(eRecap_ObjBuildGollop, Game().GetDays());
            Achieve(AT_OnTheShoulders);
            break;
        case eFacility_HyperwaveRadar:
            STAT_SetStat(eRecap_ObjBuildHyperwave, Game().GetDays());
            Achieve(AT_SeeAllKnowAll);
            break;
    }

    if (m_arrFacilityProjects[iProject].Y >= 4)
    {
        Achieve(AT_DrumsInTheDeep);
    }

    Achieve(AT_UpAndRunning);
    STAT_AddStat(eRecap_FacilitiesBuilt, 1);
}

function string RecordFacilityBuilt(EFacilityType FacilityValue)
{
    `LWCE_LOG_DEPRECATED_NOREPLACE_CLS(RecordFacilityBuilt);

    return "";
}

// #endregion

// #region Functions related to the Foundry

function AddFoundryProject(out TFoundryProject kProject)
{
    `LWCE_LOG_DEPRECATED_CLS(AddFoundryProject);
}

function LWCE_AddFoundryProject(out LWCE_TFoundryProject kProject)
{
    kProject.iIndex = m_arrCEFoundryProjects.Length;
    kProject.kOriginalCost = LWCE_GetFoundryProjectCost(kProject.ProjectName, kProject.bRush);
    m_arrCEFoundryProjects.AddItem(kProject);

    LWCE_PayCost(kProject.kOriginalCost);
    LWCE_AddFoundryProjectToQueue(kProject);
    PRES().GetMgr(class'LWCE_XGFoundryUI').UpdateView();
    m_bStartedFoundryProject = true;

    // Notify mods of this project
    `LWCE_MOD_LOADER.OnFoundryProjectAddedToQueue(kProject, `LWCE_FTECH(kProject.ProjectName));
}

function AddFoundryProjectToQueue(out TFoundryProject kProject)
{
    `LWCE_LOG_DEPRECATED_CLS(AddFoundryProjectToQueue);
}

function LWCE_AddFoundryProjectToQueue(out LWCE_TFoundryProject kProject)
{
    local TEngQueueItem kQueueItem;

    kQueueItem.bFoundry = true;
    kQueueItem.iIndex = kProject.iIndex;
    m_arrQueue.AddItem(kQueueItem);
}

function bool CanAddFoundryProject()
{
    return HQ().m_arrBaseFacilities[eFacility_Foundry] > 0;
}

function CancelFoundryProject(int iIndex)
{
    local LWCE_TFoundryProject kProject;

    kProject = LWCE_GetFoundryProject(iIndex);

    if (IsCostPopulated(kProject.kOriginalCost))
    {
        LWCE_RefundCost(kProject.kOriginalCost);
    }
    else
    {
        LWCE_RefundCost(LWCE_GetFoundryProjectCost(kProject.ProjectName, kProject.bRush));
    }

    RemoveFoundryProject(kProject.iIndex);

    // Notify mods that a project is canceled
    `LWCE_MOD_LOADER.OnFoundryProjectCanceled(kProject, `LWCE_FTECH(kProject.ProjectName));
}

function ChangeFoundryIndex(int iOldIndex, int iNewIndex)
{
    local int iQueue;

    for (iQueue = 0; iQueue < m_arrQueue.Length; iQueue++)
    {
        if (m_arrQueue[iQueue].bFoundry && m_arrQueue[iQueue].iIndex == iOldIndex)
        {
            m_arrQueue[iQueue].iIndex = iNewIndex;
            break;
        }
    }

    m_arrCEFoundryProjects[iNewIndex].iIndex = iNewIndex;
}

function int GetFoundryCounter(out TFoundryProject kProject)
{
    `LWCE_LOG_DEPRECATED_CLS(GetFoundryCounter);

    return -1;
}

function int LWCE_GetFoundryCounter(out LWCE_TFoundryProject kProject)
{
    local int iDays, iWork;

    iWork = GetWorkPerHour(kProject.iEngineers, kProject.bRush);

    if (iWork == 0)
    {
        return 999;
    }

    iDays = kProject.iHoursLeft / (24 * iWork);

    if ((kProject.iHoursLeft % (24 * iWork)) > 0)
    {
        iDays += 1;
    }

    return iDays;
}

function bool GetFoundryCostSummary(out TCostSummary kCostSummary, int iFoundryTech, bool Brush, optional bool bShowEng)
{
    `LWCE_LOG_DEPRECATED_CLS(GetFoundryCostSummary);

    return false;
}

function bool LWCE_GetFoundryCostSummary(out TCostSummary kCostSummary, name ProjectName, bool Brush, optional bool bShowEng)
{
    return LWCE_GetCostSummary(kCostSummary, LWCE_GetFoundryProjectCost(ProjectName, Brush), !bShowEng);
}

function string GetFoundryETAString(TFoundryProject kProject)
{
    `LWCE_LOG_DEPRECATED_CLS(GetFoundryETAString);

    return "";
}

function string LWCE_GetFoundryETAString(LWCE_TFoundryProject kProject)
{
    local int iHours, iDays;
    local XGParamTag kTag;

    kTag = XGParamTag(XComEngine(class'Engine'.static.GetEngine()).LocalizeContext.FindTag("XGParam"));
    iHours = kProject.iHoursLeft / (GetWorkPerHour(kProject.iEngineers, kProject.bRush));

    if (iHours < 24)
    {
        kTag.IntValue0 = iHours;
        return class'XComLocalizer'.static.ExpandString(m_strETAHour);
    }
    else
    {
        iDays = iHours / 24;

        if ((iHours % 24) > 0)
        {
            iDays += 1;
        }

        kTag.IntValue0 = iDays;
        return class'XComLocalizer'.static.ExpandString(m_strETADay);
    }
}

function TFoundryProject GetFoundryProject(int iIndex)
{
    local TFoundryProject kProject;

    `LWCE_LOG_DEPRECATED_CLS(GetFoundryProject);

    return kProject;
}

function LWCE_TFoundryProject LWCE_GetFoundryProject(int iIndex)
{
    return m_arrCEFoundryProjects[iIndex];
}

function TProjectCost GetFoundryProjectCost(int iTech, bool bRushFoundry)
{
    local TProjectCost kCost;

    `LWCE_LOG_DEPRECATED_CLS(GetFoundryProjectCost);

    return kCost;
}

function LWCE_TProjectCost LWCE_GetFoundryProjectCost(name ProjectName, bool bRushFoundry)
{
    local LWCE_TProjectCost kProjectCost;
    local LWCEFoundryProjectTemplate kTemplate;

    kTemplate = `LWCE_FTECH(ProjectName);

    if (kTemplate == none)
    {
        return kProjectCost;
    }

    kProjectCost.kCost = kTemplate.GetCost(bRushFoundry);
    kProjectCost.iStaffTypeReq = eStaff_Engineer;
    kProjectCost.iStaffNumReq = kTemplate.iEngineers;

    return kProjectCost;
}

function XComNarrativeMoment GetMusing()
{
    local LWCE_XGFacility_Labs kLabs;
    local LWCE_XGStorage kStorage;

    kLabs = LWCE_XGFacility_Labs(LABS());
    kStorage = LWCE_XGStorage(STORAGE());

    if (m_arrMusingTracker[0] == 0 && AI().GetMonth() >= 1)
    {
        m_arrMusingTracker[0] = 1;
        return `XComNarrativeMoment("EngineeringMusingI");
    }
    else if (m_arrMusingTracker[2] == 0 && kLabs.HasInterrogatedCaptive())
    {
        m_arrMusingTracker[2] = 1;
        return `XComNarrativeMoment("EngineeringMusingIII");
    }
    else if (m_arrMusingTracker[3] == 0 && kStorage.LWCE_EverHadItem('Item_FloaterCorpse'))
    {
        m_arrMusingTracker[3] = 1;
        return `XComNarrativeMomentEW("EngineeringMusingIV");
    }
    else if (m_arrMusingTracker[4] == 0 && kStorage.LWCE_EverHadItem('Item_EtherealDevice'))
    {
        m_arrMusingTracker[4] = 1;
        return `XComNarrativeMoment("EngineeringMusingV");
    }
    else if (m_arrMusingTracker[5] == 0 && BARRACKS().GetNumPsiSoldiers() > 0)
    {
        m_arrMusingTracker[5] = 1;
        return `XComNarrativeMoment("EngineeringMusingVI");
    }
    else if (m_arrMusingTracker[6] == 0 && BARRACKS().m_iHighestMecRank >= 3)
    {
        m_arrMusingTracker[6] = 1;
        return `XComNarrativeMomentEW("EngineeringMusingVII");
    }
    else if (m_arrMusingTracker[7] == 0 && kLabs.LWCE_IsResearched('Tech_AlienBiocybernetics') && BARRACKS().m_iHighestMecRank == -1)
    {
        m_arrMusingTracker[7] = 1;
        return `XComNarrativeMomentEW("EngineeringMusingVIII");
    }
    else if (m_arrMusingTracker[8] == 0 && kLabs.LWCE_IsResearched('Tech_AlienBiocybernetics') && BARRACKS().m_iHighestMecRank == -1 && GetResource(eResource_Meld) > 200)
    {
        m_arrMusingTracker[8] = 1;
        return `XComNarrativeMomentEW("EngineeringMusingIX");
    }

    return none;
}

function bool LWCE_IsFoundryTechInQueue(name ProjectName)
{
    local int iProject;

    for (iProject = 0; iProject < m_arrCEFoundryProjects.Length; iProject++)
    {
        if (m_arrCEFoundryProjects[iProject].ProjectName == ProjectName)
        {
            return true;
        }
    }

    return false;
}

function bool IsFoundryTechResearched(int iTech)
{
    `LWCE_LOG_DEPRECATED_CLS(IsFoundryTechResearched);

    return false;
}

function bool LWCE_IsFoundryTechResearched(name ProjectName)
{
    return ProjectName == '' || m_arrCEFoundryHistory.Find(ProjectName) != INDEX_NONE;
}

function ModifyFoundryProject(TFoundryProject kProject)
{
    `LWCE_LOG_DEPRECATED_CLS(ModifyFoundryProject);
}

function LWCE_ModifyFoundryProject(LWCE_TFoundryProject kProject)
{
    m_arrCEFoundryProjects[kProject.iIndex].iEngineers = kProject.iEngineers;
    m_arrCEFoundryProjects[kProject.iIndex].bAdjusted = kProject.bAdjusted;
    LWCE_PayCost(LWCE_GetFoundryProjectCost(kProject.ProjectName, kProject.bRush));
}

function OnFoundryProjectCompleted(int iProjectIndex)
{
    local LWCE_XGGeoscape kGeoscape;
    local name ProjectName;

    kGeoscape = LWCE_XGGeoscape(GEOSCAPE());
    ProjectName = m_arrCEFoundryProjects[iProjectIndex].ProjectName;

    if (m_arrCEFoundryProjects[iProjectIndex].bNotify)
    {
        m_arrCEOldRebates.AddItem(m_arrCEFoundryProjects[iProjectIndex].kRebate);

        // UE Explorer failed to decompile this line. I've put it together as best I could based on the bytecode and the alert handling code in
        // XGMissionControlUI.UpdateAlert. The decompilation failure seems to have messed up much of the remainder of the function as well, which
        // I have also worked to restore.
        kGeoscape.LWCE_Alert(`LWCE_ALERT('FoundryProjectCompleted').AddName(m_arrCEFoundryProjects[iProjectIndex].ProjectName).AddInt(m_arrCEOldRebates.Length - 1).Build());
    }

    if (ProjectName == 'Foundry_AlienGrenades')
    {
        LWCE_XGFacility_Barracks(BARRACKS()).LWCE_UpdateGrenades('Item_HEGrenade', 'Item_AlienGrenade');
    }

    m_arrCEFoundryHistory.AddItem(ProjectName);

    STAT_AddStat(eRecap_FoundryTechs, 1);

    if (TECHTREE().CheckForSkunkworks())
    {
        Achieve(AT_Skunkworks);
    }

    // Notify mods that a project is complete
    `LWCE_MOD_LOADER.OnFoundryProjectCompleted(m_arrCEFoundryProjects[iProjectIndex], `LWCE_FTECH(m_arrCEFoundryProjects[iProjectIndex].ProjectName));

    // Do this afterwards because it can also contain a mod hook and this order makes the most sense from a modder's perspective
    BARRACKS().UpdateFoundryPerks();
}

function string RecordCanceledFoundryProject(TFoundryProject Project)
{
    `LWCE_LOG_DEPRECATED_NOREPLACE_CLS(RecordCanceledFoundryProject);

    return "";
}

function string RecordFoundryProjectCompleted(TFoundryProject FinishedProject)
{
    `LWCE_LOG_DEPRECATED_NOREPLACE_CLS(RecordFoundryProjectCompleted);

    return "";
}

function string RecordStartedFoundryProject(TFoundryProject Project)
{
    `LWCE_LOG_DEPRECATED_NOREPLACE_CLS(RecordStartedFoundryProject);

    return "";
}

function RemoveFoundryProject(int iIndex)
{
    local int iProject;

    RemoveFoundryProjectFromQueue(iIndex);
    m_arrCEFoundryProjects.Remove(iIndex, 1);

    for (iProject = 0; iProject < m_arrCEFoundryProjects.Length; iProject++)
    {
        ChangeFoundryIndex(m_arrCEFoundryProjects[iProject].iIndex, iProject);
    }
}

function RestoreFoundryFunds(int iIndex)
{
    local LWCE_TProjectCost kOrigCost;

    if (IsCostPopulated(m_arrCEFoundryProjects[iIndex].kOriginalCost))
    {
        kOrigCost = m_arrCEFoundryProjects[iIndex].kOriginalCost;
    }
    else
    {
        kOrigCost = LWCE_GetFoundryProjectCost(m_arrCEFoundryProjects[iIndex].ProjectName, m_arrCEFoundryProjects[iIndex].Brush);
    }

    LWCE_PayCost(kOrigCost);
}

function UpdateFoundryProjects()
{
    local bool bGeneratedAlert;
    local int iProject, iWorkDone;

    for (iProject = 0; iProject < m_arrCEFoundryProjects.Length; iProject++)
    {
        iWorkDone = GetWorkPerHour(m_arrCEFoundryProjects[iProject].iEngineers, m_arrCEFoundryProjects[iProject].bRush);

        if (m_arrCEFoundryProjects[iProject].iHoursLeft <= iWorkDone)
        {
            // LWCE: base game returns if the geoscape is busy, presumably to stop multiple alerts from stacking up at once.
            // We modify the logic to only do so for projects which will generate alerts. This generally doesn't matter, but
            // it will behave better in modded scenarios where multiple Foundry projects are completed manually via code.
            if ( (GEOSCAPE().IsBusy() || bGeneratedAlert) && m_arrCEFoundryProjects[iProject].bNotify)
            {
                return;
            }

            m_arrCEFoundryProjects[iProject].iHoursLeft = 0;
            OnFoundryProjectCompleted(iProject);
            ITEMTREE().UpdateShips();

            // TODO: put this in the template somehow
            if (m_arrCEFoundryProjects[iProject].ProjectName == 'Foundry_WingtipSparrowhawks')
            {
                for (iWorkDone = 0; iWorkDone < HANGAR().m_arrInts.Length; iWorkDone++)
                {
                    LWCE_XGShip_Interceptor(HANGAR().m_arrInts[iWorkDone]).LWCE_EquipWeapon('Item_StingrayMissiles', 1);
                }
            }

            if (m_arrCEFoundryProjects[iProject].bNotify)
            {
                bGeneratedAlert = true;
            }

            RemoveFoundryProject(iProject);
            iProject--;
        }
        else
        {
            m_arrCEFoundryProjects[iProject].iHoursLeft -= iWorkDone;
        }
    }
}

// #endregion

// #region Functions related to items

function AddItemProject(out TItemProject kProject)
{
    `LWCE_LOG_DEPRECATED_CLS(AddItemProject);
}

function LWCE_AddItemProject(out LWCE_TItemProject kProject)
{
    kProject.iIndex = m_arrCEItemProjects.Length;
    kProject.kOriginalCost = LWCE_GetItemProjectCost(kProject.ItemName, kProject.iQuantityLeft, kProject.bRush);
    m_arrCEItemProjects.AddItem(kProject);
    LWCE_PayCost(kProject.kOriginalCost);
    LWCE_AddItemProjectToQueue(kProject);

    if (kProject.iHoursLeft <= 0)
    {
        kProject.iHoursLeft = 0;
        OnItemProjectCompleted(kProject.iIndex, true);
        RemoveItemProject(kProject.iIndex);
    }
}

function AddItemProjectToQueue(out TItemProject kProject)
{
    `LWCE_LOG_DEPRECATED_CLS(AddItemProjectToQueue);
}

function LWCE_AddItemProjectToQueue(out LWCE_TItemProject kProject)
{
    local TEngQueueItem kQueueItem;

    kQueueItem.bItem = true;
    kQueueItem.iIndex = kProject.iIndex;
    m_arrQueue.AddItem(kQueueItem);
}

function CancelItemProject(int iIndex)
{
    local LWCE_TItemProject kProject;

    kProject = LWCE_GetItemProject(iIndex);

    if (IsCostPopulated(kProject.kOriginalCost))
    {
        LWCE_RefundCost(kProject.kOriginalCost);
    }
    else
    {
        LWCE_RefundCost(LWCE_GetItemProjectCost(kProject.ItemName, kProject.iQuantityLeft, kProject.bRush));
    }

    RemoveItemProject(iIndex);
    SpillAvailableEngineers();
}

function ChangeItemIndex(int iOldIndex, int iNewIndex)
{
    local int iQueue;

    for (iQueue= 0; iQueue < m_arrQueue.Length; iQueue++)
    {
        if (m_arrQueue[iQueue].bItem && m_arrQueue[iQueue].iIndex == iOldIndex)
        {
            m_arrQueue[iQueue].iIndex = iNewIndex;
            break;
        }
    }

    m_arrCEItemProjects[iNewIndex].iIndex = iNewIndex;
}

function bool GetCostSummary(out TCostSummary kCostSummary, TProjectCost kCost, optional bool bOmitStaff)
{
    `LWCE_LOG_DEPRECATED_CLS(GetCostSummary);

    return false;
}

function bool LWCE_GetCostSummary(out TCostSummary kCostSummary, LWCE_TProjectCost kProjectCost, optional bool bOmitStaff)
{
    local TText txtCost;
    local XGParamTag kTag;
    local LWCE_XGStorage kStorage;
    local bool bCanAfford;
    local int iItem, iBarracks;
    local bool bFreeBuild;

    kTag = XGParamTag(XComEngine(class'Engine'.static.GetEngine()).LocalizeContext.FindTag("XGParam"));
    kStorage = LWCE_XGStorage(STORAGE());

    if (XComCheatManager(GetALocalPlayerController().CheatManager) != none)
    {
        bFreeBuild = XComCheatManager(GetALocalPlayerController().CheatManager).m_bStrategyAllFacilitiesFree;
    }

    bCanAfford = true;

    if (kProjectCost.kCost.iCash > 0 && !bFreeBuild)
    {
        txtCost.StrValue = class'XGScreenMgr'.static.ConvertCashToString(kProjectCost.kCost.iCash);
        txtCost.iState = eUIState_Cash;

        if (kProjectCost.kCost.iCash > GetResource(eResource_Money) && !bFreeBuild)
        {
            bCanAfford = false;
            txtCost.iState = eUIState_Bad;
            kCostSummary.strHelp = m_strErrInsufficientFunds;
        }

        kCostSummary.arrRequirements.AddItem(txtCost);
    }

    if (kProjectCost.kCost.iElerium > 0 && !bFreeBuild)
    {
        txtCost.StrValue = kProjectCost.kCost.iElerium $ "x" @ m_strCostElerium;
        txtCost.iState = eUIState_Elerium;

        if (kProjectCost.kCost.iElerium > GetResource(eResource_Elerium) && !bFreeBuild)
        {
            bCanAfford = false;
            txtCost.iState = eUIState_Bad;
            kCostSummary.strHelp = m_strErrInsufficientElerium;
        }

        kCostSummary.arrRequirements.AddItem(txtCost);
    }

    if (kProjectCost.kCost.iAlloys > 0 && !bFreeBuild)
    {
        txtCost.StrValue = kProjectCost.kCost.iAlloys $ "x" @ m_strCostAlloys;
        txtCost.iState = eUIState_Alloys;

        if (kProjectCost.kCost.iAlloys > GetResource(eResource_Alloys) && !bFreeBuild)
        {
            bCanAfford = false;
            txtCost.iState = eUIState_Bad;
            kCostSummary.strHelp = m_strErrInsufficientAlloys;
        }

        kCostSummary.arrRequirements.AddItem(txtCost);
    }

    if (kProjectCost.kCost.iMeld > 0 && !bFreeBuild)
    {
        txtCost.StrValue = kProjectCost.kCost.iMeld $ "x" @ `LWCE_ITEM('Item_Meld').strName;
        txtCost.iState = eUIState_Normal;

        if (kProjectCost.kCost.iMeld > GetResource(eResource_Meld) && !bFreeBuild)
        {
            bCanAfford = false;
            txtCost.iState = eUIState_Bad;
            kCostSummary.strHelp = m_strErrInsufficientItems;
        }

        kCostSummary.arrRequirements.AddItem(txtCost);
    }

    if (kProjectCost.kCost.iWeaponFragments > 0 && !bFreeBuild)
    {
        txtCost.StrValue = kProjectCost.kCost.iWeaponFragments $ "x" @ `LWCE_ITEM('Item_WeaponFragment').strName;
        txtCost.iState = eUIState_Normal;

        if (kProjectCost.kCost.iWeaponFragments > kStorage.LWCE_GetNumItemsAvailable('Item_WeaponFragment') && !bFreeBuild)
        {
            bCanAfford = false;
            txtCost.iState = eUIState_Bad;
            kCostSummary.strHelp = m_strErrInsufficientItems;
        }

        kCostSummary.arrRequirements.AddItem(txtCost);
    }

    if (kProjectCost.kCost.arrItems.Length > 0 && !bFreeBuild)
    {
        for (iItem = 0; iItem < kProjectCost.kCost.arrItems.Length; iItem++)
        {
            txtCost.StrValue = kProjectCost.kCost.arrItems[iItem].iQuantity $ "x" @ `LWCE_ITEM(kProjectCost.kCost.arrItems[iItem].ItemName).strName;
            txtCost.iState = eUIState_Normal;

            if (kProjectCost.kCost.arrItems[iItem].iQuantity > kStorage.LWCE_GetNumItemsAvailable(kProjectCost.kCost.arrItems[iItem].ItemName) && !bFreeBuild)
            {
                bCanAfford = false;
                txtCost.iState = eUIState_Bad;
                kCostSummary.strHelp = m_strErrInsufficientItems;
            }

            kCostSummary.arrRequirements.AddItem(txtCost);
        }
    }

    if (!bOmitStaff && kProjectCost.iStaffNumReq > 0 && !bFreeBuild)
    {
        kTag.IntValue0 = kProjectCost.iStaffNumReq;
        kTag.StrValue0 = m_strCostEngineers;
        txtCost.StrValue = class'XComLocalizer'.static.ExpandString(m_strCostLabel);
        txtCost.iState = eUIState_Normal;

        if (GetNumEngineersAvailable() < kProjectCost.iStaffNumReq)
        {
            bCanAfford = false;
            txtCost.iState = eUIState_Bad;
            kCostSummary.strHelp = m_strErrInsufficientEngineers;
        }

        kCostSummary.arrRequirements.AddItem(txtCost);
    }

    if (kProjectCost.iBarracksReq > 0)
    {
        iBarracks = BARRACKS().GetNumSoldiers() + HQ().GetStaffOnOrder(eStaff_Soldier) + GetNumShivsOrdered() + kProjectCost.iBarracksReq;
        kTag.IntValue0 = kProjectCost.iBarracksReq;
        txtCost.StrValue = class'XComLocalizer'.static.ExpandString(m_strCostBarracks);
        txtCost.iState = eUIState_Normal;

        if (iBarracks > HQ().GetSoldierCapacity())
        {
            bCanAfford = false;
            txtCost.iState = eUIState_Bad;
            kCostSummary.strHelp = m_strErrBarracksFull;
        }

        kCostSummary.arrRequirements.AddItem(txtCost);
    }

    return bCanAfford;
}

function string GetETAString(TItemProject kProject)
{
    `LWCE_LOG_DEPRECATED_CLS(GetETAString);
    return "";
}

function string LWCE_GetETAString(LWCE_TItemProject kProject)
{
    local int iHours, iDays;
    local XGParamTag kTag;

    if (kProject.iEngineers == 0)
    {
        return "--";
    }

    kTag = XGParamTag(XComEngine(class'Engine'.static.GetEngine()).LocalizeContext.FindTag("XGParam"));
    iHours = LWCE_GetItemProjectHoursRemaining(kProject);

    if (iHours < 24)
    {
        kTag.IntValue0 = iHours;
        return class'XComLocalizer'.static.ExpandString(m_strETAHour);
    }

    iDays = iHours / 24;

    if ((iHours % 24) > 0)
    {
        iDays += 1;
    }

    kTag.IntValue0 = iDays;
    return class'XComLocalizer'.static.ExpandString(m_strETADay);
}

function GetEvents(out array<THQEvent> arrEvents)
{
    `LWCE_LOG_DEPRECATED_CLS(GetEvents);
}

function LWCE_GetEvents(out array<LWCE_THQEvent> arrEvents)
{
    LWCE_GetItemEvents(arrEvents);
    LWCE_GetFacilityEvents(arrEvents);
    LWCE_GetFoundryEvents(arrEvents);
}

function GetFacilityEvents(out array<THQEvent> arrEvents)
{
    `LWCE_LOG_DEPRECATED_CLS(GetFacilityEvents);
}

function LWCE_GetFacilityEvents(out array<LWCE_THQEvent> arrEvents)
{
    local int iFacilityProject, iEvent;
    local LWCE_THQEvent kBlankEvent, kEvent;
    local bool bAdded;

    for (iFacilityProject = 0; iFacilityProject < m_arrFacilityProjects.Length; iFacilityProject++)
    {
        kEvent = kBlankEvent;
        kEvent.EventType = 'Facility';
        kEvent.iHours = m_arrFacilityProjects[iFacilityProject].iHoursLeft;

        if (m_arrFacilityProjects[iFacilityProject].bRush)
        {
            kEvent.iHours *= 0.50;
        }

        kEvent.kData = class'LWCEDataContainer'.static.NewInt('THQEventData', m_arrFacilityProjects[iFacilityProject].eFacility);

        bAdded = false;

        for (iEvent = 0; iEvent < arrEvents.Length; iEvent++)
        {
            if (arrEvents[iEvent].iHours > kEvent.iHours)
            {
                arrEvents.InsertItem(iEvent, kEvent);
                bAdded = true;
                break;
            }
        }

        if (!bAdded)
        {
            arrEvents.AddItem(kEvent);
        }
    }
}

function GetFoundryEvents(out array<THQEvent> arrEvents)
{
    `LWCE_LOG_DEPRECATED_CLS(GetFoundryEvents);
}

function LWCE_GetFoundryEvents(out array<LWCE_THQEvent> arrEvents)
{
    local int iFoundryProject, iEvent;
    local LWCE_THQEvent kBlankEvent, kEvent;
    local bool bAdded;
    local int iWorkDone;

    for (iFoundryProject = 0; iFoundryProject < m_arrCEFoundryProjects.Length; iFoundryProject++)
    {
        if (!m_arrCEFoundryProjects[iFoundryProject].bNotify)
        {
            continue;
        }

        iWorkDone = GetWorkPerHour(m_arrCEFoundryProjects[iFoundryProject].iEngineers, m_arrCEFoundryProjects[iFoundryProject].bRush);

        kEvent = kBlankEvent;
        kEvent.EventType = 'Foundry';
        kEvent.iHours = m_arrCEFoundryProjects[iFoundryProject].iHoursLeft / iWorkDone;

        if ((m_arrCEFoundryProjects[iFoundryProject].iHoursLeft % iWorkDone) > 0)
        {
            kEvent.iHours += 1;
        }

        kEvent.kData = class'LWCEDataContainer'.static.NewName('THQEventData', m_arrCEFoundryProjects[iFoundryProject].ProjectName);

        bAdded = false;

        for (iEvent = 0; iEvent < arrEvents.Length; iEvent++)
        {
            if (arrEvents[iEvent].iHours > kEvent.iHours)
            {
                arrEvents.InsertItem(iEvent, kEvent);
                bAdded = true;
                break;
            }
        }

        if (!bAdded)
        {
            arrEvents.AddItem(kEvent);
        }
    }
}

function bool GetItemCostSummary(out TCostSummary kCostSummary, EItemType eItem, optional int iQuantity = 1, optional bool Brush, optional bool bShowEng, optional int iProjectIndex = -1)
{
    `LWCE_LOG_DEPRECATED_CLS(GetItemCostSummary);
    return false;
}

function bool LWCE_GetItemCostSummary(out TCostSummary kCostSummary, name ItemName, optional int iQuantity = 1, optional bool bRush, optional bool bShowEng, optional int iProjectIndex = -1)
{
    local bool bCanAfford;
    local LWCE_TProjectCost kCost;

    if (iProjectIndex >= m_arrCEItemProjects.Length)
    {
        return false;
    }

    if (iProjectIndex != INDEX_NONE && IsCostPopulated(m_arrCEItemProjects[iProjectIndex].kOriginalCost))
    {
        kCost = m_arrCEItemProjects[iProjectIndex].kOriginalCost;
    }
    else
    {
        kCost = LWCE_GetItemProjectCost(ItemName, iQuantity, bRush);
    }

    bCanAfford = LWCE_GetCostSummary(kCostSummary, kCost, !bShowEng);
    return bCanAfford;
}

function GetItemEvents(out array<THQEvent> arrEvents)
{
    `LWCE_LOG_DEPRECATED_CLS(GetItemEvents);
}

function LWCE_GetItemEvents(out array<LWCE_THQEvent> arrEvents)
{
    local int iItemProject, iEvent;
    local LWCE_THQEvent kBlankEvent, kEvent;
    local bool bAdded;

    for (iItemProject = 0; iItemProject < m_arrCEItemProjects.Length; iItemProject++)
    {
        if (m_arrCEItemProjects[iItemProject].iEngineers == 0 || !m_arrCEItemProjects[iItemProject].bNotify)
        {
            continue;
        }

        kEvent = kBlankEvent;
        kEvent.EventType = 'ItemProject';
        kEvent.iHours = LWCE_GetItemProjectHoursRemaining(m_arrCEItemProjects[iItemProject]);

        kEvent.kData = class'LWCEDataContainer'.static.New('THQEventData');
        kEvent.kData.AddName(m_arrCEItemProjects[iItemProject].ItemName);
        kEvent.kData.AddInt(m_arrCEItemProjects[iItemProject].iQuantity);

        bAdded = false;

        for (iEvent = 0; iEvent < arrEvents.Length; iEvent++)
        {
            if (arrEvents[iEvent].iHours > kEvent.iHours)
            {
                arrEvents.InsertItem(iEvent, kEvent);
                bAdded = true;
                break;
            }
        }

        if (!bAdded)
        {
            arrEvents.AddItem(kEvent);
        }
    }
}

function TItemProject GetItemProject(int iIndex)
{
    local TItemProject kProject;

    `LWCE_LOG_DEPRECATED_CLS(GetItemProject);

    return kProject;
}

function LWCE_TItemProject LWCE_GetItemProject(int iIndex)
{
    return m_arrCEItemProjects[iIndex];
}

function int GetItemProjectHoursRemaining(TItemProject kProject)
{
    `LWCE_LOG_DEPRECATED_CLS(GetItemProjectHoursRemaining);
    return 0;
}

function int LWCE_GetItemProjectHoursRemaining(LWCE_TItemProject kProject)
{
    local int iTotalHours, iHours, iNumEngineers, iWorkDone;

    iNumEngineers = kProject.iEngineers;

    if (iNumEngineers == 0)
    {
        return -1;
    }

    iWorkDone = GetWorkPerHour(iNumEngineers, kProject.bRush);
    iTotalHours = kProject.iHoursLeft;
    iHours = iTotalHours / iWorkDone;

    if ((iTotalHours % iWorkDone) > 0)
    {
        iHours += 1;
    }

    return iHours;
}

function TProjectCost GetItemProjectCost(EItemType eItem, int iQuantity, optional bool bRush)
{
    `LWCE_LOG_DEPRECATED_CLS(GetItemProjectCost);
    return super.GetItemProjectCost(eItem, iQuantity, bRush);
}

function LWCE_TProjectCost LWCE_GetItemProjectCost(name ItemName, int iQuantity, optional bool bRush)
{
    local LWCEItemTemplate kItem;
    local LWCE_TProjectCost kProjectCost;
    local int Index;

    kItem = `LWCE_ITEM(ItemName);

    kProjectCost.kCost = kItem.kCost;
    kProjectCost.iStaffTypeReq = eStaff_Engineer;
    kProjectCost.iStaffNumReq = kItem.iEngineers;

    for (Index = 0; Index < kProjectCost.kCost.arrItems.Length; Index++)
    {
        kProjectCost.kCost.arrItems[Index].iQuantity *= iQuantity;
    }

    kProjectCost.kCost.iCash *= iQuantity;
    kProjectCost.kCost.iElerium *= iQuantity;
    kProjectCost.kCost.iAlloys *= iQuantity;

    if (bRush)
    {
        kProjectCost.kCost.iMeld    += 2 + (kProjectCost.kCost.iCash / 40);
        kProjectCost.kCost.iCash    *= 1.5;
        kProjectCost.kCost.iElerium *= 1.5;
        kProjectCost.kCost.iAlloys  *= 1.5;
    }

    // TODO move to template
    switch (ItemName)
    {
        case 'Item_SHIV':
        case 'Item_SHIVAlloy':
        case 'Item_SHIVHover':
            kProjectCost.iBarracksReq = iQuantity;
            break;
        default:
            kProjectCost.iBarracksReq = 0;
            break;
    }

    return kProjectCost;
}

function array<TItem> GetItemsByCategory(int iCategory, int iTransactionType)
{
    local array<TItem> arrItems;
    arrItems.Add(0);

    `LWCE_LOG_DEPRECATED_CLS(GetItemsByCategory);

    return arrItems;
}

function array<LWCEItemTemplate> LWCE_GetItemsByCategory(name nmCategory, int iTransactionType)
{
    if (iTransactionType == eTransaction_Build)
    {
        return LWCE_XGItemTree(ITEMTREE()).LWCE_GetBuildItems(nmCategory);
    }
    else
    {
        return LWCE_XGStorage(STORAGE()).LWCE_GetItemsInCategory(nmCategory, iTransactionType);
    }
}

function GrantInitialStores()
{
    local LWCE_XGStorage kStorage;

    kStorage = LWCE_XGStorage(STORAGE());

    kStorage.LWCE_AddItem('Item_Interceptor', 4);
    kStorage.LWCE_AddItem('Item_Skyranger');
}

function bool IsBuildingItem(EItemType eItem)
{
    `LWCE_LOG_DEPRECATED_CLS(IsBuildingItem);

    return false;
}

function bool LWCE_IsBuildingItem(name ItemName)
{
    local int iProject;

    for (iProject = 0; iProject < m_arrCEItemProjects.Length; iProject++)
    {
        if (m_arrCEItemProjects[iProject].ItemName == ItemName)
        {
            return true;
        }
    }

    return false;
}

function bool IsCorpseItem(int iItem)
{
    `LWCE_LOG_CLS("XGFacility_Engineering.IsCorpseItem is deprecated in LWCE. Use LWCE_XGItemTree.LWCE_IsCorpse instead. Stack trace follows.");
    ScriptTrace();

    return false;
}

function bool IsPriorityItem(EItemType eItem)
{
    `LWCE_LOG_CLS("ERROR: LWCE-incompatible function IsPriorityItem was called. This needs to be replaced with LWCEItemTemplate.IsPriority. Stack trace follows.");
    ScriptTrace();

    return false;
}

function ModifyItemProject(TItemProject kProject)
{
    `LWCE_LOG_DEPRECATED_CLS(ModifyItemProject);
}

function LWCE_ModifyItemProject(LWCE_TItemProject kProject)
{
    m_arrCEItemProjects[kProject.iIndex].iQuantityLeft = kProject.iQuantityLeft;
    m_arrCEItemProjects[kProject.iIndex].iQuantity = kProject.iQuantity;
    m_arrCEItemProjects[kProject.iIndex].iEngineers = kProject.iEngineers;
    m_arrCEItemProjects[kProject.iIndex].bAdjusted = kProject.bAdjusted;
    m_arrCEItemProjects[kProject.iIndex].bRush = kProject.bRush;

    LWCE_PayCost(LWCE_GetItemProjectCost(m_arrCEItemProjects[kProject.iIndex].ItemName, m_arrCEItemProjects[kProject.iIndex].iQuantityLeft, m_arrCEItemProjects[kProject.iIndex].bRush));
}

function OnItemCompleted(int iItemProject, int iQuantity, optional bool bInstant)
{
    local LWCEItemTemplate kItem;
    local LWCE_TProjectCost kRebate, kOrigCost;
    local XcomNarrativeMoment kNarrativeMoment;
    local LWCEDataContainer kData;

    kOrigCost = LWCE_GetItemProjectCost(m_arrCEItemProjects[iItemProject].ItemName, 1);

    if (!bInstant && HasRebate() && LWCE_CalcWorkshopRebate(kOrigCost, kRebate))
    {
        m_arrCEItemProjects[iItemProject].kRebate.kCost.iAlloys += kRebate.kCost.iAlloys * iQuantity;
        m_arrCEItemProjects[iItemProject].kRebate.kCost.iElerium += kRebate.kCost.iElerium * iQuantity;

        AddResource(eResource_Alloys, kRebate.kCost.iAlloys * iQuantity, true);
        AddResource(eResource_Elerium, kRebate.kCost.iElerium * iQuantity, true);
    }

    if (!bInstant)
    {
        kData = class'LWCEDataContainer'.static.New('NotifyData');
        kData.AddName(m_arrCEItemProjects[iItemProject].ItemName);
        kData.AddInt(iQuantity);

        LWCE_XComHQPresentationLayer(PRES()).LWCE_Notify('NewItemBuilt', kData);
    }

    LWCE_XGStorage(STORAGE()).LWCE_AddItem(m_arrCEItemProjects[iItemProject].ItemName, iQuantity);

    kItem = `LWCE_ITEM(m_arrCEItemProjects[iItemProject].ItemName);

    if (kItem.ItemBuiltNarrative != "")
    {
        kNarrativeMoment = XComNarrativeMoment(DynamicLoadObject(kItem.ItemBuiltNarrative, class'XComNarrativeMoment'));

        if (kNarrativeMoment != none)
        {
            if (kItem.eItemBuiltNarrativeFacility != eFacility_None)
            {
                PRES().UINarrative(kNarrativeMoment,,,, HQ().m_kBase.GetFacility3DLocation(kItem.eItemBuiltNarrativeFacility));
            }
            else
            {
                PRES().UINarrative(kNarrativeMoment);
            }
        }
    }

    // TODO move all this to templates
    if (m_arrCEItemProjects[iItemProject].ItemName == 'Item_Firestorm')
    {
        HANGAR().PlayFirestormBuiltCinematic();
    }
    else if (m_arrCEItemProjects[iItemProject].ItemName == 'Item_LaserRifle')
    {
        PRES().UINarrative(`XComNarrativeMoment("EngineeringLaser"));
    }
    else if (m_arrCEItemProjects[iItemProject].ItemName == 'Item_PlasmaRifle')
    {
        PRES().UINarrative(`XComNarrativeMoment("EngineeringPlasma"));
    }

    switch (m_arrCEItemProjects[iItemProject].ItemName)
    {
        case 'Item_PlasmaCarbine':
        case 'Item_PlasmaRifle':
        case 'Item_PlasmaNovagun':
        case 'Item_PlasmaSniperRifle':
            if (STAT_GetStat(eRecap_FirstAlienWeapon) == 0)
            {
                STAT_SetStat(eRecap_FirstAlienWeapon, Game().GetDays());
            }

            break;
        case 'Item_BlasterLauncher':
            if (STAT_GetStat(eRecap_FirstBlaster) == 0)
            {
                STAT_SetStat(eRecap_FirstBlaster, Game().GetDays());
            }

            break;
        case 'Item_CarapaceArmor':
            if (STAT_GetStat(eRecap_FirstCarapace) == 0)
            {
                STAT_SetStat(eRecap_FirstCarapace, Game().GetDays());
            }

            break;
        case 'Item_CorsairArmor':
            if (STAT_GetStat(eRecap_FirstSkeleton) == 0)
            {
                STAT_SetStat(eRecap_FirstSkeleton, Game().GetDays());
            }

            break;
        case 'Item_SHIV':
            PRES().UINarrative(`XComNarrativeMoment("EngineeringSHIVI"),,,, HQ().m_kBase.GetFacility3DLocation(eFacility_Foundry));
            Achieve(AT_IsEveryoneOk);
            break;
        case 'Item_SHIVAlloy':
            PRES().UINarrative(`XComNarrativeMoment("EngineeringSHIVII"),,,, HQ().m_kBase.GetFacility3DLocation(eFacility_Foundry));
            Achieve(AT_IsEveryoneOk);
            break;
        case 'Item_SHIVHover':
            PRES().UINarrative(`XComNarrativeMoment("EngineeringSHIVIII"),,,, HQ().m_kBase.GetFacility3DLocation(eFacility_Foundry));
            Achieve(AT_IsEveryoneOk);
            break;
        case 'Item_Firestorm':
            Achieve(AT_RideTheLightning);

            if (STAT_GetStat(eRecap_FirstFirestorm) == 0)
            {
                STAT_SetStat(eRecap_FirstFirestorm, Game().GetDays());
            }

            break;
        case 'Item_TitanArmor':
            Achieve(AT_ManNoMore);

            if (STAT_GetStat(eRecap_FirstTitan) == 0)
            {
                STAT_SetStat(eRecap_FirstTitan, Game().GetDays());
            }

            break;
        case 'Item_ArchangelArmor':
            Achieve(AT_ManNoMore);
            break;
        case 'Item_VortexArmor':
            Achieve(AT_ManNoMore);

            if (STAT_GetStat(eRecap_FirstPsiArmor) == 0)
            {
                STAT_SetStat(eRecap_FirstPsiArmor, Game().GetDays());
            }

            break;
        case 'Item_ShadowArmor':
            Achieve(AT_ManNoMore);

            if (STAT_GetStat(eRecap_FirstGhost) == 0)
            {
                STAT_SetStat(eRecap_FirstGhost, Game().GetDays());
            }

            break;
        case 'Item_LaserCannon':
            if (STAT_GetStat(eRecap_FirstIntLaser) == 0)
            {
                STAT_SetStat(eRecap_FirstIntLaser, Game().GetDays());
            }

            break;
        case 'Item_PlasmaCannon':
            if (STAT_GetStat(eRecap_FirstIntPlasma) == 0)
            {
                STAT_SetStat(eRecap_FirstIntPlasma, Game().GetDays());
            }

            break;
        case 'Item_EMPCannon':
            if (STAT_GetStat(eRecap_FirstIntEMP) == 0)
            {
                STAT_SetStat(eRecap_FirstIntEMP, Game().GetDays());
            }

            break;
        case 'Item_FusionLance':
            if (STAT_GetStat(eRecap_FirstIntFusion) == 0)
            {
                STAT_SetStat(eRecap_FirstIntFusion, Game().GetDays());
            }

            break;
    }

    STAT_AddStat(eRecap_ItemsBuilt, iQuantity);
    Achieve(AT_CombatReady);
}

function OnItemProjectCompleted(int iProject, optional bool bInstant)
{
    local LWCE_TGeoscapeAlert kAlert;

    if (bInstant)
    {
        OnItemCompleted(iProject, m_arrCEItemProjects[iProject].iQuantity, true);
    }
    else if (m_arrCEItemProjects[iProject].bNotify)
    {
        m_arrCEOldRebates.AddItem(m_arrCEItemProjects[iProject].kRebate);

        kAlert = `LWCE_ALERT('ItemProjectCompleted').AddName(m_arrCEItemProjects[iProject].ItemName).AddInt(m_arrCEItemProjects[iProject].iQuantity).AddInt(m_arrCEOldRebates.Length - 1).Build();
        LWCE_XGGeoscape(GEOSCAPE()).LWCE_Alert(kAlert);
    }

    `LWCE_MOD_LOADER.OnItemCompleted(m_arrCEItemProjects[iProject], m_arrCEItemProjects[iProject].iQuantity, bInstant);
}

function string RecordCanceledItemConstruction(TItemProject Project)
{
    `LWCE_LOG_DEPRECATED_NOREPLACE_CLS(RecordCanceledItemConstruction);

    return "";
}

function string RecordItemsBuilt(EItemType ItemType, int ItemQuantity)
{
    `LWCE_LOG_DEPRECATED_NOREPLACE_CLS(RecordItemsBuilt);

    return "";
}

function RemoveItemProject(int iIndex)
{
    local int iProject;

    RemoveItemProjectFromQueue(iIndex);
    m_arrCEItemProjects.Remove(iIndex, 1);

    for (iProject = 0; iProject < m_arrCEItemProjects.Length; iProject++)
    {
        ChangeItemIndex(m_arrCEItemProjects[iProject].iIndex, iProject);
    }
}

function RestoreItemFunds(int iIndex)
{
    local LWCE_TProjectCost kOrigCost;

    if (IsCostPopulated(m_arrCEItemProjects[iIndex].kOriginalCost))
    {
        kOrigCost = m_arrCEItemProjects[iIndex].kOriginalCost;
    }
    else
    {
        kOrigCost = LWCE_GetItemProjectCost(m_arrCEItemProjects[iIndex].ItemName, m_arrCEItemProjects[iIndex].iQuantityLeft, m_arrCEItemProjects[iIndex].bRush);
    }

    LWCE_PayCost(kOrigCost);
}

function string RecordStartedItemConstruction(TItemProject Project)
{
    `LWCE_LOG_DEPRECATED_NOREPLACE_CLS(RecordStartedItemConstruction);

    return "";
}

function UpdateItemProject()
{
    local int iItemsProduced, iEngHours, iUnitHours, iProject;

    if (m_arrCEItemProjects.Length == 0)
    {
        return;
    }

    for (iProject = 0; iProject < m_arrCEItemProjects.Length; iProject++)
    {
        if (m_arrCEItemProjects[iProject].iEngineers == 0)
        {
            continue;
        }

        iEngHours = GetWorkPerHour(m_arrCEItemProjects[iProject].iEngineers, m_arrCEItemProjects[iProject].bRush);

        // TODO: a lot of the below seems to only apply to a system where items are built individually in an order,
        // so this can probably be cleaned up quite a bit
        if (m_arrCEItemProjects[iProject].iHoursLeft <= iEngHours)
        {
            if (GEOSCAPE().IsBusy())
            {
                return;
            }

            iEngHours -= m_arrCEItemProjects[iProject].iHoursLeft;
            iUnitHours = `LWCE_ITEM(m_arrCEItemProjects[iProject].ItemName).iPointsToComplete;
            iItemsProduced = m_arrCEItemProjects[iProject].iQuantityLeft;
            iItemsProduced += (iEngHours / iUnitHours);
            m_arrCEItemProjects[iProject].iHoursLeft = iUnitHours - (iEngHours % iUnitHours);

            if (iItemsProduced > m_arrCEItemProjects[iProject].iQuantityLeft)
            {
                iItemsProduced = m_arrCEItemProjects[iProject].iQuantityLeft;
            }

            m_arrCEItemProjects[iProject].iQuantityLeft -= iItemsProduced;
            OnItemCompleted(iProject, iItemsProduced);

            if (m_arrCEItemProjects[iProject].iQuantityLeft == 0)
            {
                OnItemProjectCompleted(iProject);
                RemoveItemProject(iProject);
            }
            else
            {
                m_arrCEItemProjects[iProject].iMaxEngineers -= (iItemsProduced * `LWCE_ITEM(m_arrCEItemProjects[iProject].ItemName).iEngineers);
            }
        }
        else
        {
            m_arrCEItemProjects[iProject].iHoursLeft -= iEngHours;
        }
    }

    SpillAvailableEngineers();
}

// #endregion

// #region Miscellaneous functions

function bool CalcWorkshopRebate(TProjectCost kCost, out TProjectCost kRebate, optional bool bIsFacility)
{
    `LWCE_LOG_DEPRECATED_CLS(CalcWorkshopRebate);

    return false;
}

function bool LWCE_CalcWorkshopRebate(LWCE_TProjectCost kProjectCost, out LWCE_TProjectCost kRebate, optional bool bIsFacility)
{
    local float fBase, fExp, fRebatePercent;
    local int iAdjs;

    if (!HasRebate())
    {
        return false;
    }

    iAdjs = 2 * HQ().GetNumFacilities(eFacility_Workshop) + Base().GetAdjacencies(eAdj_Engineering);
    fExp = iAdjs / 2.0f;
    fBase = 1.0f - FMin(99.0f, 2.0f * class'XGTacticalGameCore'.default.WORKSHOP_REBATE_PCT) / 100.0f;
    fRebatePercent = 0.5f - 0.5f * (fBase ** fExp); // asymptotically approaches 50% rebate

    // TODO: add some way for other resources to be made rebateable
    kRebate.kCost.iAlloys = fRebatePercent * kProjectCost.kCost.iAlloys;
    kRebate.kCost.iElerium = fRebatePercent * kProjectCost.kCost.iElerium;

    return true;
}

function OnAlloyProjectCompleted(int iProject)
{
    `LWCE_LOG_DEPRECATED_NOREPLACE_CLS(OnAlloyProjectCompleted);
}

function PayCost(TProjectCost kCost)
{
    `LWCE_LOG_DEPRECATED_CLS(PayCost);
}

function LWCE_PayCost(LWCE_TProjectCost kProjectCost)
{
    local LWCE_XGStorage kStorage;
    local int iItem;

    kStorage = LWCE_XGStorage(STORAGE());

    AddResource(eResource_Money, -kProjectCost.kCost.iCash);
    AddResource(eResource_Elerium, -kProjectCost.kCost.iElerium);
    AddResource(eResource_Alloys, -kProjectCost.kCost.iAlloys);
    AddResource(eResource_Meld, -kProjectCost.kCost.iMeld);

    kStorage.LWCE_RemoveItem('Item_WeaponFragment', kProjectCost.kCost.iWeaponFragments);

    for (iItem = 0; iItem < kProjectCost.kCost.arrItems.Length; iItem++)
    {
        kStorage.LWCE_RemoveItem(kProjectCost.kCost.arrItems[iItem].ItemName, kProjectCost.kCost.arrItems[iItem].iQuantity);
    }
}

function RefundCost(TProjectCost kCost)
{
    `LWCE_LOG_DEPRECATED_CLS(RefundCost);
}

function LWCE_RefundCost(LWCE_TProjectCost kProjectCost)
{
    local LWCE_XGStorage kStorage;
    local int iItem;

    kStorage = LWCE_XGStorage(STORAGE());

    AddResource(eResource_Money, kProjectCost.kCost.iCash, true);
    AddResource(eResource_Elerium, kProjectCost.kCost.iElerium, true);
    AddResource(eResource_Alloys, kProjectCost.kCost.iAlloys, true);
    AddResource(eResource_Meld, kProjectCost.kCost.iMeld, true);

    for (iItem = 0; iItem < kProjectCost.kCost.arrItems.Length; iItem++)
    {
        kStorage.LWCE_AddItem(kProjectCost.kCost.arrItems[iItem].ItemName, kProjectCost.kCost.arrItems[iItem].iQuantity);
    }
}

function bool UrgeBuildMEC()
{
    local LWCE_XGStorage kStorage;
    local array<LWCEItemTemplate> arrMecSuits;
    local XGStrategySoldier kSoldier;
    local int NumMecs;

    if (m_bUrgeBuildMEC)
    {
        return false;
    }

    kStorage = `LWCE_STORAGE;
    arrMecSuits = kStorage.LWCE_GetItemsInCategory('Armor', eTransaction_None, eSC_Mec);

    foreach BARRACKS().m_arrSoldiers(kSoldier)
    {
        if (kSoldier.IsAugmented())
        {
            NumMecs++;
        }
    }

    if (NumMecs > arrMecSuits.Length)
    {
        if (kStorage.GetResource(eResource_Meld) > 99)
        {
            m_bUrgeBuildMEC = true;
        }
    }

    return m_bUrgeBuildMEC;
}

protected function bool IsCostPopulated(LWCE_TProjectCost kProjectCost)
{
    if (kProjectCost.kCost.iCash != 0 || kProjectCost.kCost.iElerium != 0 || kProjectCost.kCost.iAlloys != 0 || kProjectCost.kCost.iMeld != 0 || kProjectCost.kCost.iWeaponFragments != 0)
    {
        return true;
    }

    if (kProjectCost.kCost.arrItems.Length > 0)
    {
        return true;
    }

    return false;
}

// #endregion