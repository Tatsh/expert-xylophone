//
//  title_screen_layer0.mm
//  REFLEC BEAT plus
//
//  The theme-0 title-screen scene layer (TitleClassicScene). Reconstructed from Ghidra project
//  rb458, program rb458. @ghidraAddress values are relative to the program image base.
//

#include "titleclassicscene.h"

#import "AppDelegate.h"
#import "AudioManager.h"
#import "RBBGMManager.h"
#import "RBViewController.h"
#include "game_scene.h"
#include "gamesystem.h"
#include "neSpriteInstancing.h"
#include "neTexture.h"
#include "s_vector2.h"
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

// The instancer slot each sprite kind draws through (@ghidraAddress 0x309360): the nine title sprite
// kinds map onto the eight instancers (the last two kinds share the final slot).
constexpr unsigned int kTitleSpriteKindSlot[] = {0, 4, 5, 6, 7, 1, 2, 3, 3};

// The highest sprite kind the emitters accept (kinds below this are valid).
constexpr unsigned int kTitleSpriteKindCount = 9;

// The half factor used to centre the full-quad anchor.
constexpr float kQuadHalf = 0.5f;

// The opaque colour-channel value the full quad draws with.
constexpr unsigned int kTitleOpaque = 0xff;

// One per-kind title sprite layout: the sprite anchor, its pixel size, and its UV rectangle. The
// binary lazily builds these under a guard from read-only constants and the play-field centre split;
// the resolved records (indices 1 through 8; index 0 is unused since kind 0 draws a full quad) are
// reproduced here. The main-frame and alt-frame tables differ only in the last two records (the
// frame-specific logo).
struct TitleSpriteLayout {
    float flAnchorX;
    float flAnchorY;
    float flSizeW;
    float flSizeH;
    float flUvOriginU;
    float flUvOriginV;
    float flUvSizeU;
    float flUvSizeV;
};
constexpr TitleSpriteLayout kTitleLayoutMain[kTitleSpriteKindCount] = {
    {},
    {190.0f, 37.0f, 380.0f, 74.0f, 0.0f, 0.0f, 0.7421875f, 0.578125f},
    {175.0f, 22.0f, 350.0f, 44.0f, 0.0f, 0.0f, 0.68359375f, 0.6875f},
    {150.0f, 11.0f, 300.0f, 22.0f, 0.0f, 0.0f, 0.5859375f, 0.6875f},
    {384.0f, 512.0f, 768.0f, 1024.0f, 0.0f, 0.0f, 0.75f, 1.0f},
    {384.0f, 512.0f, 768.0f, 1024.0f, 0.0f, 0.0f, 0.75f, 1.0f},
    {255.0f, 202.5f, 510.0f, 405.0f, 0.0f, 0.0f, 0.99609375f, 0.79101562f},
    {133.0f, 157.0f, 278.0f, 256.0f, 0.0f, 0.0f, 0.5234375f, 1.0f},
    {132.0f, 157.0f, 278.0f, 256.0f, 0.0f, 0.0f, 1.0f, 1.0f},
};
constexpr TitleSpriteLayout kTitleLayoutAlt[kTitleSpriteKindCount] = {
    {},
    {190.0f, 37.0f, 380.0f, 74.0f, 0.0f, 0.0f, 0.7421875f, 0.578125f},
    {175.0f, 22.0f, 350.0f, 44.0f, 0.0f, 0.0f, 0.68359375f, 0.6875f},
    {150.0f, 11.0f, 300.0f, 22.0f, 0.0f, 0.0f, 0.5859375f, 0.6875f},
    {384.0f, 512.0f, 768.0f, 1024.0f, 0.0f, 0.0f, 0.75f, 1.0f},
    {384.0f, 512.0f, 768.0f, 1024.0f, 0.0f, 0.0f, 0.75f, 1.0f},
    {255.0f, 202.5f, 510.0f, 405.0f, 0.0f, 0.0f, 0.99609375f, 0.79101562f},
    {331.0f, 376.0f, 668.0f, 638.0f, 0.0f, 0.0f, 0.65234375f, 0.62304688f},
    {336.0f, 369.0f, 700.0f, 640.0f, 0.0f, 0.0f, 1.0f, 1.0f},
};
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
    for (ne::C_SPRITE_INSTANCING_2D *&pSprite : m_apSprites) {
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
        ne::C_SPRITE_INSTANCING_2D *pSprite =
            ne::CreateSpriteInstancer(g_aTitleSpriteCapacity[nSlot]);
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

/** @ghidraAddress 0x152a90 */
void TitleClassicScene::RenderTitleBackgroundFullQuad(unsigned int nSpriteKind,
                                                      const S_VECTOR2 &position,
                                                      float flSize,
                                                      float flRotation,
                                                      unsigned int nColorAlpha) {
    if (nSpriteKind >= kTitleSpriteKindCount) {
        return;
    }
    ne::C_SPRITE_INSTANCING_2D *pInstancer = m_apSprites[kTitleSpriteKindSlot[nSpriteKind]];
    const int nIndex = pInstancer->GetSpriteCount();
    if (nIndex >= static_cast<int>(pInstancer->GetCapacity())) {
        return;
    }

    // The quad fills the bound texture's image at its retina scale, centred on the position, with its
    // UV span the image's fraction of the allocated (power-of-two) atlas.
    ne::C_TEXTURE *pTexture = pInstancer->GetBoundTexture();
    const float flImageWidth = static_cast<float>(pTexture->GetImageWidth());
    const float flImageHeight = static_cast<float>(pTexture->GetImageHeight());
    const float flAllocWidth = static_cast<float>(pTexture->GetAllocWidth());
    const float flAllocHeight = static_cast<float>(pTexture->GetAllocHeight());
    const float flScale = pTexture->GetScale();

    pInstancer->SetSpritePosition(nIndex, position);
    pInstancer->SetSpriteAnchor(
        nIndex, S_VECTOR2{flImageWidth * kQuadHalf / flScale, flImageHeight * kQuadHalf / flScale});
    pInstancer->SetSpriteSize(nIndex, S_VECTOR2{flImageWidth / flScale, flImageHeight / flScale});
    pInstancer->SetSpriteScale(nIndex, flSize, flSize);
    pInstancer->SetSpriteRotation(nIndex, flRotation);
    pInstancer->SetSpriteUvOrigin(nIndex, S_VECTOR2{0.0f, 0.0f});
    pInstancer->SetSpriteUvSize(
        nIndex, S_VECTOR2{flImageWidth / flAllocWidth, flImageHeight / flAllocHeight});
    pInstancer->SetSpriteColor(nIndex, kTitleOpaque, kTitleOpaque, kTitleOpaque, nColorAlpha);

    pInstancer->SetSpriteCount(nIndex + 1);
}

/** @ghidraAddress 0x15259c */
void TitleClassicScene::EmitTitleSprite(unsigned int nSpriteKind,
                                        const S_VECTOR2 &position,
                                        float flSize,
                                        float flRotation,
                                        unsigned int nColorAlpha) {
    if (nSpriteKind >= kTitleSpriteKindCount) {
        return;
    }
    ne::C_SPRITE_INSTANCING_2D *pInstancer = m_apSprites[kTitleSpriteKindSlot[nSpriteKind]];
    const int nIndex = pInstancer->GetSpriteCount();
    if (nIndex >= static_cast<int>(pInstancer->GetCapacity())) {
        return;
    }

    if (nSpriteKind == 0) {
        // Kind 0 draws a full-texture quad sized from the bound texture, like the background quad.
        ne::C_TEXTURE *pTexture = pInstancer->GetBoundTexture();
        const float flImageWidth = static_cast<float>(pTexture->GetImageWidth());
        const float flImageHeight = static_cast<float>(pTexture->GetImageHeight());
        const float flAllocWidth = static_cast<float>(pTexture->GetAllocWidth());
        const float flAllocHeight = static_cast<float>(pTexture->GetAllocHeight());
        const float flScale = pTexture->GetScale();
        pInstancer->SetSpriteAnchor(
            nIndex,
            S_VECTOR2{flImageWidth * kQuadHalf / flScale, flImageHeight * kQuadHalf / flScale});
        pInstancer->SetSpriteSize(nIndex,
                                  S_VECTOR2{flImageWidth / flScale, flImageHeight / flScale});
        pInstancer->SetSpriteUvOrigin(nIndex, S_VECTOR2{0.0f, 0.0f});
        pInstancer->SetSpriteUvSize(
            nIndex, S_VECTOR2{flImageWidth / flAllocWidth, flImageHeight / flAllocHeight});
    } else {
        // Kinds 1 through 8 take a fixed layout from the frame-variant table (iPad uses the alt-frame
        // table, the phone the main-frame table).
        const TitleSpriteLayout &layout =
            IsPad() ? kTitleLayoutAlt[nSpriteKind] : kTitleLayoutMain[nSpriteKind];
        pInstancer->SetSpriteAnchor(nIndex, S_VECTOR2{layout.flAnchorX, layout.flAnchorY});
        pInstancer->SetSpriteSize(nIndex, S_VECTOR2{layout.flSizeW, layout.flSizeH});
        pInstancer->SetSpriteUvOrigin(nIndex, S_VECTOR2{layout.flUvOriginU, layout.flUvOriginV});
        pInstancer->SetSpriteUvSize(nIndex, S_VECTOR2{layout.flUvSizeU, layout.flUvSizeV});
    }

    pInstancer->SetSpritePosition(nIndex, position);
    pInstancer->SetSpriteScale(nIndex, flSize, flSize);
    pInstancer->SetSpriteRotation(nIndex, flRotation);
    pInstancer->SetSpriteColor(nIndex, kTitleOpaque, kTitleOpaque, kTitleOpaque, nColorAlpha);

    pInstancer->SetSpriteCount(nIndex + 1);
}

} // namespace rb
