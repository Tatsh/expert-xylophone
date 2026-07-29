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
#include "curve.h"
#include "gamesystem.h"
#include "neRender.h"
#include "neSpriteInstancing.h"
#include "neTexture.h"
#include "s_vector2.h"
#include "soundeffectmanager.h"
#import "touchmanager.h"

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

// The maximum value of an opaque colour channel.
constexpr unsigned int kColorMax = 255;

// The textured title sprite kinds (1..3 inclusive) bind and size from their instancer's texture;
// the two backdrop kinds (0 and 4) draw a full-viewport quad from the game system instead.
constexpr unsigned int kTitleKindTexturedFirst = 1;
constexpr unsigned int kTitleKindTexturedLast = 3;
constexpr unsigned int kTitleKindBackdropWhite = 0;

// The five title sprite kinds the per-frame update emits.
constexpr unsigned int kTitleKindBackdrop = 0;    // The white full-viewport backdrop quad.
constexpr unsigned int kTitleKindLogo0 = 1;       // The first cross-fading logo layer.
constexpr unsigned int kTitleKindLogo1 = 2;       // The second cross-fading logo layer.
constexpr unsigned int kTitleKindLogo2 = 3;       // The third cross-fading logo layer.
constexpr unsigned int kTitleKindFadeOverlay = 4; // The black fade-to-play overlay.

// The title-start timing: the earliest tap that starts the fade, the auto-timeout that starts it
// without a tap, the play state the completed fade latches, and the fade duration in frame-time.
constexpr int kTitleTapEarliest = 2999;
constexpr int kTitleAutoTimeout = 0x1d4d; // 7501 frames.
constexpr float kTitleFadeComplete = 1.0f;

// The unit-interval-to-alpha scale (@ghidraAddress 0x2eed00) and the viewport-centre half factor.
constexpr float kAlphaByteScale = 255.0f;
constexpr float kTitleCentreFactor = 0.5f;

// The unit scale every emitted title sprite draws at.
constexpr float kTitleSpriteScale = 1.0f;

// The number of {time, alpha} pairs in each logo-layer fade curve.
constexpr int kTitleFadeCurvePairs = 4;

// The three logo layers' fade-in/out alpha curves, keyed on the animation clock (@ghidraAddress
// 0x308d54, 0x308d74, 0x308d94). Each holds four {time, alpha} pairs.
constexpr float kTitleLogoFadeCurve0[] = {
    500.0f, 0.0f, 1000.0f, 1.0f, 2000.0f, 1.0f, 2500.0f, 0.0f};
constexpr float kTitleLogoFadeCurve1[] = {
    2500.0f, 0.0f, 3000.0f, 1.0f, 4000.0f, 1.0f, 4500.0f, 0.0f};
constexpr float kTitleLogoFadeCurve2[] = {
    4500.0f, 0.0f, 5000.0f, 1.0f, 7000.0f, 1.0f, 7500.0f, 0.0f};

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

/** @ghidraAddress 0x149c5c */
void LogoScene::Present(int nDeltaMs) {
    m_nElapsedMs += nDeltaMs;

    // Clear each of the five sprite instancers for this frame's re-emission.
    for (ne::C_SPRITE_INSTANCING_2D *pInstancer : m_apLayers) {
        pInstancer->SetSpriteCount(0);
    }

    // Begin the fade-out to play on the first qualifying tap: the caution must have been read and
    // the tap must land after the intro window.
    if (!m_bStarted) {
        if ([RBUserSettingData sharedInstance].alreadyReadTitleCaution &&
            m_nElapsedMs > kTitleTapEarliest &&
            TouchManager::FetchSharedSingleton()->HasActiveTouch()) {
            m_fade.SetStart(m_fade.GetCurrent());
            m_fade.SetEnd(kTitleFadeComplete);
            m_fade.SetDuration(kFadeDuration);
            m_fade.SetElapsed(0.0f);
            m_bStarted = true;
        }
    }

    CalculateFade(nDeltaMs);

    if (m_bStarted) {
        // Latch the play state once the fade-out has fully completed.
        if (m_fade.GetCurrent() >= kTitleFadeComplete) {
            m_nState = kStateStart;
        }
    } else if (m_nElapsedMs >= kTitleAutoTimeout && m_fade.GetEnd() <= 0.0f) {
        // No tap arrived before the timeout: start the same fade automatically.
        m_bStarted = true;
        m_fade.SetStart(m_fade.GetCurrent());
        m_fade.SetEnd(kTitleFadeComplete);
        m_fade.SetDuration(kFadeDuration);
        m_fade.SetElapsed(0.0f);
    }

    // The three logo layers all centre on the viewport; their alpha comes from their own fade
    // curve.
    GameSystem *pGameSystem = GameSystem::GetGameSystem();
    const S_VECTOR2 origin{0.0f, 0.0f};
    const S_VECTOR2 centre{pGameSystem->GetViewportWidth() * kTitleCentreFactor,
                           pGameSystem->GetViewportHeight() * kTitleCentreFactor};
    const auto flClock = static_cast<float>(m_nElapsedMs);

    // The white backdrop, drawn opaque behind everything.
    SetTitleSprite(
        kTitleKindBackdrop, &origin, kTitleSpriteScale, static_cast<int>(kAlphaByteScale));

    const int nLogo0Alpha = static_cast<int>(
        CalculateCurveInterpolation(kTitleLogoFadeCurve0, kTitleFadeCurvePairs, flClock) *
        kAlphaByteScale);
    SetTitleSprite(kTitleKindLogo0, &centre, kTitleSpriteScale, nLogo0Alpha);

    const int nLogo1Alpha = static_cast<int>(
        CalculateCurveInterpolation(kTitleLogoFadeCurve1, kTitleFadeCurvePairs, flClock) *
        kAlphaByteScale);
    SetTitleSprite(kTitleKindLogo1, &centre, kTitleSpriteScale, nLogo1Alpha);

    const int nLogo2Alpha = static_cast<int>(
        CalculateCurveInterpolation(kTitleLogoFadeCurve2, kTitleFadeCurvePairs, flClock) *
        kAlphaByteScale);
    SetTitleSprite(kTitleKindLogo2, &centre, kTitleSpriteScale, nLogo2Alpha);

    // The black fade-to-play overlay: its alpha tracks the fade channel's current value.
    const int nOverlayAlpha = static_cast<int>(m_fade.GetCurrent() * kAlphaByteScale);
    SetTitleSprite(kTitleKindFadeOverlay, &origin, kTitleSpriteScale, nOverlayAlpha);
}

