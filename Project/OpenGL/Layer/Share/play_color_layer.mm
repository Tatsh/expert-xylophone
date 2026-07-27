#include "play_color_layer.h"

#include "bg_layer.h"
#include "engineglobals.h"
#include "gamesystem.h"
#include "neRender.h"
#include "neSpriteInstancing.h"
#include "neTexture.h"
#import "s_vector2.h"

// The process-wide play-colour layer, created lazily by shared().
static PlayColorLayer *g_pPlayColorLayer = nullptr; // @ghidraAddress 0x3dc5a0

namespace {

// The atlas the gauge parts draw from (@ghidraAddress 0x3ceaa0).
constexpr const char *kTextureName = "00_texture/gm_parts1";

// Which batch each part group draws into (@ghidraAddress 0x2fe8a0).
constexpr int kGroupBatch[] = {0, 0, 0, 0, 0, 0, 0, 0, 1, 1};

// How many sprites each part group emits (@ghidraAddress 0x2fe8c8).
constexpr int kGroupPartCount[] = {6, 6, 6, 6, 3, 3, 6, 6, 3, 3};

// One gauge part's source rect (anchor, size) and mapped UV rect (origin, size), combining the
// source-rect table (@ghidraAddress 0x2fe900) with the UV table it indexes (@ghidraAddress
// 0x2ef668).
struct GaugePart {
    float flAnchorX;
    float flAnchorY;
    float flSizeW;
    float flSizeH;
    float flUvOriginU;
    float flUvOriginV;
    float flUvSizeU;
    float flUvSizeV;
};
constexpr GaugePart kGaugeParts[] = {
    {32.0f, 32.0f, 64.0f, 64.0f, 0.00195f, 0.31055f, 0.09766f, 0.09766f},
    {32.0f, 32.0f, 64.0f, 64.0f, 0.00195f, 0.31055f, 0.09766f, 0.09766f},
    {25.0f, 20.0f, 50.0f, 50.0f, 0.20117f, 0.31055f, 0.07031f, 0.06641f},
    {25.0f, 20.0f, 50.0f, 50.0f, 0.27344f, 0.31055f, 0.07031f, 0.06641f},
    {31.0f, 9.0f, 62.0f, 18.0f, 0.20312f, 0.37891f, 0.01953f, 0.02734f},
    {31.0f, 9.0f, 62.0f, 18.0f, 0.22852f, 0.37891f, 0.01953f, 0.02734f},
    {32.0f, 32.0f, 64.0f, 64.0f, 0.10156f, 0.31055f, 0.09766f, 0.09766f},
    {32.0f, 32.0f, 64.0f, 64.0f, 0.10156f, 0.31055f, 0.09766f, 0.09766f},
    {31.0f, 31.0f, 62.0f, 62.0f, 0.89062f, 0.09961f, 0.06055f, 0.06055f},
    {31.0f, 31.0f, 62.0f, 62.0f, 0.89062f, 0.09961f, 0.06055f, 0.06055f},
};

// The additive-style vertex flag the gauge batches set.
constexpr int kVertexFlagMode = 1;

// The gauge fill brightness maps a normalised level onto [kGaugeFillBrightnessBase,
// kGaugeFillBrightnessBase + kGaugeFillBrightnessRange] = [0.3, 1.0].
constexpr float kGaugeFillBrightnessRange = 0.7f;
constexpr float kGaugeFillBrightnessBase = 0.3f;

// The two far-lane slopes the sheet-inset half-height is scaled by for the gauge Y positions.
// @ghidraAddress 0x3ce96c and 0x3ce970
constexpr float g_flPlayfieldFarLaneSlopeNeg = -0.35354489f;
constexpr float g_flPlayfieldFarLaneSlope = 0.35354489f;

// The glow-pulse clock's wrap period, in milliseconds, and its two ends. @ghidraAddress 0x2f8540
// (period) and 0x2f8544 (the -1000 wrap subtrahend).
constexpr float kPulseClockPeriod = 1000.0f;
constexpr float kPulseClockWrap = -1000.0f;

// The glow phase spans a full 2*pi turn; the base fill rotation is pi. @ghidraAddress 0x2fe898
// (2*pi, a double) and 0x2fe894 (pi).
constexpr double kGlowPhaseTurn = 6.2831853071795862;
constexpr float kBaseFillRotation = 3.14159274f;

// The maximum sprite alpha the fill/glow intensities scale. @ghidraAddress 0x2eed00
constexpr float kMaxAlpha = 255.0f;

// The per-play-colour gauge lane counts. @ghidraAddress 0x2fe8f0
constexpr int kGaugeLaneCounts[] = {2, 2, 3, 3};

// The number of play sides the gauge draws for, and the five layered part sprites emitted per lane:
// three stacked base-fill parts, a highlight, and a glow.
constexpr int kGaugeSideCount = 2;

// The gauge part groups the five layers draw from (base fill, its two colour siblings, the
// highlight, and the glow), keyed off the side's colour index.
constexpr unsigned int kPartOffsetFillA = 0;
constexpr unsigned int kPartOffsetFillB = 2;
constexpr unsigned int kPartOffsetFillC = 4;
constexpr unsigned int kPartOffsetHighlight = 6;
constexpr unsigned int kPartOffsetGlow = 8;

// The batch each layer emits into: the first four into batch 0, the glow into batch 1.
constexpr unsigned int kBatchBase = 0;
constexpr unsigned int kBatchGlow = 1;

} // namespace

