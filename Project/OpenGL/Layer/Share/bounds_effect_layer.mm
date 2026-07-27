//
//  bounds_effect_layer.mm
//  REFLEC BEAT plus
//
//  The play-field bounds effect layer (BoundsEffectLayer). Reconstructed from Ghidra project rb458,
//  program rb458. @ghidraAddress values are relative to the program image base.
//

#include "bounds_effect_layer.h"

namespace {
// The effect size the constructor seeds.
constexpr float kInitialEffectSize = 1.0f;
} // namespace

// The process-wide bounds-effect layer, created lazily by shared().
static BoundsEffectLayer *g_pBoundsEffectLayer = nullptr; // @ghidraAddress 0x3de9b0

/** @ghidraAddress 0x17528c */
BoundsEffectLayer *BoundsEffectLayer::shared() {
    if (g_pBoundsEffectLayer == nullptr) {
        g_pBoundsEffectLayer = new BoundsEffectLayer();
    }
    return g_pBoundsEffectLayer;
}

/** @ghidraAddress 0x175210 */
BoundsEffectLayer::BoundsEffectLayer() {
    // The base constructor and member initialisers clear the layer; both lane-light flags start on
    // and the effect size seeds to one.
    m_bLaneLight0 = true;
    m_bLaneLight1 = true;
    m_flEffectSize = kInitialEffectSize;
}

/** @ghidraAddress 0x1754c4 */
void BoundsEffectLayer::SetEffectSize(float flSize) {
    m_flEffectSize = flSize;
}

/** @ghidraAddress 0x1754a8 */
void BoundsEffectLayer::SetLaneLightFlag(float flValue, int nLane) {
    // The binary truncates the float to an integer byte; the callers only ever pass 0.0 or 1.0.
    const bool bFlag = static_cast<int>(flValue) != 0;
    if (nLane == 1) {
        m_bLaneLight0 = bFlag;
    } else {
        m_bLaneLight1 = bFlag;
    }
}
