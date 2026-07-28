//
//  title_screen_layer2.mm
//  REFLEC BEAT plus
//
//  The parts-based title-screen scene layer (TitleLimelightScene). Reconstructed from Ghidra project
//  rb458, program rb458. @ghidraAddress values are relative to the program image base.
//

#include "titlelimelightscene.h"

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
#include "title_part_layout.h"
#include "titlecolettescene.h"

namespace {
// The value the constructor seeds into the fade value (the fully-shown level).
constexpr float kInitialFadeValue = 1.0f;

// The sentinel the constructor writes into the trailing per-slot index (no slot selected).
constexpr int kNoSlotIndex = -1;

// The dispatch states OnFrame selects between.
constexpr int kStateLoad = 0;
constexpr int kStateStartMusic = 1;
constexpr int kStateRender = 2;
constexpr int kStateFinish = 3;

// The fade-in time, in seconds, the title BGM begins playing with (@ghidraAddress 0x2ee910).
constexpr float kTitleBgmFadeInTime = 0.3f;

// The three title textures, in load order (indices into m_apTextures).
constexpr const char *kTitleTextureNames[TitleLimelightScene::kTextureCount] = {
    "00_texture/ti_bg",
    "00_texture/ti_parts",
    "00_texture/ti_parts_eff",
};

// The part-layout record's texture index marking an instancer that binds no texture.
constexpr int kUntexturedTextureIndex = 4;

// The ready-delay timer the title screen counts down before the start prompt, and the fade-curve
// duration, in milliseconds.
constexpr int kTitleReadyDelay = 0x708;
constexpr float kTitleFadeDuration = 500.0f;

// The themed voice bank the title screen loads.
constexpr int kTitleVoiceId = 0;

// The maximum value of an opaque colour channel, and the half factor for a size-to-anchor centre.
constexpr unsigned int kColorMax = 255;
constexpr float kHalf = 0.5f;

// The part-layout anchor mode that draws from the per-device lettered/logo UV atlas; every other
// mode draws from the shared default title-part atlas.
constexpr int kPartAnchorModeAtlas = 1;

// The screen-space transform the default-device parts apply: the X and Y offsets and the scale that
// map a part's layout position into screen space (@ghidraAddress 0x2f8568 X offset, 0x301f94 Y
// offset, 0x301108 scale), plus the layer's own half-anchor origins.
constexpr float kPartScreenOffsetX = -384.0f;
constexpr float kPartScreenOffsetY = -680.0f;
constexpr float kPartScreenScale = 0.4f;

// The interactive part kinds whose screen rectangles are recorded for the title touch tests.
constexpr unsigned int kPartKindHit0 = 0x2b;
constexpr unsigned int kPartKindHit1 = 0x32;
constexpr unsigned int kPartKindHit2 = 0x34;
constexpr unsigned int kPartKindHit3 = 0x3e;
constexpr unsigned int kPartKindHit4 = 0x50;

// The extra offsets the default-device hit-rect for kind 0x50 (the start prompt) is nudged by
// (@ghidraAddress 0x2f855c width, 0x2f8574 X, 0x2f8578 height, plus an inline -30 Y).
constexpr float kStartPromptWidthPad = 80.0f;
constexpr float kStartPromptOffsetX = -40.0f;
constexpr float kStartPromptHeightPad = 60.0f;
constexpr float kStartPromptOffsetY = -30.0f;

// The star-field particle burst: the number of particles, the number of {time, value} pairs each
// animation curve holds (and its float count), the part-kind base the particles emit at, and the
// unit-interval-to-alpha scale.
constexpr int kBurstParticleCount = 0x23;
constexpr int kBurstCurvePairs = 3;
constexpr int kBurstCurveFloats = kBurstCurvePairs * 2;
constexpr unsigned int kBurstPartKindBase = 5;
constexpr float kBurstAlphaByteScale = 255.0f;

// The 35 burst particles' fixed X columns. @ghidraAddress 0x30b3b0
constexpr float kBurstParticleX[kBurstParticleCount] = {
    74.0f,  74.0f,  194.0f, 194.0f, 454.0f, 454.0f, 229.0f, 229.0f, 545.0f, 545.0f, 725.0f, 725.0f,
    564.0f, 564.0f, 234.0f, 234.0f, 657.0f, 657.0f, 464.0f, 464.0f, 593.0f, 593.0f, 593.0f, 593.0f,
    334.0f, 334.0f, 134.0f, 134.0f, 644.0f, 644.0f, 71.0f,  71.0f,  424.0f, 424.0f, 384.0f,
};

// the particles' Y-position curves (three {time, value} pairs each). @ghidraAddress 0x30b43c
constexpr float kBurstYCurve[kBurstParticleCount][kBurstCurveFloats] = {
    {333.33334f, 738.0f, 500.0f, 730.5f, 1000.0f, 716.5f},
    {333.33334f, 738.0f, 500.0f, 730.5f, 1000.0f, 716.5f},
    {333.33334f, 768.0f, 500.0f, 760.5f, 1000.0f, 746.5f},
    {333.33334f, 768.0f, 500.0f, 760.5f, 1000.0f, 746.5f},
    {166.66667f, 638.0f, 333.33334f, 630.5f, 833.3333f, 616.5f},
    {166.66667f, 638.0f, 333.33334f, 630.5f, 833.3333f, 616.5f},
    {316.66666f, 584.0f, 333.33334f, 584.0f, 1000.0f, 554.0f},
    {316.66666f, 584.0f, 333.33334f, 584.0f, 1000.0f, 554.0f},
    {316.66666f, 590.0f, 333.33334f, 590.0f, 1000.0f, 560.0f},
    {316.66666f, 590.0f, 333.33334f, 590.0f, 1000.0f, 560.0f},
    {316.66666f, 647.0f, 333.33334f, 647.0f, 1000.0f, 617.0f},
    {316.66666f, 647.0f, 333.33334f, 647.0f, 1000.0f, 617.0f},
    {166.66667f, 764.0f, 333.33334f, 739.0f, 833.3333f, 724.0f},
    {166.66667f, 764.0f, 333.33334f, 739.0f, 833.3333f, 724.0f},
    {0.0f, 794.0f, 166.66667f, 744.0f, 666.6667f, 724.0f},
    {0.0f, 794.0f, 166.66667f, 744.0f, 666.6667f, 724.0f},
    {0.0f, 609.0f, 166.66667f, 559.0f, 666.6667f, 539.0f},
    {0.0f, 609.0f, 166.66667f, 559.0f, 666.6667f, 539.0f},
    {0.0f, 815.0f, 166.66667f, 765.0f, 666.6667f, 745.0f},
    {0.0f, 815.0f, 166.66667f, 765.0f, 666.6667f, 745.0f},
    {0.0f, 802.0f, 166.66667f, 752.0f, 666.6667f, 732.0f},
    {0.0f, 802.0f, 166.66667f, 752.0f, 666.6667f, 732.0f},
    {0.0f, 802.0f, 166.66667f, 752.0f, 666.6667f, 732.0f},
    {0.0f, 802.0f, 166.66667f, 752.0f, 666.6667f, 732.0f},
    {0.0f, 704.0f, 166.66667f, 674.0f, 666.6667f, 654.0f},
    {0.0f, 704.0f, 166.66667f, 674.0f, 666.6667f, 654.0f},
    {333.33334f, 704.0f, 500.0f, 674.0f, 1000.0f, 644.0f},
    {333.33334f, 704.0f, 500.0f, 674.0f, 1000.0f, 644.0f},
    {333.33334f, 704.0f, 500.0f, 674.0f, 1000.0f, 644.0f},
    {250.0f, 704.0f, 416.66666f, 674.0f, 916.6667f, 644.0f},
    {0.0f, 709.0f, 166.66667f, 695.0f, 666.6667f, 659.0f},
    {0.0f, 709.0f, 166.66667f, 695.0f, 666.6667f, 659.0f},
    {83.333336f, 594.0f, 250.0f, 564.0f, 750.0f, 544.0f},
    {83.333336f, 594.0f, 250.0f, 564.0f, 750.0f, 544.0f},
    {166.66667f, 574.0f, 333.33334f, 524.0f, 833.3333f, 494.0f},
};

// the particles' alpha curves (three {time, value} pairs each). @ghidraAddress 0x30b784
constexpr float kBurstAlphaCurve[kBurstParticleCount][kBurstCurveFloats] = {
    {483.33334f, 0.0f, 500.0f, 1.0f, 1000.0f, 0.0f},
    {466.66666f, 0.0f, 483.33334f, 1.0f, 650.0f, 0.0f},
    {483.33334f, 0.0f, 500.0f, 1.0f, 1000.0f, 0.0f},
    {466.66666f, 0.0f, 483.33334f, 1.0f, 650.0f, 0.0f},
    {316.66666f, 0.0f, 333.33334f, 1.0f, 833.3333f, 0.0f},
    {300.0f, 0.0f, 316.66666f, 1.0f, 483.33334f, 0.0f},
    {483.33334f, 0.0f, 500.0f, 1.0f, 1000.0f, 0.0f},
    {466.66666f, 0.0f, 483.33334f, 1.0f, 650.0f, 0.0f},
    {483.33334f, 0.0f, 500.0f, 1.0f, 1000.0f, 0.0f},
    {466.66666f, 0.0f, 483.33334f, 1.0f, 650.0f, 0.0f},
    {483.33334f, 0.0f, 500.0f, 1.0f, 1000.0f, 0.0f},
    {466.66666f, 0.0f, 483.33334f, 1.0f, 650.0f, 0.0f},
    {316.66666f, 0.0f, 333.33334f, 1.0f, 833.3333f, 0.0f},
    {466.66666f, 0.0f, 483.33334f, 1.0f, 650.0f, 0.0f},
    {150.0f, 0.0f, 166.66667f, 1.0f, 666.6667f, 0.0f},
    {133.33333f, 0.0f, 150.0f, 1.0f, 483.33334f, 0.0f},
    {150.0f, 0.0f, 166.66667f, 1.0f, 666.6667f, 0.0f},
    {133.33333f, 0.0f, 150.0f, 1.0f, 483.33334f, 0.0f},
    {150.0f, 0.0f, 166.66667f, 1.0f, 666.6667f, 0.0f},
    {133.33333f, 0.0f, 150.0f, 1.0f, 483.33334f, 0.0f},
    {150.0f, 0.0f, 166.66667f, 1.0f, 666.6667f, 0.0f},
    {133.33333f, 0.0f, 150.0f, 1.0f, 483.33334f, 0.0f},
    {150.0f, 0.0f, 166.66667f, 1.0f, 666.6667f, 0.0f},
    {133.33333f, 0.0f, 150.0f, 1.0f, 483.33334f, 0.0f},
    {150.0f, 0.0f, 166.66667f, 1.0f, 666.6667f, 0.0f},
    {133.33333f, 0.0f, 150.0f, 1.0f, 483.33334f, 0.0f},
    {483.33334f, 0.0f, 500.0f, 1.0f, 1000.0f, 0.0f},
    {466.66666f, 0.0f, 483.33334f, 1.0f, 650.0f, 0.0f},
    {400.0f, 0.0f, 583.3333f, 1.0f, 916.6667f, 0.0f},
    {466.66666f, 0.0f, 483.33334f, 1.0f, 650.0f, 0.0f},
    {150.0f, 0.0f, 166.66667f, 1.0f, 666.6667f, 0.0f},
    {133.33333f, 0.0f, 150.0f, 1.0f, 316.66666f, 0.0f},
    {233.33333f, 0.0f, 250.0f, 1.0f, 750.0f, 0.0f},
    {216.66667f, 0.0f, 233.33333f, 1.0f, 400.0f, 0.0f},
    {216.66667f, 0.0f, 233.33333f, 1.0f, 400.0f, 0.0f},
};

// the particles' scale curves (three {time, value} pairs each). @ghidraAddress 0x30bacc
constexpr float kBurstScaleCurve[kBurstParticleCount][kBurstCurveFloats] = {
    {333.33334f, 0.0f, 1000.0f, 0.5f, 1016.6667f, 0.5f},
    {333.33334f, 0.0f, 1000.0f, 0.5f, 1016.6667f, 0.5f},
    {333.33334f, 0.0f, 1000.0f, 0.5f, 1016.6667f, 0.5f},
    {333.33334f, 0.0f, 1000.0f, 0.5f, 1016.6667f, 0.5f},
    {166.66667f, 0.0f, 833.3333f, 0.5f, 850.0f, 0.5f},
    {166.66667f, 0.0f, 833.3333f, 0.5f, 850.0f, 0.5f},
    {333.33334f, 0.0f, 1000.0f, 0.5f, 1016.6667f, 0.5f},
    {333.33334f, 0.0f, 1000.0f, 0.5f, 1016.6667f, 0.5f},
    {333.33334f, 0.0f, 1000.0f, 0.5f, 1016.6667f, 0.5f},
    {333.33334f, 0.0f, 1000.0f, 0.5f, 1016.6667f, 0.5f},
    {333.33334f, 0.0f, 1000.0f, 0.5f, 1016.6667f, 0.5f},
    {333.33334f, 0.0f, 1000.0f, 0.5f, 1016.6667f, 0.5f},
    {166.66667f, 0.0f, 333.33334f, 0.6f, 833.3333f, 0.8f},
    {166.66667f, 0.0f, 333.33334f, 0.6f, 833.3333f, 0.8f},
    {0.0f, 0.0f, 166.66667f, 0.4f, 666.6667f, 0.7f},
    {0.0f, 0.0f, 166.66667f, 0.4f, 666.6667f, 0.7f},
    {0.0f, 0.0f, 166.66667f, 0.5f, 666.6667f, 1.0f},
    {0.0f, 0.0f, 166.66667f, 0.5f, 666.6667f, 1.0f},
    {0.0f, 0.0f, 166.66667f, 0.8f, 666.6667f, 1.0f},
    {0.0f, 0.0f, 166.66667f, 0.8f, 666.6667f, 1.0f},
    {0.0f, 0.0f, 166.66667f, 0.4f, 666.6667f, 1.0f},
    {0.0f, 0.0f, 166.66667f, 0.4f, 666.6667f, 1.0f},
    {0.0f, 0.0f, 166.66667f, 0.4f, 666.6667f, 1.0f},
    {0.0f, 0.0f, 166.66667f, 0.4f, 666.6667f, 1.0f},
    {0.0f, 0.0f, 166.66667f, 0.8f, 666.6667f, 1.0f},
    {0.0f, 0.0f, 166.66667f, 0.8f, 666.6667f, 1.0f},
    {333.33334f, 0.0f, 500.0f, 0.4f, 1000.0f, 0.5f},
    {333.33334f, 0.0f, 500.0f, 0.4f, 1000.0f, 0.5f},
    {250.0f, 0.0f, 416.66666f, 0.4f, 916.6667f, 0.5f},
    {250.0f, 0.0f, 416.66666f, 0.4f, 916.6667f, 0.5f},
    {0.0f, 0.0f, 166.66667f, 0.6f, 666.6667f, 1.0f},
    {0.0f, 0.0f, 166.66667f, 0.6f, 666.6667f, 1.0f},
    {83.333336f, 0.0f, 250.0f, 0.6f, 750.0f, 1.0f},
    {83.333336f, 0.0f, 250.0f, 0.8f, 750.0f, 1.0f},
    {166.66667f, 0.0f, 333.33334f, 0.6f, 833.3333f, 1.0f},
};

} // namespace

