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

static ClearGaugeLayer *g_pClearGaugeLayer = nullptr; // @ghidraAddress 0x3deb38

namespace {

constexpr unsigned int kColorMax = 255;

constexpr const char *kAtlasTextureName = "00_texture/gm_parts2";

constexpr int kAdditiveBlendBatch = 1;
constexpr int kBlendModeAdditive = 1;

constexpr int kBandCount = 2;

constexpr unsigned int kIconBatch = 0;

constexpr unsigned int kMarkerBatch = 1;

constexpr unsigned int kSeparatorBatch = 5;
constexpr unsigned int kPercentBatch = 7;

constexpr float kPercentScale = 1000.0f;
constexpr float kHighValueThreshold = 700.0f; // Seventy percent, in per-mille.
constexpr int kHighValueGlyphOffset = 10;
constexpr int kFractionalGlyphOffset = 20;
constexpr float kPadDefaultStyleShiftX = -181.0f;

enum DigitPlace { kDigitThousands, kDigitHundreds, kDigitTens, kDigitOnes, kDigitPlaceCount };
constexpr int kFirstAlwaysDrawnPlace = kDigitTens;

constexpr float kPhoneGaugeX = -190.0f;
constexpr int kPhoneBandTopY = 0x1d6;
constexpr int kPhoneBandBottomY = 0x22a;

constexpr float kPadGaugeX = 200.0f;

} // namespace

namespace {
constexpr int kPerBatchCapacityStep = 2;
constexpr int kBatchStateWindow = 8;
constexpr int kBatchStateCopyCount = 42;
constexpr int kInitialGaugeStyle = 0;
constexpr int kInitialTwoSideEnabled = 1;
} // namespace

/** @ghidraAddress 0x1759fc */
ClearGaugeLayer::ClearGaugeLayer() {
    m_aSideAlphaScale[0] = 1.0f;
    m_aSideAlphaScale[1] = 1.0f;
    m_nGaugeStyle = kInitialGaugeStyle;
    m_nTwoSideEnabled = kInitialTwoSideEnabled;

    // Leaves the first eight entries (the per-batch sprite capacities) at two and the rest zero.
    for (int i = 0; i < kBatchStateCopyCount; ++i) {
        m_aBatchState[i + kBatchStateWindow] = m_aBatchState[i];
        m_aBatchState[i] += kPerBatchCapacityStep;
    }
}

/** @ghidraAddress 0x175c90 */
void ClearGaugeLayer::SetValue(float flValue, unsigned int nSide) {
    assert(static_cast<int>(nSide) >= 0 && static_cast<int>(nSide) < kSideCount);
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
        if (nBatch == kAdditiveBlendBatch) {
            pBatch->SetBlendMode(kBlendModeAdditive);
        }
    }

    for (int nBand = 0; nBand < kBandCount; ++nBand) {
        SetClearGaugeIcon(nBand, 1);
    }
    m_bBuilt = true;
}

/** @ghidraAddress 0x175dd4 */
void ClearGaugeLayer::Process(float flDelta) {
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

    for (ne::C_SPRITE_INSTANCING_2D *pBatch : m_apSprites) {
        pBatch->SetSpriteCount(0);
    }

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
    S_VECTOR2 quad[2];
    int nAtlasFrame;
    if (!IsPad()) {
        quad[0] = S_VECTOR2{86.0f, 20.0f};
        quad[1] = S_VECTOR2{168.0f, 40.0f};
        nAtlasFrame = 0x11c;
    } else if (m_nGaugeStyle == 0) {
        quad[0] = S_VECTOR2{231.0f, 17.0f};
        quad[1] = S_VECTOR2{462.0f, 34.0f};
        nAtlasFrame = 0x99;
    } else {
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
    S_VECTOR2 anchor;
    float flHeight;
    float flWidthBase;
    int nAtlasFrame;
    if (!IsPad()) {
        anchor = S_VECTOR2{50.0f, -4.0f};
        flHeight = 4.0f;
        flWidthBase = 100.0f;
        nAtlasFrame = 0x11d;
    } else if (m_nGaugeStyle == 0) {
        anchor = S_VECTOR2{216.0f, 11.0f};
        flHeight = 22.0f;
        flWidthBase = 360.0f;
        nAtlasFrame = 0x9a;
    } else {
        anchor = S_VECTOR2{48.0f, -11.0f};
        flHeight = 4.0f;
        flWidthBase = 100.0f;
        nAtlasFrame = 0x9c;
    }

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
    float flAnchorX = (pAnchorX != nullptr) ? *pAnchorX : glyph.flAnchorX;
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

    const int nLabelVariant = bHighValue ? 1 : 0;
    const bool bIsPad = IsPad();
    const GaugeGlyphDesc &separator =
        (bIsPad ? g_aGaugeLabelSeparatorPad : g_aGaugeLabelSeparatorPhone)[nLabelVariant];
    const GaugeGlyphDesc &percent =
        (bIsPad ? g_aGaugeLabelPercentPad : g_aGaugeLabelPercentPhone)[nLabelVariant];
    EmitGlyph(separator, kSeparatorBatch, nSide, nAlpha, nullptr);
    EmitGlyph(percent, kPercentBatch, nSide, nAlpha, nullptr);

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

    S_VECTOR2 position{};
    float flRotation = 0.0f;
    if (!IsPad()) {
        position.x = kPhoneGaugeX;
        const int nBandY = (nBottomBand != 0) ? kPhoneBandBottomY : kPhoneBandTopY;
        position.y = static_cast<float>(nBandY - g_nPlayfieldCentreSplit);
    } else if (nBottomBand != 0) {
        if (m_nGaugeStyle == 0) {
            position.x = 0.0f;
            position.y = static_cast<float>(g_nGaugeAltBottomBaseY - g_nPlayfieldCentreSplit);
        } else {
            position.x = kPadGaugeX;
            position.y = static_cast<float>(g_nGaugeBottomBaseY - g_nPlayfieldCentreSplit);
        }
    } else if (m_nGaugeStyle == 0) {
        position.x = 0.0f;
        position.y = static_cast<float>(g_nGaugeAltTopBaseY - g_nPlayfieldCentreSplit);
        if (m_nTwoSideEnabled == 1) {
            flRotation = static_cast<float>(M_PI);
        }
    } else {
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
        g_pClearGaugeLayer = new ClearGaugeLayer();
    }
    return g_pClearGaugeLayer;
}
