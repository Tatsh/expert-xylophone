//
//  full_combo_effect_layer.cpp
//  REFLEC BEAT plus
//
//  Reconstructed from Ghidra project rb458, program rb458. Pure C++.
//

#include "full_combo_effect_layer.h"

/** @ghidraAddress 0x18795c */
void FullComboEffectLayer::AdvanceFadeInterp(float flDeltaTime) {
    m_fadeChannel.Advance(flDeltaTime);
}
