#include "slide_note_layer.h"

#include <cassert>
#include <cmath>

#include "bg_layer.h"
#include "gamesystem.h"
#include "neRender.h"
#include "neSpriteInstancing.h"
#include "neTexture.h"
#include "s_vector2.h"
#include "slide_note_sprite_table.h"
#include "sprite_uv_table.h"
#include "vectormath.h"

static SlideNoteLayer *g_pSlideNoteLayer = nullptr; // @ghidraAddress 0x3dc658

int g_nActiveSlideTrailCount = 0; // @ghidraAddress 0x3dc650

extern const SpriteUvEntry g_aScoreGaugeUvTable[]; // @ghidraAddress 0x2ef668

const SlideNoteSpriteType g_aSlideNoteSpriteTypes[kSlideNoteSpriteTypeCount] = {
    {0, 29.0f, 0.0f, 58.0f, 27.0f, 59},
    {0, 29.0f, 27.0f, 58.0f, 27.0f, 60},
    {1, 31.0f, 31.0f, 62.0f, 62.0f, 65},
    {1, 31.0f, 31.0f, 62.0f, 62.0f, 66},
    {1, 31.0f, 31.0f, 62.0f, 62.0f, 67},
    {1, 31.0f, 31.0f, 62.0f, 62.0f, 68},
    {1, 31.0f, 31.0f, 62.0f, 62.0f, 69},
    {1, 31.0f, 31.0f, 62.0f, 62.0f, 70},
    {1, 31.0f, 31.0f, 62.0f, 31.0f, 39},
    {1, 31.0f, 31.0f, 62.0f, 31.0f, 40},
    {2, 31.0f, 31.0f, 62.0f, 62.0f, 62},
    {2, 31.0f, 31.0f, 62.0f, 62.0f, 63},
    {2, 31.0f, 31.0f, 62.0f, 62.0f, 64},
    {2, 50.0f, 55.0f, 100.0f, 88.0f, 43},
    {2, 50.0f, 55.0f, 100.0f, 88.0f, 44},
    {0, 40.0f, 0.0f, 80.0f, 18.0f, 61},
};

namespace {
constexpr float kInvalidClock = -1.0f;

constexpr const char *kTrailTextureName = "00_texture/gm_parts1";
constexpr unsigned int kBatchCapacity = 0xf0;

constexpr int kBlendModeAdditive = 1;
constexpr int kTexParamWrapT = 1;
constexpr int kTexParamWrapS = 0;
constexpr int kTexWrapRepeat = 1;

// @ghidraAddress 0x2fe894
constexpr float kMirrorRotation = 3.1415927f;
} // namespace

/** @ghidraAddress 0x95a18 */
SlideNoteLayer::SlideNoteLayer() {
    m_bBuilt = false;
    m_flLastClock = kInvalidClock;
    g_nActiveSlideTrailCount = 0;
}

/** @ghidraAddress 0x95bc0 */
void SlideNoteLayer::Create(int nColor,
                            unsigned char nFlagA,
                            int nKind,
                            float flEndX,
                            float flEndY,
                            float flTargetX,
                            float flTargetY,
                            float flAlphaScale,
                            unsigned char nFlagB,
                            unsigned char nFlagC,
                            unsigned char nFlagD,
                            unsigned char nFlagE) {
    assert(nColor >= 0 && nColor < kPlayerColorMax);

    const float flRotation =
        GameSystem::GetGameSystem()->GetPlayColor() != nColor ? kMirrorRotation : 0.0f;

    // A full pool silently drops the trail.
    for (int nSlot = g_nActiveSlideTrailCount; nSlot < kTrailCount; ++nSlot) {
        SlideNoteTrail &trail = m_aTrails[nSlot];
        if (!trail.bActive) {
            trail.nKind = nKind;
            trail.nColor = nColor;
            trail.bActive = true;
            trail.nFlagA = nFlagA;
            trail.flEndX = flEndX;
            trail.flEndY = flEndY;
            trail.flTargetX = flTargetX;
            trail.flTargetY = flTargetY;
            trail.nFlagB = nFlagB;
            trail.nFlagC = nFlagC;
            trail.flAlphaScale = flAlphaScale;
            trail.flRotation = flRotation;
            trail.nFlagD = nFlagD;
            trail.nFlagE = nFlagE;
            ++g_nActiveSlideTrailCount;
            return;
        }
    }
}