/** @ghidraAddress 0x83460 */
PlayColorLayer::PlayColorLayer() {
    // Seed the gauge brightness to full and the transform block's scales to 1 (offsets
    // +0x90/+0x98/+0x9c in the binary).
    m_flGaugeBrightness = 1.0f;
    m_flScaleY = 1.0f;
    m_flScaleZ = 1.0f;

    // Assign each part group a non-overlapping index range within its batch, accumulating each
    // batch's total capacity as it goes.
    for (int nGroup = 0; nGroup < kPartGroupCount; ++nGroup) {
        const int nBatch = kGroupBatch[nGroup];
        m_aPartBaseIndex[nGroup] = m_aBatchCapacity[nBatch];
        m_aBatchCapacity[nBatch] += kGroupPartCount[nGroup];
    }
}

/** @ghidraAddress 0x8350c */
PlayColorLayer *PlayColorLayer::shared() {
    if (g_pPlayColorLayer == nullptr) {
        // The binary allocates the raw 0xa0-byte object and runs the constructor.
        g_pPlayColorLayer = new PlayColorLayer();
    }
    return g_pPlayColorLayer;
}

/** @ghidraAddress 0x8355c */
void PlayColorLayer::BuildGaugePartsSpriteBatches() {
    if (m_bBuilt) {
        return;
    }

    // The batches hang beneath the shared background layer's render object rather than the global
    // scene root.
    BgLayer *pBackgroundLayer = BgLayer::GetBackgroundLayer();
    ne::C_RENDER *pParent = pBackgroundLayer->GetBackgroundRenderObject();

    m_pTexture = ne::C_TEXTURE::FindOrLoadCached(kTextureName);

    // Build the two batches, each sized to hold all the part groups routed to it, and set the
    // additive-style vertex flag on each.
    for (int nBatch = 0; nBatch < kBatchCount; ++nBatch) {
        ne::C_SPRITE_INSTANCING_2D *pSprite =
            ne::CreateWorldSpriteBatch(static_cast<unsigned int>(m_aBatchCapacity[nBatch]));
        m_apSprites[nBatch] = pSprite;
        pParent->AttachChild(pSprite);
        pSprite->SetVisible(true);
        pSprite->SetRefCountedMember(m_pTexture);
        pSprite->SetSpriteCount(m_aBatchCapacity[nBatch]);
        pSprite->SetBlendMode(kVertexFlagMode);
    }

    // Emit each part group's sprites into its batch.
    for (int nGroup = 0; nGroup < kPartGroupCount; ++nGroup) {
        for (int nPart = 0; nPart < kGroupPartCount[nGroup]; ++nPart) {
            EmitGaugePartSprite(0.0f,
                                0.0f,
                                1.0f,
                                1.0f,
                                0.0f,
                                static_cast<unsigned int>(kGroupBatch[nGroup]),
                                static_cast<unsigned int>(nGroup),
                                0);
        }
    }

    m_bBuilt = true;
}

