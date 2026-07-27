#include "clear_gauge_layer.h"

#include <cassert>
#include <cmath>

#include "engineglobals.h"
#include "neSpriteInstancing.h"
#include "s_vector2.h"
#include "sprite_uv_table.h"

// The process-wide clear-gauge layer, created lazily by shared().
static ClearGaugeLayer *g_pClearGaugeLayer = nullptr; // @ghidraAddress 0x3deb38

namespace {

// The fully opaque per-channel colour value the gauge always writes.
constexpr unsigned int kColorMax = 255;

// The base gauge icon draws into the first sprite batch.
constexpr unsigned int kIconBatch = 0;

// The gauge fill marker draws into the second sprite batch.
constexpr unsigned int kMarkerBatch = 1;

// The phone (non-iPad) gauge sits at a fixed X, with its two bands on two literal rows.
constexpr float kPhoneGaugeX = -190.0f;
constexpr int kPhoneBandTopY = 0x1d6;    // 470
constexpr int kPhoneBandBottomY = 0x22a; // 554

// The iPad gauge sits out at a fixed X (mirrored to the negative side in the two-side layout).
constexpr float kPadGaugeX = 200.0f;

} // namespace

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

/** @ghidraAddress 0x175c70 */
void ClearGaugeLayer::ClearValues() {
    for (ValueSlot &slot : m_aValues) {
        slot = ValueSlot{};
    }
}

/** @ghidraAddress 0x175d68 */
void ClearGaugeLayer::SetGaugeStyle(int nStyle) {
    m_nGaugeStyle = nStyle;
}

/** @ghidraAddress 0x175d70 */
void ClearGaugeLayer::SetTwoSideEnabled(bool bTwoSide) {
    m_nTwoSideEnabled = bTwoSide;
}

/** @ghidraAddress 0x175d78 */
void ClearGaugeLayer::StartFadeIn(float flDuration) {
    m_flFadeFrom = m_flFadeCurrent;
    m_flFadeTo = 1.0f;
    m_flFadeDuration = flDuration;
    m_flFadeElapsed = 0.0f;
    // A non-positive duration snaps straight to opaque and marks the colour dirty.
    if (flDuration <= 0.0f) {
        m_flFadeCurrent = 1.0f;
        m_bColorDirty = true;
    }
}

/** @ghidraAddress 0x175da8 */
void ClearGaugeLayer::StartFadeOut(float flDuration) {
    m_flFadeFrom = m_flFadeCurrent;
    m_flFadeTo = 0.0f;
    m_flFadeDuration = flDuration;
    m_flFadeElapsed = 0.0f;
    // A non-positive duration snaps straight to transparent and marks the colour dirty.
    if (flDuration <= 0.0f) {
        m_flFadeCurrent = 0.0f;
        m_bColorDirty = true;
    }
}

/** @ghidraAddress 0x175bc8 */
void ClearGaugeLayer::SetClearGaugeIcon(int nBottomBand, int nAlpha) {
    // The icon's anchor/size quad and its atlas frame, chosen by orientation and gauge style.
    S_VECTOR2 quad[2];
    int nAtlasFrame;
    if (!IsPad()) {
        // Phone.
        quad[0] = S_VECTOR2{86.0f, 20.0f};
        quad[1] = S_VECTOR2{168.0f, 40.0f};
        nAtlasFrame = 0x11c;
    } else if (m_nGaugeStyle == 0) {
        // iPad, default style.
        quad[0] = S_VECTOR2{231.0f, 17.0f};
        quad[1] = S_VECTOR2{462.0f, 34.0f};
        nAtlasFrame = 0x99;
    } else {
        // iPad, alternate style.
        quad[0] = S_VECTOR2{80.0f, 20.0f};
        quad[1] = S_VECTOR2{160.0f, 40.0f};
        nAtlasFrame = 0x9b;
    }

    const SpriteUvEntry &uv = g_aSpriteUvTable[nAtlasFrame];
    SetClearGaugeSprite(kIconBatch,
                        nBottomBand,
                        quad,
                        nAlpha,
                        S_VECTOR2{uv.flOriginU, uv.flOriginV},
                        S_VECTOR2{uv.flSizeU, uv.flSizeV});
}

