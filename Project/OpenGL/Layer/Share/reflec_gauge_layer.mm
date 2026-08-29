#include "reflec_gauge_layer.h"

#include <algorithm>
#include <cassert>
#include <cmath>

#include "bg_layer.h"
#include "engineglobals.h"
#include "gamesystem.h"
#include "neRender.h"
#include "neSpriteInstancing.h"
#include "neTexture.h"
#include "sprite_uv_table.h"

static ReflecGaugeLayer *g_pReflecGaugeLayer = nullptr; // @ghidraAddress 0x3df2c8

namespace {

// @ghidraAddress 0x3ceaa8
constexpr const char *kTextureName = "00_texture/gm_parts2";

// @ghidraAddress 0x30fc58
constexpr int kGroupBatch[] = {0, 1, 2, 1, 2, 3};

// @ghidraAddress 0x30fc70
constexpr int kGroupPartCount[] = {2, 5, 5, 5, 5, 2};

constexpr int kVertexFlagBatch = 2;
constexpr int kVertexFlagMode = 1;

// @ghidraAddress 0x2ec6b0
constexpr float kGaugeQuantizeScale = 100.0f;
constexpr float kGaugeMax = 5.0f;

constexpr float kGaugeChallengeValue = 5.0f;

// @ghidraAddress 0x2fd008 and 0x2ee910
constexpr float kBrightnessScale = 0.7f;
constexpr float kBrightnessBias = 0.3f;

constexpr unsigned int kColorMax = 255;

// @ghidraAddress 0x18b0bc
constexpr unsigned int kBaseBatch = 0;

constexpr unsigned int kValueBatch = 1;

constexpr unsigned int kLabelBatch = 2;

constexpr unsigned int kIconBatch = 3;

// @ghidraAddress 0x30fcb0
constexpr float kPortraitGaugeX = 190.0f;
constexpr float kLandscapeGaugeX = 200.0f;
constexpr float kLandscapeAltGaugeX = 0.0f;
constexpr int kFieldHalfSpan = 0x200;
constexpr int kPortraitBandBaseTop = 0x1d6;
constexpr int kPortraitBandBaseBottom = 0x22a;

// @ghidraAddress 0x30fc88 default, 0x30fc9c alternate, 0x30fcb0 portrait
constexpr ReflecGaugeLayer::GaugeSpriteDescriptor kBaseSpriteDefault = {
    {80.0f, 20.0f}, {160.0f, 40.0f}, 0x88};
constexpr ReflecGaugeLayer::GaugeSpriteDescriptor kBaseSpriteAlt = {
    {178.0f, 19.0f}, {356.0f, 37.0f}, 0x83};
constexpr ReflecGaugeLayer::GaugeSpriteDescriptor kBaseSpritePortrait = {
    {84.0f, 20.0f}, {168.0f, 40.0f}, 0x113};

// @ghidraAddress 0x30fdf4
struct GaugeLabelSide {
    float flAnchorY = {};
    float flSizeX = {};
    float flSizeY = {};
    int nAtlasFrame = {};
};
constexpr GaugeLabelSide kLabelSideRecord[ReflecGaugeLayer::kSideCount] = {
    {17.0f, 76.0f, 28.0f, 0x85},
    {17.0f, 76.0f, 28.0f, 0x87},
};

// @ghidraAddress 0x30fe18
constexpr float kLabelAnchorX[] = {173.0f, 106.0f, 39.0f, -28.0f, -95.0f};

const ReflecGaugeLayer::GaugeSpriteDescriptor g_aGaugeIconPortrait[] = {
    {{54.0f, 1.0f}, {10.0f, 14.0f}, 0x89},
    {{54.0f, 1.0f}, {10.0f, 14.0f}, 0x8a},
    {{54.0f, 1.0f}, {10.0f, 14.0f}, 0x8b},
    {{54.0f, 1.0f}, {10.0f, 14.0f}, 0x8c},
    {{54.0f, 1.0f}, {10.0f, 14.0f}, 0x8d},
    {{58.0f, 1.0f}, {17.0f, 14.0f}, 0x8e},
}; // @ghidraAddress 0x30fe2c

const ReflecGaugeLayer::GaugeSpriteDescriptor g_aGaugeIconLandscape[] = {
    {{65.0f, 6.0f}, {10.0f, 14.0f}, 0x116},
    {{65.0f, 6.0f}, {10.0f, 14.0f}, 0x117},
    {{65.0f, 6.0f}, {10.0f, 14.0f}, 0x118},
    {{65.0f, 6.0f}, {10.0f, 14.0f}, 0x119},
    {{65.0f, 6.0f}, {10.0f, 14.0f}, 0x11a},
    {{69.0f, 6.0f}, {17.0f, 14.0f}, 0x11b},
}; // @ghidraAddress 0x30fea4

constexpr int kPortraitValueRowStride = 5;

const ReflecGaugeLayer::GaugeSpriteDescriptor g_aGaugeValueLandscape[] = {
    {{50.0f, 10.0f}, {120.0f, 20.0f}, 0x114},
    {{50.0f, 10.0f}, {120.0f, 20.0f}, 0x115},
}; // @ghidraAddress 0x30fdc8

const ReflecGaugeLayer::GaugeSpriteDescriptor g_aGaugeValuePortrait[] = {
    {{39.0f, 5.0f}, {100.0f, 20.0f}, 0x8f},
    {{39.0f, 5.0f}, {100.0f, 20.0f}, 0x90},
    {{39.0f, 5.0f}, {100.0f, 20.0f}, 0x91},
    {{39.0f, 5.0f}, {100.0f, 20.0f}, 0x92},
    {{39.0f, 5.0f}, {100.0f, 20.0f}, 0x93},
    {{39.0f, 5.0f}, {100.0f, 20.0f}, 0x94},
    {{39.0f, 5.0f}, {100.0f, 20.0f}, 0x95},
    {{39.0f, 5.0f}, {100.0f, 20.0f}, 0x96},
    {{39.0f, 5.0f}, {100.0f, 20.0f}, 0x97},
    {{39.0f, 5.0f}, {100.0f, 20.0f}, 0x98},
}; // @ghidraAddress 0x30fcc4

const ReflecGaugeLayer::GaugeSpriteDescriptor g_aGaugeValuePortraitAlt[] = {
    {{0.0f, 9.0f}, {60.0f, 12.0f}, 0x84},
    {{0.0f, 9.0f}, {60.0f, 12.0f}, 0x86},
}; // @ghidraAddress 0x30fd8c

// @ghidraAddress 0x30fdb4
constexpr float kGaugeValueDigitX[] = {164.0f, 97.0f, 30.0f, -37.0f, -104.0f};

} // namespace

