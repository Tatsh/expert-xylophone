#include "clear_gauge_layer.h"

#include <cassert>
#include <cmath>

#include "bg_layer.h"
#include "clear_gauge_digit_table.h"
#include "engineglobals.h"
#include "neRender.h"
#include "neSpriteInstancing.h"
#include "neTexture.h"
#include "s_vector2.h"
#include "sprite_uv_table.h"

// The process-wide clear-gauge layer, created lazily by shared().
static ClearGaugeLayer *g_pClearGaugeLayer = nullptr; // @ghidraAddress 0x3deb38

namespace {

// The fully opaque per-channel colour value the gauge always writes.
constexpr unsigned int kColorMax = 255;

// The gm_parts2 atlas the gauge sprites draw from.
constexpr const char *kAtlasTextureName = "00_texture/gm_parts2";

// The batch whose build additionally enables the two-side gauge.
constexpr int kTwoSideEnableBatch = 1;

// The number of gauge bands (upper and lower) seeded with a base icon.
constexpr int kBandCount = 2;

// The base gauge icon draws into the first sprite batch.
constexpr unsigned int kIconBatch = 0;

// The gauge fill marker draws into the second sprite batch.
constexpr unsigned int kMarkerBatch = 1;

// The separator and percent-sign labels draw into the sixth and eighth sprite batches.
constexpr unsigned int kSeparatorBatch = 5;
constexpr unsigned int kPercentBatch = 7;

// The gauge value (zero to one) scales to a per-mille percentage, so a full gauge reads 100.0.
constexpr float kPercentScale = 1000.0f;
// At or above this per-mille reading (seventy percent) the high-value glyph variants are used.
constexpr float kHighValueThreshold = 700.0f;
// The high-value glyph variants sit ten entries past the normal ones in each digit bank.
constexpr int kHighValueGlyphOffset = 10;
// The small fractional digits sit twenty entries past the large digits in each glyph table.
constexpr int kFractionalGlyphOffset = 20;
// The iPad default gauge style recentres each glyph horizontally by this offset.
constexpr float kPadDefaultStyleShiftX = -181.0f;

// The four digit places drawn, most significant first.
enum DigitPlace { kDigitThousands, kDigitHundreds, kDigitTens, kDigitOnes, kDigitPlaceCount };
// The tens place and everything below it always draw, even as leading zeros.
constexpr int kFirstAlwaysDrawnPlace = kDigitTens;

// The phone (non-iPad) gauge sits at a fixed X, with its two bands on two literal rows.
constexpr float kPhoneGaugeX = -190.0f;
constexpr int kPhoneBandTopY = 0x1d6;    // 470
constexpr int kPhoneBandBottomY = 0x22a; // 554

// The iPad gauge sits out at a fixed X (mirrored to the negative side in the two-side layout).
constexpr float kPadGaugeX = 200.0f;

} // namespace

namespace {
// The two-band icon batch count the constructor's cascade converges each batch capacity to (each of
// the eight batches holds one glyph per side).
constexpr int kPerBatchCapacityStep = 2;
// The eight-entry stride between the two windows the constructor's copy loop reads and writes.
constexpr int kBatchStateWindow = 8;
// The number of batch-state entries the constructor's copy loop advances (42 of the 50).
constexpr int kBatchStateCopyCount = 42;
// The gauge's initial gauge-style and two-side defaults, and its initial reveal-fade side scales.
constexpr int kInitialGaugeStyle = 0;
constexpr int kInitialTwoSideEnabled = 1;
} // namespace

