//
//  titlecolettescene.mm
//  REFLEC BEAT plus
//
//  The theme-2 (Colette) title-screen scene, rb::TitleColetteScene. Reconstructed from Ghidra
//  project rb458, program rb458. @ghidraAddress values are relative to the program image base.
//

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
#include "neDebugLog.h"
#include "neSpriteInstancing.h"
#include "neTexture.h"
#include "shotsoundmanager.h"
#include "soundeffectmanager.h"
#include "title_anim_table.h"
#include "touch_point.h"
#include "touchmanager.h"

namespace {
// The dispatch states OnFrame selects between: load resources, start the music, run the main loop,
// then finish and open the music list.
constexpr int kStateLoad = 0;
constexpr int kStateStartMusic = 1;
constexpr int kStateMainLoop = 2;
constexpr int kStateFinish = 3;

// The scene starts fully hidden (fade value one, reveal zero), with no touch tracked.
constexpr float kInitialFadeValue = 1.0f;
constexpr int kNoTouchId = -1;

// The three shared title texture base names; the fourth cached texture is the campaign-specific
// one.
constexpr const char *kTitleTextureNames[] = {
    "00_texture/ti_bg",
    "00_texture/ti_parts",
    "00_texture/ti_parts_eff",
};
// The fallback campaign texture name used when no campaign is active.
static NSString *const kCampaignTextureFallback = @"00_texture/title_campaign";
// The format building the campaign-specific texture path from the campaign name.
static NSString *const kCampaignTextureFormat = @"%@/%@";
// The layout texture index that marks a part binding no texture.
constexpr int kNoTextureIndex = 5;
// The voice bank the title screen loads.
constexpr int kTitleVoiceId = 0;
// The start ready-delay timer, in milliseconds.
constexpr int kReadyDelay = 0x708;
// The reveal cross-fade duration, in milliseconds.
constexpr float kFadeDuration = 300.0f;

// The theme sound-effect path format and its two components' file type.
static NSString *const kTitleSeFormat = @"Sounds/%@/SE/SD_SE_%@";
static NSString *const kTitleSeType = @"m4a";
// The part name spliced into the theme sound-effect path (@ghidraAddress 0x35dca8).
static NSString *const kTitleSePartName = @"JUMP";

// The background part fills the screen from its texture.
constexpr unsigned int kBackgroundPartId = 0;
// The campaign-portrait parts (ids 0x62 to 0x67) are the only ones binding the campaign texture, in
// both layout tables, and it doubles as their UV-table selector. The title letters bind texture 1,
// so this index never selects them despite the name it used to carry.
constexpr int kPartTextureIndexCampaign = 3;

// The landscape layout recentres each part around the viewport: it offsets by half the design
// resolution, scales to 0.8, halves, and adds the viewport centre.
constexpr float kLandscapeOffsetX = -384.0f; // @ghidraAddress 0x2f8568
constexpr float kLandscapeOffsetY = -512.0f; // @ghidraAddress 0x2f8570
constexpr float kLandscapeScale = 0.8f;      // @ghidraAddress 0x2f856c
constexpr float kHalf = 0.5f;

// The corporate-logo part's landscape hit-box is nudged and grown relative to its sprite.
constexpr float kCorporateHitOffsetX = -40.0f; // @ghidraAddress 0x2f8574
constexpr float kCorporateHitOffsetY = -30.0f;
constexpr float kCorporateHitGrowX = 80.0f; // @ghidraAddress 0x2f855c
constexpr float kCorporateHitGrowY = 60.0f; // @ghidraAddress 0x2f8578

// The part ids that carry a touch hit-box, and the hit-box slot each records into. The main loop's
// hit-test cascade shows slot 0 (the corporate logo) starts the exit and slot 7 plays the
// sound-effect jingle.
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
    // Slot 6 is tested by the touch loop but never written by the emitter, so it stays a zero rect
    // and its branch plays the themed voice cue.
    kHitBoxVoiceCue = 6,
    kHitBoxSoundEffect = 7,
};

// The title-logo swing pivot the particle rest positions are measured against, and the screen
// origin their rotated positions are offset back to.
constexpr double kSwingPivotX = -384.0; // @ghidraAddress 0x2f8590
constexpr double kSwingPivotY = -467.0; // @ghidraAddress 0x2f8598
constexpr double kSwingOriginX = 384.0; // @ghidraAddress 0x2f85a8
constexpr double kSwingOriginY = 467.0; // @ghidraAddress 0x2f85b0
// The swing phase, in degrees, is scaled to radians before rotating.
constexpr double kSwingPhaseRadiansPerDegree = M_PI / 180.0;

