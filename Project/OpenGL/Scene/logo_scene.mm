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

constexpr const char *kKonamiTextureName = "konami";
constexpr const char *kBemaniTextureName = "bemani";
constexpr const char *kRatingTextureName = "nonage";

// @ghidraAddress 0x308d40
constexpr int kLayerSourceIndex[rb::LogoScene::kLayerCount] = {4, 0, 1, 2, 4};

constexpr int kNoSourceIndex = 4;

constexpr unsigned int kLayerSpriteCapacity = 1;

constexpr float kFadeDuration = 1000.0f;

enum {
    kStateInitialise = 0,
    kStatePresent = 1,
    kStateStart = 2,
};

constexpr unsigned int kColorMax = 255;

constexpr unsigned int kTitleKindTexturedFirst = 1;
constexpr unsigned int kTitleKindTexturedLast = 3;
constexpr unsigned int kTitleKindBackdropWhite = 0;

constexpr unsigned int kTitleKindBackdrop = 0;
constexpr unsigned int kTitleKindLogo0 = 1;
constexpr unsigned int kTitleKindLogo1 = 2;
constexpr unsigned int kTitleKindLogo2 = 3;
constexpr unsigned int kTitleKindFadeOverlay = 4;

constexpr int kTitleTapEarliest = 2999;
constexpr int kTitleAutoTimeout = 0x1d4d; // 7501 frames.
constexpr float kTitleFadeComplete = 1.0f;

// @ghidraAddress 0x2eed00
constexpr float kAlphaByteScale = 255.0f;
constexpr float kTitleCentreFactor = 0.5f;

constexpr float kTitleSpriteScale = 1.0f;

constexpr int kTitleFadeCurvePairs = 4;

// @ghidraAddress 0x308d54, 0x308d74, 0x308d94
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
            // The scene graph owns the sprite node, so flag it rather than deleting it here.
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

        const int nSource = kLayerSourceIndex[nLayer];
        if (nSource != kNoSourceIndex) {
            pLayer->SetRefCountedMember(apTextures[nSource]);
        }
        pLayer->SetSpriteCount(0);
    }

    SoundEffectManager::GetInstance()->LoadAll();

    m_bStarted = false;
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

    for (ne::C_SPRITE_INSTANCING_2D *pInstancer : m_apLayers) {
        pInstancer->SetSpriteCount(0);
    }

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
        if (m_fade.GetCurrent() >= kTitleFadeComplete) {
            m_nState = kStateStart;
        }
    } else if (m_nElapsedMs >= kTitleAutoTimeout && m_fade.GetEnd() <= 0.0f) {
        m_bStarted = true;
        m_fade.SetStart(m_fade.GetCurrent());
        m_fade.SetEnd(kTitleFadeComplete);
        m_fade.SetDuration(kFadeDuration);
        m_fade.SetElapsed(0.0f);
    }

    GameSystem *pGameSystem = GameSystem::GetGameSystem();
    const S_VECTOR2 origin{0.0f, 0.0f};
    const S_VECTOR2 centre{pGameSystem->GetViewportWidth() * kTitleCentreFactor,
                           pGameSystem->GetViewportHeight() * kTitleCentreFactor};
    const auto flClock = static_cast<float>(m_nElapsedMs);

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

    ne::C_SPRITE_INSTANCING_2D *pInstancer = m_apLayers[nKind];
    const int nSlot = pInstancer->GetSpriteCount();
    if (nSlot >= static_cast<int>(pInstancer->GetCapacity())) {
        return;
    }

    if (nKind >= kTitleKindTexturedFirst && nKind <= kTitleKindTexturedLast) {
        ne::C_TEXTURE *pTexture = pInstancer->GetBoundTexture();

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
        // The image occupies only its fraction of the power-of-two allocation.
        pInstancer->SetSpriteUvSize(
            nSlot,
            S_VECTOR2{static_cast<float>(pTexture->GetImageWidth()) / pTexture->GetAllocWidth(),
                      static_cast<float>(pTexture->GetImageHeight()) / pTexture->GetAllocHeight()});
        pInstancer->SetSpriteColor(
            nSlot, kColorMax, kColorMax, kColorMax, static_cast<unsigned int>(nAlpha));
    } else {
        // The backdrop quads ignore the caller's position and scale.
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
