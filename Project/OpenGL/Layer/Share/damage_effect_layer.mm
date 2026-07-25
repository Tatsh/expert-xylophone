//
//  damage_effect_layer.mm
//  REFLEC BEAT plus
//
//  The bounds-damage effect layer (DamageEffectLayer). Reconstructed from Ghidra project rb458,
//  program rb458. @ghidraAddress values are relative to the program image base.
//

#include "damage_effect_layer.h"

/** @ghidraAddress 0x174224 */
void DamageEffectLayer::SetLaneValue(int nLane, float flValue) {
    m_aLaneValue[nLane != 0 ? 1 : 0] = flValue;
}

/** @ghidraAddress 0x174238 */
void DamageEffectLayer::SetEffectSize(float flSize) {
    m_flEffectSize = flSize;
}
