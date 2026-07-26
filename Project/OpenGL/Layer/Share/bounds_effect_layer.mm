//
//  bounds_effect_layer.mm
//  REFLEC BEAT plus
//
//  The play-field bounds effect layer (BoundsEffectLayer). Reconstructed from Ghidra project rb458,
//  program rb458. @ghidraAddress values are relative to the program image base.
//

#include "bounds_effect_layer.h"

/** @ghidraAddress 0x1754c4 */
void BoundsEffectLayer::SetEffectSize(float flSize) {
    m_flEffectSize = flSize;
}

/** @ghidraAddress 0x1754a8 */
void BoundsEffectLayer::SetLaneLightFlag(float flValue, int nLane) {
    const unsigned char nFlag = static_cast<unsigned char>(static_cast<int>(flValue));
    if (nLane == 1) {
        m_bLaneLight0 = nFlag;
    } else {
        m_bLaneLight1 = nFlag;
    }
}
