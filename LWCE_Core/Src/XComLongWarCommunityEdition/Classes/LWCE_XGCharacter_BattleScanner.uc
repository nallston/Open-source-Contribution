class LWCE_XGCharacter_BattleScanner extends XGCharacter_BattleScanner implements(LWCE_XGCharacter);

`include(generators_xgcharacter_fields.uci)

`include(generators_xgcharacter_functions.uci)

defaultproperties
{
    m_kUnitPawnClassToSpawn=class'LWCE_XComBattleScanner'
}