// The themed sound-effect slots the completed gesture sequences fire.
constexpr int kSoundEffectTitleSecret = 0xd;
constexpr int kSoundEffectTitleSwing = 0xe;
// The idle timer value a completed gesture rewinds to.
constexpr int kReplayTimerValue = 0x24fa;

// The directional gesture inputs the touch handling classifies from flick direction. The main
// sequence is the Konami code; the alternate branch is left/right/left/right then B, A.
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

// The progress steps through the gesture sequences.
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

// The idle timer caps at this value and flags attract mode once it passes the attract threshold.
constexpr int kIdleTimerCap = 6000;
constexpr int kAttractThreshold = 0x492d;
// The sound-effect timer flags the sound-effect-ready state past this value.
constexpr int kSeReadyThreshold = 5000;
// Below this idle time the shot-sound plays its softer variant; at or past it the louder one.
constexpr int kShotSoftThreshold = 0x360a;

// The swing animation steps by the phase velocity, rewinds by a full turn past the squared limit,
// and idles toward zero by the reciprocal decay when released.
constexpr int kSwingFullTurn = 0x168;
constexpr double kSwingPhaseSquaredLimit = 129600.0; // @ghidraAddress 0x2f8580
constexpr double kSwingIdleDecay = 1.1;              // @ghidraAddress 0x2f8588

// The cycling glow phase wraps within [0, kGlowPhaseWrap); the exit fade accelerates it fivefold.
constexpr float kGlowPhaseWrap = 1000.0f;      // @ghidraAddress 0x2f8540
constexpr float kGlowPhaseWrapStep = -1000.0f; // @ghidraAddress 0x2f8544
constexpr int kExitPhaseBoost = 5;

// The background/logo/glow draw uses fully opaque white; the glow's alpha comes from a curve.
constexpr float kFullColor = 255.0f; // @ghidraAddress 0x2eed00
constexpr float kOne = 1.0f;

// The glow alpha curve (pairs of {phase, alpha}) and its pair count.
constexpr int kGlowCurvePairCount = 3;

// The glow and glow-overlay part ids drawn on top of the logo (kPartCorporateLogo).
constexpr unsigned int kPartGlow = 0x5e;
constexpr unsigned int kPartGlowOverlay = 0x5f;

// The flick classification threshold, in pixels.
constexpr float kFlickThreshold = 25.0f;

// The Hinabita campaign portrait layer: the main portrait plus five sub-characters, fit-scaled to
// the screen against a reference width, arranged on a row that rises with the fit.
constexpr int kCampaignPortraitCount = 6;
constexpr unsigned int kPartCampaignMain = 0x62;
constexpr unsigned int kCampaignSubColor = 128;
constexpr float kPortraitFitReference = 320.0f; // @ghidraAddress 0x2f8558
constexpr float kPortraitRowRise = 80.0f;       // @ghidraAddress 0x2f855c
constexpr float kPortraitBaseY = 1020.0f;       // @ghidraAddress 0x2f8560
constexpr float kPortraitCentreX = 384.0f;      // @ghidraAddress 0x2f8550
constexpr float kPortraitMainX = 389.0f;

// The attract intro animation (window one): two sprites (part ids one and two) with six-knot scale
// and alpha curves laid out twelve floats apart.
constexpr int kAnim01Count = 2;
constexpr int kAnim01Stride = 12;
constexpr unsigned int kAnim01Base = 1;
// The standalone attract-hint and title-logo sprite part ids.
constexpr unsigned int kPartAttractHint = 0x4b;
constexpr unsigned int kPartTitleLogo = 0x60;

// The exit sound effect and the value the fade reaches to advance to the finish state.
constexpr int kSoundEffectExit = 0x10;
constexpr float kFadeComplete = 1.0f;

// The fade-in duration, in seconds, the title BGM starts playing over. @ghidraAddress 0x2ee910
constexpr float kTitleMusicFadeInDuration = 0.3f;

// The sentinel that no touch is being tracked.
constexpr int kNoTouch = -1;

// The logo and glow draw position (seeded once through a guarded static in the binary).
constexpr S_VECTOR2 kLogoPosition{389.0f, 823.0f};

