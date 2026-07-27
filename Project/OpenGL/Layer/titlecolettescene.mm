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
#import "RBCampaignData.h"
#import "RBUserSettingData.h"
#import "RBViewController.h"
#import "SePlayer.h"
#include "game_scene.h"
#include "gamesystem.h"
#include "neSpriteInstancing.h"
#include "neTexture.h"
#include "shotsoundmanager.h"
#include "soundeffectmanager.h"

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

// The three shared title texture base names; the fourth cached texture is the campaign-specific one.
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
// The fixed drop-in offset seeded into the fade transform's third element.
constexpr float kFadeDropOffset = 300.0f;

// The theme sound-effect path format and its two components' file type.
static NSString *const kTitleSeFormat = @"Sounds/%@/SE/SD_SE_%@";
static NSString *const kTitleSeType = @"m4a";
// The part name spliced into the theme sound-effect path (@ghidraAddress 0x35dca8).
static NSString *const kTitleSePartName = @"JUMP";
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

/** @ghidraAddress 0x57558 */
void TitleColetteScene::LoadResources() {
    m_nFadeTimer = 0;
    m_nScrollTimer = 0;

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

    // Build the 104 part sprite instancers: register each in the global scene tree, make it visible,
    // bind its texture from the layout table (unless the part binds none), and seed its sprite count.
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

    // Seed the fade transform: element zero from the fade base, element two the fixed drop-in offset,
    // the rest zero.
    m_aFadeTransform[0] = m_flFadeBase;
    m_aFadeTransform[1] = 0.0f;
    m_aFadeTransform[2] = kFadeDropOffset;
    m_aFadeTransform[3] = 0.0f;
    m_aFadeTransform[4] = 0.0f;

    // Create the theme's sound-effect player from the theme-named SE path.
    const RBUserSettingDataTheme themaID = RBUserSettingData.sharedInstance.thema;
    NSString *seName = [NSString stringWithFormat:kTitleSeFormat,
                                                  [RBUserSettingData themaNameWithID:themaID],
                                                  kTitleSePartName];
    NSString *sePath = [NSBundle.mainBundle pathForResource:seName ofType:kTitleSeType];
    m_pSePlayer = [[SePlayer alloc] initWithPath:sePath];

    m_nState = kStateStartMusic;
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
