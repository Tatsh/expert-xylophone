//
//  titlecolettescene.mm
//  REFLEC BEAT plus
//
//  The theme-2 (Colette) title-screen scene, rb::TitleColetteScene. Reconstructed from Ghidra
//  project rb458, program rb458. @ghidraAddress values are relative to the program image base.
//

#include "titlecolettescene.h"

#import "AppDelegate.h"
#import "AudioManager.h"
#import "RBBGMManager.h"
#import "RBViewController.h"
#import "SePlayer.h"
#include "game_scene.h"
#include "gamesystem.h"
#include "neSpriteInstancing.h"
#include "neTexture.h"

namespace {
// The dispatch states OnFrame selects between: load resources, start the music, run the main loop,
// then finish and open the music list.
constexpr int kStateLoad = 0;
constexpr int kStateStartMusic = 1;
constexpr int kStateMainLoop = 2;
constexpr int kStateFinish = 3;
} // namespace

namespace rb {

/** @ghidraAddress 0x57a64 */
void TitleColetteScene::StartMusic() {
    m_nState = kStateMainLoop;
    [RBBGMManager.getInstance PlayMusic:0.0f];
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
void TitleColetteScene::OnFrame(void *pFrameArg) {
    switch (m_nState) {
    case kStateLoad:
        LoadResources();
        return;
    case kStateStartMusic:
        StartMusic();
        return;
    case kStateMainLoop:
        RunMainLoop(pFrameArg);
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