namespace {
// @ghidraAddress 0x2fee08/0x2fee0c
constexpr float kPulsePeriod = 66.66666412f;
constexpr float kPulseWrap = -66.66666412f;
// @ghidraAddress 0x2fee10
constexpr float kSparklePhase = 33.33333206f;
constexpr int kFrameCount = 30;
constexpr int kFadeHalf = 5;
constexpr int kFadePeriod = 10;
constexpr double kFadeGrowSlope = 0.125;
constexpr double kFadeGrowBias = 0.5;
constexpr double kFadeDecaySlope = -0.125;
constexpr double kFadeBias1 = 1.0;
constexpr int kScaleGrowBound = 0xe;
constexpr double kScaleGrowSlope = 0.01;   // @ghidraAddress 0x2fee20
constexpr double kScaleGrowBias = 0.85;    // @ghidraAddress 0x2fee28
constexpr double kScaleDecaySlope = -0.01; // @ghidraAddress 0x2fee18
// @ghidraAddress 0x2fee30
constexpr float kFrameAlphaTable[] = {255.0f, 128.0f};
// @ghidraAddress 0x2fedd8
constexpr double kCometAngleBias = 1.5707963267948966;
constexpr double kBodyAlphaHalf = 0.5;
constexpr int kSpriteKindBody = 1;
constexpr int kSpriteKindGlow = 0xf;
constexpr int kSpriteCapOffset = 8;
constexpr int kSpriteSparkleOffset = 0xd;
constexpr int kSpriteHeadKindOffset = 0xa;
} // namespace

