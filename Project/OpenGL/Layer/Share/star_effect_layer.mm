//
//  star_effect_layer.mm
//  REFLEC BEAT plus
//
//  The score-star effect layer (StarEffectLayer). Reconstructed from Ghidra project rb458, program
//  rb458. @ghidraAddress values are relative to the program image base.
//

#include "star_effect_layer.h"

// The process-wide star effect layer, created lazily by shared().
static StarEffectLayer *g_pStarEffectLayer = nullptr; // @ghidraAddress 0x3df238

namespace {

// The layer's initial animation state and its default per-quad scale.
constexpr int kInitialState = 1;
constexpr float kInitialScale = 1.0f;

} // namespace

/** @ghidraAddress 0x189294 */
StarEffectLayer::StarEffectLayer() {
    m_pHandle = nullptr;
    m_pSprites = nullptr;
    m_nSpriteCount = 0;
    for (int nQuad = 0; nQuad < kQuadCount; ++nQuad) {
        m_aQuadPos[nQuad] = S_VECTOR2{};
        m_aQuads[nQuad] = StarQuad{};
    }
    m_nState = kInitialState;
    m_bCreated = false;
    m_flScaleA = kInitialScale;
    m_flScaleB = kInitialScale;
}

/** @ghidraAddress 0x1892fc */
StarEffectLayer *StarEffectLayer::shared() {
    if (g_pStarEffectLayer == nullptr) {
        g_pStarEffectLayer = new StarEffectLayer();
    }
    return g_pStarEffectLayer;
}
