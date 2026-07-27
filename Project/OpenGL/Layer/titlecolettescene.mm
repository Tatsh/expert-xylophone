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

// The fully-shown fade level the scene starts at, and the sentinel for no selected slot.
constexpr float kInitialFadeBase = 1.0f;
constexpr int kNoSlotIndex = -1;
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
    // scalars and copy the part anchor ring into place.
    m_flFadeBase = kInitialFadeBase;
    m_nTrailingIndex = kNoSlotIndex;
    for (int nPart = 0; nPart < kPartAnchorCount; ++nPart) {
        m_aPartAnchor[nPart] = g_aTitleCampaignPartAnchor[nPart];
    }
}

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
