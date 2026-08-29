#include "titlecolettescene.h"

#include <cmath>

#import "AppDelegate.h"
#import "AudioManager.h"
#import "RBBGMManager.h"
#import "RBCampaignData.h"
#import "RBUserSettingData.h"
#import "RBViewController.h"
#import "SePlayer.h"
#include "campaign_portrait_table.h"
#include "curve.h"
#include "game_scene.h"
#include "gamesystem.h"
#include "neSpriteInstancing.h"
#include "neTexture.h"
#include "shotsoundmanager.h"
#include "soundeffectmanager.h"
#include "title_anim_table.h"
#include "touch_point.h"
#include "touchmanager.h"

namespace {
constexpr int kStateLoad = 0;
constexpr int kStateStartMusic = 1;
constexpr int kStateMainLoop = 2;
constexpr int kStateFinish = 3;

constexpr float kInitialFadeValue = 1.0f;
constexpr int kNoTouchId = -1;

constexpr const char *kTitleTextureNames[] = {
    "00_texture/ti_bg",
    "00_texture/ti_parts",
    "00_texture/ti_parts_eff",
};
static NSString *const kCampaignTextureFallback = @"00_texture/title_campaign";
static NSString *const kCampaignTextureFormat = @"%@/%@";
constexpr int kNoTextureIndex = 5;
constexpr int kTitleVoiceId = 0;
constexpr int kReadyDelay = 0x708;      // Milliseconds.
constexpr float kFadeDuration = 300.0f; // Milliseconds.

static NSString *const kTitleSeFormat = @"Sounds/%@/SE/SD_SE_%@";
static NSString *const kTitleSeType = @"m4a";
// @ghidraAddress 0x35dca8
static NSString *const kTitleSePartName = @"JUMP";

constexpr unsigned int kBackgroundPartId = 0;
// The campaign texture index doubles as the campaign-portrait parts' UV-table selector.
constexpr int kPartTextureIndexCampaign = 3;

constexpr float kLandscapeOffsetX = -384.0f; // @ghidraAddress 0x2f8568
constexpr float kLandscapeOffsetY = -512.0f; // @ghidraAddress 0x2f8570
constexpr float kLandscapeScale = 0.8f;      // @ghidraAddress 0x2f856c
constexpr float kHalf = 0.5f;

constexpr float kCorporateHitOffsetX = -40.0f; // @ghidraAddress 0x2f8574
constexpr float kCorporateHitOffsetY = -30.0f;
constexpr float kCorporateHitGrowX = 80.0f; // @ghidraAddress 0x2f855c
constexpr float kCorporateHitGrowY = 60.0f; // @ghidraAddress 0x2f8578

enum TitlePartId {
    kPartCorporateLogo = 0x5d,
    kPartLetterF = 0x46,
    kPartLetterI = 0x49,
    kPartLetterG = 0x47,
    kPartLetterD = 0x44,
    kPartLetterA = 0x41,
    kPartSoundEffect = 0x62,
};
enum TitleHitBoxSlot {
    kHitBoxCorporateLogo = 0,
    kHitBoxLetterF = 1,
    kHitBoxLetterI = 2,
    kHitBoxLetterG = 3,
    kHitBoxLetterD = 4,
    kHitBoxLetterA = 5,
    // Never written by the emitter, so this slot stays a zero rect.
    kHitBoxVoiceCue = 6,
    kHitBoxSoundEffect = 7,
};

constexpr double kSwingPivotX = -384.0; // @ghidraAddress 0x2f8590
constexpr double kSwingPivotY = -467.0; // @ghidraAddress 0x2f8598
constexpr double kSwingOriginX = 384.0; // @ghidraAddress 0x2f85a8
constexpr double kSwingOriginY = 467.0; // @ghidraAddress 0x2f85b0
constexpr double kSwingPhaseRadiansPerDegree = M_PI / 180.0;

constexpr int kSoundEffectTitleSecret = 0xd;
constexpr int kSoundEffectTitleSwing = 0xe;
constexpr int kReplayTimerValue = 0x24fa;

// The main sequence is the Konami code; the alternate branch is left/right/left/right then B, A.
enum TitleGestureInput {
    kGestureUp = 0,
    kGestureDown = 1,
    kGestureLeft = 2,
    kGestureRight = 3,
    kGestureButtonA = 4,
    kGestureButtonB = 5,
    kGestureAltLeft = 6,
    kGestureAltRight = 7,
};

enum TitleGestureStep {
    kGestureStepNone = 0,
    kGestureStepUp1 = 1,
    kGestureStepUp2 = 2,
    kGestureStepDown1 = 3,
    kGestureStepDown2 = 4,
    kGestureStepLeft1 = 5,
    kGestureStepRight1 = 6,
    kGestureStepLeft2 = 7,
    kGestureStepRight2 = 8,
    kGestureStepButtonB = 9,
    kGestureStepComplete = 10,
    kGestureStepAltLeft1 = 0xf,
    kGestureStepAltRight1 = 0x10,
    kGestureStepAltLeft2 = 0x11,
    kGestureStepAltRight2 = 0x12,
    kGestureStepAltButtonB = 0x13,
    kGestureStepAltComplete = 0x14,
};

constexpr int kIdleTimerCap = 6000;
constexpr int kAttractThreshold = 0x492d;
constexpr int kSeReadyThreshold = 5000;
constexpr int kShotSoftThreshold = 0x360a;

constexpr int kSwingFullTurn = 0x168;
constexpr double kSwingPhaseSquaredLimit = 129600.0; // @ghidraAddress 0x2f8580
constexpr double kSwingIdleDecay = 1.1;              // @ghidraAddress 0x2f8588

constexpr float kGlowPhaseWrap = 1000.0f;      // @ghidraAddress 0x2f8540
constexpr float kGlowPhaseWrapStep = -1000.0f; // @ghidraAddress 0x2f8544
constexpr int kExitPhaseBoost = 5;

constexpr float kFullColor = 255.0f; // @ghidraAddress 0x2eed00
constexpr float kOne = 1.0f;

constexpr int kGlowCurvePairCount = 3;

constexpr unsigned int kPartGlow = 0x5e;
constexpr unsigned int kPartGlowOverlay = 0x5f;

constexpr float kFlickThreshold = 25.0f; // Pixels.

constexpr int kCampaignPortraitCount = 6;
constexpr unsigned int kPartCampaignMain = 0x62;
constexpr unsigned int kCampaignSubColor = 128;
constexpr float kPortraitFitReference = 320.0f; // @ghidraAddress 0x2f8558
constexpr float kPortraitRowRise = 80.0f;       // @ghidraAddress 0x2f855c
constexpr float kPortraitBaseY = 1020.0f;       // @ghidraAddress 0x2f8560
constexpr float kPortraitCentreX = 384.0f;      // @ghidraAddress 0x2f8550
constexpr float kPortraitMainX = 389.0f;

constexpr int kAnim01Count = 2;
constexpr int kAnim01Stride = 12;
constexpr unsigned int kAnim01Base = 1;
constexpr unsigned int kPartAttractHint = 0x4b;
constexpr unsigned int kPartTitleLogo = 0x60;

constexpr int kSoundEffectExit = 0x10;
constexpr float kFadeComplete = 1.0f;

// @ghidraAddress 0x2ee910
constexpr float kTitleMusicFadeInDuration = 0.3f; // Seconds.

constexpr int kNoTouch = -1;

constexpr S_VECTOR2 kLogoPosition{389.0f, 823.0f};

// @ghidraAddress 0x2f9940
constexpr float kGlowAlphaCurve[] = {0.0f, 0.0f, 500.0f, 1.0f, 1000.0f, 0.0f};

constexpr float kExitFadeTo = 1.0f;
constexpr float kExitFadeDuration = 2700.0f;
constexpr float kExitFadeElapsed = 0.0f;
constexpr float kExitFadeStartDelay = 2400.0f;
} // namespace