/** @ghidraAddress 0x18a7d0 */
ReflecGaugeLayer::ReflecGaugeLayer() {
    m_aScales[0] = 1.0f;
    m_aScales[1] = 1.0f;
    // @ghidraAddress 0x18a804
    m_nGaugeStyle = 1;

    for (int i = 0; i < kPartGroupCount; ++i) {
        const int nBatch = kGroupBatch[i];
        m_aPartBaseIndex[i] = m_aBatchCapacity[nBatch];
        m_aBatchCapacity[nBatch] += kGroupPartCount[i];
    }
}

/** @ghidraAddress 0x18a88c */
ReflecGaugeLayer *ReflecGaugeLayer::shared() {
    if (g_pReflecGaugeLayer == nullptr) {
        g_pReflecGaugeLayer = new ReflecGaugeLayer();
    }
    return g_pReflecGaugeLayer;
}

/** @ghidraAddress 0x18a8dc */
void ReflecGaugeLayer::CreateGaugeSliderSprites() {
    if (m_bBuilt) {
        return;
    }

    m_pTexture = ne::C_TEXTURE::FindOrLoadCached(kTextureName);

    for (int i = 0; i < kBatchCount; ++i) {
        ne::C_SPRITE_INSTANCING_2D *pSprite =
            ne::CreateWorldSpriteBatch(static_cast<unsigned int>(m_aBatchCapacity[i]));
        m_apSprites[i] = pSprite;
        BgLayer *pBackgroundLayer = BgLayer::GetBackgroundLayer();
        ne::C_RENDER *pParent = pBackgroundLayer->GetBackgroundRenderObject();
        pParent->AttachChild(pSprite);
        pSprite->SetVisible(true);
        pSprite->SetRefCountedMember(m_pTexture);
        pSprite->SetSpriteCount(0);
        if (i == kVertexFlagBatch) {
            pSprite->SetBlendMode(kVertexFlagMode);
        }
    }

    m_bBuilt = true;
}

