#include "titleclassicscene.h"

#include <cstdint>

#import "AppDelegate.h"
#import "AudioManager.h"
#import "RBBGMManager.h"
#import "RBViewController.h"
#include "curve.h"
#include "game_scene.h"
#include "gamesystem.h"
#include "neSpriteInstancing.h"
#include "neTexture.h"
#include "s_vector2.h"
#include "shotsoundmanager.h"
#include "soundeffectmanager.h"
#include "touch_point.h"
#include "touchmanager.h"
#include "vectormath.h"

namespace {
constexpr float kInitialFadeBase = 1.0f;

constexpr int kNoTouchId = -1;

constexpr int kStateLoad = 0;
constexpr int kStateStartMusic = 1;
constexpr int kStateRender = 2;
constexpr int kStateFinish = 3;

// Seconds.
constexpr float kTitleBgmFadeInTime = 0.3f;

constexpr const char *kTitleTextureNames[rb::TitleClassicScene::kTextureCount] = {
    "00_texture/ti_bg",
    "00_texture/ti_star",
    "00_texture/ti_start",
    "00_texture/ti_start_eff",
    "00_texture/ti_start_eff_text",
    "00_texture/ti_maru",
    "00_texture/ti_logo",
};

constexpr int kUntexturedSlot = 7;

// Slots 1, 2, and 4.
constexpr unsigned int kAdditiveSlotMask = 0x16;

constexpr unsigned int kClampedSlotCount = 2;

constexpr int kBlendModeAdditive = 1;
constexpr int kTexParamAxisT = 1;
constexpr int kTexParamAxisS = 0;
constexpr int kTexClampValue = 1;

// Milliseconds.
constexpr int kTitleReadyDelay = 1000;
constexpr float kTitleFadeDuration = 1000.0f;

constexpr int kTitleVoiceId = 0;

// The nine sprite kinds map onto eight instancers; the last two kinds share the final slot.
// @ghidraAddress 0x309360
constexpr unsigned int kTitleSpriteKindSlot[] = {0, 4, 5, 6, 7, 1, 2, 3, 3};

constexpr unsigned int kTitleSpriteKindCount = 9;

constexpr float kQuadHalf = 0.5f;

constexpr unsigned int kTitleOpaque = 0xff;

// Index 0 is unused since kind 0 draws a full quad.
struct TitleSpriteLayout {
    float flAnchorX;
    float flAnchorY;
    float flSizeW;
    float flSizeH;
    float flUvOriginU;
    float flUvOriginV;
    float flUvSizeU;
    float flUvSizeV;
};
constexpr TitleSpriteLayout kTitleLayoutMain[kTitleSpriteKindCount] = {
    {},
    {190.0f, 37.0f, 380.0f, 74.0f, 0.0f, 0.0f, 0.7421875f, 0.578125f},
    {175.0f, 22.0f, 350.0f, 44.0f, 0.0f, 0.0f, 0.68359375f, 0.6875f},
    {150.0f, 11.0f, 300.0f, 22.0f, 0.0f, 0.0f, 0.5859375f, 0.6875f},
    {384.0f, 512.0f, 768.0f, 1024.0f, 0.0f, 0.0f, 0.75f, 1.0f},
    {384.0f, 512.0f, 768.0f, 1024.0f, 0.0f, 0.0f, 0.75f, 1.0f},
    {255.0f, 202.5f, 510.0f, 405.0f, 0.0f, 0.0f, 0.99609375f, 0.79101562f},
    {133.0f, 157.0f, 278.0f, 256.0f, 0.0f, 0.0f, 0.5234375f, 1.0f},
    {132.0f, 157.0f, 278.0f, 256.0f, 0.0f, 0.0f, 1.0f, 1.0f},
};
constexpr TitleSpriteLayout kTitleLayoutAlt[kTitleSpriteKindCount] = {
    {},
    {190.0f, 37.0f, 380.0f, 74.0f, 0.0f, 0.0f, 0.7421875f, 0.578125f},
    {175.0f, 22.0f, 350.0f, 44.0f, 0.0f, 0.0f, 0.68359375f, 0.6875f},
    {150.0f, 11.0f, 300.0f, 22.0f, 0.0f, 0.0f, 0.5859375f, 0.6875f},
    {384.0f, 512.0f, 768.0f, 1024.0f, 0.0f, 0.0f, 0.75f, 1.0f},
    {384.0f, 512.0f, 768.0f, 1024.0f, 0.0f, 0.0f, 0.75f, 1.0f},
    {255.0f, 202.5f, 510.0f, 405.0f, 0.0f, 0.0f, 0.99609375f, 0.79101562f},
    {331.0f, 376.0f, 668.0f, 638.0f, 0.0f, 0.0f, 0.65234375f, 0.62304688f},
    {336.0f, 369.0f, 700.0f, 640.0f, 0.0f, 0.0f, 1.0f, 1.0f},
};

constexpr unsigned int kSpriteKindBackground = 0;
constexpr unsigned int kSpriteKindStartGlow = 1;
constexpr unsigned int kSpriteKindStartPlate = 2;
constexpr unsigned int kSpriteKindStartText = 3;
constexpr unsigned int kColorQuadKindFade = 4;
constexpr unsigned int kSpriteKindStar = 5;
constexpr unsigned int kSpriteKindRing = 6;
constexpr unsigned int kSpriteKindLogo = 7;

constexpr float kPhoneLayoutScale = 0.5f;

constexpr float kUnitScale = 1.0f;
constexpr float kNoRotation = 0.0f;

// @ghidraAddress 0x2eed00
constexpr float kAlphaScale = 255.0f;

// @ghidraAddress 0x2fd024
constexpr float kPromptOffsetY = 180.0f;

// @ghidraAddress 0x2fcff4
constexpr float kPromptFadeLimit = 1500.0f;
constexpr int kPromptFadePairCount = 2;
// @ghidraAddress 0x3093a4
constexpr float kPromptFadeCurve[] = {500.0f, 0.0f, 1500.0f, 1.0f};

// The clock wraps by adding 0x2f8544.
// @ghidraAddress 0x2f8540
constexpr float kPromptPulsePeriod = 1000.0f;
constexpr int kPromptPulsePairCount = 3;
// @ghidraAddress 0x3093b4
constexpr float kPromptPulseCurve[] = {0.0f, 0.0f, 500.0f, 1.0f, 1000.0f, 0.0f};

// Once the hidden sequence completes every animation clock runs five times faster.
constexpr int kNormalSpeed = 1;
constexpr int kSecretSpeedUp = 5;
constexpr int kLeavingPulseSpeedUp = 5;

// @ghidraAddress 0x3093dc
constexpr float kStarScrollPeriod[] = {153600.0f, 614400.0f};
// @ghidraAddress 0x3093e4
constexpr float kStarScrollDistance[] = {-1024.0f, -1024.0f};
// @ghidraAddress 0x309164
constexpr float kStarWrapDistance = 1024.0f;
// @ghidraAddress 0x3093cc
constexpr float kStarAlphaHigh[] = {0.5f, 0.2f};
// @ghidraAddress 0x3093d4
constexpr float kStarAlphaLow[] = {0.2f, 0.5f};
// @ghidraAddress 0x2feff4
constexpr float kStarTwinklePeriod = 500.0f;
constexpr int kStarTwinklePeriodMs = 500;
// @ghidraAddress 0x3093f4
constexpr float kStarLayerScale[] = {1.0f, -1.0f};

// @ghidraAddress 0x3093f4
constexpr float kRingScaleStart[] = {1.0f, -1.0f};
// @ghidraAddress 0x3093ec
constexpr float kRingScaleEnd[] = {2.0f, -2.5f};
// @ghidraAddress 0x309168
constexpr float kRingScalePeriod = 30000.0f;
constexpr int kRingScalePeriodMs = 30000;
// @ghidraAddress 0x309170
constexpr double kRingSpinTurn[] = {6.283185307179586, -6.283185307179586};
// @ghidraAddress 0x3093fc
constexpr float kRingSpinPeriod[] = {30000.0f, 30000.0f};
constexpr int kRingAlphaPairCount = 5;
// Offset of the curve's last keyframe time; it doubles as the alpha clock's wrap.
constexpr int kRingAlphaCurveEndTime = 8;
// @ghidraAddress 0x309404
constexpr float kRingAlphaCurve[rb::TitleClassicScene::kRingCount][kRingAlphaPairCount * 2] = {
    {0.0f, 0.0f, 3000.0f, 0.0f, 5000.0f, 0.7f, 22000.0f, 0.7f, 30000.0f, 0.0f},
    {0.0f, 0.0f, 3000.0f, 0.7f, 5000.0f, 0.7f, 22000.0f, 0.7f, 30000.0f, 0.0f},
};

constexpr unsigned int kFadeQuadRgb = 0;

constexpr float kFadeComplete = 1.0f;
constexpr float kLeaveFadeDuration = 1500.0f;
constexpr float kLeaveMusicFadeTime = 0.5f;

constexpr float kCorporateButtonAlpha = 0.0f;

// Touch input is ignored until this clock has run out.
// @ghidraAddress 0x2f8540
constexpr float kStartDelayLimit = 1000.0f;

// Pixels along the dominant axis.
constexpr float kSwipeDeadZone = 25.0f;

// The sequence is the Konami code: up, up, down, down, left, right, left, right, B, A.
enum TitleSwipeInput {
    kTitleSwipeUp = 0,
    kTitleSwipeDown = 1,
    kTitleSwipeLeft = 2,
    kTitleSwipeRight = 3,
    kTitleSwipeButtonA = 4,
    kTitleSwipeButtonB = 5,
};

enum TitleSwipeStep {
    kSwipeStepNone = 0,
    kSwipeStepUp1 = 1,
    kSwipeStepUp2 = 2,
    kSwipeStepDown1 = 3,
    kSwipeStepDown2 = 4,
    kSwipeStepLeft1 = 5,
    kSwipeStepRight1 = 6,
    kSwipeStepLeft2 = 7,
    kSwipeStepRight2 = 8,
    kSwipeStepButtonB = 9,
    kSwipeStepComplete = 10,
};

constexpr int kSoundEffectTitleSecret = 0xd;

constexpr unsigned long kShotAuditionChannel = 1;
constexpr int kShotAuditionVariant = 0;

// Offsets and extents before the layout scale is applied.
struct TitleHitBoxLayout {
    float flOffsetX;
    float flOffsetY;
    float flWidth;
    float flHeight;
};

constexpr int kHitBoxCount = 4;
constexpr int kHitBoxStart = 0;
constexpr int kHitBoxShotSound = 1;
constexpr int kHitBoxSecretA = 2;
constexpr int kHitBoxSecretB = 3;
// @ghidraAddress 0x309180
constexpr TitleHitBoxLayout kTitleHitBoxLayout[kHitBoxCount] = {
    {0.0f, 0.0f, 400.0f, 100.0f},
    {8.0f, 76.0f, 90.0f, 96.0f},
    {249.0f, 76.0f, 90.0f, 96.0f},
    {114.0f, 76.0f, 64.0f, 96.0f},
};

// Double so the centring subtraction rounds through double before narrowing, as the binary does.
constexpr double kHitBoxHalf = 0.5;

// In screen space.
struct TitleHitBox {
    float flX = {};
    float flY = {};
    float flWidth = {};
    float flHeight = {};
};

// Inclusive on all four edges.
bool IsInsideHitBox(const TitleHitBox &box, float flTouchX, float flTouchY) {
    return (box.flX <= flTouchX) && (flTouchX <= box.flX + box.flWidth) && (box.flY <= flTouchY) &&
           (flTouchY <= box.flY + box.flHeight);
}
} // namespace

