//
//  logo_scene.mm
//  REFLEC BEAT plus
//
//  The boot logo scene (rb::LogoScene). Reconstructed from Ghidra project rb458, program rb458.
//  @ghidraAddress values are relative to the program image base.
//

#include "logo_scene.h"

#import "AppDelegate.h"
#import "AudioManager.h"
#import "RBUserSettingData.h"
#include "neRender.h"
#include "neSpriteInstancing.h"
#include "neTexture.h"
#include "soundeffectmanager.h"

namespace {

// The logo texture names, loaded into the scene's three texture slots.
constexpr const char *kKonamiTextureName = "konami";
constexpr const char *kBemaniTextureName = "bemani";
constexpr const char *kRatingTextureName = "nonage";

// The sprite-source index each logo layer binds to (an index into the three loaded textures);
// layers 0 and 4 carry no source and keep the sentinel value 4 (@ghidraAddress 0x308d40).
constexpr int kLayerSourceIndex[rb::LogoScene::kLayerCount] = {4, 0, 1, 2, 4};

// The sentinel source index that marks a layer as having no bound texture.
constexpr int kNoSourceIndex = 4;

// The per-logo sprite capacity each layer instancer is built with.
constexpr unsigned int kLayerSpriteCapacity = 1;

// The fade tween's duration, seeded when the present animation begins.
constexpr float kFadeDuration = 1000.0f;

// The scene states dispatched from the per-frame callback.
enum {
    kStateInitialise = 0,
    kStatePresent = 1,
    kStateStart = 2,
};

} // namespace

namespace rb {

/** @ghidraAddress 0x149a04 */
LogoScene::LogoScene() {
    // The base constructor installs the task node; the member initialisers zero-clear the
    // animation, fade, and sprite state. The fade's current value is seeded to one.
    m_fade.SetCurrent(1.0f);
}

/** @ghidraAddress 0x149a6c */
LogoScene::~LogoScene() {
    ne::C_TEXTURE *apTextures[] = {m_pKonamiTexture, m_pBemaniTexture, m_pRatingTexture};
    for (auto *&pTexture : apTextures) {
        if (pTexture != nullptr) {
            pTexture->Release();
            pTexture = nullptr;
        }
    }

    for (auto *&pLayer : m_apLayers) {
        if (pLayer != nullptr) {
            // The sprite node is owned by the scene graph; flag it for the walker to delete.
            pLayer->RequestDelete();
            pLayer = nullptr;
        }
    }
}

/** @ghidraAddress 0x149b40 */
void LogoScene::OnFrame(int nElapsedMs) {
    const int nDeltaMs = nElapsedMs;
    switch (m_nState) {
    case kStateInitialise:
        Initialise();
        break;
    case kStatePresent:
        Present(nDeltaMs);
        break;
    case kStateStart:
        Start();
        break;
    default:
        break;
    }
}

/** @ghidraAddress 0x149b68 */
void LogoScene::Initialise() {
    m_nElapsedMs = 0;

    m_pKonamiTexture = ne::C_TEXTURE::FindOrLoadCached(kKonamiTextureName);
    m_pBemaniTexture = ne::C_TEXTURE::FindOrLoadCached(kBemaniTextureName);
    m_pRatingTexture = ne::C_TEXTURE::FindOrLoadCached(kRatingTextureName);
    ne::C_TEXTURE *apTextures[] = {m_pKonamiTexture, m_pBemaniTexture, m_pRatingTexture};

    for (int nLayer = 0; nLayer < kLayerCount; ++nLayer) {
        m_aLayerStateAc[nLayer] = 1;
        ne::C_SPRITE_INSTANCING_2D *pLayer = ne::CreateSpriteInstancer(kLayerSpriteCapacity);
        m_apLayers[nLayer] = pLayer;
        pLayer->RegisterGlobal();
        pLayer->SetVisible(true);

        // Layers 0 and 4 carry no source texture; the others bind one of the three logos.
        const int nSource = kLayerSourceIndex[nLayer];
        if (nSource != kNoSourceIndex) {
            pLayer->SetRefCountedMember(apTextures[nSource]);
        }
        pLayer->SetSpriteCount(0);
    }

    SoundEffectManager::GetInstance()->LoadAll();

    m_bStarted = false;
    // Seed the fade to ease from its current value to zero over the fade duration.
    m_fade.SetStart(m_fade.GetCurrent());
    m_fade.SetEnd(0.0f);
    m_fade.SetDuration(kFadeDuration);
    m_fade.SetElapsed(0.0f);
    m_nState = kStatePresent;
}

/** @ghidraAddress 0x149ec8 */
void LogoScene::Start() {
    if (![AudioManager.sharedManager isStart]) {
        return;
    }
    [AppDelegate.appDelegate startApplication];
    RBUserSettingData.sharedInstance.alreadyReadTitleCaution = YES;
    [RBUserSettingData.sharedInstance save];
    MarkDead();
}

} // namespace rb