/** @ghidraAddress 0x95d14 */
void SlideNoteLayer::Update(float flDeltaTime) {
    m_anBatchCount[0] = 0;
    m_anBatchCount[1] = 0;
    m_anBatchCount[2] = 0;
    m_flLastClock += flDeltaTime;
    if (m_flLastClock > kPulsePeriod) {
        do {
            m_flLastClock += kPulseWrap;
        } while (m_flLastClock > kPulsePeriod);
    }
    const float flPulseClock = m_flLastClock;

    int nFrame = m_nFrameCounter;
    if (flDeltaTime > 0.0f) {
        ++nFrame;
        m_nFrameCounter = nFrame;
    }
    if (nFrame >= kFrameCount) {
        nFrame = 0;
        m_nFrameCounter = 0;
    }

    const int nFadePhase = nFrame % kFadePeriod;
    float flFade;
    if (nFadePhase <= kFadeHalf - 1) {
        flFade = static_cast<float>(nFadePhase * kFadeGrowSlope + kFadeGrowBias);
    } else {
        flFade = static_cast<float>((nFadePhase - kFadeHalf) * kFadeDecaySlope + kFadeBias1);
    }

    float flScalePulse;
    if (nFrame <= kScaleGrowBound) {
        flScalePulse = static_cast<float>(nFrame * kScaleGrowSlope + kScaleGrowBias);
    } else {
        flScalePulse =
            static_cast<float>((nFrame - (kScaleGrowBound + 1)) * kScaleDecaySlope + kFadeBias1);
    }

    GameSystem *pGameSystem = GameSystem::GetGameSystem();
    const bool bColorIsOne = pGameSystem->GetPlayColor() == 1;
    const float flCrossAlpha = pGameSystem->GetRivalAlpha();
    const float flSideFactor0 = bColorIsOne ? flCrossAlpha : 1.0f;
    const float flSideFactor1 = bColorIsOne ? 1.0f : flCrossAlpha;
    const float flBaseScale = pGameSystem->GetSheetRadiusScaled();

    for (int nTrail = 0; nTrail < kTrailCount; ++nTrail) {
        SlideNoteTrail &trail = m_aTrails[nTrail];
        // @ghidraAddress 0x95eac
        if (nTrail >= g_nActiveSlideTrailCount) {
            trail.bActive = false;
            continue;
        }
        if (!trail.bActive) {
            continue;
        }
        trail.bActive = false;

        S_VECTOR2 vComet{trail.flEndX, trail.flEndY};
        S_VECTOR2 targetPos{trail.flTargetX, trail.flTargetY};
        SubtractVector2(&vComet, &targetPos);
        const float flLength = Vector2Length(&vComet);
        float flAngle = 0.0f;
        if (flLength >= 1.0f || trail.nFlagD != 0) {
            flAngle = static_cast<float>(
                std::atan2(static_cast<double>(-vComet.y), static_cast<double>(vComet.x)) +
                kCometAngleBias);
        }

        const S_VECTOR2 *pPosition = &targetPos;
        const float flFrameAlpha = kFrameAlphaTable[trail.nFlagC];
        const float flSideFactor = trail.nColor == 0 ? flSideFactor0 : flSideFactor1;
        const int nBaseAlpha = static_cast<int>(flFrameAlpha * flSideFactor);
        const int nTrailAlpha =
            static_cast<int>(trail.flAlphaScale * static_cast<float>(nBaseAlpha));

        if (trail.nFlagE != 0) {
            const int nBodyAlpha =
                trail.nFlagB == 0 ?
                    static_cast<int>(static_cast<double>(nTrailAlpha) * kBodyAlphaHalf) :
                    static_cast<int>(static_cast<float>(nTrailAlpha) * flScalePulse);
            CreateSprite(kSpriteKindBody,
                         pPosition,
                         static_cast<unsigned int>(nBodyAlpha),
                         flLength,
                         flAngle,
                         flBaseScale);
            if (flLength >= 1.0f) {
                CreateSprite(kSpriteKindGlow,
                             pPosition,
                             static_cast<unsigned int>(nBodyAlpha),
                             flLength,
                             flAngle,
                             flBaseScale);
            }
            CreateSprite(trail.nColor + kSpriteCapOffset,
                         pPosition,
                         static_cast<unsigned int>(nTrailAlpha),
                         flLength,
                         flAngle,
                         flBaseScale);
            if (flPulseClock < kSparklePhase && trail.nFlagB != 0) {
                CreateSprite(trail.nColor + kSpriteSparkleOffset,
                             pPosition,
                             static_cast<unsigned int>(nTrailAlpha),
                             flLength,
                             flAngle,
                             flBaseScale);
            }
        } else {
            CreateSprite(trail.nColor + trail.nKind * 2 + 2,
                         pPosition,
                         static_cast<unsigned int>(nTrailAlpha),
                         flLength,
                         trail.flRotation,
                         flBaseScale);
            if (flLength == 0.0f) {
                if (trail.nFlagB != 0) {
                    const int nSparkleAlpha =
                        static_cast<int>(flFade * static_cast<float>(nTrailAlpha));
                    CreateSprite(trail.nKind + kSpriteHeadKindOffset,
                                 pPosition,
                                 static_cast<unsigned int>(nSparkleAlpha),
                                 flLength,
                                 trail.flRotation,
                                 flBaseScale);
                }
            } else if (flLength >= 1.0f) {
                const int nGlowAlpha =
                    trail.nFlagB == 0 ?
                        static_cast<int>(static_cast<double>(nTrailAlpha) * kBodyAlphaHalf) :
                        static_cast<int>(static_cast<float>(nTrailAlpha) * flScalePulse);
                CreateSprite(kSpriteKindGlow,
                             pPosition,
                             static_cast<unsigned int>(nGlowAlpha),
                             flLength,
                             flAngle,
                             flBaseScale);
            }
        }
    }

    for (int nBatch = 0; nBatch < kBatchCount; ++nBatch) {
        m_apBatches[nBatch]->SetSpriteCount(m_anBatchCount[nBatch]);
    }
    g_nActiveSlideTrailCount = 0;
}