/** @ghidraAddress 0x149ff4 */
void LogoScene::CalculateFade(int nDeltaMs) {
    m_fade.Advance(static_cast<float>(nDeltaMs));
}

/** @ghidraAddress 0x14a040 */
void LogoScene::SetTitleSprite(unsigned int nKind,
                               const S_VECTOR2 *pPosition,
                               float flScale,
                               int nAlpha) {
    if (nKind >= kLayerCount) {
        return;
    }

    // The kind indexes both the instancer and (by identity) the slot table; a full instancer drops
    // the sprite.
    ne::C_SPRITE_INSTANCING_2D *pInstancer = m_apLayers[nKind];
    const int nSlot = pInstancer->GetSpriteCount();
    if (nSlot >= static_cast<int>(pInstancer->GetCapacity())) {
        return;
    }

    if (nKind >= kTitleKindTexturedFirst && nKind <= kTitleKindTexturedLast) {
        // A textured sprite: size and place it from its instancer's bound texture.
        ne::C_TEXTURE *pTexture = pInstancer->GetBoundTexture();

        // The texture's point size (its pixel size divided by the retina scale), truncated to whole
        // pixels for the size and to a half-size centre for the anchor.
        const int nPointWidth =
            static_cast<int>(static_cast<float>(pTexture->GetImageWidth()) / pTexture->GetScale());
        const int nPointHeight =
            static_cast<int>(static_cast<float>(pTexture->GetImageHeight()) / pTexture->GetScale());

        pInstancer->SetSpritePosition(nSlot, *pPosition);
        pInstancer->SetSpriteAnchor(
            nSlot,
            S_VECTOR2{static_cast<float>(nPointWidth >> 1), static_cast<float>(nPointHeight >> 1)});
        pInstancer->SetSpriteSize(
            nSlot, S_VECTOR2{static_cast<float>(nPointWidth), static_cast<float>(nPointHeight)});
        pInstancer->SetSpriteScale(nSlot, flScale, flScale);
        pInstancer->SetSpriteUvOrigin(nSlot, S_VECTOR2{0.0f, 0.0f});
        // The UV span is the source image's fraction of the allocated (power-of-two) texture.
        pInstancer->SetSpriteUvSize(
            nSlot,
            S_VECTOR2{static_cast<float>(pTexture->GetImageWidth()) / pTexture->GetAllocWidth(),
                      static_cast<float>(pTexture->GetImageHeight()) / pTexture->GetAllocHeight()});
        pInstancer->SetSpriteColor(
            nSlot, kColorMax, kColorMax, kColorMax, static_cast<unsigned int>(nAlpha));
    } else {
        // A backdrop quad: a full-viewport rectangle from the game system, pinned to the origin,
        // white for kind 0 and black for kind 4. The caller's position and scale are unused here.
        GameSystem *pGameSystem = GameSystem::GetGameSystem();
        pInstancer->SetSpritePosition(nSlot, S_VECTOR2{0.0f, 0.0f});
        pInstancer->SetSpriteAnchor(nSlot, S_VECTOR2{0.0f, 0.0f});
        pInstancer->SetSpriteSize(
            nSlot, S_VECTOR2{pGameSystem->GetViewportWidth(), pGameSystem->GetViewportHeight()});
        const unsigned int nChannel = nKind == kTitleKindBackdropWhite ? kColorMax : 0;
        pInstancer->SetSpriteColor(
            nSlot, nChannel, nChannel, nChannel, static_cast<unsigned int>(nAlpha));
    }

    pInstancer->SetSpriteCount(nSlot + 1);
}

} // namespace rb