/** @ghidraAddress 0x1759fc */
ClearGaugeLayer::ClearGaugeLayer() {
    // The base constructor caches the device flags and theme; the member initialisers zero every
    // field, so only the non-zero seeds and the batch-state cascade need writing here.
    m_aSideAlphaScale[0] = 1.0f;
    m_aSideAlphaScale[1] = 1.0f;
    m_nGaugeStyle = kInitialGaugeStyle;
    m_nTwoSideEnabled = kInitialTwoSideEnabled;

    // Seed the batch-state array: copy each entry forward by one eight-entry window and step the
    // source up by two, which leaves the first eight entries (the per-batch sprite capacities read
    // by CreateSprites) at two and the rest zero.
    for (int i = 0; i < kBatchStateCopyCount; ++i) {
        m_aBatchState[i + kBatchStateWindow] = m_aBatchState[i];
        m_aBatchState[i] += kPerBatchCapacityStep;
    }
}

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

/** @ghidraAddress 0x175afc */
void ClearGaugeLayer::CreateSprites() {
    if (m_bBuilt) {
        return;
    }

    m_pTexture = ne::C_TEXTURE::FindOrLoadCached(kAtlasTextureName);
    for (int nBatch = 0; nBatch < kBatchCount; ++nBatch) {
        ne::C_SPRITE_INSTANCING_2D *pBatch =
            ne::CreateWorldSpriteBatch(static_cast<unsigned int>(m_aBatchState[nBatch]));
        m_apSprites[nBatch] = pBatch;
        BgLayer::GetBackgroundLayer()->GetBackgroundRenderObject()->AttachChild(pBatch);
        pBatch->SetVisible(true);
        pBatch->SetRefCountedMember(m_pTexture);
        pBatch->SetSpriteCount(0);
        // Building the second batch also enables the two-side gauge.
        if (nBatch == kTwoSideEnableBatch) {
            m_nTwoSideEnabled = 1;
        }
    }

    // Seed both bands' base icons.
    for (int nBand = 0; nBand < kBandCount; ++nBand) {
        SetClearGaugeIcon(nBand, 1);
    }
    m_bBuilt = true;
}

