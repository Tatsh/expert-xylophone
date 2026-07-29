//
//  title_screen_layer_classic.mm
//  REFLEC BEAT plus
//
//  The classic title screen layer's per-frame animation: the fade channel, the touch-to-start and
//  auto-timeout handling, and the three cross-fading logo layers. Objective-C++ because the start
//  gate reads the user settings through the Objective-C runtime.
//
//  Reconstructed from Ghidra project rb458, program rb458. @ghidraAddress values are relative to
//  the program image base.
//

#import "title_screen_layer_classic.h"

#import "RBUserSettingData.h"
#import "curve.h"
#import "gamesystem.h"
#import "neSpriteInstancing.h"
#import "neTexture.h"
#import "s_vector2.h"
#import "touchmanager.h"

// The maximum value of an opaque colour channel.
static constexpr unsigned int kColorMax = 255;

// The textured title sprite kinds (1..3 inclusive) bind and size from their instancer's texture; the
// two backdrop kinds (0 and 4) draw a full-viewport quad from the game system instead.
static constexpr unsigned int kTitleKindTexturedFirst = 1;
static constexpr unsigned int kTitleKindTexturedLast = 3;
static constexpr unsigned int kTitleKindBackdropWhite = 0;

// The five title sprite kinds the per-frame update emits.
static constexpr unsigned int kTitleKindBackdrop = 0;    // The white full-viewport backdrop quad.
static constexpr unsigned int kTitleKindLogo0 = 1;       // The first cross-fading logo layer.
static constexpr unsigned int kTitleKindLogo1 = 2;       // The second cross-fading logo layer.
static constexpr unsigned int kTitleKindLogo2 = 3;       // The third cross-fading logo layer.
static constexpr unsigned int kTitleKindFadeOverlay = 4; // The black fade-to-play overlay.

// The title-start timing: the earliest tap that starts the fade, the auto-timeout that starts it
// without a tap, the play state the completed fade latches, and the fade duration in frame-time.
static constexpr int kTitleTapEarliest = 2999;
static constexpr int kTitleAutoTimeout = 0x1d4d; // 7501 frames.
static constexpr int kTitleStatePlay = 2;
static constexpr float kTitleFadeDuration = 1000.0f;
static constexpr float kTitleFadeComplete = 1.0f;

// The unit-interval-to-alpha scale (@ghidraAddress 0x2eed00) and the viewport-centre half factor.
static constexpr float kAlphaByteScale = 255.0f;
static constexpr float kTitleCentreFactor = 0.5f;

// The unit scale every emitted title sprite draws at.
static constexpr float kTitleSpriteScale = 1.0f;

// The number of {time, alpha} pairs in each logo-layer fade curve.
static constexpr int kTitleFadeCurvePairs = 4;

// The three logo layers' fade-in/out alpha curves, keyed on the animation clock (@ghidraAddress
// 0x308d54, 0x308d74, 0x308d94). Each holds four {time, alpha} pairs.
static constexpr float kTitleLogoFadeCurve0[] = {
    500.0f, 0.0f, 1000.0f, 1.0f, 2000.0f, 1.0f, 2500.0f, 0.0f};
static constexpr float kTitleLogoFadeCurve1[] = {
    2500.0f, 0.0f, 3000.0f, 1.0f, 4000.0f, 1.0f, 4500.0f, 0.0f};
static constexpr float kTitleLogoFadeCurve2[] = {
    4500.0f, 0.0f, 5000.0f, 1.0f, 7000.0f, 1.0f, 7500.0f, 0.0f};

/** @ghidraAddress 0x149c5c */
void TitleScreenLayerClassic::ProcessTitleLayer(int nDeltaFrames) {
    m_nElapsed += nDeltaFrames;

    // Clear each of the five sprite instancers for this frame's re-emission.
    for (ne::C_SPRITE_INSTANCING_2D *pInstancer : m_apInstancers) {
        pInstancer->SetSpriteCount(0);
    }

    // Begin the fade-out to play on the first qualifying tap: the caution must have been read and the
    // tap must land after the intro window.
    if (!m_bStartTriggered) {
        if ([RBUserSettingData sharedInstance].alreadyReadTitleCaution &&
            m_nElapsed > kTitleTapEarliest &&
            TouchManager::FetchSharedSingleton()->HasActiveTouch()) {
            m_fadeChannel.SetStart(m_fadeChannel.GetCurrent());
            m_fadeChannel.SetEnd(kTitleFadeComplete);
            m_fadeChannel.SetDuration(kTitleFadeDuration);
            m_fadeChannel.SetElapsed(0.0f);
            m_bStartTriggered = true;
        }
    }

    CalculateFade(nDeltaFrames);

    if (m_bStartTriggered) {
        // Latch the play state once the fade-out has fully completed.
        if (m_fadeChannel.GetCurrent() >= kTitleFadeComplete) {
            m_nState = kTitleStatePlay;
        }
    } else if (m_nElapsed >= kTitleAutoTimeout && m_fadeChannel.GetEnd() <= 0.0f) {
        // No tap arrived before the timeout: start the same fade automatically.
        m_bStartTriggered = true;
        m_fadeChannel.SetStart(m_fadeChannel.GetCurrent());
        m_fadeChannel.SetEnd(kTitleFadeComplete);
        m_fadeChannel.SetDuration(kTitleFadeDuration);
        m_fadeChannel.SetElapsed(0.0f);
    }

    // The three logo layers all centre on the viewport; their alpha comes from their own fade curve.
    GameSystem *pGameSystem = GameSystem::GetGameSystem();
    const S_VECTOR2 origin{0.0f, 0.0f};
    const S_VECTOR2 centre{pGameSystem->GetViewportWidth() * kTitleCentreFactor,
                           pGameSystem->GetViewportHeight() * kTitleCentreFactor};
    const auto flClock = static_cast<float>(m_nElapsed);

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
    const int nOverlayAlpha = static_cast<int>(m_fadeChannel.GetCurrent() * kAlphaByteScale);
    SetTitleSprite(kTitleKindFadeOverlay, &origin, kTitleSpriteScale, nOverlayAlpha);
}

/** @ghidraAddress 0x149ff4 */
void TitleScreenLayerClassic::CalculateFade(int nDeltaFrames) {
    m_fadeChannel.Advance(static_cast<float>(nDeltaFrames));
}

/** @ghidraAddress 0x14a040 */
void TitleScreenLayerClassic::SetTitleSprite(unsigned int nKind,
                                             const S_VECTOR2 *pPosition,
                                             float flScale,
                                             int nAlpha) {
    if (nKind >= kInstancerCount) {
        return;
    }

    // The kind indexes both the instancer and (by identity) the slot table; a full instancer drops
    // the sprite.
    ne::C_SPRITE_INSTANCING_2D *pInstancer = m_apInstancers[nKind];
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
