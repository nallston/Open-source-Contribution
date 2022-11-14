class LWCE_XGFacility_CyberneticsLab extends XGFacility_CyberneticsLab
    dependson(LWCETypes);

struct LWCE_TRepairingItem
{
    var name ItemName;
    var int iHoursLeft;
};

var array<LWCE_TRepairingItem> m_arrRepairingItems;

function Update()
{
    LWCE_UpdatePatients();
    UpdateRepairingMecs();
}

function bool AddItemForRepair(name ItemName, optional int iQuantity = 1)
{
    local LWCE_TRepairingItem kRepairingItem;
    local LWCE_XGStorage kStorage;

    kStorage = LWCE_XGStorage(STORAGE());

    if (CanAffordItemRepair(ItemName, iQuantity))
    {
        kRepairingItem.ItemName = ItemName;
        kRepairingItem.iHoursLeft = GetHoursToRepairItem(ItemName);
        m_arrRepairingItems.AddItem(kRepairingItem);

        PayItemRepairCost(ItemName, iQuantity);

        kStorage.LWCE_RepairItem(ItemName, iQuantity);
        kStorage.LWCE_ClaimItem(ItemName, /* kSoldier */ none, iQuantity);

        return true;
    }

    return false;
}

function bool AddMecForRepair(EItemType eItem)
{
    `LWCE_LOG_CLS("ERROR: LWCE-incompatible function AddMecForRepair was called. This needs to be replaced with AddItemForRepair. Stack trace follows.");
    ScriptTrace();

    return false;
}

function bool CanAffordItemRepair(name ItemName, int iQuantity)
{
    local LWCE_TCost kCost;

    kCost = GetCostToRepairItem(ItemName, iQuantity);

    return LWCE_XGHeadquarters(HQ()).CanAffordCost(kCost);
}

function bool CanAffordMecRepair(EItemType eItem)
{
    `LWCE_LOG_CLS("ERROR: LWCE-incompatible function CanAffordMecRepair was called. This needs to be replaced with CanAffordItemRepair. Stack trace follows.");
    ScriptTrace();

    return false;
}

function GetEvents(out array<THQEvent> arrEvents)
{
    `LWCE_LOG_DEPRECATED_CLS(GetEvents);
}

function LWCE_GetEvents(out array<LWCE_THQEvent> arrEvents)
{
    LWCE_GetPatientEvents(arrEvents);
    LWCE_GetRepairingMecEvents(arrEvents);
}

/// <summary>
/// Calculates the cost to repair a quantity of the given item. By default, repairing items only
/// costs money, alloys, elerium, and meld, proportional to the cost to build the item.
/// </summary>
function LWCE_TCost GetCostToRepairItem(name ItemName, int iQuantity)
{
    local LWCE_TCost kItemCost, kRepairCost;

    // Miracle Workers removes all repair costs; they only take time
    if (IsOptionEnabled(`LW_SECOND_WAVE_ID(MiracleWorkers)))
    {
        return kRepairCost;
    }

    kItemCost = `LWCE_ITEM(ItemName).GetCost(/* bRush */ false);

    // Costs are normally paid one at a time, so we have to floor the individual cost before multiplying
    kRepairCost.iCash = iQuantity * int(kItemCost.iCash * m_fMecRepairCostMod);
    kRepairCost.iAlloys = iQuantity * int(kItemCost.iAlloys * m_fMecRepairCostMod);
    kRepairCost.iElerium = iQuantity * int(kItemCost.iElerium * m_fMecRepairCostMod);
    kRepairCost.iMeld = iQuantity * int(kItemCost.iMeld * m_fMecRepairCostMod);

    return kRepairCost;
}

function int GetHoursToRepairItem(name ItemName)
{
    local float fAdvancedRepairMult, fEngWorkPerHour, fRepairTimePercentage;
    local LWCE_XGFacility_Engineering kEngineering;
    local LWCEItemTemplate kItem;

    kEngineering = LWCE_XGFacility_Engineering(ENGINEERING());
    kItem = `LWCE_ITEM(ItemName);

    if (kItem.iPointsToComplete <= 0)
    {
        return 0;
    }

    // TODO move min repair time, advanced repair effect into config
    fAdvancedRepairMult = kEngineering.LWCE_IsFoundryTechResearched('Foundry_AdvancedRepair') ? 0.67f : 1.0f;
    fEngWorkPerHour = kEngineering.GetWorkPerHour(GetResource(eResource_Engineers), /* bRush */ false);
    fRepairTimePercentage = class'XGTacticalGameCore'.default.CB_EXPERT_BONUS / 100.0f;

    return Max(72, (kItem.iPointsToComplete * fRepairTimePercentage * fAdvancedRepairMult) / fEngWorkPerHour);
}