namespace rb {

/** @ghidraAddress 0x152de8 */
TitleLimelightScene::TitleLimelightScene() {
    // The UI-layer base constructor ran first and the compiler installed the title dispatch vtable;
    // the presentation state is otherwise zero-initialised by the member initialisers.
    m_flFadeValue = kInitialFadeValue;
    m_nTrailingIndex = kNoSlotIndex;
}

/**
 * @ghidraAddress 0x152e90
 * @ghidraAddress 0x152f4c
 */
TitleLimelightScene::~TitleLimelightScene() {
    ReleaseResources();
}

/** @ghidraAddress 0x152edc */
void TitleLimelightScene::ReleaseResources() {
    // Release and null each cached texture.
    for (ne::C_TEXTURE *&pTexture : m_apTextures) {
        if (pTexture != nullptr) {
            pTexture->Release();
            pTexture = nullptr;
        }
    }
    // The part instancers are owned by the scene graph; flag each for the scene walker and null it.
    for (ne::C_SPRITE_INSTANCING_2D *&pSprite : m_apSprites) {
        if (pSprite != nullptr) {
            pSprite->RequestDelete();
            pSprite = nullptr;
        }
    }
}

/** @ghidraAddress 0x152f84 */
void TitleLimelightScene::OnFrame(void *pFrameArg) {
    switch (m_nState) {
    case kStateLoad:
        LoadResources();
        return;
    case kStateStartMusic:
        StartMusic();
        return;
    case kStateRender:
        RenderFrame(pFrameArg);
        return;
    case kStateFinish:
        FinishAndOpenList();
        return;
    default:
        return;
    }
}

/** @ghidraAddress 0x152fc8 */
void TitleLimelightScene::LoadResources() {
    m_nFadeTimer = 0;

    // Load the three title textures.
    for (int nTexture = 0; nTexture < kTextureCount; ++nTexture) {
        m_apTextures[nTexture] = ne::C_TEXTURE::FindOrLoadCached(kTitleTextureNames[nTexture]);
    }

    // Build the part sprite instancers (each holds one sprite): register each in the global scene
    // tree, make it visible, bind its texture from the per-device part-layout table (unless the
    // record marks it untextured), and seed its sprite count.
    const TitlePartLayoutRecord *pLayout =
        IsPad() ? g_aTitle2PartLayoutAltFrame : g_aTitle2PartLayoutDefault;
    for (int nSlot = 0; nSlot < kSpriteSlotCount; ++nSlot) {
        ne::C_SPRITE_INSTANCING_2D *pSprite = ne::CreateSpriteInstancer(1);
        pSprite->RegisterGlobal();
        pSprite->SetVisible(true);
        if (pLayout[nSlot].nTextureIndex != kUntexturedTextureIndex) {
            pSprite->SetRefCountedMember(m_apTextures[pLayout[nSlot].nTextureIndex]);
        }
        pSprite->SetSpriteCount(m_aSpriteCount[nSlot]);
        m_apSprites[nSlot] = pSprite;
    }

    // Start the title BGM and load the title voice and shot-sound banks.
    [RBBGMManager.getInstance LoadMusicTitleWithLoop:NO];
    SoundEffectManager::GetInstance()->LoadThemedVoiceData(kTitleVoiceId);
    ShotSoundManager::GetInstance()->LoadSlotVariants(GameSystem::GetGameSystem()->GetShotType());

    // Seed the fade curve from the current fade value and arm the ready-delay timer, then advance.
    m_flFadeStart = m_flFadeValue;
    m_flFadeEnd = 0.0f;
    m_flFadeDuration = kTitleFadeDuration;
    m_flFadeElapsed = 0.0f;
    m_nReadyDelay = kTitleReadyDelay;
    m_nState = kStateStartMusic;
}

/** @ghidraAddress 0x153190 */
void TitleLimelightScene::StartMusic() {
    m_nState = kStateRender;
    [RBBGMManager.getInstance PlayMusic:kTitleBgmFadeInTime];
}

/** @ghidraAddress 0x154288 */
void TitleLimelightScene::FinishAndOpenList() {
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

/** @ghidraAddress 0x154380 */
void TitleLimelightScene::AdvanceFadeValue(int nDeltaFrames) {
    // Past the fade duration, snap to the end value.
    if (m_flFadeElapsed >= m_flFadeDuration) {
        m_flFadeValue = m_flFadeEnd;
        return;
    }

    // Accumulate the elapsed frames, clamping to the duration.
    m_flFadeElapsed += static_cast<float>(nDeltaFrames);
    if (m_flFadeElapsed < m_flFadeStartDelay) {
        return;
    }
    if (m_flFadeElapsed > m_flFadeDuration) {
        m_flFadeElapsed = m_flFadeDuration;
    }

    // Interpolate from the start to the end value over the span past the start delay.
    float flProgress;
    if (m_flFadeDuration == 0.0f) {
        flProgress = 1.0f;
    } else {
        flProgress =
            (m_flFadeElapsed - m_flFadeStartDelay) / (m_flFadeDuration - m_flFadeStartDelay);
    }
    m_flFadeValue = m_flFadeStart + flProgress * (m_flFadeEnd - m_flFadeStart);
}

/** @ghidraAddress 0x1543fc */
void TitleLimelightScene::RenderPartsElement(unsigned int nKind,
                                             unsigned int nColorAlpha,
                                             float flTransformX,
                                             float flTransformY,
                                             float flSize,
                                             float flRotation) {
    if (nKind >= static_cast<unsigned int>(kSpriteSlotCount)) {
        return;
    }
    ne::C_SPRITE_INSTANCING_2D *pInstancer = m_apSprites[nKind];
    const int nSlot = pInstancer->GetSpriteCount();
    if (nSlot >= static_cast<int>(pInstancer->GetCapacity())) {
        return;
    }

    if (nKind == 0) {
        // The background: a full-texture quad sized from the instancer's bound texture.
        ne::C_TEXTURE *pTexture = pInstancer->GetBoundTexture();
        const float flScale = pTexture->GetScale();
        const float flPointWidth = static_cast<float>(pTexture->GetImageWidth()) / flScale;
        const float flPointHeight = static_cast<float>(pTexture->GetImageHeight()) / flScale;

        pInstancer->SetSpriteAnchor(nSlot, S_VECTOR2{flPointWidth * kHalf, flPointHeight * kHalf});
        pInstancer->SetSpriteSize(nSlot, S_VECTOR2{flPointWidth, flPointHeight});
        pInstancer->SetSpriteUvOrigin(nSlot, S_VECTOR2{0.0f, 0.0f});
        pInstancer->SetSpriteUvSize(
            nSlot,
            S_VECTOR2{static_cast<float>(pTexture->GetImageWidth()) / pTexture->GetAllocWidth(),
                      static_cast<float>(pTexture->GetImageHeight()) / pTexture->GetAllocHeight()});
        pInstancer->SetSpritePosition(nSlot, S_VECTOR2{flTransformX, flTransformY});
        // The background draws at the texture's retina scale, not the caller's scale.
        pInstancer->SetSpriteScale(nSlot, flScale, flScale);
    } else {
        // A lettered or logo part: its anchor, size, and atlas frame come from the per-device layout
        // record (the record's position/size fields serve as the sprite anchor and size here).
        const bool bIsPad = IsPad();
        const TitlePartLayoutRecord &layout =
            bIsPad ? g_aTitle2PartLayoutAltFrame[nKind] : g_aTitle2PartLayoutDefault[nKind];
        const float flAnchorX = layout.flPosX;
        const float flAnchorY = layout.flPosY;
        const float flSizeX = layout.flWidth;
        const float flSizeY = layout.flHeight;

        // The anchor mode selects the atlas: mode one draws from the per-device lettered/logo atlas,
        // any other mode from the shared default title-part atlas.
        const SpriteUvEntry *pUvTable;
        if (layout.nTextureIndex != kPartAnchorModeAtlas) {
            pUvTable = g_aTitlePartUvDefault;
        } else if (bIsPad) {
            pUvTable = g_aTitle2PartUvAlt;
        } else {
            pUvTable = g_aTitle2PartUvMain;
        }
        const SpriteUvEntry &uv = pUvTable[layout.nUvIndex];
        pInstancer->SetSpriteUvOrigin(nSlot, S_VECTOR2{uv.flOriginU, uv.flOriginV});
        pInstancer->SetSpriteUvSize(nSlot, S_VECTOR2{uv.flSizeU, uv.flSizeV});

        // Map the part's transform into screen space. The iPad layout is already in screen units
        // barring the Y offset; the default device also scales about the screen offsets.
        float flPosX;
        float flPosY;
        if (bIsPad) {
            flPosX = flTransformX;
            flPosY = (flTransformY + kPartScreenOffsetY) + m_flPartOriginY * kHalf;
        } else {
            flPosX =
                (flTransformX + kPartScreenOffsetX) * kPartScreenScale + m_flPartOriginX * kHalf;
            flPosY =
                (flTransformY + kPartScreenOffsetY) * kPartScreenScale + m_flPartOriginY * kHalf;
        }
        pInstancer->SetSpritePosition(nSlot, S_VECTOR2{flPosX, flPosY});
        pInstancer->SetSpriteAnchor(nSlot, S_VECTOR2{flAnchorX, flAnchorY});
        pInstancer->SetSpriteSize(nSlot, S_VECTOR2{flSizeX, flSizeY});
        pInstancer->SetSpriteScale(nSlot, flSize, flSize);

        // Record the interactive parts' touch rectangles (top-left corner, then size) for the title
        // touch tests. Kind 0x50 (the start prompt) is padded outwards on the default device.
        const float flRectX = flPosX - flAnchorX;
        const float flRectY = flPosY - flAnchorY;
        switch (nKind) {
        case kPartKindHit0:
            m_aHitRects[1] = {flRectX, flRectY, flSizeX, flSizeY};
            break;
        case kPartKindHit1:
            m_aHitRects[3] = {flRectX, flRectY, flSizeX, flSizeY};
            break;
        case kPartKindHit2:
            m_aHitRects[2] = {flRectX, flRectY, flSizeX, flSizeY};
            break;
        case kPartKindHit3:
            m_aHitRects[4] = {flRectX, flRectY, flSizeX, flSizeY};
            break;
        case kPartKindHit4:
            if (bIsPad) {
                m_aHitRects[0] = {flRectX, flRectY, flSizeX, flSizeY};
            } else {
                m_aHitRects[0] = {flRectX + kStartPromptOffsetX,
                                  flRectY + kStartPromptOffsetY,
                                  flSizeX + kStartPromptWidthPad,
                                  flSizeY + kStartPromptHeightPad};
            }
            break;
        default:
            break;
        }
    }

    pInstancer->SetSpriteRotation(nSlot, flRotation);

    // Tint by the intro-fade complement: a grey (1 - fade) with the caller's alpha scaled by it.
    const float flIntensity = 1.0f - m_flFadeValue;
    const auto nChannel = static_cast<unsigned int>(flIntensity * kColorMax);
    const auto nAlpha = static_cast<unsigned int>(static_cast<float>(nColorAlpha) * flIntensity);
    pInstancer->SetSpriteColor(nSlot, nChannel, nChannel, nChannel, nAlpha);

    pInstancer->SetSpriteCount(nSlot + 1);
}

/** @ghidraAddress 0x15484c */
void TitleLimelightScene::RenderParticleBurst(float flTime) {
    for (int nParticle = 0; nParticle < kBurstParticleCount; ++nParticle) {
        const float flPosY =
            CalculateCurveInterpolation(kBurstYCurve[nParticle], kBurstCurvePairs, flTime);
        const float flAlpha =
            CalculateCurveInterpolation(kBurstAlphaCurve[nParticle], kBurstCurvePairs, flTime);
        float flScale =
            CalculateCurveInterpolation(kBurstScaleCurve[nParticle], kBurstCurvePairs, flTime);
        // The hidden code doubles every particle's scale.
        if (m_bSecretActive) {
            flScale += flScale;
        }
        RenderPartsElement(kBurstPartKindBase + static_cast<unsigned int>(nParticle),
                           static_cast<unsigned int>(flAlpha * kBurstAlphaByteScale),
                           kBurstParticleX[nParticle],
                           flPosY,
                           flScale,
                           0.0f);
    }
}

} // namespace rb