// The glow's alpha curve: a triangular pulse over the cycling phase, peaking at the midpoint.
// @ghidraAddress 0x2f9940
constexpr float kGlowAlphaCurve[] = {0.0f, 0.0f, 500.0f, 1.0f, 1000.0f, 0.0f};

// The exit cross-fade the corporate-logo tap starts: ease to fully hidden over its duration after a
// start delay. Its four components come from a binary constant ({to, duration} then {elapsed,
// start-delay} after a NEON lane swap).
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
    // The UI-layer base constructor ran first and the compiler installed the title dispatch vtable;
    // every presentation field is otherwise zeroed by its member initialiser. Seed the two non-zero
    // scalars (the fade starts fully hidden and no touch is tracked) and copy the part anchor ring
    // into place.
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

    // Resolve the campaign-specific title texture name: when a campaign is active its name prefixes
    // the base path, otherwise the bare fallback is used.
    NSString *campaignName = RBCampaignData.sharedInstance.campaignName;
    NSString *campaignTexture =
        (campaignName != nil) ?
            [NSString
                stringWithFormat:kCampaignTextureFormat, campaignName, kCampaignTextureFallback] :
            kCampaignTextureFallback;

    // Cache the four title textures: the three shared layers plus the campaign layer.
    m_apTextures[0] = ne::C_TEXTURE::FindOrLoadCached(kTitleTextureNames[0]);
    m_apTextures[1] = ne::C_TEXTURE::FindOrLoadCached(kTitleTextureNames[1]);
    m_apTextures[2] = ne::C_TEXTURE::FindOrLoadCached(kTitleTextureNames[2]);
    m_apTextures[3] = ne::C_TEXTURE::FindOrLoadCached(campaignTexture.UTF8String);

    // Build the 104 part sprite instancers: register each in the global scene tree, make it
    // visible, bind its texture from the layout table (unless the part binds none), and seed its
    // sprite count.
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

    // Start the title BGM and load the title voice and shot-sound banks, then arm the ready-delay.
    [RBBGMManager.getInstance LoadMusicTitleWithLoop:NO];
    SoundEffectManager::GetInstance()->LoadThemedVoiceData(kTitleVoiceId);
    m_nReadyDelay = kReadyDelay;
    ShotSoundManager::GetInstance()->LoadSlotVariants(GameSystem::GetGameSystem()->GetShotType());

    // Seed the reveal cross-fade: ease from the current value to zero (fully shown) over the fade
    // duration, with no start delay.
    m_flFadeFrom = m_flFadeValue;
    m_flFadeTo = 0.0f;
    m_flFadeDuration = kFadeDuration;
    m_flFadeElapsed = 0.0f;
    m_flFadeStartDelay = 0.0f;

    // Create the theme's sound-effect player from the theme-named SE path.
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
    // The hit-box's top-left corner is the draw position offset back by the layout anchor.
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
        // The corporate-logo part in the landscape layout uses a nudged, grown hit-box; the
        // portrait layout uses the plain rectangle.
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
        // The remaining parts carry no hit-box.
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
        // The background fills the screen from its texture: the quad is the image size divided by
        // the texture scale, anchored at its centre, with the UV covering the image within its
        // power-of-two allocation.
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
        // The other parts take their placement from the platform layout table and their UV
        // rectangle from the type-specific atlas table.
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

        // The landscape layout recentres the part around the viewport; the portrait layout draws it
        // at the caller's position directly.
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

        // RBPDBG: this is the theme that actually runs, so record what the mapping is handed and
        // what it produces for the logo. The pad path leaves the caller's position untouched while
        // the other centres on the viewport, which is the asymmetry to judge against these numbers.
        if (layout.nTextureIndex == kPartTextureIndexCampaign && NE_DBG_FIRST(4)) {
            neDebugLog("colettePart id=%u isPad=%d tex=%d viewport=%.0fx%.0f",
                       nPartId,
                       bIsPad ? 1 : 0,
                       layout.nTextureIndex,
                       m_flViewportWidth,
                       m_flViewportHeight);
            neDebugLog("  in pos=(%.1f,%.1f) scale=(%.2f,%.2f) record anchor=(%.1f,%.1f) "
                       "size=(%.1fx%.1f)",
                       position.x,
                       position.y,
                       scale.width,
                       scale.height,
                       layout.flPosX,
                       layout.flPosY,
                       layout.flWidth,
                       layout.flHeight);
            neDebugLog("  out pos=(%.1f,%.1f) scale=(%.2f,%.2f) topLeft=(%.1f,%.1f)",
                       drawPosition.x,
                       drawPosition.y,
                       drawScale.width,
                       drawScale.height,
                       drawPosition.x - layout.flPosX,
                       drawPosition.y - layout.flPosY);
        }

        // The touchable parts record their hit-box (top-left corner and extent) for the main loop.
        RecordPartHitBox(nPartId, drawPosition, layout);
    }

    pSprite->SetSpriteRotation(nIndex, flRotation);
    // The tint is scaled by the reveal (one minus the fade value): as the fade eases toward zero
    // the parts brighten in and the alpha rises.
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
            // Completing the alternate branch toggles the hidden Hinabita campaign mode.
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
            // Completing the main code toggles the swing direction and returns the sound handle.
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
    // No sound handle was produced this step. (On these paths the binary leaves its object pointer
    // in the return register; no caller reads it, so a plain 0 is faithful to observed behaviour.)
    return 0;
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
    // Once the fade has run its full duration, hold the end value.
    if (m_flFadeElapsed >= m_flFadeDuration) {
        m_flFadeValue = m_flFadeTo;
        return;
    }

    m_flFadeElapsed += static_cast<float>(nDeltaMs);
    // The fade only advances once the start delay has elapsed.
    if (m_flFadeElapsed < m_flFadeStartDelay) {
        return;
    }
    if (m_flFadeElapsed > m_flFadeDuration) {
        m_flFadeElapsed = m_flFadeDuration;
    }

    // A zero duration snaps straight to the end; otherwise ease across the post-delay span.
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

    // Cache the viewport size and advance the idle timer, capping it and arming attract mode.
    GameSystem *pGameSystem = GameSystem::GetGameSystem();
    m_flViewportWidth = pGameSystem->GetViewportWidth();
    m_flViewportHeight = pGameSystem->GetViewportHeight();
    m_nIdleTimer += nDeltaMs;
    if (m_nIdleTimer > kAttractThreshold) {
        m_nIdleTimer = kIdleTimerCap;
        m_bAttractMode = true;
    }

    // In the Hinabita campaign, advance the sound-effect timer (arming the ready flag), and once
    // the sound effect has fired, accumulate the elapsed time since.
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

    // Drive the logo swing: while held (m_bSwingToggle) the phase steps by the velocity and rewinds
    // a full turn past the squared limit; when released it idles back toward zero. A non-zero phase
    // rotates each of the twelve swing particles into its animated position.
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

    // Clear every part instancer's sprite count before rebuilding this frame.
    for (ne::C_SPRITE_INSTANCING_2D *pSprite : m_apSprites) {
        pSprite->SetSpriteCount(0);
    }

    // Tick the intro/ready timer; when it expires, play the intro voice.
    if (m_nReadyDelay > 0) {
        m_nReadyDelay -= nDeltaMs;
        if (m_nReadyDelay < 1) {
            SoundEffectManager::GetInstance()->PlayThemedVoice(0);
        }
    }

    // Advance the reveal fade, then emit the background, the part sprites, the logo, the pulsing
    // glow, and the glow overlay.
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

    // Advance the cycling glow phase (fivefold while exiting), wrapping it into range.
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

    // The Hinabita campaign draws an extra portrait layer in portrait orientation.
    if (m_bHinabitaMode && RBCampaignData.sharedInstance.isCampaignHinabita201703 &&
        m_flViewportWidth < m_flViewportHeight) {
        RenderCampaignPortrait();
    }

    // Handle touch input unless the exit is already running.
    if (!m_bExiting) {
        ProcessTitleTouch();
    }

    // Once the exit fade reaches fully hidden, advance to the finish state.
    if (m_bExiting && m_flFadeValue >= kFadeComplete) {
        m_nState = kStateFinish;
    }
}