/** @ghidraAddress 0x18ab98 */
float ReflecGaugeLayer::GetValueBySide(unsigned int nSide) const {
    assert(static_cast<int>(nSide) >= 0 && nSide < kSideCount);
    return m_aSides[nSide].flValue;
}

/** @ghidraAddress 0x18aa68 */
void ReflecGaugeLayer::SetValueBySide(float flValue, unsigned int nSide) {
    assert(static_cast<int>(nSide) >= 0 && nSide < kSideCount);
    // The full-just-reflec flag pins the gauge to the maximum, it does not exempt it.
    float flQuantized = std::round(flValue * kGaugeQuantizeScale) / kGaugeQuantizeScale;
    if (flQuantized <= 0.0f) {
        flQuantized = 0.0f;
    }
    // Fetched unconditionally ahead of the comparison, as the binary does.
    // @ghidraAddress 0x18aaa8
    const bool bFullJustReflec = GameSystem::GetGameSystem()->GetFullJustReflec();
    if (flQuantized > kGaugeMax || bFullJustReflec) {
        flQuantized = kGaugeMax;
    }
    m_aSides[nSide].flValue = flQuantized;
}

/** @ghidraAddress 0x18ab18 */
float ReflecGaugeLayer::GetValue(int nColor) const {
    assert(nColor >= 0 && nColor < kSideCount);
    const unsigned int nSide = GameSystem::GetGameSystem()->GetPlayColor() == nColor ? 1 : 0;
    return GetValueBySide(nSide);
}

/** @ghidraAddress 0x18ac38 */
float ReflecGaugeLayer::GetAnotherValue(int nColor) const {
    assert(nColor >= 0 && nColor < kSideCount);
    const unsigned int nSide = GameSystem::GetGameSystem()->GetPlayColor() != nColor ? 1 : 0;
    return GetValueBySide(nSide);
}

/** @ghidraAddress 0x18a9d8 */
void ReflecGaugeLayer::SetValue(float flValue, int nColor) {
    assert(nColor >= 0 && nColor < kSideCount);
    const unsigned int nSide = GameSystem::GetGameSystem()->GetPlayColor() == nColor ? 1 : 0;
    SetValueBySide(flValue, nSide);
}

/** @ghidraAddress 0x18abfc */
void ReflecGaugeLayer::AddReflecGaugeValue(float flDelta, ReflecGaugeLayer *pGauge, int nColor) {
    pGauge->SetValue(pGauge->GetValue(nColor) + flDelta, nColor);
}

/** @ghidraAddress 0x18acb8 */
void ReflecGaugeLayer::SubReflecGaugeValue(float flDelta, ReflecGaugeLayer *pGauge, int nPlayer) {
    const unsigned int nSide = GameSystem::GetGameSystem()->GetPlayColor() != nPlayer ? 1 : 0;
    pGauge->SetValueBySide(pGauge->GetValueBySide(nSide) - flDelta, nSide);
}

/** @ghidraAddress 0x18ad0c */
void ReflecGaugeLayer::SetGaugeDisplayBrightness(float flValue) {
    m_flDisplayBrightness = flValue * kBrightnessScale + kBrightnessBias;
}

/** @ghidraAddress 0x18ad2c */
void ReflecGaugeLayer::SetGaugeStyle(int nStyle) {
    m_nGaugeStyle = nStyle;
}

/** @ghidraAddress 0x18ad34 */
void ReflecGaugeLayer::SetMirrorSide(int nSide) {
    m_nMirrorSide = nSide;
}

/** @ghidraAddress 0x18ad3c */
void ReflecGaugeLayer::StartFadeIn(float flDuration) {
    m_fadeChannel.SetStart(m_fadeChannel.GetCurrent());
    m_fadeChannel.SetEnd(1.0f);
    m_fadeChannel.SetDuration(flDuration);
    m_fadeChannel.SetElapsed(0.0f);
    if (flDuration <= 0.0f) {
        m_fadeChannel.SetCurrent(1.0f);
        m_bFadeDone = true;
    }
}