function int GetHoursToRepairMec(EItemType eItem)
{
    `LWCE_LOG_CLS("ERROR: LWCE-incompatible function GetHoursToRepairMec was called. This needs to be replaced with GetHoursToRepairItem. Stack trace follows.");
    ScriptTrace();

    return -1;
}

function LWCE_GetPatientEvents(out array<LWCE_THQEvent> arrEvents)
{
    local int iModTime, iEvent;
    local LWCE_THQEvent kEvent;
    local bool bAdded;
    local array<int> arrEventTimes;
    local TCyberneticsLabPatient kPatient;

    foreach m_arrPatients(kPatient)
    {
        if (arrEventTimes.Find(kPatient.m_iHoursLeft) == INDEX_NONE)
        {
            arrEventTimes.AddItem(kPatient.m_iHoursLeft);
        }
    }

    for (iModTime = 0; iModTime < arrEventTimes.Length; iModTime++)
    {
        kEvent.EventType = 'CyberneticModification';
        kEvent.iHours = arrEventTimes[iModTime];

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

function LWCE_GetRepairingMecEvents(out array<LWCE_THQEvent> arrEvents)
{
    local int iRepairTime, iEvent;
    local bool bAdded;
    local array<int> arrEventTimes;
    local LWCE_TData kData;
    local LWCE_THQEvent kBlankEvent, kEvent;
    local LWCE_TRepairingItem kRepairingItem;

    foreach m_arrRepairingItems(kRepairingItem)
    {
        if (arrEventTimes.Find(kRepairingItem.iHoursLeft) == INDEX_NONE)
        {
            arrEventTimes.AddItem(kRepairingItem.iHoursLeft);
        }
    }

    for (iRepairTime = 0; iRepairTime < m_arrRepairingItems.Length; iRepairTime++)
    {
        kEvent = kBlankEvent;
        kEvent.EventType = 'ItemRepair';
        kEvent.iHours = m_arrRepairingItems[iRepairTime].iHoursLeft;

        kData.eType = eDT_Name;
        kData.nmData = m_arrRepairingItems[iRepairTime].ItemName;
        kEvent.arrData.AddItem(kData);

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

function MecCinematicComplete()
{
    local XComHumanPawn kPawn;

    class'XComMapManager'.static.RemoveStreamingMapByName("Addon_CyberneticsLab_CAP");
    MecCinematicSoldier.SetStatus(eStatus_Active);

    kPawn = XComHumanPawn(MecCinematicSoldier.m_kPawn);
    kPawn.Mesh.SetPhysicsAsset(MecCinematicPhysics, true);

    MecCinematicSoldier = none;

    GEOSCAPE().Resume();
    LWCE_UpdatePatients();
}

function bool PayItemRepairCost(name ItemName, int iQuantity)
{
    local LWCE_TCost kCost;

    kCost = GetCostToRepairItem(ItemName, iQuantity);

    return LWCE_XGHeadquarters(HQ()).PayCost(kCost);
}

function LWCE_UpdatePatients()
{
    local LWCE_TData kData;
    local LWCE_TGeoscapeAlert kAlert, kBlankAlert;
    local int iPatient;
    local bool bPatientsCompleted, bIsTraining;
    local XGStrategySoldier kSoldier;
    local LWCE_XGStrategySoldier kCESoldier;

    if (GEOSCAPE().IsPaused())
    {
        return;
    }

    iPatient = m_arrPatients.Length - 1;

    while (iPatient >= 0)
    {
        kAlert = kBlankAlert;
        kAlert.AlertType = 'Augmentation';

        m_arrPatients[iPatient].m_iHoursLeft = Max(m_arrPatients[iPatient].m_iHoursLeft - 1, 0);

        if (m_arrPatients[iPatient].m_iHoursLeft == 0 && !GEOSCAPE().IsBusy())
        {
            bPatientsCompleted = true;

            if (!Game().m_bCompletedFirstMec)
            {
                Achieve(AT_WhoNeedsLimbs);
                Game().m_bCompletedFirstMec = true;
                MecCinematicSoldier = m_arrPatients[iPatient].m_kSoldier;
                GEOSCAPE().Pause();
                FirstMecCinematic();
                return;
            }

            kCESoldier = LWCE_XGStrategySoldier(m_arrPatients[iPatient].m_kSoldier);
            kCESoldier.LWCE_SetSoldierClass(eSC_Mec);

            kData.eType = eDT_Int;
            kData.iData = m_arrPatients[iPatient].m_kSoldier.m_kSoldier.iID;
            kAlert.arrData.AddItem(kData);

            LWCE_XGGeoscape(GEOSCAPE()).LWCE_Alert(kAlert);

            m_arrPatients.Remove(iPatient, 1);
        }

        iPatient--;
    }

    if (bPatientsCompleted)
    {
        BARRACKS().ReorderRanks();
    }

    foreach BARRACKS().m_arrSoldiers(kSoldier)
    {
        if (kSoldier.GetStatus() == eStatus_Augmenting)
        {
            bIsTraining = false;

            for (iPatient = 0; iPatient < m_arrPatients.Length; iPatient++)
            {
                if (kSoldier == m_arrPatients[iPatient].m_kSoldier)
                {
                    bIsTraining = true;
                    break;
                }
            }

            if (!bIsTraining)
            {
                kSoldier.SetStatus(eStatus_Active);
            }
        }
    }
}