void TitleColetteScene::BeginExit() {
    // Seed the exit cross-fade from the current value, stop the music, mark the scene exiting, play
    // the exit sound, and fade the corporate button in.
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
        // A touch is being tracked: on its release, classify the flick direction into the gesture
        // state machine (a flick must exceed the pixel threshold on its dominant axis).
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

        // Classify the flick into the swipe sequence, advancing the gesture state to the next step.
        // A flick under the pixel threshold on the dominant axis is ignored.
        int nNextStep;
        if (flAbsX <= flAbsY) {
            if (flDy <= kFlickThreshold) {
                // Upward flick: advances the first up (from idle) then the second.
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
                // Downward flick: advances the first down (after the ups) then the second.
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
            // Leftward flick: the second left (after a right) or the first left (after the downs).
            if (m_nGestureState == kGestureStepRight1) {
                nNextStep = kGestureStepLeft2;
            } else {
                if (m_nGestureState != kGestureStepDown2) {
                    return;
                }
                nNextStep = kGestureStepLeft1;
            }
        } else if (m_nGestureState == kGestureStepLeft2) {
            // Rightward flick: the second right (after the second left).
            nNextStep = kGestureStepRight2;
        } else {
            // Rightward flick: the first right (after the first left).
            if (m_nGestureState != kGestureStepLeft1) {
                return;
            }
            nNextStep = kGestureStepRight1;
        }
        m_nGestureState = nNextStep;
        return;
    }

    // No touch tracked: adopt the first fresh touch this frame and hit-test it against the menu.
    if (pTouchManager->GetActiveTouchCount() <= 0) {
        return;
    }
    // A pending terms-of-service update pre-empts everything.
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

        // The corporate-logo box (only while fully shown) starts the exit.
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
            // The sound-effect box (once ready) fires the SE jingle and resets the accumulator.
            m_bSeTriggered = true;
            m_nSeAccumulator = 0;
            [m_pSePlayer sePlay];
        }
        break;
    }
}