/** @ghidraAddress 0x83684 */
void PlayColorLayer::EmitGaugePartSprite(float flPosX,
                                         float flPosY,
                                         float flScaleX,
                                         float flScaleY,
                                         float flRotation,
                                         unsigned int nBatchIndex,
                                         unsigned int nPartIndex,
                                         unsigned int nAlpha) {
    if (nBatchIndex >= static_cast<unsigned int>(kBatchCount) ||
        nPartIndex >= static_cast<unsigned int>(kPartGroupCount)) {
        return;
    }
    ne::C_SPRITE_INSTANCING_2D *pBatch = m_apSprites[nBatchIndex];
    const int nIndex = pBatch->GetSpriteCount();
    if (nIndex >= static_cast<int>(pBatch->GetCapacity())) {
        return;
    }

    const GaugePart &part = kGaugeParts[nPartIndex];
    pBatch->SetSpritePosition(nIndex, S_VECTOR2{flPosX, flPosY});
    pBatch->SetSpriteAnchor(nIndex, S_VECTOR2{part.flAnchorX, part.flAnchorY});
    pBatch->SetSpriteSize(nIndex, S_VECTOR2{part.flSizeW, part.flSizeH});
    pBatch->SetSpriteUvOrigin(nIndex, S_VECTOR2{part.flUvOriginU, part.flUvOriginV});
    pBatch->SetSpriteUvSize(nIndex, S_VECTOR2{part.flUvSizeU, part.flUvSizeV});
    pBatch->SetSpriteScale(nIndex, flScaleX, flScaleY);
    pBatch->SetSpriteRotation(nIndex, flRotation);
    pBatch->SetSpriteColor(nIndex, 0xff, 0xff, 0xff, nAlpha);
    pBatch->SetSpriteCount(nIndex + 1);
}

/** @ghidraAddress 0x8394c */
void PlayColorLayer::StartShrinkAnimation(float flDuration) {
    m_flAnimFrom = 0.0f;
    m_shrinkChannel.SetStart(m_shrinkChannel.GetCurrent());
    m_shrinkChannel.SetEnd(0.0f);
    m_shrinkChannel.SetDuration(flDuration);
    m_shrinkChannel.SetElapsed(0.0f);
    // A non-positive duration snaps straight to empty and marks the colour dirty.
    if (flDuration <= 0.0f) {
        m_shrinkChannel.SetCurrent(0.0f);
        m_bGaugeColorDirty = true;
    }
}

/** @ghidraAddress 0x83918 */
void PlayColorLayer::StartGaugeGrowAnimation(float flDuration, float flFromValue) {
    m_flAnimFrom = flFromValue;
    m_shrinkChannel.SetStart(m_shrinkChannel.GetCurrent());
    m_shrinkChannel.SetEnd(1.0f);
    m_shrinkChannel.SetDuration(flDuration);
    m_shrinkChannel.SetElapsed(0.0f);
    // A non-positive duration snaps straight to full and marks the colour dirty.
    if (flDuration <= 0.0f) {
        m_shrinkChannel.SetCurrent(1.0f);
        m_bGaugeColorDirty = true;
    }
}

/** @ghidraAddress 0x83978 */
void PlayColorLayer::SetGaugeFillLevel(float flLevel) {
    const float flClamped = flLevel < 0.0f ? 0.0f : (flLevel > 1.0f ? 1.0f : flLevel);
    m_flGaugeBrightness = flClamped * kGaugeFillBrightnessRange + kGaugeFillBrightnessBase;
    m_bGaugeColorDirty = true;
}

/** @ghidraAddress 0x83c90 */
void PlayColorLayer::SetPlayColorValue(int nValue) {
    m_nPlayColorValue = nValue;
}

/** @ghidraAddress 0x837e8 */
void PlayColorLayer::SyncGaugeValuesFromGameSystem() {
    // The three X positions scale the sheet-inset half-width by the two per-side gauge-parts scales
    // (the third scale is zero). The binary lazily copies the scale table into a local once.
    static const float kGaugePosXScale[kGaugeLaneXCount] = {
        g_aGaugePartsScale[0], g_aGaugePartsScale[1], 0.0f};
    for (int nLane = 0; nLane < kGaugeLaneXCount; ++nLane) {
        m_aGaugePosX[nLane] =
            kGaugePosXScale[nLane] * GameSystem::GetGameSystem()->GetSheetInsetHalfX();
    }

    // The two Y positions scale the sheet-inset half-height by the far-lane slopes, truncated.
    const float kGaugePosYScale[kGaugeLaneYCount] = {g_flPlayfieldFarLaneSlope,
                                                     g_flPlayfieldFarLaneSlopeNeg};
    for (int nLane = 0; nLane < kGaugeLaneYCount; ++nLane) {
        const float flY = GameSystem::GetGameSystem()->GetSheetInsetHalfY();
        m_aGaugePosY[nLane] = static_cast<float>(static_cast<int>(kGaugePosYScale[nLane] * flY));
    }
}

