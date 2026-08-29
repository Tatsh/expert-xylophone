#include "play_color_layer.h"

#include "bg_layer.h"
#include "engineglobals.h"
#include "gamesystem.h"
#include "neDebugLog.h"
#include "neRender.h"
#include "neSpriteInstancing.h"
#include "neTexture.h"
#import "s_vector2.h"

static PlayColorLayer *g_pPlayColorLayer = nullptr; // @ghidraAddress 0x3dc5a0

namespace {

// @ghidraAddress 0x3ceaa0
constexpr const char *kTextureName = "00_texture/gm_parts1";

// @ghidraAddress 0x2fe8a0
constexpr int kGroupBatch[] = {0, 0, 0, 0, 0, 0, 0, 0, 1, 1};

// @ghidraAddress 0x2fe8c8
constexpr int kGroupPartCount[] = {6, 6, 6, 6, 3, 3, 6, 6, 3, 3};

// @ghidraAddress 0x2fe900 and @ghidraAddress 0x2ef668
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

constexpr int kVertexFlagMode = 1;

constexpr float kGaugeFillBrightnessRange = 0.7f;
constexpr float kGaugeFillBrightnessBase = 0.3f;

// @ghidraAddress 0x2f8540
constexpr float kPulseClockPeriod = 1000.0f;
// @ghidraAddress 0x2f8544
constexpr float kPulseClockWrap = -1000.0f;

// @ghidraAddress 0x2fe898
constexpr double kGlowPhaseTurn = 6.2831853071795862;
// @ghidraAddress 0x2fe894
constexpr float kBaseFillRotation = 3.14159274f;

// @ghidraAddress 0x2eed00
constexpr float kMaxAlpha = 255.0f;

// @ghidraAddress 0x2fe8f0
constexpr int kGaugeLaneCounts[] = {2, 2, 3, 3};

constexpr int kGaugeSideCount = 2;

constexpr unsigned int kPartOffsetFillA = 0;
constexpr unsigned int kPartOffsetFillB = 2;
constexpr unsigned int kPartOffsetFillC = 4;
constexpr unsigned int kPartOffsetHighlight = 6;
constexpr unsigned int kPartOffsetGlow = 8;

constexpr unsigned int kBatchBase = 0;
constexpr unsigned int kBatchGlow = 1;

} // namespace

/** @ghidraAddress 0x83460 */
PlayColorLayer::PlayColorLayer() {
    m_flGaugeBrightness = 1.0f;
    m_flScaleY = 1.0f;
    m_flScaleZ = 1.0f;

    for (int nGroup = 0; nGroup < kPartGroupCount; ++nGroup) {
        const int nBatch = kGroupBatch[nGroup];
        m_aPartBaseIndex[nGroup] = m_aBatchCapacity[nBatch];
        m_aBatchCapacity[nBatch] += kGroupPartCount[nGroup];
    }
}

/** @ghidraAddress 0x8350c */
PlayColorLayer *PlayColorLayer::shared() {
    if (g_pPlayColorLayer == nullptr) {
        g_pPlayColorLayer = new PlayColorLayer();
    }
    return g_pPlayColorLayer;
}

/** @ghidraAddress 0x8355c */
void PlayColorLayer::BuildGaugePartsSpriteBatches() {
    if (m_bBuilt) {
        return;
    }

    BgLayer *pBackgroundLayer = BgLayer::GetBackgroundLayer();
    ne::C_RENDER *pParent = pBackgroundLayer->GetBackgroundRenderObject();

    m_pTexture = ne::C_TEXTURE::FindOrLoadCached(kTextureName);

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

    for (int nGroup = 0; nGroup < kPartGroupCount; ++nGroup) {
        for (int nPart = 0; nPart < kGroupPartCount[nGroup]; ++nPart) {
            EmitGaugePartSprite(0.0f,
                                0.0f,
                                1.0f,
                                1.0f,
                                0.0f,
                                static_cast<unsigned int>(kGroupBatch[nGroup]),
                                static_cast<unsigned int>(nPart),
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
    pBatch->SetSpritePositionXY(nIndex, flPosX, flPosY);
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
    // The binary lazily copies the scale table into a function-local static once.
    static const float kGaugePosXScale[kGaugeLaneXCount] = {
        g_aGaugePartsScale[0], g_aGaugePartsScale[1], 0.0f};
    for (int nLane = 0; nLane < kGaugeLaneXCount; ++nLane) {
        m_aGaugePosX[nLane] =
            kGaugePosXScale[nLane] * GameSystem::GetGameSystem()->GetSheetInsetHalfX();
    }

    const float kGaugePosYScale[kGaugeLaneYCount] = {g_flPlayfieldFarLaneSlope,
                                                     g_flPlayfieldFarLaneSlopeNeg};
    for (int nLane = 0; nLane < kGaugeLaneYCount; ++nLane) {
        const float flY = GameSystem::GetGameSystem()->GetSheetInsetHalfY();
        m_aGaugePosY[nLane] = static_cast<float>(static_cast<int>(kGaugePosYScale[nLane] * flY));
    }
}

/** @ghidraAddress 0x839b8 */
void PlayColorLayer::Update(float flDeltaTime) {
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

    for (ne::C_SPRITE_INSTANCING_2D *pSprite : m_apSprites) {
        pSprite->SetSpriteCount(0);
    }

    const int nLaneCount = kGaugeLaneCounts[m_nPlayColorValue];
    for (int nSide = 0; nSide < kGaugeSideCount; ++nSide) {
        unsigned int nColor = GameSystem::GetGameSystem()->GetPlayColor();
        if (nSide != 1) {
            nColor = nColor == 0 ? 1u : 0u;
        }

        const float flFill = m_shrinkChannel.GetCurrent();
        const float flLayerScale = nSide == 0 ? m_flScaleY : m_flScaleZ;
        const float flRotation = nSide == 0 ? kBaseFillRotation : 0.0f;
        const float flGlowAlpha = flLayerScale * flFill * m_flGaugeBrightness * kMaxAlpha;
        const auto nAlpha = static_cast<unsigned int>(flFill * kMaxAlpha * flLayerScale);

        for (int nLane = 0; nLane < nLaneCount; ++nLane) {
            const float flX = m_aGaugePosX[nLane];
            const float flY = m_aGaugePosY[nSide];
            // Arming only once the targets have a real position keeps the capture on a frame that
            // contains the play field.
            NE_DBG(if (g_nDebugSnapshotFrame == 0 && flY != 0.0f) {
                g_nDebugSnapshotFrame = g_nDebugFrameCounter + 1;
            });
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