const unsigned int g_aTitleSpriteCapacity[rb::TitleClassicScene::kSpriteSlotCount] = {
    1, 4, 2, 1, 1, 1, 1, 1};
const unsigned int g_aTitleSpriteTextureIndex[rb::TitleClassicScene::kSpriteSlotCount] = {
    0, 1, 5, 6, 3, 2, 4, 8};

namespace rb {

/** @ghidraAddress 0x1514b4 */
TitleClassicScene::TitleClassicScene() {
    m_fadeChannel.SetCurrent(kInitialFadeBase);
    m_nTrackedTouchId = kNoTouchId;
}

/**
 * @ghidraAddress 0x151580
 * @ghidraAddress 0x151640
 */
TitleClassicScene::~TitleClassicScene() {
    ReleaseResources();
}

/** @ghidraAddress 0x1515cc */
void TitleClassicScene::ReleaseResources() {
    for (ne::C_TEXTURE *&pTexture : m_apTextures) {
        if (pTexture != nullptr) {
            pTexture->Release();
            pTexture = nullptr;
        }
    }
    // The scene graph owns the instancers, so they are flagged for deletion, not freed here.
    for (ne::C_SPRITE_INSTANCING_2D *&pSprite : m_apSprites) {
        if (pSprite != nullptr) {
            pSprite->RequestDelete();
            pSprite = nullptr;
        }
    }
}

/** @ghidraAddress 0x151678 */
void TitleClassicScene::OnFrame(int nElapsedMs) {
    switch (m_nState) {
    case kStateLoad:
        LoadResources();
        return;
    case kStateStartMusic:
        StartMusic();
        return;
    case kStateRender:
        RenderFrame(nElapsedMs);
        return;
    case kStateFinish:
        FinishAndOpenList();
        return;
    default:
        return;
    }
}

/** @ghidraAddress 0x1516bc */
void TitleClassicScene::LoadResources() {
    m_nFadeTimer = 0;

    for (int nTexture = 0; nTexture < kTextureCount; ++nTexture) {
        m_apTextures[nTexture] = ne::C_TEXTURE::FindOrLoadCached(kTitleTextureNames[nTexture]);
    }

    for (int nSlot = 0; nSlot < kSpriteSlotCount; ++nSlot) {
        ne::C_SPRITE_INSTANCING_2D *pSprite =
            ne::CreateSpriteInstancer(g_aTitleSpriteCapacity[nSlot]);
        pSprite->RegisterGlobal();
        pSprite->SetVisible(true);
        if (nSlot != kUntexturedSlot) {
            pSprite->SetRefCountedMember(m_apTextures[g_aTitleSpriteTextureIndex[nSlot]]);
        }
        pSprite->SetSpriteCount(m_aSpriteCount[nSlot]);
        if (((kAdditiveSlotMask >> nSlot) & 1) != 0) {
            pSprite->SetBlendMode(kBlendModeAdditive);
        }
        if (static_cast<unsigned int>(nSlot - 1) < kClampedSlotCount) {
            pSprite->SetTexParam(kTexParamAxisT, kTexClampValue);
            pSprite->SetTexParam(kTexParamAxisS, kTexClampValue);
        }
        m_apSprites[nSlot] = pSprite;
    }

    [RBBGMManager.getInstance LoadMusicTitleWithLoop:NO];
    SoundEffectManager::GetInstance()->LoadThemedVoiceData(kTitleVoiceId);
    ShotSoundManager::GetInstance()->LoadSlotVariants(GameSystem::GetGameSystem()->GetShotType());

    m_fadeChannel.SetStart(m_fadeChannel.GetCurrent());
    m_fadeChannel.SetEnd(0.0f);
    m_fadeChannel.SetDuration(kTitleFadeDuration);
    m_fadeChannel.SetElapsed(0.0f);
    m_nReadyDelay = kTitleReadyDelay;
    m_nState = kStateStartMusic;
}

/** @ghidraAddress 0x1518c8 */
void TitleClassicScene::StartMusic() {
    m_nState = kStateRender;
    [RBBGMManager.getInstance PlayMusic:kTitleBgmFadeInTime];
}

/** @ghidraAddress 0x151934 */
void TitleClassicScene::RenderFrame(int nElapsedMs) {
    const int nDeltaFrames = nElapsedMs;
    const float flDelta = static_cast<float>(nDeltaFrames);

    const GameSystem *pGameSystem = GameSystem::GetGameSystem();
    const float flViewportWidth = pGameSystem->GetViewportWidth();
    const float flViewportHeight = pGameSystem->GetViewportHeight();
    const float flLayoutScale = IsPad() ? kUnitScale : kPhoneLayoutScale;

    // Numerically identical to the centre computed below, but the binary keeps both.
    S_VECTOR2 halfViewport{flViewportWidth, flViewportHeight};
    ScaleVector2(&halfViewport, kQuadHalf);

    const float flCentreY = flViewportHeight * kQuadHalf;
    const float flPromptBaseY = flCentreY + flLayoutScale * kPromptOffsetY;
    const float flPromptSpread = (flViewportHeight - flPromptBaseY) * kQuadHalf;

    m_nFadeTimer += nDeltaFrames;

    for (ne::C_SPRITE_INSTANCING_2D *pSprite : m_apSprites) {
        pSprite->SetSpriteCount(0);
    }

    const float flCentreX = flViewportWidth * kQuadHalf;

    if (m_nReadyDelay > 0) {
        m_nReadyDelay -= nDeltaFrames;
        if (m_nReadyDelay < 1) {
            SoundEffectManager::GetInstance()->PlayThemedVoice(kTitleVoiceId);
        }
    }

    const float flPromptY = flPromptBaseY + flPromptSpread;

    AdvanceFadeValue(nDeltaFrames);

    EmitTitleSprite(kSpriteKindBackground,
                    kTitleOpaque,
                    S_VECTOR2{flCentreX, flCentreY},
                    kUnitScale,
                    kNoRotation);

    if (m_flPromptFadeClock < kPromptFadeLimit) {
        m_flPromptFadeClock += flDelta;
        if (m_flPromptFadeClock >= kPromptFadeLimit) {
            m_flPromptFadeClock = kPromptFadeLimit;
        }
    }
    const float flPromptFade =
        CalculateCurveInterpolation(kPromptFadeCurve, kPromptFadePairCount, m_flPromptFadeClock);

    const S_VECTOR2 promptPosition{flCentreX, flPromptY};
    RenderTitleBackgroundFullQuad(
        kSpriteKindStartGlow, kTitleOpaque, promptPosition, kUnitScale, kNoRotation);
    RenderTitleBackgroundFullQuad(
        kSpriteKindStartPlate, kTitleOpaque, promptPosition, kUnitScale, kNoRotation);

    m_flPromptPulseClock += flDelta;
    if (m_bLeaving) {
        m_flPromptPulseClock += static_cast<float>(nDeltaFrames * kLeavingPulseSpeedUp);
    }
    while (m_flPromptPulseClock >= kPromptPulsePeriod) {
        m_flPromptPulseClock -= kPromptPulsePeriod;
    }
    const float flPromptPulse =
        CalculateCurveInterpolation(kPromptPulseCurve, kPromptPulsePairCount, m_flPromptPulseClock);
    RenderTitleBackgroundFullQuad(
        kSpriteKindStartText,
        static_cast<unsigned int>(flPromptFade * flPromptPulse * kAlphaScale),
        promptPosition,
        kUnitScale,
        kNoRotation);

    // Each layer is drawn twice, a wrap apart, so the field never shows a seam.
    for (int nLayer = 0; nLayer < kStarLayerCount; ++nLayer) {
        const int nSpeed = m_bSwipeTriggered ? kSecretSpeedUp : kNormalSpeed;

        const float flScrollPeriod = kStarScrollPeriod[nLayer];
        const int nScrollClock = (m_anStarScrollClock[nLayer] + nSpeed * nDeltaFrames) %
                                 static_cast<int>(flScrollPeriod);
        m_anStarScrollClock[nLayer] = nScrollClock;

        // The twinkle clock is deliberately not sped up by the hidden sequence.
        const int nTwinkleClock =
            (m_anStarTwinkleClock[nLayer] + nDeltaFrames) % kStarTwinklePeriodMs;
        m_anStarTwinkleClock[nLayer] = nTwinkleClock;

        const float flScrollY =
            (kStarScrollDistance[nLayer] * static_cast<float>(nScrollClock)) / flScrollPeriod;

        float flTwinkle = static_cast<float>(nTwinkleClock) / kStarTwinklePeriod;
        flTwinkle = flTwinkle + flTwinkle - 1.0f;
        if (flTwinkle < 0.0f) {
            flTwinkle = -flTwinkle;
        }
        const float flAlpha =
            kStarAlphaLow[nLayer] + (kStarAlphaHigh[nLayer] - kStarAlphaLow[nLayer]) * flTwinkle;
        const unsigned int nAlpha = static_cast<unsigned int>(flAlpha * kAlphaScale);

        EmitTitleSprite(kSpriteKindStar,
                        nAlpha,
                        S_VECTOR2{flCentreX, flCentreY + flLayoutScale * flScrollY},
                        kStarLayerScale[nLayer],
                        kNoRotation);
        EmitTitleSprite(
            kSpriteKindStar,
            nAlpha,
            S_VECTOR2{flCentreX, flCentreY + flLayoutScale * (flScrollY + kStarWrapDistance)},
            kStarLayerScale[nLayer],
            kNoRotation);
    }

    for (int nRing = 0; nRing < kRingCount; ++nRing) {
        const int nSpeed = m_bSwipeTriggered ? kSecretSpeedUp : kNormalSpeed;

        const int nScaleClock =
            (m_anRingScaleClock[nRing] + nSpeed * nDeltaFrames) % kRingScalePeriodMs;
        m_anRingScaleClock[nRing] = nScaleClock;

        const float flSpinPeriod = kRingSpinPeriod[nRing];
        const int nSpinClock =
            (m_anRingSpinClock[nRing] + nSpeed * nDeltaFrames) % static_cast<int>(flSpinPeriod);
        m_anRingSpinClock[nRing] = nSpinClock;

        const float *pAlphaCurve = kRingAlphaCurve[nRing];
        const int nAlphaClock = (m_anRingAlphaClock[nRing] + nSpeed * nDeltaFrames) %
                                static_cast<int>(pAlphaCurve[kRingAlphaCurveEndTime]);
        m_anRingAlphaClock[nRing] = nAlphaClock;

        const float flScaleProgress = static_cast<float>(nScaleClock) / kRingScalePeriod;
        const float flScale = kRingScaleStart[nRing] +
                              (kRingScaleEnd[nRing] - kRingScaleStart[nRing]) * flScaleProgress;

        // Computed in double, as the binary does.
        const float flRotation =
            static_cast<float>(kRingSpinTurn[nRing] *
                               static_cast<double>(static_cast<float>(nSpinClock) / flSpinPeriod));

        const unsigned int nAlpha = static_cast<unsigned int>(
            CalculateCurveInterpolation(
                pAlphaCurve, kRingAlphaPairCount, static_cast<float>(nAlphaClock)) *
            kAlphaScale);

        EmitTitleSprite(kSpriteKindRing,
                        nAlpha,
                        S_VECTOR2{flCentreX, flCentreY},
                        flLayoutScale * flScale,
                        flRotation);
    }

    EmitTitleSprite(
        kSpriteKindLogo, kTitleOpaque, S_VECTOR2{flCentreX, flCentreY}, kUnitScale, kNoRotation);

    EmitTitleColorQuad(kColorQuadKindFade,
                       kFadeQuadRgb,
                       static_cast<unsigned int>(m_fadeChannel.GetCurrent() * kAlphaScale),
                       S_VECTOR2{0.0f, 0.0f},
                       S_VECTOR2{flViewportWidth, flViewportHeight},
                       S_VECTOR2{0.0f, 0.0f});

    if (m_flStartDelayClock < kStartDelayLimit) {
        m_flStartDelayClock += flDelta;
    } else if (!m_bLeaving) {
        TouchManager *pTouchManager = TouchManager::FetchSharedSingleton();
        if (m_nTrackedTouchId != kNoTouchId) {
            TouchPoint *pTouch = pTouchManager->FindTouchById(m_nTrackedTouchId);
            if (pTouch == nullptr) {
                m_nTrackedTouchId = kNoTouchId;
            } else if (pTouch->bEnded) {
                m_nTrackedTouchId = kNoTouchId;
                const float flDragX =
                    static_cast<float>(pTouch->nCurrentX) - static_cast<float>(pTouch->nBeginX);
                const float flDragY =
                    static_cast<float>(pTouch->nCurrentY) - static_cast<float>(pTouch->nBeginY);
                const float flAbsX = (flDragX > 0.0f) ? flDragX : -flDragX;
                const float flAbsY = (flDragY > 0.0f) ? flDragY : -flDragY;
                if (flAbsX > flAbsY) {
                    if (flDragX > kSwipeDeadZone) {
                        AdvanceSwipeState(kTitleSwipeRight);
                    } else if (flDragX < -kSwipeDeadZone) {
                        AdvanceSwipeState(kTitleSwipeLeft);
                    }
                } else if (flDragY > kSwipeDeadZone) {
                    AdvanceSwipeState(kTitleSwipeDown);
                } else if (flDragY < -kSwipeDeadZone) {
                    AdvanceSwipeState(kTitleSwipeUp);
                }
            }
        } else if (pTouchManager->GetActiveTouchCount() > 0) {
            if ([AppDelegate.appDelegate needUpdateTerms]) {
                [AppDelegate.appDelegate showTerms];
                return;
            }

            TitleHitBox aHitBoxes[kHitBoxCount] = {};
            for (int nBox = 0; nBox < kHitBoxCount; ++nBox) {
                const TitleHitBoxLayout &layout = kTitleHitBoxLayout[nBox];
                const float flWidth = flLayoutScale * layout.flWidth;
                const float flHeight = flLayoutScale * layout.flHeight;
                const float flAnchorX = (nBox == kHitBoxStart) ? flCentreX : halfViewport.x;
                const float flAnchorY = (nBox == kHitBoxStart) ? flPromptY : halfViewport.y;
                aHitBoxes[nBox].flX = static_cast<float>(
                    (flAnchorX + flLayoutScale * layout.flOffsetX) - flWidth * kHitBoxHalf);
                aHitBoxes[nBox].flY = static_cast<float>(
                    (flAnchorY + flLayoutScale * layout.flOffsetY) - flHeight * kHitBoxHalf);
                aHitBoxes[nBox].flWidth = flWidth;
                aHitBoxes[nBox].flHeight = flHeight;
            }

            // Only the first freshly-added touch is considered, whether or not it hits anything.
            for (int nTouch = 0; nTouch < pTouchManager->GetActiveTouchCount(); ++nTouch) {
                TouchPoint *pTouch = pTouchManager->GetActiveTouch(nTouch);
                if (!pTouch->bIsNew) {
                    continue;
                }
                m_nTrackedTouchId = pTouch->nId;
                const float flTouchX = static_cast<float>(pTouch->nCurrentX);
                const float flTouchY = static_cast<float>(pTouch->nCurrentY);
                if (IsInsideHitBox(aHitBoxes[kHitBoxStart], flTouchX, flTouchY)) {
                    m_fadeChannel.SetStart(m_fadeChannel.GetCurrent());
                    m_fadeChannel.SetEnd(kFadeComplete);
                    m_fadeChannel.SetDuration(kLeaveFadeDuration);
                    m_fadeChannel.SetElapsed(0.0f);
                    [RBBGMManager.getInstance StopMusic:kLeaveMusicFadeTime];
                    m_bLeaving = true;
                    SoundEffectManager::GetInstance()->PlaySharedSoundEffect();
                    [AppDelegate.appDelegate.viewController
                        fadeCorporateButton:kCorporateButtonAlpha];
                } else if (IsInsideHitBox(aHitBoxes[kHitBoxSecretA], flTouchX, flTouchY)) {
                    AdvanceSwipeState(kTitleSwipeButtonA);
                } else if (IsInsideHitBox(aHitBoxes[kHitBoxSecretB], flTouchX, flTouchY)) {
                    AdvanceSwipeState(kTitleSwipeButtonB);
                } else if (IsInsideHitBox(aHitBoxes[kHitBoxShotSound], flTouchX, flTouchY)) {
                    ShotSoundManager::GetInstance()->PlaySlot(
                        kShotAuditionChannel,
                        GameSystem::GetGameSystem()->GetShotType(),
                        kShotAuditionVariant);
                }
                break;
            }
        }
    }

    if (m_bLeaving && (m_fadeChannel.GetCurrent() >= kFadeComplete)) {
        m_nState = kStateFinish;
    }
}

/** @ghidraAddress 0x152548 */
void TitleClassicScene::AdvanceFadeValue(int nDeltaFrames) {
    m_fadeChannel.Advance(static_cast<float>(nDeltaFrames));
}

/** @ghidraAddress 0x152cc8 */
void TitleClassicScene::AdvanceSwipeState(int iSwipeEvent) {
    switch (iSwipeEvent) {
    case kTitleSwipeUp:
        if (m_nSwipeState != kSwipeStepUp1) {
            if (m_nSwipeState != kSwipeStepNone) {
                return;
            }
            m_nSwipeState = kSwipeStepUp1;
        }
        m_nSwipeState = kSwipeStepUp2;
        return;
    case kTitleSwipeDown:
        if (m_nSwipeState != kSwipeStepDown1) {
            if (m_nSwipeState != kSwipeStepUp2) {
                return;
            }
            m_nSwipeState = kSwipeStepDown1;
        }
        m_nSwipeState = kSwipeStepDown2;
        return;
    case kTitleSwipeLeft:
        if (m_nSwipeState == kSwipeStepRight1) {
            m_nSwipeState = kSwipeStepLeft2;
        } else if (m_nSwipeState == kSwipeStepDown2) {
            m_nSwipeState = kSwipeStepLeft1;
        }
        return;
    case kTitleSwipeRight:
        if (m_nSwipeState == kSwipeStepLeft2) {
            m_nSwipeState = kSwipeStepRight2;
        } else if (m_nSwipeState == kSwipeStepLeft1) {
            m_nSwipeState = kSwipeStepRight1;
        }
        return;
    case kTitleSwipeButtonA:
        if (m_nSwipeState == kSwipeStepButtonB) {
            m_nSwipeState = kSwipeStepComplete;
            SoundEffectManager::GetInstance()->PlayThemedSoundEffect(kSoundEffectTitleSecret);
            m_bSwipeTriggered = true;
        }
        return;
    case kTitleSwipeButtonB:
        if (m_nSwipeState == kSwipeStepRight2) {
            m_nSwipeState = kSwipeStepButtonB;
        }
        return;
    default:
        return;
    }
}

/** @ghidraAddress 0x152450 */
void TitleClassicScene::FinishAndOpenList() {
    if (![AudioManager.sharedManager isStart]) {
        return;
    }
    ReleaseResources();
    rb::GameScene::GetInstance(GameSystem::GetGameSystem()->GetCurrentSceneSlot());
    [AppDelegate.appDelegate.viewController showMusicListView];
    MarkDead();
}

/** @ghidraAddress 0x152a90 */
void TitleClassicScene::RenderTitleBackgroundFullQuad(unsigned int nSpriteKind,
                                                      unsigned int nColorAlpha,
                                                      S_VECTOR2 position,
                                                      float flSize,
                                                      float flRotation) {
    if (nSpriteKind >= kTitleSpriteKindCount) {
        return;
    }
    ne::C_SPRITE_INSTANCING_2D *pInstancer = m_apSprites[kTitleSpriteKindSlot[nSpriteKind]];
    const int nIndex = pInstancer->GetSpriteCount();
    if (nIndex >= static_cast<int>(pInstancer->GetCapacity())) {
        return;
    }

    ne::C_TEXTURE *pTexture = pInstancer->GetBoundTexture();
    const float flImageWidth = static_cast<float>(pTexture->GetImageWidth());
    const float flImageHeight = static_cast<float>(pTexture->GetImageHeight());
    const float flAllocWidth = static_cast<float>(pTexture->GetAllocWidth());
    const float flAllocHeight = static_cast<float>(pTexture->GetAllocHeight());
    const float flScale = pTexture->GetScale();

    pInstancer->SetSpritePosition(nIndex, position);
    pInstancer->SetSpriteAnchor(
        nIndex, S_VECTOR2{flImageWidth * kQuadHalf / flScale, flImageHeight * kQuadHalf / flScale});
    pInstancer->SetSpriteSize(nIndex, S_VECTOR2{flImageWidth / flScale, flImageHeight / flScale});
    pInstancer->SetSpriteScale(nIndex, flSize, flSize);
    pInstancer->SetSpriteRotation(nIndex, flRotation);
    pInstancer->SetSpriteUvOrigin(nIndex, S_VECTOR2{0.0f, 0.0f});
    pInstancer->SetSpriteUvSize(
        nIndex, S_VECTOR2{flImageWidth / flAllocWidth, flImageHeight / flAllocHeight});
    pInstancer->SetSpriteColor(nIndex, kTitleOpaque, kTitleOpaque, kTitleOpaque, nColorAlpha);

    pInstancer->SetSpriteCount(nIndex + 1);
}

/** @ghidraAddress 0x15259c */
void TitleClassicScene::EmitTitleSprite(unsigned int nSpriteKind,
                                        unsigned int nColorAlpha,
                                        S_VECTOR2 position,
                                        float flSize,
                                        float flRotation) {
    if (nSpriteKind >= kTitleSpriteKindCount) {
        return;
    }
    ne::C_SPRITE_INSTANCING_2D *pInstancer = m_apSprites[kTitleSpriteKindSlot[nSpriteKind]];
    const int nIndex = pInstancer->GetSpriteCount();
    if (nIndex >= static_cast<int>(pInstancer->GetCapacity())) {
        return;
    }

    if (nSpriteKind == 0) {
        ne::C_TEXTURE *pTexture = pInstancer->GetBoundTexture();
        const float flImageWidth = static_cast<float>(pTexture->GetImageWidth());
        const float flImageHeight = static_cast<float>(pTexture->GetImageHeight());
        const float flAllocWidth = static_cast<float>(pTexture->GetAllocWidth());
        const float flAllocHeight = static_cast<float>(pTexture->GetAllocHeight());
        const float flScale = pTexture->GetScale();
        pInstancer->SetSpriteAnchor(
            nIndex,
            S_VECTOR2{flImageWidth * kQuadHalf / flScale, flImageHeight * kQuadHalf / flScale});
        pInstancer->SetSpriteSize(nIndex,
                                  S_VECTOR2{flImageWidth / flScale, flImageHeight / flScale});
        pInstancer->SetSpriteUvOrigin(nIndex, S_VECTOR2{0.0f, 0.0f});
        pInstancer->SetSpriteUvSize(
            nIndex, S_VECTOR2{flImageWidth / flAllocWidth, flImageHeight / flAllocHeight});
    } else {
        const TitleSpriteLayout &layout =
            IsPad() ? kTitleLayoutAlt[nSpriteKind] : kTitleLayoutMain[nSpriteKind];
        pInstancer->SetSpriteAnchor(nIndex, S_VECTOR2{layout.flAnchorX, layout.flAnchorY});
        pInstancer->SetSpriteSize(nIndex, S_VECTOR2{layout.flSizeW, layout.flSizeH});
        pInstancer->SetSpriteUvOrigin(nIndex, S_VECTOR2{layout.flUvOriginU, layout.flUvOriginV});
        pInstancer->SetSpriteUvSize(nIndex, S_VECTOR2{layout.flUvSizeU, layout.flUvSizeV});
    }

    pInstancer->SetSpritePosition(nIndex, position);
    pInstancer->SetSpriteScale(nIndex, flSize, flSize);
    pInstancer->SetSpriteRotation(nIndex, flRotation);
    pInstancer->SetSpriteColor(nIndex, kTitleOpaque, kTitleOpaque, kTitleOpaque, nColorAlpha);

    pInstancer->SetSpriteCount(nIndex + 1);
}

/** @ghidraAddress 0x152bfc */
void TitleClassicScene::EmitTitleColorQuad(unsigned int nKind,
                                           unsigned int nColorRgb,
                                           unsigned int nAlpha,
                                           S_VECTOR2 position,
                                           S_VECTOR2 size,
                                           S_VECTOR2 anchor) {
    if (nKind >= kTitleSpriteKindCount) {
        return;
    }
    ne::C_SPRITE_INSTANCING_2D *pInstancer = m_apSprites[kTitleSpriteKindSlot[nKind]];
    const int nIndex = pInstancer->GetSpriteCount();
    if (nIndex >= static_cast<int>(pInstancer->GetCapacity())) {
        return;
    }

    // No texture is bound and no UV rectangle is written: the quad draws as a flat colour.
    pInstancer->SetSpritePosition(nIndex, position);
    pInstancer->SetSpriteAnchor(nIndex, anchor);
    pInstancer->SetSpriteSize(nIndex, size);
    pInstancer->SetSpriteColor(nIndex, nColorRgb, nColorRgb, nColorRgb, nAlpha);

    pInstancer->SetSpriteCount(nIndex + 1);
}

} // namespace rb