/** @ghidraAddress 0x59474 */
void TitleColetteScene::RenderCampaignPortrait() {
    // The characters fit-scale to the screen: full size on iPad, else the min screen dimension over
    // the reference width.
    float flFit;
    if (IsPad()) {
        flFit = 1.0f;
    } else {
        const float flMin =
            m_flViewportWidth < m_flViewportHeight ? m_flViewportWidth : m_flViewportHeight;
        flFit = flMin / kPortraitFitReference;
    }

    // Build the six character anchor positions. The iPad uses the fixed table; the phone places the
    // main portrait at a scaled Y and eases each sub-character's X toward the screen centre.
    S_VECTOR2 aAnchor[kCampaignPortraitCount];
    if (IsPad()) {
        for (int nChar = 0; nChar < kCampaignPortraitCount; ++nChar) {
            aAnchor[nChar] = S_VECTOR2{g_aCampaignPortraitPadAnchor[nChar][0],
                                       g_aCampaignPortraitPadAnchor[nChar][1]};
        }
    } else {
        // The shared row Y rises from the base by the fit scale; every character sits on it.
        const float flRowY = flFit * kPortraitRowRise + kPortraitBaseY;
        aAnchor[0] = S_VECTOR2{kPortraitMainX, flRowY};
        for (int nSub = 1; nSub < kCampaignPortraitCount; ++nSub) {
            const float flBaseX = g_aCampaignPortraitPhoneBaseX[nSub - 1];
            aAnchor[nSub] =
                S_VECTOR2{kPortraitCentreX - flFit * (kPortraitCentreX - flBaseX), flRowY};
        }
    }

    if (!m_bSeReady) {
        // Entrance animation: the main portrait fades and pops in over the sound-effect timer, then
        // the five sub-characters follow with their own staggered curves.
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
        // Shown and idle: the main portrait draws statically at full size.
        EmitPartSprite(kPartCampaignMain,
                       0xff,
                       aAnchor[0],
                       S_VECTOR2{flFit, flFit},
                       0.0f,
                       S_VECTOR3{kFullColor, kFullColor, kFullColor});
    } else {
        // Shown and reacting to a sound-effect hit: the main portrait plays the reaction squash
        // over the reaction timer; when it finishes the reaction flag and timer reset.
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
    // While the logo swing is active the part follows its swung position, otherwise its anchor ring
    // rest position.
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

    // The attract intro plays only before attract mode latches: two sprites from a dedicated
    // position table with six-knot scale and alpha curves.
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

    // The standard timeline windows: each spans a timer range and animates a run of parts through
    // the shared per-sprite path.
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
    // The counter starts at -9 and counts up to zero, with the increment at the top of the loop and
    // skipped on entry, so the `add w1,w25,#0x4a` at 0x58be8 makes 0x4a the last part id and 0x41
    // the first. These ten are the logo's letters.
    if (m_nIdleTimer > 0xa6) {
        for (int i = 0; i < 10; ++i) {
            // The positions come from the letters' own table, read at 0x58bac and 0x58bb0 from the
            // pointer set up at 0x58b84. This loop has no swing-phase test and no anchor selection,
            // unlike the standard windows, so the letters keep these positions throughout.
            EmitTablePositionedPart(0x41 + static_cast<unsigned int>(i),
                                    S_VECTOR2{g_aTitleLetterPos[i][0], g_aTitleLetterPos[i][1]},
                                    &g_aTitleAnim05Scale[i * 0x3a],
                                    0x1d,
                                    &g_aTitleAnim05Alpha[i * 4],
                                    2);
        }
    }

    // Window 6: six parts with a single seven-knot scale curve, from a dedicated position table.
    // The `add w1,w22,#0x55` at 0x58c8c makes 0x55 the last id, so these run 0x50 to 0x55, and the
    // start prompt is the first of them rather than one past the end. The position pointer starts
    // at the table plus twelve (0x58c4c) and is read eight back, so the first pair is skipped.
    if (static_cast<unsigned int>(m_nIdleTimer - 0xa7) < 0x1a0b) {
        for (int i = 0; i < 6; ++i) {
            // Both this window's curve and position tables hold seven rows, and the pre-header
            // advances one row before the loop starts (0x58c40), so rows one through six are read
            // and row zero is dead data. The position table already carried that offset; the curve
            // never did.
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

    // Same shape again: the `add w1,w25,#0x5c` at 0x58d64 makes 0x5c the last id, so these six run
    // 0x57 to 0x5c. Emitting 0x5c to 0x61 instead reached part 0x61, a full-screen quad over a
    // single solid texel, which is the white box that appeared beside the logo.
    if (m_nIdleTimer > 0xa6) {
        for (int i = 0; i < 6; ++i) {
            // Seven-row tables read from row one, as in window 6: the pre-header advances both
            // pointers a row before the loop (0x58cf0 and 0x58cf4). This window shares window 6's
            // position table too — both compute the same base at 0x58c4c and 0x58d00 — and likewise
            // performs no swing selection.
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

    // Window 8 and the attract hint are the two arms of one split, at 0x58d90: past the intro the
    // four idle extras animate their own position, and in attract mode the single hint sprite
    // replaces them. Each extra interpolates its x, its y and its alpha from a three-knot curve and
    // its scale from a two-knot one, so unlike the standard windows it consults no position table.
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

    // Window 9 through 12: further standard windows over their own timer ranges.
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

    // Window 13: two sprites from a dedicated position table, drawn at fixed scale with a rotation
    // curve and a shared two-knot alpha curve.
    if (m_nIdleTimer > 0xa6) {
        for (int i = 0; i < 2; ++i) {
            const float flTime = static_cast<float>(m_nIdleTimer);
            const float flRotation =
                // Both sprites share row zero: the memcpy at 0x5932c copies 0x50 bytes, one
                // ten-knot curve, and 0x59378 recomputes the pointer every iteration with no
                // stride. Indexing by the sprite read twenty floats past the end of the array.
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

    // The standalone logo sprite (window 14), always drawn, with a two-knot alpha curve.
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
    // Release and null each cached texture.
    for (ne::C_TEXTURE *&pTexture : m_apTextures) {
        if (pTexture != nullptr) {
            pTexture->Release();
            pTexture = nullptr;
        }
    }
    // The part sprites are owned by the scene graph; flag each for the scene walker and null it.
    for (ne::C_SPRITE_INSTANCING_2D *&pSprite : m_apSprites) {
        if (pSprite != nullptr) {
            pSprite->RequestDelete();
            pSprite = nullptr;
        }
    }
    // Terminate and release the theme sound-effect player.
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
    // Wait until the fade-out audio has fully stopped before tearing down.
    if (![AudioManager.sharedManager isStart]) {
        return;
    }
    ReleaseResources();
    // Construct the gameplay scene into the game system's leading scene slot, then open the music
    // list through the app's root view controller.
    rb::GameScene::GetInstance(GameSystem::GetGameSystem()->GetCurrentSceneSlot());
    [AppDelegate.appDelegate.viewController showMusicListView];
    MarkDead();
}

} // namespace rb
