//
//  number_effect_layer.cpp
//  REFLEC BEAT plus
//
//  Reconstructed from Ghidra project rb458, program rb458. Pure C++.
//

#include "number_effect_layer.h"

/** @ghidraAddress 0x189ef0 */
void NumberEffectLayer::AdvanceFadeInterp(float flDeltaTime) {
    if (m_fadeChannel.GetElapsed() >= m_fadeChannel.GetDuration()) {
        return;
    }
    m_fadeChannel.Advance(flDeltaTime);
    m_bFadeActive = true;
}
