//
//  title_screen_layer0.mm
//  REFLEC BEAT plus
//
//  The theme-0 title-screen scene layer (TitleScreenLayer0). Reconstructed from Ghidra project
//  rb458, program rb458. @ghidraAddress values are relative to the program image base.
//

#include "title_screen_layer0.h"

#import "AppDelegate.h"
#import "AudioManager.h"
#import "RBBGMManager.h"
#import "RBViewController.h"
#include "gamesystem.h"
#include "neSpriteInstancing.h"
#include "neTexture.h"
#include "play_task.h"

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
} // namespace

/** @ghidraAddress 0x1514b4 */
TitleScreenLayer0::TitleScreenLayer0() {
    // The UI-layer base constructor ran first and the compiler installed the title dispatch vtable;
    // the presentation state is otherwise zero-initialised by the member initialisers.
    m_fadeChannel.SetCurrent(kInitialFadeBase);
    m_nTrailingIndex = kNoSlotIndex;
}

/**
 * @ghidraAddress 0x151580
 * @ghidraAddress 0x151640
 */
TitleScreenLayer0::~TitleScreenLayer0() {
    ReleaseResources();
}

/** @ghidraAddress 0x1515cc */
void TitleScreenLayer0::ReleaseResources() {
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
void TitleScreenLayer0::OnFrame(void *pFrameArg) {
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

/** @ghidraAddress 0x1518c8 */
void TitleScreenLayer0::StartMusic() {
    m_nState = kStateRender;
    [RBBGMManager.getInstance PlayMusic:kTitleBgmFadeInTime];
}

/** @ghidraAddress 0x152450 */
void TitleScreenLayer0::FinishAndOpenList() {
    // Wait until the fade-out audio has fully stopped before tearing down.
    if (![AudioManager.sharedManager isStart]) {
        return;
    }
    ReleaseResources();
    // Construct the gameplay task (its slot is the game system's leading scene pointer), then open
    // the music list through the app's root view controller.
    GameSystem *pGameSystem = GameSystem::GetGameSystem();
    PlayTask::GetInstance(reinterpret_cast<PlayTask **>(pGameSystem));
    [AppDelegate.appDelegate.viewController showMusicListView];
    MarkDead();
}