/** @ghidraAddress 0x175eec */
void ClearGaugeLayer::SetClearGaugeMarker(unsigned int nSide, int nAlpha) {
    // The marker's anchor, height, unfilled width, and atlas frame, chosen by orientation and style.
    S_VECTOR2 anchor;
    float flHeight;
    float flWidthBase;
    int nAtlasFrame;
    if (!IsPad()) {
        // Phone.
        anchor = S_VECTOR2{50.0f, -4.0f};
        flHeight = 4.0f;
        flWidthBase = 100.0f;
        nAtlasFrame = 0x11d;
    } else if (m_nGaugeStyle == 0) {
        // iPad, default style.
        anchor = S_VECTOR2{216.0f, 11.0f};
        flHeight = 22.0f;
        flWidthBase = 360.0f;
        nAtlasFrame = 0x9a;
    } else {
        // iPad, alternate style.
        anchor = S_VECTOR2{48.0f, -11.0f};
        flHeight = 4.0f;
        flWidthBase = 100.0f;
        nAtlasFrame = 0x9c;
    }

    // The bar fills horizontally: the pixel width and the atlas U span both scale by the value.
    const float flValue = GetValue(nSide);
    const SpriteUvEntry &uv = g_aSpriteUvTable[nAtlasFrame];
    S_VECTOR2 quad[2];
    quad[0] = anchor;
    quad[1] = S_VECTOR2{flWidthBase * flValue, flHeight};
    SetClearGaugeSprite(kMarkerBatch,
                        static_cast<int>(nSide),
                        quad,
                        nAlpha,
                        S_VECTOR2{uv.flOriginU, uv.flOriginV},
                        S_VECTOR2{uv.flSizeU * flValue, uv.flSizeV});
}

/** @ghidraAddress 0x1763d0 */
void ClearGaugeLayer::SetClearGaugeSprite(unsigned int nBatch,
                                          int nBottomBand,
                                          const S_VECTOR2 *pQuad,
                                          int nAlpha,
                                          S_VECTOR2 uvOrigin,
                                          S_VECTOR2 uvSize) {
    ne::C_SPRITE_INSTANCING_2D *pBatch = m_apSprites[nBatch];
    const int nIndex = pBatch->GetSpriteCount();
    if (nIndex >= static_cast<int>(pBatch->GetCapacity())) {
        return;
    }

    // Pick the quad's screen position and rotation by orientation, band, and gauge style.
    S_VECTOR2 position{};
    float flRotation = 0.0f;
    if (!IsPad()) {
        // Phone: a fixed X with the two bands on two literal rows.
        position.x = kPhoneGaugeX;
        const int nBandY = (nBottomBand != 0) ? kPhoneBandBottomY : kPhoneBandTopY;
        position.y = static_cast<float>(nBandY - g_nPlayfieldCentreSplit);
    } else if (nBottomBand != 0) {
        // iPad lower band: the alternate style centres on X zero, the default style sits out at X.
        if (m_nGaugeStyle == 0) {
            position.x = 0.0f;
            position.y = static_cast<float>(g_nGaugeAltBottomBaseY - g_nPlayfieldCentreSplit);
        } else {
            position.x = kPadGaugeX;
            position.y = static_cast<float>(g_nGaugeBottomBaseY - g_nPlayfieldCentreSplit);
        }
    } else if (m_nGaugeStyle == 0) {
        // iPad upper band, alternate style: centred on X zero, half-turned in the two-side layout.
        position.x = 0.0f;
        position.y = static_cast<float>(g_nGaugeAltTopBaseY - g_nPlayfieldCentreSplit);
        if (m_nTwoSideEnabled == 1) {
            flRotation = static_cast<float>(M_PI);
        }
    } else {
        // iPad upper band, default style: sits out at X, mirroring the X and half-turning in the
        // two-side layout.
        position.y = static_cast<float>(g_nGaugeTopBaseY - g_nPlayfieldCentreSplit);
        if (m_nTwoSideEnabled == 1) {
            position.x = -kPadGaugeX;
            flRotation = static_cast<float>(M_PI);
        } else {
            position.x = kPadGaugeX;
        }
    }

    pBatch->SetSpriteAnchor(nIndex, pQuad[0]);
    pBatch->SetSpriteSize(nIndex, pQuad[1]);
    pBatch->SetSpriteUvOrigin(nIndex, uvOrigin);
    pBatch->SetSpriteUvSize(nIndex, uvSize);
    pBatch->SetSpritePosition(nIndex, position);
    pBatch->SetSpriteRotation(nIndex, flRotation);
    pBatch->SetSpriteScale(nIndex, 1.0f, 1.0f);
    pBatch->SetSpriteColor(
        nIndex, kColorMax, kColorMax, kColorMax, static_cast<unsigned int>(nAlpha));
    pBatch->SetSpriteCount(nIndex + 1);
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
