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

// The background part fills the screen from its texture; the logo parts carry a distinct render type.
constexpr unsigned int kBackgroundPartId = 0;
constexpr int kPartTypeLogo = 3;

// The landscape layout recentres each part around the viewport: it offsets by half the design
// resolution, scales to 0.8, halves, and adds the viewport centre.
constexpr float kLandscapeOffsetX = -384.0f; // @ghidraAddress 0x2f8568
constexpr float kLandscapeOffsetY = -512.0f; // @ghidraAddress 0x2f8570
constexpr float kLandscapeScale = 0.8f;      // @ghidraAddress 0x2f856c
constexpr float kHalf = 0.5f;

// The sound-effect part's landscape hit-box is nudged and grown relative to its sprite.
constexpr float kSeHitOffsetX = -40.0f; // @ghidraAddress 0x2f8574
constexpr float kSeHitOffsetY = -30.0f;
constexpr float kSeHitGrowX = 80.0f; // @ghidraAddress 0x2f855c
constexpr float kSeHitGrowY = 60.0f; // @ghidraAddress 0x2f8578

// The part ids that carry a touch hit-box, and the hit-box slot each records into.
enum TitlePartId {
    kPartSoundEffect = 0x5d,
    kPartLetterF = 0x46,
    kPartLetterI = 0x49,
    kPartLetterG = 0x47,
    kPartLetterD = 0x44,
    kPartLetterA = 0x41,
    kPartCorporateLogo = 0x62,
};
enum TitleHitBoxSlot {
    kHitBoxSoundEffect = 0,
    kHitBoxLetterF = 1,
    kHitBoxLetterI = 2,
    kHitBoxLetterG = 3,
    kHitBoxLetterD = 4,
    kHitBoxLetterA = 5,
    kHitBoxCorporateLogo = 7,
};
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
    case kPartCorporateLogo:
        nSlot = kHitBoxCorporateLogo;
        break;
    case kPartSoundEffect:
        // The sound-effect part in the landscape layout uses a nudged, grown hit-box; the portrait
        // layout uses the plain rectangle.
        if (!IsPad()) {
            m_aHitBox[kHitBoxSoundEffect] = TitleHitRect{flLeft + kSeHitOffsetX,
                                                         flTop + kSeHitOffsetY,
                                                         layout.flWidth + kSeHitGrowX,
                                                         layout.flHeight + kSeHitGrowY};
            return;
        }
        nSlot = kHitBoxSoundEffect;
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
        // The other parts take their placement from the platform layout table and their UV rectangle
        // from the type-specific atlas table.
        const bool bIsPad = IsPad();
        const TitlePartLayoutRecord &layout =
            (bIsPad ? g_aTitleCampaignLayoutAltFrame : g_aTitleCampaignLayoutDefault)[nPartId];
        const SpriteUvEntry *pUvTable;
        if (layout.nTextureIndex == kPartTypeLogo) {
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

        // The touchable parts record their hit-box (top-left corner and extent) for the main loop.
        RecordPartHitBox(nPartId, drawPosition, layout);
    }

    pSprite->SetSpriteRotation(nIndex, flRotation);
    // The tint fades out with the scene's reveal: colours darken and the alpha drops as the fade
    // level rises toward one.
    const float flReveal = 1.0f - m_flFadeBase;
    pSprite->SetSpriteColor(nIndex,
                            static_cast<unsigned int>(flReveal * color.r),
                            static_cast<unsigned int>(flReveal * color.g),
                            static_cast<unsigned int>(flReveal * color.b),
                            static_cast<unsigned int>(static_cast<float>(nAlpha) * flReveal));
    pSprite->SetSpriteCount(nIndex + 1);
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
