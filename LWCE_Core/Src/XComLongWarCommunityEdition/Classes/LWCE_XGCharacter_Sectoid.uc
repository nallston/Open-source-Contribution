class LWCE_XGCharacter_Sectoid extends XGCharacter_Sectoid implements(LWCE_XGCharacter);

`include(generators_xgcharacter_checkpointrecord.uci)

`GENERATE_CHECKPOINT_STRUCT(XGCharacter_Sectoid);

`include(generators_xgcharacter_fields.uci)

`include(generators_xgcharacter_functions.uci)

defaultproperties
{
    m_kUnitPawnClassToSpawn=class'LWCE_XComSectoid'
}