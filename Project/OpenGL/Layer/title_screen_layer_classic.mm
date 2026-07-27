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

#import "soundeffectmanager.h"

// The themed sound-effect slot the completed Konami code fires (the secret/credits jingle).
static constexpr int kSoundEffectTitleSecret = 0xd;

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
