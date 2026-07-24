//
//  title_screen_layer_colette.mm
//  REFLEC BEAT plus
//
//  The theme-2 (Colette) title screen layer's hidden Konami-code state machine. A directional swipe
//  (or the A/B input) advances a small step counter along the code (up, up, down, down, left,
//  right, left, right, B, A); completing it rewinds the layer timer, plays the secret sound effect,
//  and latches the completion flag. Objective-C++ because the sound path reaches the ne engine
//  bridge.
//
//  Reconstructed from Ghidra project rb458, program rb458. @ghidraAddress values are relative to
//  the program image base.
//

#import "title_screen_layer_colette.h"

#import "soundeffectmanager.h"

// The themed sound-effect slot the completed Konami code fires (the secret/credits jingle).
static constexpr int kSoundEffectTitleSecret = 0xd;

// The idle timer value the completion rewinds to.
static constexpr int kReplayTimerValue = 0x24fa;

// The directional-swipe and button inputs the title touch handling classifies from flick direction
// and the corner hit-boxes. The sequence is the Konami code: up, up, down, down, left, right, left,
// right, B, A.
enum TitleSwipeInput {
    kTitleSwipeUp = 0,      // An upward flick.
    kTitleSwipeDown = 1,    // A downward flick.
    kTitleSwipeLeft = 2,    // A leftward flick.
    kTitleSwipeRight = 3,   // A rightward flick.
    kTitleSwipeButtonA = 4, // The "A" confirm input that completes the sequence.
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
    kSwipeStepButtonB = 9,   // B entered; the next A completes the sequence.
    kSwipeStepComplete = 10, // The sequence completed.
};

void TitleScreenLayerColette::AdvanceSwipeState(int iSwipeEvent) {
    /** @ghidraAddress 0x1549b8 */
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
        // The final A completes the code: fire the secret effect, latch the flag, rewind timer.
        if (m_nSwipeState == kSwipeStepButtonB) {
            m_nSwipeState = kSwipeStepComplete;
            SoundEffectManager::GetInstance()->PlayThemedSoundEffect(kSoundEffectTitleSecret);
            m_bSwipeTriggered = true;
            m_nSwipeTimer = kReplayTimerValue;
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
