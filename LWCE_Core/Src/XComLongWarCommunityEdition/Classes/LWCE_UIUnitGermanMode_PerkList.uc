class LWCE_UIUnitGermanMode_PerkList extends UIUnitGermanMode_PerkList;

simulated function PrepareData(EPerkBuffCategory eBuffCategory, string listTitle, array<int> perkArray, XGUnit kUnit)
{
    local int I;
    local LWCE_TPerk kPerk;
    local LWCE_XComPerkManager kPerksMgr;
    local UIPerkData perkData;

    kPerksMgr = LWCE_XComPerkManager(XComTacticalController(controllerRef).PERKS());
    m_strTitle = listTitle;
    m_arrPerkData.Length = 0;

    for (I = 0; I < perkArray.Length; I++)
    {
        kPerk = kPerksMgr.LWCE_GetPerk(perkArray[I]);

        if (!kPerk.bShowPerk)
        {
            continue;
        }

        perkData.strName = kPerksMgr.GetPerkName(kPerk.iPerkId, eBuffCategory);
        perkData.strDescription = kPerksMgr.GetDynamicPerkDescription(kPerk.iPerkId, LWCE_XGUnit(kUnit), eBuffCategory);
        perkData.strIcon = kPerk.Icon;
        perkData.buffCategory = eBuffCategory;

        m_arrPerkData.AddItem(perkData);
    }

    m_arrPerkData.Sort(SortPerks);
}

simulated function PrepareItemData(array<EItemType_Info> arrItemInfos)
{
    `LWCE_LOG_DEPRECATED_CLS(PrepareItemData);
}

simulated function LWCE_PrepareItemData(XGInventory kInventory)
{
    local int I, J;
    local UIPerkData perkData;
    local XGInventoryItem kInvItem;
    local LWCE_XGWeapon kWeapon;

    `LWCE_LOG_CLS("LWCE_PrepareItemData");

    for (I = 0; I < eSlot_MAX; I++)
    {
        for (J = 0; J < kInventory.GetNumberOfItemsInSlot(ELocation(I)); J++)
        {
            kInvItem = kInventory.GetItemByIndexInSlot(J, ELocation(I));

            if (kInvItem == none)
            {
                continue;
            }

            kWeapon = LWCE_XGWeapon(kInvItem);

            if (kWeapon == none)
            {
                `LWCE_LOG_CLS("WARNING: found XGInventoryItem which could not be cast to LWCE_XGWeapon in slot " $ ELocation(I) $ ", index " $ J);
                continue;
            }

            `LWCE_LOG_CLS("Handling item " $ kWeapon.m_TemplateName);
            if (kWeapon.m_kTemplate.strPerkHUDIcon == "" || kWeapon.m_kTemplate.strPerkHUDSummary == "")
            {
                `LWCE_LOG_CLS("Missing data: icon = " $ kWeapon.m_kTemplate.strPerkHUDIcon $ ", summary = " $ kWeapon.m_kTemplate.strPerkHUDSummary);
                continue;
            }

            perkData.strName = kWeapon.m_kTemplate.strName;
            perkData.strDescription = kWeapon.m_kTemplate.strPerkHUDSummary;
            perkData.strIcon = kWeapon.m_kTemplate.strPerkHUDIcon;

            m_arrPerkData.AddItem(perkData);
        }
    }
}

protected function int SortPerks(UIPerkData kPerkA, UIPerkData kPerkB)
{
    // Sort by perk name in ascending order
    return kPerkB.strName < kPerkA.strName ? -1 : 0;
}