/** @ghidraAddress 0x18ad6c */
void ReflecGaugeLayer::StartFadeOut(float flDuration) {
    m_fadeChannel.SetStart(m_fadeChannel.GetCurrent());
    m_fadeChannel.SetEnd(0.0f);
    m_fadeChannel.SetDuration(flDuration);
    m_fadeChannel.SetElapsed(0.0f);
    if (flDuration <= 0.0f) {
        m_fadeChannel.SetCurrent(0.0f);
        m_bFadeDone = true;
    }
}

/** @ghidraAddress 0x18a988 */
void ReflecGaugeLayer::ResetSideGauges() {
    const float flReset =
        GameSystem::GetGameSystem()->GetFullJustReflec() ? kGaugeChallengeValue : 0.0f;
    for (SideGauge &side : m_aSides) {
        side = SideGauge{};
        side.flValue = flReset;
    }
}

/** @ghidraAddress 0x18b380 */
void ReflecGaugeLayer::EmitGaugeSprite(const GaugeSpriteDescriptor &descriptor,
                                       unsigned int nBatch,
                                       unsigned int nSide,
                                       int nAlpha,
                                       const S_VECTOR2 &uvOrigin,
                                       const S_VECTOR2 &uvSize) {
    ne::C_SPRITE_INSTANCING_2D *pBatch = m_apSprites[nBatch];
    const int nIndex = pBatch->GetSpriteCount();
    if (nIndex >= static_cast<int>(pBatch->GetCapacity())) {
        return;
    }

    S_VECTOR2 position{};
    float flRotation = 0.0f;
    // C's truncating signed division is what the binary's `cinc w9,w9,lt` + `asr #1` pair
    // implements; applying the bias as well would round twice.
    const int nHalfHeight = g_nPlayfieldFullHeightY / 2;
    if (!IsPad()) {
        const float aBandY[kSideCount] = {
            static_cast<float>(kPortraitBandBaseTop - g_nPlayfieldCentreSplit),
            static_cast<float>(kPortraitBandBaseBottom - g_nPlayfieldCentreSplit),
        };
        position = S_VECTOR2{kPortraitGaugeX, aBandY[nSide]};
    } else if (m_nGaugeStyle == 0) {
        const float aBandY[kSideCount] = {
            static_cast<float>(g_nGaugeTopBaseY + nHalfHeight - kFieldHalfSpan),
            static_cast<float>(g_nGaugeBottomBaseY - nHalfHeight - kFieldHalfSpan),
        };
        position = S_VECTOR2{kLandscapeGaugeX, aBandY[nSide]};
        if (nSide == 0 && m_nMirrorSide == 1) {
            position.x = -position.x;
            flRotation = static_cast<float>(M_PI);
        }
    } else {
        const float aBandY[kSideCount] = {
            static_cast<float>(g_nGaugeAltTopBaseY + nHalfHeight - kFieldHalfSpan),
            static_cast<float>(g_nGaugeAltBottomBaseY - nHalfHeight - kFieldHalfSpan),
        };
        position = S_VECTOR2{kLandscapeAltGaugeX, aBandY[nSide]};
        flRotation = static_cast<float>(M_PI);
        if (m_nMirrorSide != 1 || nSide != 0) {
            flRotation = 0.0f;
        }
    }

    pBatch->SetSpritePosition(nIndex, position);
    pBatch->SetSpriteAnchor(nIndex, descriptor.anchor);
    pBatch->SetSpriteSize(nIndex, descriptor.size);
    pBatch->SetSpriteUvOrigin(nIndex, uvOrigin);
    pBatch->SetSpriteUvSize(nIndex, uvSize);
    pBatch->SetSpriteRotation(nIndex, flRotation);
    pBatch->SetSpriteScale(nIndex, 1.0f, 1.0f);
    pBatch->SetSpriteColor(
        nIndex, kColorMax, kColorMax, kColorMax, static_cast<unsigned int>(nAlpha));
    pBatch->SetSpriteCount(nIndex + 1);
}

