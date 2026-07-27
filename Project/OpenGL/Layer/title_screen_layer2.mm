//
//  title_screen_layer2.mm
//  REFLEC BEAT plus
//
//  The parts-based title-screen scene layer (TitleLimelightScene). Reconstructed from Ghidra project
//  rb458, program rb458. @ghidraAddress values are relative to the program image base.
//

#include "title_screen_layer2.h"

#import "AppDelegate.h"
#import "AudioManager.h"
#import "RBBGMManager.h"
#import "RBViewController.h"
#include "game_scene.h"
#include "gamesystem.h"
#include "neSpriteInstancing.h"
#include "neTexture.h"
#include "shotsoundmanager.h"
#include "soundeffectmanager.h"
#include "title_part_layout.h"

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
    for (ne::C_SPRITE_INSTANCING *&pSprite : m_apSprites) {
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
        ne::C_SPRITE_INSTANCING *pSprite = ne::CreateSpriteInstancer(1);
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

} // namespace rb
