#include "clear_gauge_layer.h"

#include <cassert>

// The process-wide clear-gauge layer, created lazily by shared().
static ClearGaugeLayer *g_pClearGaugeLayer = nullptr; // @ghidraAddress 0x3deb38

/** @ghidraAddress 0x175c90 */
void ClearGaugeLayer::SetValue(float flValue, unsigned int nSide) {
    assert(static_cast<int>(nSide) >= 0 && static_cast<int>(nSide) < kSideCount);
    // Clamp the value to the drawable range before storing it.
    if (flValue <= 0.0f) {
        flValue = 0.0f;
    }
    if (flValue > 1.0f) {
        flValue = 1.0f;
    }
    m_aValues[nSide].flValue = flValue;
}

/** @ghidraAddress 0x175d04 */
float ClearGaugeLayer::GetValue(unsigned int nSide) const {
    assert(static_cast<int>(nSide) >= 0 && static_cast<int>(nSide) < kSideCount);
    return m_aValues[nSide].flValue;
}

/** @ghidraAddress 0x175aac */
ClearGaugeLayer *ClearGaugeLayer::shared() {
    if (g_pClearGaugeLayer == nullptr) {
        // The binary allocates the raw object and runs the clear-gauge constructor
        // (InitClearGaugeLayer, 0x1759fc), which chains to the play-field base initialiser and seeds
        // the sprite-slot bookkeeping.
        g_pClearGaugeLayer = new ClearGaugeLayer();
    }
    return g_pClearGaugeLayer;
}