/** @ghidraAddress 0x18b034 */
void ReflecGaugeLayer::EmitBaseSprite(unsigned int nSide, int nAlpha) {
    GaugeSpriteDescriptor descriptor;
    if (!IsPad()) {
        descriptor = kBaseSpritePortrait;
    } else if (m_nGaugeStyle == 0) {
        descriptor = kBaseSpriteDefault;
    } else {
        descriptor = kBaseSpriteAlt;
    }
    const SpriteUvEntry &uv = g_aSpriteUvTable[descriptor.nAtlasFrame];
    EmitGaugeSprite(descriptor,
                    kBaseBatch,
                    nSide,
                    nAlpha,
                    S_VECTOR2{uv.flOriginU, uv.flOriginV},
                    S_VECTOR2{uv.flSizeU, uv.flSizeV});
}

/** @ghidraAddress 0x18b2cc */
void ReflecGaugeLayer::EmitLabelSprite(unsigned int nSide, int nLabelIndex, int nAlpha) {
    unsigned int nColor = static_cast<unsigned int>(GameSystem::GetGameSystem()->GetPlayColor());
    if (nSide != 1) {
        nColor = (nColor == 0) ? 1 : 0;
    }

    const GaugeLabelSide &side = kLabelSideRecord[nColor];
    GaugeSpriteDescriptor descriptor;
    descriptor.anchor = S_VECTOR2{kLabelAnchorX[nLabelIndex], side.flAnchorY};
    descriptor.size = S_VECTOR2{side.flSizeX, side.flSizeY};
    descriptor.nAtlasFrame = side.nAtlasFrame;
    const SpriteUvEntry &uv = g_aSpriteUvTable[descriptor.nAtlasFrame];
    EmitGaugeSprite(descriptor,
                    kLabelBatch,
                    nSide,
                    nAlpha,
                    S_VECTOR2{uv.flOriginU, uv.flOriginV},
                    S_VECTOR2{uv.flSizeU, uv.flSizeV});
}

/** @ghidraAddress 0x18b0dc */
void ReflecGaugeLayer::EmitIconSprite(unsigned int nSide, int nIconIndex, int nAlpha) {
    const GaugeSpriteDescriptor &descriptor =
        IsPad() ? g_aGaugeIconPortrait[nIconIndex] : g_aGaugeIconLandscape[nIconIndex];
    const SpriteUvEntry &uv = g_aSpriteUvTable[descriptor.nAtlasFrame];
    EmitGaugeSprite(descriptor,
                    kIconBatch,
                    nSide,
                    nAlpha,
                    S_VECTOR2{uv.flOriginU, uv.flOriginV},
                    S_VECTOR2{uv.flSizeU, uv.flSizeV});
}

/** @ghidraAddress 0x18b174 */
void ReflecGaugeLayer::EmitGaugeValueSprite(float flScale,
                                            unsigned int nSide,
                                            int nDigit,
                                            int nAlpha) {
    unsigned int nColorSide =
        static_cast<unsigned int>(GameSystem::GetGameSystem()->GetPlayColor());
    if (nSide != 1) {
        nColorSide = (nColorSide == 0) ? 1 : 0;
    }

    const GaugeSpriteDescriptor *pRecord = nullptr;
    float flAnchorX = 0.0f;
    if (!IsPad()) {
        pRecord = &g_aGaugeValueLandscape[nColorSide];
        flAnchorX = pRecord->anchor.x;
    } else if (m_nGaugeStyle == 0) {
        pRecord = &g_aGaugeValuePortrait[nColorSide * kPortraitValueRowStride + nDigit];
        flAnchorX = pRecord->anchor.x;
    } else {
        pRecord = &g_aGaugeValuePortraitAlt[nColorSide];
        flAnchorX = kGaugeValueDigitX[nDigit];
    }

    const SpriteUvEntry &uv = g_aSpriteUvTable[pRecord->nAtlasFrame];
    GaugeSpriteDescriptor descriptor;
    descriptor.anchor = S_VECTOR2{flAnchorX, pRecord->anchor.y};
    descriptor.size = S_VECTOR2{pRecord->size.x * flScale, pRecord->size.y};
    descriptor.nAtlasFrame = pRecord->nAtlasFrame;
    EmitGaugeSprite(descriptor,
                    kValueBatch,
                    nSide,
                    nAlpha,
                    S_VECTOR2{uv.flOriginU, uv.flOriginV},
                    S_VECTOR2{uv.flSizeU * flScale, uv.flSizeV});
}