/** @ghidraAddress 0x95ae0 */
void SlideNoteLayer::BuildSprites() {
    if (m_bBuilt) {
        return;
    }
    ne::C_RENDER *pParent = BgLayer::GetBackgroundLayer()->GetBackgroundRenderObject();
    m_pTexture = ne::C_TEXTURE::FindOrLoadCached(kTrailTextureName);
    for (int nBatch = 0; nBatch < kBatchCount; ++nBatch) {
        ne::C_SPRITE_INSTANCING_2D *pBatch = ne::CreateWorldSpriteBatch(kBatchCapacity);
        m_apBatches[nBatch] = pBatch;
        pParent->AttachChild(pBatch);
        pBatch->SetVisible(true);
        pBatch->SetRefCountedMember(m_pTexture);
        pBatch->SetSpriteCount(0);
        // Batches 0 and 2 draw with additive blending.
        if ((nBatch & ~2) == 0) {
            pBatch->SetBlendMode(kBlendModeAdditive);
        }
        // The newer hardware needs the wrap sampler parameters set explicitly.
        if (!IsHardwareType9()) {
            pBatch->SetTexParam(kTexParamWrapT, kTexWrapRepeat);
            pBatch->SetTexParam(kTexParamWrapS, kTexWrapRepeat);
        }
    }
    m_bBuilt = true;
    g_nActiveSlideTrailCount = 0;
}

/** @ghidraAddress 0x95a90 */
SlideNoteLayer *SlideNoteLayer::shared() {
    if (g_pSlideNoteLayer == nullptr) {
        g_pSlideNoteLayer = new SlideNoteLayer();
    }
    return g_pSlideNoteLayer;
}

/** @ghidraAddress 0x96164 */
void SlideNoteLayer::CreateSprite(int nType,
                                  const S_VECTOR2 *pPosition,
                                  unsigned int nAlpha,
                                  float flLength,
                                  float flRotation,
                                  float flScale) {
    assert(nType >= 0);
    assert(nType < kSlideNoteSpriteTypeCount);

    const SlideNoteSpriteType &spriteType = g_aSlideNoteSpriteTypes[nType];
    const SpriteUvEntry &uv = g_aScoreGaugeUvTable[spriteType.nUvIndex];

    ne::C_SPRITE_INSTANCING_2D *pBatch = m_apBatches[spriteType.nBatchIndex];
    const int nIndex = m_anBatchCount[spriteType.nBatchIndex];

    pBatch->SetSpritePosition(nIndex, *pPosition);
    pBatch->SetSpriteAnchor(nIndex, S_VECTOR2{spriteType.flAnchorX, spriteType.flAnchorY});
    pBatch->SetSpriteUvOrigin(nIndex, S_VECTOR2{uv.flOriginU, uv.flOriginV});
    pBatch->SetSpriteUvSize(nIndex, S_VECTOR2{uv.flSizeU, uv.flSizeV});
    pBatch->SetSpriteRotation(nIndex, flRotation);
    pBatch->SetSpriteColor(nIndex, 0xff, 0xff, 0xff, nAlpha);

    float flScaleY;
    if (nType < kSlideNoteGlowTypeBase) {
        pBatch->SetSpriteSize(nIndex, S_VECTOR2{spriteType.flSizeW, spriteType.flSizeH});
        flScaleY = flScale;
    } else {
        pBatch->SetSpriteSize(nIndex, S_VECTOR2{spriteType.flSizeW, flLength});
        flScaleY = 1.0f;
    }
    pBatch->SetSpriteScale(nIndex, flScale, flScaleY);

    ++m_anBatchCount[spriteType.nBatchIndex];
}
