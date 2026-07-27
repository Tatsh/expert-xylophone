//
//  title_screen_layer0.mm
//  REFLEC BEAT plus
//
//  The theme-0 title-screen scene layer (TitleClassicScene). Reconstructed from Ghidra project
//  rb458, program rb458. @ghidraAddress values are relative to the program image base.
//

#include "title_screen_layer0.h"

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

namespace {
// The value the constructor seeds into the fade channel's base (the fully-shown fade level).
constexpr float kInitialFadeBase = 1.0f;

// The sentinel the constructor writes into the trailing per-slot index (no slot selected).
constexpr int kNoSlotIndex = -1;

// The dispatch states OnFrame selects between: load resources, wait for the start music, render the
// title, then finish and open the music list.
constexpr int kStateLoad = 0;
constexpr int kStateStartMusic = 1;
constexpr int kStateRender = 2;
constexpr int kStateFinish = 3;

// The fade-in time, in seconds, the title BGM begins playing with.
constexpr float kTitleBgmFadeInTime = 0.3f;

// The seven title textures, in load order (indices into m_apTextures).
constexpr const char *kTitleTextureNames[TitleClassicScene::kTextureCount] = {
    "00_texture/ti_bg",
    "00_texture/ti_star",
    "00_texture/ti_start",
    "00_texture/ti_start_eff",
    "00_texture/ti_start_eff_text",
    "00_texture/ti_maru",
    "00_texture/ti_logo",
};

// The instancer slot that binds no texture (the last one).
constexpr int kUntexturedSlot = 7;

// The bitmask of instancer slots drawn additively (slots 1, 2, and 4).
constexpr unsigned int kAdditiveSlotMask = 0x16;

// The number of leading instancer slots (1 and 2) whose texture wrap is clamped on both axes.
constexpr unsigned int kClampedSlotCount = 2;

// The additive blend mode, and the texture-parameter axes and clamp value the clamped slots set.
constexpr int kBlendModeAdditive = 1;
constexpr int kTexParamAxisT = 1;
constexpr int kTexParamAxisS = 0;
constexpr int kTexClampValue = 1;

// The ready-delay timer the title screen counts down before the start prompt, and the fade-curve
// duration, in milliseconds.
constexpr int kTitleReadyDelay = 1000;
constexpr float kTitleFadeDuration = 1000.0f;

// The themed voice bank and the sound-effect voice id the title screen loads.
constexpr int kTitleVoiceId = 0;
} // namespace

// The eight title-screen instancer capacities and texture indices live in the binary's read-only
// data; only the pointers are referenced here.
const unsigned int g_aTitleSpriteCapacity[rb::TitleClassicScene::kSpriteSlotCount] = {
    1, 4, 2, 1, 1, 1, 1, 1};
const unsigned int g_aTitleSpriteTextureIndex[rb::TitleClassicScene::kSpriteSlotCount] = {
    0, 1, 5, 6, 3, 2, 4, 8};

namespace rb {

/** @ghidraAddress 0x1514b4 */
TitleClassicScene::TitleClassicScene() {
    // The UI-layer base constructor ran first and the compiler installed the title dispatch vtable;
    // the presentation state is otherwise zero-initialised by the member initialisers.
    m_fadeChannel.SetCurrent(kInitialFadeBase);
    m_nTrailingIndex = kNoSlotIndex;
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
    // Release and null each cached texture.
    for (ne::C_TEXTURE *&pTexture : m_apTextures) {
        if (pTexture != nullptr) {
            pTexture->Release();
            pTexture = nullptr;
        }
    }
    // The sprite instancers are owned by the scene graph; flag each for the scene walker and null it.
    for (ne::C_SPRITE_INSTANCING *&pSprite : m_apSprites) {
        if (pSprite != nullptr) {
            pSprite->RequestDelete();
            pSprite = nullptr;
        }
    }
}

/** @ghidraAddress 0x151678 */
void TitleClassicScene::OnFrame(void *pFrameArg) {
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

/** @ghidraAddress 0x1516bc */
void TitleClassicScene::LoadResources() {
    m_nFadeTimer = 0;

    // Load the seven title textures.
    for (int nTexture = 0; nTexture < kTextureCount; ++nTexture) {
        m_apTextures[nTexture] = ne::C_TEXTURE::FindOrLoadCached(kTitleTextureNames[nTexture]);
    }

    // Build the eight sprite instancers: register each in the global scene tree, make it visible,
    // bind its texture (except the last slot), seed its sprite count, and set its blend/texture modes.
    for (int nSlot = 0; nSlot < kSpriteSlotCount; ++nSlot) {
        ne::C_SPRITE_INSTANCING *pSprite = ne::CreateSpriteInstancer(g_aTitleSpriteCapacity[nSlot]);
        pSprite->RegisterGlobal();
        pSprite->SetVisible(true);
        if (nSlot != kUntexturedSlot) {
            pSprite->SetRefCountedMember(m_apTextures[g_aTitleSpriteTextureIndex[nSlot]]);
        }
        pSprite->SetSpriteCount(m_aSpriteCount[nSlot]);
        if (((kAdditiveSlotMask >> nSlot) & 1) != 0) {
            pSprite->SetBlendMode(kBlendModeAdditive);
        }
        // The two logo slots clamp their texture wrap on both axes.
        if (static_cast<unsigned int>(nSlot - 1) < kClampedSlotCount) {
            pSprite->SetTexParam(kTexParamAxisT, kTexClampValue);
            pSprite->SetTexParam(kTexParamAxisS, kTexClampValue);
        }
        m_apSprites[nSlot] = pSprite;
    }

    // Start the title BGM and load the title voice and shot-sound banks.
    [RBBGMManager.getInstance LoadMusicTitleWithLoop:NO];
    SoundEffectManager::GetInstance()->LoadThemedVoiceData(kTitleVoiceId);
    ShotSoundManager::GetInstance()->LoadSlotVariants(GameSystem::GetGameSystem()->GetShotType());

    // Seed the fade curve from the current fade level and arm the ready-delay timer, then advance.
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

/** @ghidraAddress 0x152450 */
void TitleClassicScene::FinishAndOpenList() {
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