namespace {

// @ghidraAddress 0x30fc50 rising, 0x30fc54 falling
constexpr float kDisplayRiseRate = 0.0012f;
constexpr float kDisplayFallRate = 0.0060000005178153515f;

// @ghidraAddress 0x2ee878
constexpr double kCellFillThreshold = 0.001;
constexpr int kMaxCells = 5;
constexpr int kLabelGaugeMode = 1;

} // namespace

/** @ghidraAddress 0x18ad94 */
void ReflecGaugeLayer::UpdateGaugeBar(float flDelta) {
    // The fade channel's floats are repurposed here as the fill tween.
    const float flTarget = m_fadeChannel.GetDuration();
    float flRatio;
    if (flTarget > m_fadeChannel.GetElapsed()) {
        float flCurrent = m_fadeChannel.GetElapsed() + flDelta;
        if (flCurrent > flTarget) {
            flCurrent = flTarget;
        }
        m_fadeChannel.SetElapsed(flCurrent);
        const float flProgress = flTarget == 0.0f ? 1.0f : flCurrent / flTarget;
        const float flFill = m_fadeChannel.GetStart() +
                             flProgress * (m_fadeChannel.GetEnd() - m_fadeChannel.GetStart());
        m_fadeChannel.SetCurrent(flFill);
        m_bFadeDone = true;
        flRatio = flFill;
    } else {
        flRatio = m_fadeChannel.GetCurrent();
    }

    const float flLabelAlpha = flRatio * m_flDisplayBrightness * kColorMax;

    for (int i = 0; i < kBatchCount; ++i) {
        m_apSprites[i]->SetSpriteCount(0);
    }

    const float flRise = flDelta * kDisplayRiseRate;
    const float flFall = flDelta * kDisplayFallRate;
    for (unsigned int nHalf = 0; nHalf < kSideCount; ++nHalf) {
        const int nColor = static_cast<int>(flRatio * kColorMax * m_aScales[nHalf]);
        EmitBaseSprite(nHalf, nColor);

        SideGauge &side = m_aSides[nHalf];
        if (side.flDisplayValue < side.flValue) {
            side.flDisplayValue += flRise;
            if (side.flDisplayValue > side.flValue) {
                side.flDisplayValue = side.flValue;
            }
        } else {
            side.flDisplayValue -= flFall;
            if (side.flDisplayValue < side.flValue) {
                side.flDisplayValue = side.flValue;
            }
        }
        const int nWholeCells = static_cast<int>(side.flDisplayValue);

        if (!IsPad()) {
            const float flFrac = nWholeCells == kMaxCells ?
                                     1.0f :
                                     side.flDisplayValue - static_cast<float>(nWholeCells);
            EmitIconSprite(nHalf, nWholeCells, nColor);
            EmitGaugeValueSprite(flFrac, nHalf, nWholeCells, nColor);
            continue;
        }

        if (m_nGaugeStyle == 0) {
            EmitIconSprite(nHalf, nWholeCells, nColor);
        }
        const float flFrac = side.flDisplayValue - static_cast<float>(nWholeCells);
        const int nExtra = static_cast<double>(flFrac) > kCellFillThreshold ? 1 : 0;
        const int nCellCount = std::min(nWholeCells + nExtra, kMaxCells);
        for (int nCell = 0; nCell < nCellCount; ++nCell) {
            const float flCellFill =
                nCell >= nCellCount - 1 ? side.flDisplayValue - static_cast<float>(nCell) : 1.0f;
            EmitGaugeValueSprite(flCellFill, nHalf, nCell, nColor);
            if (flCellFill >= 1.0f && m_nGaugeStyle == kLabelGaugeMode) {
                EmitLabelSprite(nHalf, nCell, static_cast<int>(flLabelAlpha));
            }
        }
    }
}
