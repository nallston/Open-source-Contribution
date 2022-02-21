class LWCE_UIKeybindingsPCScreen extends UIKeybindingsPCScreen
    config(LWCEInput);

struct LWCE_UIKeybind
{
    var UIKeyBind kBinding;
    var KeybindCategories eBindingCategory;
    var string strIdentifier; // Unique identifier in order to tell if a keybind is missing completely
};

var config array<LWCE_UIKeyBind> m_arrCEKeybinds;

/**
 * Adds new keybindings to arrKeybinds only if they're not already present. Do not modify anything
 * if a keybinding is already in the array, or you may overwrite user settings.
 */
static function PopulateCustomKeybinds(out array<LWCE_UIKeybind> arrKeybinds)
{
    local LWCE_UIKeybind kBlankBinding, kCEBinding;

    if (arrKeybinds.Find('strIdentifier', "LWCE_ToggleDisplayOfMovementGrid") == INDEX_NONE)
    {
        kCEBinding.strIdentifier = "LWCE_ToggleDisplayOfMovementGrid";
        kCEBinding.eBindingCategory = eKC_Tactical;

        kCEBinding.kBinding.UserLabel = "TOGGLE GRID";
        kCEBinding.kBinding.PrimaryBind.Command = "ToggleDisplayOfMovementGrid";
        kCEBinding.kBinding.PrimaryBind.Name = 'T';
        kCEBinding.kBinding.PrimaryBind.Alt = true;

        arrKeybinds.AddItem(kCEBinding);

        kCEBinding = kBlankBinding;
    }
}

simulated function bool OnAccept(optional string Arg = "")
{
    local int iBindingIndex, Index;

    super.OnAccept(arg);

    // We need to sync back keybinding info from m_arrBindings for any custom bindings,
    // since all the structs we're using are being copied
    if (m_eBindingCategory == eKC_General)
    {
        iBindingIndex = eGBC_MAX;
    }
    else
    {
        iBindingIndex = eTBC_MAX;
    }

    // Since m_arrBindings only contains bindings appropriate to the keybinding category,
    // we need to track progress in it separately from progress in m_arrCEKeybinds
    for (Index = 0; Index < m_arrCEKeybinds.Length; Index++)
    {
        if (m_arrCEKeybinds[Index].eBindingCategory != m_eBindingCategory)
        {
            continue;
        }

        m_arrCEKeybinds[Index].kBinding = m_arrBindings[iBindingIndex];
        iBindingIndex++;
    }

    SaveConfig();

    return true;
}

simulated function UpdateBindingsList()
{
    local LWCE_UIKeybind kCEBinding;

    ReadBindings();
    PopulateCustomKeybinds(m_arrCEKeybinds);

    foreach m_arrCEKeybinds(kCEBinding)
    {
        if (kCEBinding.eBindingCategory == m_eBindingCategory)
        {
            m_arrBindings.AddItem(kCEBinding.kBinding);
        }
    }

    DisplayBindings();
}

simulated function bool RawInputHandler(name Key, int Actionmask, bool bCtrl, bool bAlt, bool bShift)
{
    local PlayerInput kPlayerInput;
    local KeyBind kBind;

    if (m_bAlreadyProcessingRawInput || !m_bAwaitingInputForBind || Actionmask != class'UI_FxsInput'.const.FXS_ACTION_RELEASE || !IsBindable(Key))
    {
        return false;
    }

    m_bAlreadyProcessingRawInput = true;
    FlushPressedKeys();

    m_bAlreadyProcessingRawInput = false;
    m_bAwaitingInputForBind = false;
    m_iKeySlotConflicting = IsKeyAlreadyBound(Key, bCtrl, bAlt, bShift);

    if (m_iKeySlotConflicting != -1)
    {
        if (m_iKeySlotBeingBound == m_iKeySlotConflicting)
        {
            AS_DeactivateSlot(m_iKeySlotBeingBound, m_bSecondaryKeyBeingBound);
            return true;
        }

        m_kCachedKeyBeingBound.Name = Key;
        m_kCachedKeyBeingBound.bPrimaryBinding = !m_bSecondaryKeyBeingBound;
        m_kCachedKeyBeingBound.bSecondaryBinding = m_bSecondaryKeyBeingBound;
        m_kCachedKeyBeingBound.Control = bCtrl;
        m_kCachedKeyBeingBound.Shift = bShift;
        m_kCachedKeyBeingBound.Alt = bAlt;

        if (IsBaseGameKeybindBeingBound())
        {
            m_kCachedKeyBeingBound.Command = GetCommandForKeyBeingBound();
        }

        DisplayConflictingKeyDialog();
        return true;
    }

    switch (m_eBindingCategory)
    {
        case eKC_General:
            kPlayerInput = m_kBaseInputController.PlayerInput;
            break;
        case eKC_Tactical:
            kPlayerInput = m_kTacticalInputController.PlayerInput;
            break;
    }

    if (m_arrDirtyPlayerInputs.Find(kPlayerInput) == -1)
    {
        m_arrDirtyPlayerInputs.AddItem(kPlayerInput);
    }

    if (m_bSecondaryKeyBeingBound)
    {
        kBind = m_arrBindings[m_iKeySlotBeingBound].SecondaryBind;
    }
    else
    {
        kBind = m_arrBindings[m_iKeySlotBeingBound].PrimaryBind;
    }

    if (kBind.Name != 'None')
    {
        kPlayerInput.RemoveBind(kBind.Name, kBind.Command, m_bSecondaryKeyBeingBound);
    }

    kBind.Name = Key;
    kBind.bPrimaryBinding = !m_bSecondaryKeyBeingBound;
    kBind.bSecondaryBinding = m_bSecondaryKeyBeingBound;
    kBind.Control = bCtrl;
    kBind.Shift = bShift;
    kBind.Alt = bAlt;

    if (IsBaseGameKeybindBeingBound())
    {
        // Only call this function for keybindings in the base game, or else it will result in a crash
        // in native code. Custom keybinds should already have their command field set anyway.
        kBind.Command = GetCommandForKeyBeingBound();
    }

    if (m_bSecondaryKeyBeingBound)
    {
        m_arrBindings[m_iKeySlotBeingBound].SecondaryBind = kBind;
    }
    else
    {
        m_arrBindings[m_iKeySlotBeingBound].PrimaryBind = kBind;
    }

    kPlayerInput.AddBind(kBind);
    AS_DeactivateSlot(m_iKeySlotBeingBound, m_bSecondaryKeyBeingBound);
    AS_SetNewKey(m_iKeySlotBeingBound, m_bSecondaryKeyBeingBound, m_kKeybindingData.GetKeyString(kBind));

    return true;
}

protected function bool IsBaseGameKeybindBeingBound()
{
    return (m_eBindingCategory == eKC_General && m_iKeySlotBeingBound < eGBC_MAX) || (m_eBindingCategory == eKC_Tactical && m_iKeySlotBeingBound < eTBC_MAX);
}