/** @ghidraAddress 0x175dd4 */
void ClearGaugeLayer::Process(float flDelta) {
    // Advance the reveal fade toward its target over its duration, only while it is still running.
    if (m_flFadeElapsed < m_flFadeDuration) {
        float flElapsed = m_flFadeElapsed + flDelta;
        if (flElapsed > m_flFadeDuration) {
            flElapsed = m_flFadeDuration;
        }
        m_flFadeElapsed = flElapsed;
        const float flFraction = (m_flFadeDuration == 0.0f) ? 1.0f : (flElapsed / m_flFadeDuration);
        m_flFadeCurrent = m_flFadeFrom + flFraction * (m_flFadeTo - m_flFadeFrom);
        m_bColorDirty = true;
    }

    // Clear every batch's sprite count before rebuilding this frame's quads.
    for (ne::C_SPRITE_INSTANCING_2D *pBatch : m_apSprites) {
        pBatch->SetSpriteCount(0);
    }

    // Rebuild each drawn side: the first side only draws when the two-side gauge is enabled.
    for (unsigned int nSide = 0; nSide < kSideCount; ++nSide) {
        if (m_nTwoSideEnabled == 0 && nSide == 0) {
            continue;
        }
        const int nFadeAlpha = static_cast<int>(m_flFadeCurrent * kColorMax);
        const int nAlpha =
            static_cast<int>(static_cast<float>(nFadeAlpha) * m_aSideAlphaScale[nSide]);
        SetClearGaugeIcon(static_cast<int>(nSide), nAlpha);
        SetClearGaugeMarker(nSide, nAlpha);
        SetClearGaugeDigits(nSide, nAlpha);
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
    // The marker's anchor, height, unfilled width, and atlas frame, chosen by orientation and
    // style.
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

void ClearGaugeLayer::EmitGlyph(const GaugeGlyphDesc &glyph,
                                unsigned int nBatch,
                                unsigned int nSide,
                                int nAlpha,
                                const float *pAnchorX) {
    // The digits override the descriptor's anchor X with a per-position value; the labels keep it.
    float flAnchorX = (pAnchorX != nullptr) ? *pAnchorX : glyph.flAnchorX;
    // The iPad default style recentres every glyph horizontally.
    if (IsPad() && m_nGaugeStyle == 0) {
        flAnchorX += kPadDefaultStyleShiftX;
    }

    const SpriteUvEntry &uv = g_aSpriteUvTable[glyph.nAtlasFrame];
    S_VECTOR2 quad[2];
    quad[0] = S_VECTOR2{flAnchorX, glyph.flAnchorY};
    quad[1] = S_VECTOR2{glyph.flSizeX, glyph.flSizeY};
    SetClearGaugeSprite(nBatch,
                        static_cast<int>(nSide),
                        quad,
                        nAlpha,
                        S_VECTOR2{uv.flOriginU, uv.flOriginV},
                        S_VECTOR2{uv.flSizeU, uv.flSizeV});
}

/** @ghidraAddress 0x176000 */
void ClearGaugeLayer::SetClearGaugeDigits(unsigned int nSide, int nAlpha) {
    // The gauge value becomes a per-mille percentage (a full gauge reads 100.0), split into a
    // hundreds-of-percent thousands digit down to a fractional ones digit.
    const float flPercent = GetValue(nSide) * kPercentScale;
    const bool bHighValue = flPercent >= kHighValueThreshold;
    const int nThousands = static_cast<int>(flPercent * 0.001f);
    float flRemainder = flPercent - static_cast<float>(nThousands * 1000);
    const int nHundreds = static_cast<int>(flRemainder * 0.01f);
    flRemainder -= static_cast<float>(nHundreds * 100);
    const int nTens = static_cast<int>(flRemainder * 0.1f);
    flRemainder -= static_cast<float>(nTens * 10);
    const int nOnes = static_cast<int>(flRemainder);
    const int aDigits[kDigitPlaceCount] = {nThousands, nHundreds, nTens, nOnes};

    // The two fixed labels: a separator and the percent sign, in the high-value variant above 70%.
    const int nLabelVariant = bHighValue ? 1 : 0;
    const bool bIsPad = IsPad();
    const GaugeGlyphDesc &separator =
        (bIsPad ? g_aGaugeLabelSeparatorPad : g_aGaugeLabelSeparatorPhone)[nLabelVariant];
    const GaugeGlyphDesc &percent =
        (bIsPad ? g_aGaugeLabelPercentPad : g_aGaugeLabelPercentPhone)[nLabelVariant];
    EmitGlyph(separator, kSeparatorBatch, nSide, nAlpha, nullptr);
    EmitGlyph(percent, kPercentBatch, nSide, nAlpha, nullptr);

    // The four digits, suppressing leading zeros above the tens place.
    const GaugeGlyphDesc *pGlyphTable = bIsPad ? g_aGaugeDigitGlyphPad : g_aGaugeDigitGlyphPhone;
    bool bDrawing = false;
    for (int nPlace = 0; nPlace < kDigitPlaceCount; ++nPlace) {
        const int nDigit = aDigits[nPlace];
        if (nPlace >= kFirstAlwaysDrawnPlace || nDigit != 0) {
            bDrawing = true;
        }
        if (!bDrawing) {
            continue;
        }
        // The ones digit is the small fractional glyph; the high-value bank sits ten entries on.
        int nGlyphIndex = nDigit;
        if (nPlace == kDigitOnes) {
            nGlyphIndex += kFractionalGlyphOffset;
        }
        if (bHighValue) {
            nGlyphIndex += kHighValueGlyphOffset;
        }
        EmitGlyph(pGlyphTable[nGlyphIndex],
                  static_cast<unsigned int>(g_aGaugeDigitBatch[nPlace]),
                  nSide,
                  nAlpha,
                  &g_aGaugeDigitAnchorX[nPlace]);
    }
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
        // (InitClearGaugeLayer, 0x1759fc), which chains to the play-field base initialiser and
        // seeds the sprite-slot bookkeeping.
        g_pClearGaugeLayer = new ClearGaugeLayer();
    }
    return g_pClearGaugeLayer;
}
