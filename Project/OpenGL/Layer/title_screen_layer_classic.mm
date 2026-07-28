//
//  title_screen_layer_classic.mm
//  REFLEC BEAT plus
//
//  The classic title screen layer's hidden Konami-code swipe state machine and its two fade
//  channels. A directional swipe (or the A/B input) advances a small step counter along the code
//  (up, up, down, down, left, right, left, right, B, A); completing it plays a themed sound effect
//  and latches a flag. Objective-C++ because the sound path reaches the ne engine bridge.
//
//  Reconstructed from Ghidra project rb458, program rb458. @ghidraAddress values are relative to
//  the program image base.
//

#import "title_screen_layer_classic.h"

#import "gamesystem.h"
#import "neSpriteInstancing.h"
#import "neTexture.h"
#import "s_vector2.h"
#import "soundeffectmanager.h"

// The themed sound-effect slot the completed Konami code fires (the secret/credits jingle).
static constexpr int kSoundEffectTitleSecret = 0xd;

// The maximum value of an opaque colour channel.
static constexpr unsigned int kColorMax = 255;

// The textured title sprite kinds (1..3 inclusive) bind and size from their instancer's texture; the
// two backdrop kinds (0 and 4) draw a full-viewport quad from the game system instead.
static constexpr unsigned int kTitleKindTexturedFirst = 1;
static constexpr unsigned int kTitleKindTexturedLast = 3;
static constexpr unsigned int kTitleKindBackdropWhite = 0;

// The directional-swipe and button inputs the title touch handling classifies from flick direction
// and the corner hit-boxes. The sequence is the Konami code: up, up, down, down, left, right, left,
// right, B, A.
enum TitleSwipeInput {
    kTitleSwipeUp = 0,      // An upward flick.
    kTitleSwipeDown = 1,    // A downward flick.
    kTitleSwipeLeft = 2,    // A leftward flick.
    kTitleSwipeRight = 3,   // A rightward flick.
    kTitleSwipeButtonA = 4, // The "A" confirm input that completes a sequence.
    kTitleSwipeButtonB = 5, // The "B" input, the penultimate step.
};

// The progress steps through the Konami-code sequence.
enum TitleSwipeStep {
    kSwipeStepNone = 0,      // No input entered yet.
    kSwipeStepUp1 = 1,       // First up entered.
    kSwipeStepUp2 = 2,       // Second up entered.
    kSwipeStepDown1 = 3,     // First down entered.
    kSwipeStepDown2 = 4,     // Second down entered.
    kSwipeStepLeft1 = 5,     // First left entered.
    kSwipeStepRight1 = 6,    // First right entered.
    kSwipeStepLeft2 = 7,     // Second left entered.
    kSwipeStepRight2 = 8,    // Second right entered.
    kSwipeStepButtonB = 9,   // B entered; the next A completes the swing sequence.
    kSwipeStepComplete = 10, // The swing sequence completed.
};

void TitleScreenLayerClassic::AdvanceSwipeState(int iSwipeEvent) {
    /** @ghidraAddress 0x152cc8 */
    switch (iSwipeEvent) {
    case kTitleSwipeUp:
        if (m_nSwipeState != kSwipeStepUp1) {
            if (m_nSwipeState != kSwipeStepNone) {
                return;
            }
            m_nSwipeState = kSwipeStepUp1;
        }
        m_nSwipeState = kSwipeStepUp2;
        return;
    case kTitleSwipeDown:
        if (m_nSwipeState != kSwipeStepDown1) {
            if (m_nSwipeState != kSwipeStepUp2) {
                return;
            }
            m_nSwipeState = kSwipeStepDown1;
        }
        m_nSwipeState = kSwipeStepDown2;
        return;
    case kTitleSwipeLeft:
        if (m_nSwipeState == kSwipeStepRight1) {
            m_nSwipeState = kSwipeStepLeft2;
        } else if (m_nSwipeState == kSwipeStepDown2) {
            m_nSwipeState = kSwipeStepLeft1;
        }
        return;
    case kTitleSwipeRight:
        if (m_nSwipeState == kSwipeStepLeft2) {
            m_nSwipeState = kSwipeStepRight2;
        } else if (m_nSwipeState == kSwipeStepLeft1) {
            m_nSwipeState = kSwipeStepRight1;
        }
        return;
    case kTitleSwipeButtonA:
        // The final A after B completes the code: fire the secret effect and latch the flag.
        if (m_nSwipeState == kSwipeStepButtonB) {
            m_nSwipeState = kSwipeStepComplete;
            SoundEffectManager::GetInstance()->PlayThemedSoundEffect(kSoundEffectTitleSecret);
            m_bSwipeTriggered = true;
        }
        return;
    case kTitleSwipeButtonB:
        if (m_nSwipeState == kSwipeStepRight2) {
            m_nSwipeState = kSwipeStepButtonB;
        }
        return;
    default:
        return;
    }
}

/** @ghidraAddress 0x149ff4 */
void TitleScreenLayerClassic::CalculateFade(int nDeltaFrames) {
    m_fadeChannel.Advance(static_cast<float>(nDeltaFrames));
}

/** @ghidraAddress 0x152548 */
void TitleScreenLayerClassic::AdvanceFadeValue(int nDeltaFrames) {
    m_fadeValueChannel.Advance(static_cast<float>(nDeltaFrames));
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