namespace rb {

/** @ghidraAddress 0x2fc2c0 */
const S_VECTOR2 g_aTitleCampaignPartAnchor[] = {
    {166.0f, 373.0f},
    {229.0f, 283.0f},
    {334.0f, 232.0f},
    {438.0f, 232.0f},
    {541.0f, 284.0f},
    {606.0f, 374.0f},
    {606.0f, 558.0f},
    {541.0f, 651.0f},
    {435.0f, 700.0f},
    {331.0f, 704.0f},
    {230.0f, 655.0f},
    {165.0f, 560.0f},
};

/** @ghidraAddress 0x572e4 */
TitleColetteScene::TitleColetteScene() {
    m_flFadeValue = kInitialFadeValue;
    m_nActiveTouchId = kNoTouchId;
    for (int nPart = 0; nPart < kPartAnchorCount; ++nPart) {
        m_aPartAnchor[nPart] = g_aTitleCampaignPartAnchor[nPart];
    }
}

/** @ghidraAddress 0x57558 */
void TitleColetteScene::LoadResources() {
    m_nIdleTimer = 0;
    m_nSeTimer = 0;

    NSString *campaignName = RBCampaignData.sharedInstance.campaignName;
    NSString *campaignTexture =
        (campaignName != nil) ?
            [NSString
                stringWithFormat:kCampaignTextureFormat, campaignName, kCampaignTextureFallback] :
            kCampaignTextureFallback;

    m_apTextures[0] = ne::C_TEXTURE::FindOrLoadCached(kTitleTextureNames[0]);
    m_apTextures[1] = ne::C_TEXTURE::FindOrLoadCached(kTitleTextureNames[1]);
    m_apTextures[2] = ne::C_TEXTURE::FindOrLoadCached(kTitleTextureNames[2]);
    m_apTextures[3] = ne::C_TEXTURE::FindOrLoadCached(campaignTexture.UTF8String);

    const TitlePartLayoutRecord *pLayout =
        IsPad() ? g_aTitleCampaignLayoutAltFrame : g_aTitleCampaignLayoutDefault;
    for (int nSlot = 0; nSlot < kSpriteSlotCount; ++nSlot) {
        ne::C_SPRITE_INSTANCING_2D *pSprite = ne::CreateSpriteInstancer(1);
        pSprite->RegisterGlobal();
        pSprite->SetVisible(true);
        if (pLayout[nSlot].nTextureIndex != kNoTextureIndex) {
            pSprite->SetRefCountedMember(m_apTextures[pLayout[nSlot].nTextureIndex]);
        }
        pSprite->SetSpriteCount(m_aSpriteCount[nSlot]);
        m_apSprites[nSlot] = pSprite;
    }

    [RBBGMManager.getInstance LoadMusicTitleWithLoop:NO];
    SoundEffectManager::GetInstance()->LoadThemedVoiceData(kTitleVoiceId);
    m_nReadyDelay = kReadyDelay;
    ShotSoundManager::GetInstance()->LoadSlotVariants(GameSystem::GetGameSystem()->GetShotType());

    m_flFadeFrom = m_flFadeValue;
    m_flFadeTo = 0.0f;
    m_flFadeDuration = kFadeDuration;
    m_flFadeElapsed = 0.0f;
    m_flFadeStartDelay = 0.0f;

    const RBUserSettingDataTheme themaID = RBUserSettingData.sharedInstance.thema;
    NSString *seName = [NSString stringWithFormat:kTitleSeFormat,
                                                  [RBUserSettingData themaNameWithID:themaID],
                                                  kTitleSePartName];
    NSString *sePath = [NSBundle.mainBundle pathForResource:seName ofType:kTitleSeType];
    m_pSePlayer = [[SePlayer alloc] initWithPath:sePath];

    m_nState = kStateStartMusic;
}

void TitleColetteScene::RecordPartHitBox(unsigned int nPartId,
                                         const S_VECTOR2 &drawPosition,
                                         const TitlePartLayoutRecord &layout) {
    const float flLeft = drawPosition.x - layout.flPosX;
    const float flTop = drawPosition.y - layout.flPosY;

    int nSlot;
    switch (nPartId) {
    case kPartLetterA:
        nSlot = kHitBoxLetterA;
        break;
    case kPartLetterD:
        nSlot = kHitBoxLetterD;
        break;
    case kPartLetterF:
        nSlot = kHitBoxLetterF;
        break;
    case kPartLetterG:
        nSlot = kHitBoxLetterG;
        break;
    case kPartLetterI:
        nSlot = kHitBoxLetterI;
        break;
    case kPartSoundEffect:
        nSlot = kHitBoxSoundEffect;
        break;
    case kPartCorporateLogo:
        if (!IsPad()) {
            m_aHitBox[kHitBoxCorporateLogo] = TitleHitRect{flLeft + kCorporateHitOffsetX,
                                                           flTop + kCorporateHitOffsetY,
                                                           layout.flWidth + kCorporateHitGrowX,
                                                           layout.flHeight + kCorporateHitGrowY};
            return;
        }
        nSlot = kHitBoxCorporateLogo;
        break;
    default:
        return;
    }
    m_aHitBox[nSlot] = TitleHitRect{flLeft, flTop, layout.flWidth, layout.flHeight};
}

/** @ghidraAddress 0x599e0 */
void TitleColetteScene::EmitPartSprite(unsigned int nPartId,
                                       unsigned int nAlpha,
                                       const S_VECTOR2 &position,
                                       const S_VECTOR2 &scale,
                                       float flRotation,
                                       const S_VECTOR3 &color) {
    if (nPartId >= static_cast<unsigned int>(kSpriteSlotCount)) {
        return;
    }
    ne::C_SPRITE_INSTANCING_2D *pSprite = m_apSprites[nPartId];
    const int nIndex = pSprite->GetSpriteCount();
    if (nIndex >= static_cast<int>(pSprite->GetCapacity())) {
        return;
    }

    if (nPartId == kBackgroundPartId) {
        const ne::C_TEXTURE *pTexture = pSprite->GetBoundTexture();
        const float flScale = pTexture->GetScale();
        const float flQuadWidth = static_cast<float>(pTexture->GetImageWidth()) / flScale;
        const float flQuadHeight = static_cast<float>(pTexture->GetImageHeight()) / flScale;
        pSprite->SetSpriteAnchor(nIndex, S_VECTOR2{flQuadWidth * kHalf, flQuadHeight * kHalf});
        pSprite->SetSpriteSize(nIndex, S_VECTOR2{flQuadWidth, flQuadHeight});
        pSprite->SetSpriteUvOrigin(nIndex, S_VECTOR2{0.0f, 0.0f});
        pSprite->SetSpriteUvSize(
            nIndex,
            S_VECTOR2{static_cast<float>(pTexture->GetImageWidth()) / pTexture->GetAllocWidth(),
                      static_cast<float>(pTexture->GetImageHeight()) / pTexture->GetAllocHeight()});
        pSprite->SetSpritePosition(nIndex, position);
        pSprite->SetSpriteScale(nIndex, flScale, flScale);
    } else {
        const bool bIsPad = IsPad();
        const TitlePartLayoutRecord &layout =
            (bIsPad ? g_aTitleCampaignLayoutAltFrame : g_aTitleCampaignLayoutDefault)[nPartId];
        const SpriteUvEntry *pUvTable;
        if (layout.nTextureIndex == kPartTextureIndexCampaign) {
            pUvTable = bIsPad ? g_aTitlePartUvLogoPad : g_aTitlePartUvLogoPhone;
        } else {
            pUvTable = bIsPad ? g_aTitlePartUvLetterPad : g_aTitlePartUvLetterPhone;
        }
        const SpriteUvEntry &uv = pUvTable[layout.nUvIndex];

        pSprite->SetSpriteUvOrigin(nIndex, S_VECTOR2{uv.flOriginU, uv.flOriginV});
        pSprite->SetSpriteUvSize(nIndex, S_VECTOR2{uv.flSizeU, uv.flSizeV});

        S_VECTOR2 drawPosition = position;
        S_VECTOR2 drawScale = scale;
        if (!bIsPad) {
            drawPosition.x = (position.x + kLandscapeOffsetX) * kLandscapeScale * kHalf +
                             m_flViewportWidth * kHalf;
            drawPosition.y = (position.y + kLandscapeOffsetY) * kLandscapeScale * kHalf +
                             m_flViewportHeight * kHalf;
            drawScale.width = scale.width * kHalf;
            drawScale.height = scale.height * kHalf;
        }
        pSprite->SetSpritePosition(nIndex, drawPosition);
        pSprite->SetSpriteAnchor(nIndex, S_VECTOR2{layout.flPosX, layout.flPosY});
        pSprite->SetSpriteSize(nIndex, S_VECTOR2{layout.flWidth, layout.flHeight});
        pSprite->SetSpriteScale(nIndex, drawScale.width, drawScale.height);

        RecordPartHitBox(nPartId, drawPosition, layout);
    }

    pSprite->SetSpriteRotation(nIndex, flRotation);
    const float flReveal = 1.0f - m_flFadeValue;
    pSprite->SetSpriteColor(nIndex,
                            static_cast<unsigned int>(flReveal * color.r),
                            static_cast<unsigned int>(flReveal * color.g),
                            static_cast<unsigned int>(flReveal * color.b),
                            static_cast<unsigned int>(static_cast<float>(nAlpha) * flReveal));
    pSprite->SetSpriteCount(nIndex + 1);
}

/** @ghidraAddress 0x597a8 */
unsigned int TitleColetteScene::AdvanceGestureState(int nInputCode) {
    switch (nInputCode) {
    case kGestureUp:
        if (m_nGestureState != kGestureStepUp1) {
            if (m_nGestureState != kGestureStepNone) {
                break;
            }
            m_nGestureState = kGestureStepUp1;
        }
        m_nGestureState = kGestureStepUp2;
        break;
    case kGestureDown:
        if (m_nGestureState != kGestureStepDown1) {
            if (m_nGestureState != kGestureStepUp2) {
                break;
            }
            m_nGestureState = kGestureStepDown1;
        }
        m_nGestureState = kGestureStepDown2;
        break;
    case kGestureLeft:
        if (m_nGestureState == kGestureStepRight1) {
            m_nGestureState = kGestureStepLeft2;
        } else if (m_nGestureState == kGestureStepDown2) {
            m_nGestureState = kGestureStepLeft1;
        }
        break;
    case kGestureRight:
        if (m_nGestureState == kGestureStepLeft2) {
            m_nGestureState = kGestureStepRight2;
        } else if (m_nGestureState == kGestureStepLeft1) {
            m_nGestureState = kGestureStepRight1;
        }
        break;
    case kGestureButtonA:
        if (m_nGestureState == kGestureStepAltButtonB) {
            m_nGestureState = kGestureStepAltComplete;
            SoundEffectManager::GetInstance()->PlayThemedSoundEffect(kSoundEffectTitleSecret);
            m_bGestureTriggered = true;
            m_bHinabitaMode = !m_bHinabitaMode;
            [RBCampaignData.sharedInstance setHinabitaMode:m_bHinabitaMode];
            m_nIdleTimer = kReplayTimerValue;
            m_nSeTimer = 0;
            m_nSeAccumulator = 0;
            m_nGestureState = kGestureStepNone;
            return 0;
        }
        if (m_nGestureState == kGestureStepButtonB) {
            m_nGestureState = kGestureStepComplete;
            const unsigned int nHandle =
                SoundEffectManager::GetInstance()->PlayThemedSoundEffect(kSoundEffectTitleSwing);
            m_bGestureTriggered = true;
            m_nIdleTimer = kReplayTimerValue;
            const bool bWasSet = m_bSwingToggle;
            m_bSwingToggle = !m_bSwingToggle;
            m_nSwingDelta = bWasSet ? -1 : 1;
            m_nGestureState = kGestureStepNone;
            return nHandle;
        }
        break;
    case kGestureButtonB:
        if (m_nGestureState == kGestureStepAltRight2) {
            m_nGestureState = kGestureStepAltButtonB;
        } else if (m_nGestureState == kGestureStepRight2) {
            m_nGestureState = kGestureStepButtonB;
        }
        break;
    case kGestureAltLeft:
        if (m_nGestureState == kGestureStepAltRight1) {
            m_nGestureState = kGestureStepAltLeft2;
        } else if (m_nGestureState == kGestureStepDown2) {
            m_nGestureState = kGestureStepAltLeft1;
        }
        break;
    case kGestureAltRight:
        if (m_nGestureState == kGestureStepAltLeft2) {
            m_nGestureState = kGestureStepAltRight2;
        } else if (m_nGestureState == kGestureStepAltLeft1) {
            m_nGestureState = kGestureStepAltRight1;
        }
        break;
    default:
        break;
    }
    return 0; // The binary leaves a stale object pointer here; no caller reads it.
}

/** @ghidraAddress 0x58570 */
float TitleColetteScene::ComputeSwingParticleX(float flBaseX, float flBaseY) const {
    const double dx = flBaseX + kSwingPivotX;
    const double dy = flBaseY + kSwingPivotY;
    const double angle = std::atan2(dy, dx) + m_nSwingPhase * kSwingPhaseRadiansPerDegree;
    const double radius = std::sqrt(dx * dx + dy * dy);
    return static_cast<float>(radius * std::cos(static_cast<float>(angle)) + kSwingOriginX);
}

/** @ghidraAddress 0x58610 */
float TitleColetteScene::ComputeSwingParticleY(float flBaseX, float flBaseY) const {
    const double dx = flBaseX + kSwingPivotX;
    const double dy = flBaseY + kSwingPivotY;
    const double angle = std::atan2(dy, dx) + m_nSwingPhase * kSwingPhaseRadiansPerDegree;
    const double radius = std::sqrt(dx * dx + dy * dy);
    return static_cast<float>(radius * std::sin(static_cast<float>(angle)) + kSwingOriginY);
}

/** @ghidraAddress 0x586b0 */
void TitleColetteScene::UpdateFadeProgress(int nDeltaMs) {
    if (m_flFadeElapsed >= m_flFadeDuration) {
        m_flFadeValue = m_flFadeTo;
        return;
    }

    m_flFadeElapsed += static_cast<float>(nDeltaMs);
    if (m_flFadeElapsed < m_flFadeStartDelay) {
        return;
    }
    if (m_flFadeElapsed > m_flFadeDuration) {
        m_flFadeElapsed = m_flFadeDuration;
    }

    float flFraction;
    if (m_flFadeDuration == 0.0f) {
        flFraction = 1.0f;
    } else {
        flFraction =
            (m_flFadeElapsed - m_flFadeStartDelay) / (m_flFadeDuration - m_flFadeStartDelay);
    }
    m_flFadeValue = m_flFadeFrom + flFraction * (m_flFadeTo - m_flFadeFrom);
}

bool TitleColetteScene::IsInsideHitBox(float flX, float flY, const TitleHitRect &box) {
    return box.x <= flX && flX <= box.x + box.width && box.y <= flY && flY <= box.y + box.height;
}

/** @ghidraAddress 0x57ad8 */
void TitleColetteScene::RunMainLoop(int nElapsedMs) {
    const int nDeltaMs = nElapsedMs;

    GameSystem *pGameSystem = GameSystem::GetGameSystem();
    m_flViewportWidth = pGameSystem->GetViewportWidth();
    m_flViewportHeight = pGameSystem->GetViewportHeight();
    m_nIdleTimer += nDeltaMs;
    if (m_nIdleTimer > kAttractThreshold) {
        m_nIdleTimer = kIdleTimerCap;
        m_bAttractMode = true;
    }

    if (m_bHinabitaMode) {
        m_nSeTimer += nDeltaMs;
        if (m_nSeTimer > kSeReadyThreshold) {
            m_bSeReady = true;
        }
        if (!m_bSeTriggered) {
            m_nSeAccumulator = 0;
        } else {
            m_nSeAccumulator += nDeltaMs;
        }
    }

    if (m_bSwingToggle) {
        m_nSwingPhase += m_nSwingDelta;
        if (kSwingPhaseSquaredLimit <=
            static_cast<double>(m_nSwingPhase) * static_cast<double>(m_nSwingPhase)) {
            m_nSwingPhase -= kSwingFullTurn;
        }
    } else if (m_nSwingPhase != 0) {
        m_nSwingPhase = static_cast<int>(static_cast<double>(m_nSwingPhase) / kSwingIdleDecay);
    }
    if (m_nSwingPhase != 0) {
        for (int nPart = 0; nPart < kPartAnchorCount; ++nPart) {
            const S_VECTOR2 &anchor = m_aPartAnchor[nPart];
            m_aSwingParticle[nPart].x = ComputeSwingParticleX(anchor.x, anchor.y);
            m_aSwingParticle[nPart].y = ComputeSwingParticleY(m_aSwingParticle[nPart].x, anchor.y);
        }
    }

    for (ne::C_SPRITE_INSTANCING_2D *pSprite : m_apSprites) {
        pSprite->SetSpriteCount(0);
    }

    if (m_nReadyDelay > 0) {
        m_nReadyDelay -= nDeltaMs;
        if (m_nReadyDelay < 1) {
            SoundEffectManager::GetInstance()->PlayThemedVoice(0);
        }
    }

    UpdateFadeProgress(nDeltaMs);
    EmitPartSprite(kBackgroundPartId,
                   0xff,
                   S_VECTOR2{m_flViewportWidth * 0.5f, m_flViewportHeight * 0.5f},
                   S_VECTOR2{kOne, kOne},
                   0.0f,
                   S_VECTOR3{kFullColor, kFullColor, kFullColor});
    RenderSprites();
    EmitPartSprite(kPartCorporateLogo,
                   0xff,
                   kLogoPosition,
                   S_VECTOR2{kOne, kOne},
                   0.0f,
                   S_VECTOR3{kFullColor, kFullColor, kFullColor});

    m_flGlowPhase += static_cast<float>(nDeltaMs);
    if (m_bExiting) {
        m_flGlowPhase += static_cast<float>(nDeltaMs * kExitPhaseBoost);
    }
    while (m_flGlowPhase >= kGlowPhaseWrap) {
        m_flGlowPhase += kGlowPhaseWrapStep;
    }
    const float flGlowAlpha =
        CalculateCurveInterpolation(kGlowAlphaCurve, kGlowCurvePairCount, m_flGlowPhase);
    EmitPartSprite(kPartGlow,
                   static_cast<unsigned int>(flGlowAlpha * kFullColor),
                   kLogoPosition,
                   S_VECTOR2{kOne, kOne},
                   0.0f,
                   S_VECTOR3{kFullColor, kFullColor, kFullColor});
    EmitPartSprite(kPartGlowOverlay,
                   0xff,
                   kLogoPosition,
                   S_VECTOR2{kOne, kOne},
                   0.0f,
                   S_VECTOR3{kFullColor, kFullColor, kFullColor});

    if (m_bHinabitaMode && RBCampaignData.sharedInstance.isCampaignHinabita201703 &&
        m_flViewportWidth < m_flViewportHeight) {
        RenderCampaignPortrait();
    }

    if (!m_bExiting) {
        ProcessTitleTouch();
    }

    if (m_bExiting && m_flFadeValue >= kFadeComplete) {
        m_nState = kStateFinish;
    }
}

void TitleColetteScene::BeginExit() {
    m_flFadeFrom = m_flFadeValue;
    m_flFadeTo = kExitFadeTo;
    m_flFadeDuration = kExitFadeDuration;
    m_flFadeElapsed = kExitFadeElapsed;
    m_flFadeStartDelay = kExitFadeStartDelay;
    [RBBGMManager.getInstance StopMusic:1.0f];
    m_bExiting = true;
    SoundEffectManager::GetInstance()->PlayThemedSoundEffect(kSoundEffectExit);
    [AppDelegate.appDelegate.viewController fadeCorporateButton:0.0f];
}

void TitleColetteScene::ProcessTitleTouch() {
    TouchManager *pTouchManager = TouchManager::FetchSharedSingleton();

    if (m_nActiveTouchId != kNoTouch) {
        TouchPoint *pTouch = pTouchManager->FindTouchById(m_nActiveTouchId);
        if (pTouch == nullptr) {
            m_nActiveTouchId = kNoTouch;
            return;
        }
        if (!pTouch->bEnded) {
            return;
        }
        m_nActiveTouchId = kNoTouch;
        const float flDx = static_cast<float>(pTouch->nCurrentX - pTouch->nBeginX);
        const float flDy = static_cast<float>(pTouch->nCurrentY - pTouch->nBeginY);
        const float flAbsX = flDx <= 0.0f ? -flDx : flDx;
        const float flAbsY = flDy <= 0.0f ? -flDy : flDy;

        int nNextStep;
        if (flAbsX <= flAbsY) {
            if (flDy <= kFlickThreshold) {
                if (-kFlickThreshold <= flDy) {
                    return;
                }
                if (m_nGestureState != kGestureStepUp1) {
                    if (m_nGestureState != kGestureStepNone) {
                        return;
                    }
                    m_nGestureState = kGestureStepUp1;
                }
                nNextStep = kGestureStepUp2;
            } else {
                if (m_nGestureState != kGestureStepDown1) {
                    if (m_nGestureState != kGestureStepUp2) {
                        return;
                    }
                    m_nGestureState = kGestureStepDown1;
                }
                nNextStep = kGestureStepDown2;
            }
        } else if (flDx <= kFlickThreshold) {
            if (-kFlickThreshold <= flDx) {
                return;
            }
            if (m_nGestureState == kGestureStepRight1) {
                nNextStep = kGestureStepLeft2;
            } else {
                if (m_nGestureState != kGestureStepDown2) {
                    return;
                }
                nNextStep = kGestureStepLeft1;
            }
        } else if (m_nGestureState == kGestureStepLeft2) {
            nNextStep = kGestureStepRight2;
        } else {
            if (m_nGestureState != kGestureStepLeft1) {
                return;
            }
            nNextStep = kGestureStepRight1;
        }
        m_nGestureState = nNextStep;
        return;
    }

    if (pTouchManager->GetActiveTouchCount() <= 0) {
        return;
    }
    if (AppDelegate.appDelegate.needUpdateTerms) {
        [AppDelegate.appDelegate showTerms];
        return;
    }
    for (int nIndex = 0; nIndex < pTouchManager->GetActiveTouchCount(); ++nIndex) {
        TouchPoint *pTouch = pTouchManager->GetActiveTouch(nIndex);
        if (!pTouch->bIsNew) {
            continue;
        }
        m_nActiveTouchId = pTouch->nId;
        const float flX = static_cast<float>(pTouch->nCurrentX);
        const float flY = static_cast<float>(pTouch->nCurrentY);

        if (m_flFadeValue == 0.0f && IsInsideHitBox(flX, flY, m_aHitBox[kHitBoxCorporateLogo])) {
            BeginExit();
        } else if (IsInsideHitBox(flX, flY, m_aHitBox[kHitBoxLetterD])) {
            if (m_nGestureState == kGestureStepAltRight1) {
                m_nGestureState = kGestureStepAltLeft2;
            } else if (m_nGestureState == kGestureStepDown2) {
                m_nGestureState = kGestureStepAltLeft1;
            }
        } else if (IsInsideHitBox(flX, flY, m_aHitBox[kHitBoxLetterA])) {
            if (m_nGestureState == kGestureStepAltLeft2) {
                m_nGestureState = kGestureStepAltRight2;
            } else if (m_nGestureState == kGestureStepAltLeft1) {
                m_nGestureState = kGestureStepAltRight1;
            }
        } else if (IsInsideHitBox(flX, flY, m_aHitBox[kHitBoxLetterI])) {
            AdvanceGestureState(kGestureButtonA);
        } else if (IsInsideHitBox(flX, flY, m_aHitBox[kHitBoxLetterG])) {
            if (m_nGestureState == kGestureStepAltRight2) {
                m_nGestureState = kGestureStepAltButtonB;
            } else if (m_nGestureState == kGestureStepRight2) {
                m_nGestureState = kGestureStepButtonB;
            }
        } else if (IsInsideHitBox(flX, flY, m_aHitBox[kHitBoxLetterF])) {
            if (m_nIdleTimer < kShotSoftThreshold && !m_bAttractMode) {
                ShotSoundManager::GetInstance()->PlaySlot(
                    1, GameSystem::GetGameSystem()->GetShotType(), 2);
            } else {
                ShotSoundManager::GetInstance()->PlaySlot(
                    1, GameSystem::GetGameSystem()->GetShotType(), 0);
            }
        } else if (IsInsideHitBox(flX, flY, m_aHitBox[kHitBoxVoiceCue])) {
            SoundEffectManager::GetInstance()->PlayThemedVoice(0);
        } else if (m_bSeReady && IsInsideHitBox(flX, flY, m_aHitBox[kHitBoxSoundEffect])) {
            m_bSeTriggered = true;
            m_nSeAccumulator = 0;
            [m_pSePlayer sePlay];
        }
        break;
    }
}

/** @ghidraAddress 0x59474 */
void TitleColetteScene::RenderCampaignPortrait() {
    float flFit;
    if (IsPad()) {
        flFit = 1.0f;
    } else {
        const float flMin =
            m_flViewportWidth < m_flViewportHeight ? m_flViewportWidth : m_flViewportHeight;
        flFit = flMin / kPortraitFitReference;
    }

    S_VECTOR2 aAnchor[kCampaignPortraitCount];
    if (IsPad()) {
        for (int nChar = 0; nChar < kCampaignPortraitCount; ++nChar) {
            aAnchor[nChar] = S_VECTOR2{g_aCampaignPortraitPadAnchor[nChar][0],
                                       g_aCampaignPortraitPadAnchor[nChar][1]};
        }
    } else {
        const float flRowY = flFit * kPortraitRowRise + kPortraitBaseY;
        aAnchor[0] = S_VECTOR2{kPortraitMainX, flRowY};
        for (int nSub = 1; nSub < kCampaignPortraitCount; ++nSub) {
            const float flBaseX = g_aCampaignPortraitPhoneBaseX[nSub - 1];
            aAnchor[nSub] =
                S_VECTOR2{kPortraitCentreX - flFit * (kPortraitCentreX - flBaseX), flRowY};
        }
    }

    if (!m_bSeReady) {
        const float flTime = static_cast<float>(m_nSeTimer);
        const int nMainAlpha = static_cast<int>(
            CalculateCurveInterpolation(g_aCampaignPortraitEntranceAlpha[0], 4, flTime) *
            kFullColor);
        const float flMainScale =
            CalculateCurveInterpolation(g_aCampaignPortraitEntranceScale[0], 6, flTime);
        EmitPartSprite(kPartCampaignMain,
                       static_cast<unsigned int>(nMainAlpha),
                       aAnchor[0],
                       S_VECTOR2{flFit, flFit * flMainScale},
                       0.0f,
                       S_VECTOR3{kFullColor, kFullColor, kFullColor});
        for (int nSub = 1; nSub < kCampaignPortraitCount; ++nSub) {
            const int nAlpha = static_cast<int>(
                CalculateCurveInterpolation(g_aCampaignPortraitEntranceAlpha[nSub], 4, flTime) *
                kFullColor);
            const float flScale =
                CalculateCurveInterpolation(g_aCampaignPortraitEntranceScale[nSub], 6, flTime);
            EmitPartSprite(kPartCampaignMain + static_cast<unsigned int>(nSub),
                           static_cast<unsigned int>(nAlpha),
                           aAnchor[nSub],
                           S_VECTOR2{flFit, flFit * flScale},
                           0.0f,
                           S_VECTOR3{kCampaignSubColor, kCampaignSubColor, kCampaignSubColor});
        }
    } else if (!m_bSeTriggered) {
        EmitPartSprite(kPartCampaignMain,
                       0xff,
                       aAnchor[0],
                       S_VECTOR2{flFit, flFit},
                       0.0f,
                       S_VECTOR3{kFullColor, kFullColor, kFullColor});
    } else {
        const float flTime = static_cast<float>(m_nSeAccumulator);
        const float flScale = CalculateCurveInterpolation(g_aCampaignPortraitReaction, 6, flTime);
        EmitPartSprite(kPartCampaignMain,
                       0xff,
                       aAnchor[0],
                       S_VECTOR2{flFit, flFit * flScale},
                       0.0f,
                       S_VECTOR3{kFullColor, kFullColor, kFullColor});
        if (flTime > kCampaignPortraitReactionEnd) {
            m_bSeTriggered = false;
            m_nSeAccumulator = 0;
        }
    }
}

void TitleColetteScene::EmitAnimatedPart(unsigned int nPartId,
                                         int nPosIndex,
                                         const float *pScaleTable,
                                         int nScaleKnots,
                                         const float *pAlphaTable,
                                         int nAlphaKnots) {
    const S_VECTOR2 &position =
        m_nSwingPhase != 0 ? m_aSwingParticle[nPosIndex] : m_aPartAnchor[nPosIndex];
    const float flTime = static_cast<float>(m_nIdleTimer);
    const float flScale = CalculateCurveInterpolation(pScaleTable, nScaleKnots, flTime);
    const int nAlpha = static_cast<int>(
        CalculateCurveInterpolation(pAlphaTable, nAlphaKnots, flTime) * kFullColor);
    EmitPartSprite(nPartId,
                   static_cast<unsigned int>(nAlpha),
                   position,
                   S_VECTOR2{flScale, flScale},
                   0.0f,
                   S_VECTOR3{kFullColor, kFullColor, kFullColor});
}

void TitleColetteScene::EmitTablePositionedPart(unsigned int nPartId,
                                                const S_VECTOR2 &position,
                                                const float *pScaleTable,
                                                int nScaleKnots,
                                                const float *pAlphaTable,
                                                int nAlphaKnots) {
    const float flTime = static_cast<float>(m_nIdleTimer);
    const float flScale = CalculateCurveInterpolation(pScaleTable, nScaleKnots, flTime);
    const int nAlpha = static_cast<int>(
        CalculateCurveInterpolation(pAlphaTable, nAlphaKnots, flTime) * kFullColor);
    EmitPartSprite(nPartId,
                   static_cast<unsigned int>(nAlpha),
                   position,
                   S_VECTOR2{flScale, flScale},
                   0.0f,
                   S_VECTOR3{kFullColor, kFullColor, kFullColor});
}

/** @ghidraAddress 0x5872c */
void TitleColetteScene::RenderSprites() {
    const int nClock = m_nIdleTimer;

    if (!m_bAttractMode) {
        for (int nSprite = 0; nSprite < kAnim01Count; ++nSprite) {
            const float flTime = static_cast<float>(m_nIdleTimer);
            const float flScale = CalculateCurveInterpolation(
                &g_aTitleAnim01Scale[nSprite * kAnim01Stride], 6, flTime);
            const int nAlpha =
                static_cast<int>(CalculateCurveInterpolation(
                                     &g_aTitleAnim01Alpha[nSprite * kAnim01Stride], 6, flTime) *
                                 kFullColor);
            EmitPartSprite(kAnim01Base + static_cast<unsigned int>(nSprite),
                           static_cast<unsigned int>(nAlpha),
                           S_VECTOR2{g_aTitleAnim01Pos[nSprite][0], g_aTitleAnim01Pos[nSprite][1]},
                           S_VECTOR2{flScale, flScale},
                           0.0f,
                           S_VECTOR3{kFullColor, kFullColor, kFullColor});
        }
    }

    if (static_cast<unsigned int>(nClock - 0x353) < 0xa6a) {
        for (int i = 0; i < 12; ++i) {
            EmitAnimatedPart(
                0x3 + i, i, &g_aTitleAnim02Scale[i * 6], 3, &g_aTitleAnim02Alpha[i * 4], 2);
        }
    }
    if (static_cast<unsigned int>(m_nIdleTimer - 0x1a0b) < 0x960) {
        for (int i = 0; i < 12; ++i) {
            EmitAnimatedPart(
                0xf + i, i, &g_aTitleAnim03Scale[i * 6], 3, &g_aTitleAnim03Alpha[i * 4], 2);
        }
    }
    if (static_cast<unsigned int>(m_nIdleTimer - 0x2f45) < 0x6e6) {
        for (int i = 0; i < 12; ++i) {
            EmitAnimatedPart(
                0x1b + i, i, &g_aTitleAnim04Scale[i * 6], 3, &g_aTitleAnim04Alpha[i * 4], 2);
        }
    }
    // @ghidraAddress 0x58be8
    if (m_nIdleTimer > 0xa6) {
        for (int i = 0; i < 10; ++i) {
            EmitTablePositionedPart(0x41 + static_cast<unsigned int>(i),
                                    S_VECTOR2{g_aTitleLetterPos[i][0], g_aTitleLetterPos[i][1]},
                                    &g_aTitleAnim05Scale[i * 0x3a],
                                    0x1d,
                                    &g_aTitleAnim05Alpha[i * 4],
                                    2);
        }
    }

    // @ghidraAddress 0x58c8c
    if (static_cast<unsigned int>(m_nIdleTimer - 0xa7) < 0x1a0b) {
        for (int i = 0; i < 6; ++i) {
            // Row zero is dead data; the binary reads rows one through six.
            const int nRow = i + 1;
            const float flScale = CalculateCurveInterpolation(
                &g_aTitleAnim06Curve[nRow * 0xe], 7, static_cast<float>(m_nIdleTimer));
            EmitPartSprite(0x50 + static_cast<unsigned int>(i),
                           0xff,
                           S_VECTOR2{g_aTitleAnim06Pos[nRow][0], g_aTitleAnim06Pos[nRow][1]},
                           S_VECTOR2{flScale, flScale},
                           0.0f,
                           S_VECTOR3{kFullColor, kFullColor, kFullColor});
        }
    }

    // @ghidraAddress 0x58d64
    if (m_nIdleTimer > 0xa6) {
        for (int i = 0; i < 6; ++i) {
            // Row zero is dead data here too, and the position table above is shared.
            const int nRow = i + 1;
            EmitTablePositionedPart(
                0x57 + static_cast<unsigned int>(i),
                S_VECTOR2{g_aTitleAnim06Pos[nRow][0], g_aTitleAnim06Pos[nRow][1]},
                &g_aTitleAnim07Scale[nRow * 0x2a],
                0x15,
                &g_aTitleAnim07Alpha[nRow * 4],
                2);
        }
    }

    // @ghidraAddress 0x58d90
    if (m_nIdleTimer > 0xa6 && !m_bAttractMode) {
        for (int i = 0; i < 4; ++i) {
            const float flTime = static_cast<float>(m_nIdleTimer);
            const float flPosX = CalculateCurveInterpolation(&g_aTitleAnim08A[i * 6], 3, flTime);
            const float flPosY = CalculateCurveInterpolation(&g_aTitleAnim08B[i * 6], 3, flTime);
            const int nAlpha = static_cast<int>(
                CalculateCurveInterpolation(&g_aTitleAnim08C[i * 6], 3, flTime) * kFullColor);
            const float flScale = CalculateCurveInterpolation(&g_aTitleAnim08D[i * 4], 2, flTime);
            EmitPartSprite(0x4b + static_cast<unsigned int>(i),
                           static_cast<unsigned int>(nAlpha),
                           S_VECTOR2{flPosX, flPosY},
                           S_VECTOR2{flScale, flScale},
                           0.0f,
                           S_VECTOR3{kFullColor, kFullColor, kFullColor});
        }
    } else if (m_bAttractMode) {
        EmitPartSprite(kPartAttractHint,
                       0xff,
                       S_VECTOR2{g_aTitleHintPos[0], g_aTitleHintPos[1]},
                       S_VECTOR2{kOne, kOne},
                       0.0f,
                       S_VECTOR3{kFullColor, kFullColor, kFullColor});
    }

    if (static_cast<unsigned int>(m_nIdleTimer - 0x353) < 0x127d) {
        for (int i = 0; i < 12; ++i) {
            EmitAnimatedPart(
                0x33 + i, i, &g_aTitleAnim09Scale[i * 10], 5, &g_aTitleAnim09Alpha[i * 0xc], 6);
        }
    }
    if (static_cast<unsigned int>(m_nIdleTimer - 0x1817) < 0x1953) {
        for (int i = 0; i < 12; ++i) {
            EmitAnimatedPart(
                0x33 + i, i, &g_aTitleAnim10Scale[i * 0x10], 8, &g_aTitleAnim10Alpha[i * 0x10], 8);
        }
    }
    if ((static_cast<unsigned int>(m_nIdleTimer - 0x353) >> 1) < 0xdff) {
        for (int i = 0; i < 12; ++i) {
            EmitAnimatedPart(
                0x27 + i, i, &g_aTitleAnim11Scale[i * 0x20], 0x10, &g_aTitleAnim11Alpha[i * 4], 2);
        }
    }
    if (m_nIdleTimer > 0x1816) {
        for (int i = 0; i < 12; ++i) {
            EmitAnimatedPart(
                0x27 + i, i, &g_aTitleAnim12Scale[i * 0x2a], 0x15, &g_aTitleAnim12Alpha[i * 8], 4);
        }
    }

    if (m_nIdleTimer > 0xa6) {
        for (int i = 0; i < 2; ++i) {
            const float flTime = static_cast<float>(m_nIdleTimer);
            const float flRotation =
                // Both sprites share row zero; the binary applies no per-sprite stride here.
                CalculateCurveInterpolation(g_aTitleAnim13Rotation, 0xa, flTime);
            const int nAlpha = static_cast<int>(
                CalculateCurveInterpolation(g_aTitleAnim13Alpha, 2, flTime) * kFullColor);
            EmitPartSprite(0x3f + static_cast<unsigned int>(i),
                           static_cast<unsigned int>(nAlpha),
                           S_VECTOR2{g_aTitleAnim13Pos[i][0], g_aTitleAnim13Pos[i][1]},
                           S_VECTOR2{kOne, kOne},
                           flRotation,
                           S_VECTOR3{kFullColor, kFullColor, kFullColor});
        }
    }

    const int nLogoAlpha = static_cast<int>(
        CalculateCurveInterpolation(g_aTitleAnim14, 2, static_cast<float>(m_nIdleTimer)) *
        kFullColor);
    EmitPartSprite(kPartTitleLogo,
                   static_cast<unsigned int>(nLogoAlpha),
                   S_VECTOR2{g_aTitleLogoPos[0], g_aTitleLogoPos[1]},
                   S_VECTOR2{kOne, kOne},
                   0.0f,
                   S_VECTOR3{kFullColor, kFullColor, kFullColor});
}

/** @ghidraAddress 0x57a64 */
void TitleColetteScene::StartMusic() {
    m_nState = kStateMainLoop;
    [RBBGMManager.getInstance PlayMusic:kTitleMusicFadeInDuration];
    m_bSeTriggered = false;
}

/** @ghidraAddress 0x57440 */
void TitleColetteScene::ReleaseResources() {
    for (ne::C_TEXTURE *&pTexture : m_apTextures) {
        if (pTexture != nullptr) {
            pTexture->Release();
            pTexture = nullptr;
        }
    }
    // The scene graph owns the part sprites, so they are flagged rather than deleted.
    for (ne::C_SPRITE_INSTANCING_2D *&pSprite : m_apSprites) {
        if (pSprite != nullptr) {
            pSprite->RequestDelete();
            pSprite = nullptr;
        }
    }
    if (m_pSePlayer != nil) {
        [m_pSePlayer terminate];
        m_pSePlayer = nil;
    }
}

/**
 * @ghidraAddress 0x574d8
 * @ghidraAddress 0x574dc
 */
TitleColetteScene::~TitleColetteScene() {
    ReleaseResources();
}

/** @ghidraAddress 0x57514 */
void TitleColetteScene::OnFrame(int nElapsedMs) {
    switch (m_nState) {
    case kStateLoad:
        LoadResources();
        return;
    case kStateStartMusic:
        StartMusic();
        return;
    case kStateMainLoop:
        RunMainLoop(nElapsedMs);
        return;
    case kStateFinish:
        FinishAndOpenList();
        return;
    default:
        return;
    }
}

/** @ghidraAddress 0x58478 */
void TitleColetteScene::FinishAndOpenList() {
    if (![AudioManager.sharedManager isStart]) {
        return;
    }
    ReleaseResources();
    rb::GameScene::GetInstance(GameSystem::GetGameSystem()->GetCurrentSceneSlot());
    [AppDelegate.appDelegate.viewController showMusicListView];
    MarkDead();
}

} // namespace rb