/** @ghidraAddress 0x839b8 */
void PlayColorLayer::Update(float flDeltaTime) {
    // Advance the fill tween toward its end value, marking the colour dirty once it moves.
    const float flDuration = m_shrinkChannel.GetDuration();
    const float flEndElapsed = flDuration + m_flAnimFrom;
    if (m_shrinkChannel.GetElapsed() < flEndElapsed) {
        float flElapsed = m_shrinkChannel.GetElapsed() + flDeltaTime;
        if (flElapsed > flEndElapsed) {
            flElapsed = flEndElapsed;
        }
        m_shrinkChannel.SetElapsed(flElapsed);
        float flFraction = flDuration == 0.0f ? 1.0f : (flElapsed - m_flAnimFrom) / flDuration;
        if (flFraction <= 0.0f) {
            flFraction = 0.0f;
        }
        m_shrinkChannel.SetCurrent(m_shrinkChannel.GetStart() +
                                   flFraction *
                                       (m_shrinkChannel.GetEnd() - m_shrinkChannel.GetStart()));
        m_bGaugeColorDirty = true;
    }

    // Advance the glow-pulse clock, wrapping it at the period, and map it to the glow phase.
    float flClock = m_flPulseClock + flDeltaTime;
    if (flClock > kPulseClockPeriod) {
        flClock += kPulseClockWrap;
    }
    m_flPulseClock = flClock;
    float flPhase = flClock / kPulseClockPeriod;
    if (flPhase > 1.0f) {
        flPhase = 1.0f;
    } else if (flPhase < 0.0f) {
        flPhase = 0.0f;
    }
    m_flGlowPhase = static_cast<float>(static_cast<double>(flPhase) * kGlowPhaseTurn);

    const float flPartScale = GameSystem::GetGameSystem()->GetSheetRadiusScaled();

    // Reset both batches' sprite counts before re-emitting.
    for (ne::C_SPRITE_INSTANCING_2D *pSprite : m_apSprites) {
        pSprite->SetSpriteCount(0);
    }

    const int nLaneCount = kGaugeLaneCounts[m_nPlayColorValue];
    for (int nSide = 0; nSide < kGaugeSideCount; ++nSide) {
        // The first side uses the play colour; the other side its opposite.
        unsigned int nColor = GameSystem::GetGameSystem()->GetPlayColor();
        if (nSide != 1) {
            nColor = nColor == 0 ? 1u : 0u;
        }

        // Side 0 pulses its highlight rotation and glow; side 1 draws without rotation. Each side
        // scales its intensity by its own transform scale.
        const float flFill = m_shrinkChannel.GetCurrent();
        const float flLayerScale = nSide == 0 ? m_flScaleY : m_flScaleZ;
        const float flRotation = nSide == 0 ? kBaseFillRotation : 0.0f;
        const float flGlowAlpha = flLayerScale * flFill * m_flGaugeBrightness * kMaxAlpha;
        const auto nAlpha = static_cast<unsigned int>(flFill * kMaxAlpha * flLayerScale);

        for (int nLane = 0; nLane < nLaneCount; ++nLane) {
            const float flX = m_aGaugePosX[nLane];
            const float flY = m_aGaugePosY[nSide];
            EmitGaugePartSprite(flX,
                                flY,
                                flPartScale,
                                flPartScale,
                                flRotation,
                                kBatchBase,
                                nColor + kPartOffsetFillA,
                                nAlpha);
            EmitGaugePartSprite(flX,
                                flY,
                                flPartScale,
                                flPartScale,
                                flRotation,
                                kBatchBase,
                                nColor + kPartOffsetFillB,
                                nAlpha);
            EmitGaugePartSprite(flX,
                                flY,
                                flPartScale,
                                flPartScale,
                                flRotation,
                                kBatchBase,
                                nColor + kPartOffsetFillC,
                                nAlpha);
            EmitGaugePartSprite(flX,
                                flY,
                                flPartScale,
                                flPartScale,
                                flRotation,
                                kBatchBase,
                                nColor + kPartOffsetHighlight,
                                static_cast<unsigned int>(flGlowAlpha));
            EmitGaugePartSprite(flX,
                                flY,
                                flPartScale,
                                flPartScale,
                                flRotation + m_flGlowPhase,
                                kBatchGlow,
                                nColor + kPartOffsetGlow,
                                nAlpha);
        }
    }
}
