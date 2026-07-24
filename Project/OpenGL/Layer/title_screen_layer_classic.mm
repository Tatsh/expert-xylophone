//
//  title_screen_layer_classic.mm
//  REFLEC BEAT plus
//
//  The classic title screen layer's hidden Konami-code state machines and swing-particle rotation.
//  A directional swipe (or the A/B input) advances a small step counter along the code (up, up,
//  down, down, left, right, left, right, B, A); completing it toggles a hidden mode and plays a
//  themed sound effect. Objective-C++ because the sound path reaches the ne engine bridge and the
//  Hinabita toggle reaches RBCampaignData.
//
//  Reconstructed from Ghidra project rb458, program rb458. @ghidraAddress values are relative to
//  the program image base.
//

#import "title_screen_layer_classic.h"

#import <cmath>

#import "RBCampaignData.h"
#import "soundeffectmanager.h"

// The title-logo swing pivot the particle rest positions are measured against, and the screen
// origin their rotated positions are offset back to.
static constexpr double kSwingPivotX = -384.0;
static constexpr double kSwingPivotY = -466.0;
static constexpr double kSwingOriginX = 384.0;
static constexpr double kSwingOriginY = 466.0;
// The swing phase (in degrees) is scaled by pi/180 to radians before rotating.
static constexpr double kSwingPhaseRadiansPerDegree = M_PI / 180.0;

// The themed sound-effect slot the completed Konami code fires (the secret/credits jingle).
static constexpr int kSoundEffectTitleSecret = 0xd;
// The themed sound-effect slot the flick-gesture swing toggle fires.
static constexpr int kSoundEffectTitleSwing = 0xe;

// The idle timer value the completion rewinds to.
static constexpr int kReplayTimerValue = 0x24fa;

// The directional-swipe and button inputs the title touch handling classifies from flick direction
// and the corner hit-boxes. The sequence is the Konami code: up, up, down, down, left, right, left,
// right, B, A.
enum TitleSwipeInput {
    kTitleSwipeUp = 0,       // An upward flick.
    kTitleSwipeDown = 1,     // A downward flick.
    kTitleSwipeLeft = 2,     // A leftward flick.
    kTitleSwipeRight = 3,    // A rightward flick.
    kTitleSwipeButtonA = 4,  // The "A" confirm input that completes a sequence.
    kTitleSwipeButtonB = 5,  // The "B" input, the penultimate step.
    kTitleSwipeAltLeft = 6,  // The leftward flick of the gesture layer's alternate branch.
    kTitleSwipeAltRight = 7, // The rightward flick of the gesture layer's alternate branch.
};

// The progress steps through the Konami-code sequence; the gesture layer adds an alternate
// left/right/left/right branch that ends in the Hinabita toggle.
enum TitleSwipeStep {
    kSwipeStepNone = 0,             // No input entered yet.
    kSwipeStepUp1 = 1,              // First up entered.
    kSwipeStepUp2 = 2,              // Second up entered.
    kSwipeStepDown1 = 3,            // First down entered.
    kSwipeStepDown2 = 4,            // Second down entered.
    kSwipeStepLeft1 = 5,            // First left entered.
    kSwipeStepRight1 = 6,           // First right entered.
    kSwipeStepLeft2 = 7,            // Second left entered.
    kSwipeStepRight2 = 8,           // Second right entered.
    kSwipeStepButtonB = 9,          // B entered; the next A completes the swing sequence.
    kSwipeStepComplete = 10,        // The swing sequence completed.
    kGestureStepAltLeft1 = 0xf,     // First left of the gesture layer's alternate branch.
    kGestureStepAltRight1 = 0x10,   // First right of the alternate branch.
    kGestureStepAltLeft2 = 0x11,    // Second left of the alternate branch.
    kGestureStepAltRight2 = 0x12,   // Second right of the alternate branch.
    kGestureStepAltButtonB = 0x13,  // B of the alternate branch; the next A toggles Hinabita.
    kGestureStepAltComplete = 0x14, // The Hinabita alternate sequence completed.
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

unsigned int TitleScreenLayerClassic::AdvanceGestureState(int inputCode) {
    /** @ghidraAddress 0x597a8 */
    switch (inputCode) {
    case kTitleSwipeUp:
        if (m_nGestureState != kSwipeStepUp1) {
            if (m_nGestureState != kSwipeStepNone) {
                break;
            }
            m_nGestureState = kSwipeStepUp1;
        }
        m_nGestureState = kSwipeStepUp2;
        break;
    case kTitleSwipeDown:
        if (m_nGestureState != kSwipeStepDown1) {
            if (m_nGestureState != kSwipeStepUp2) {
                break;
            }
            m_nGestureState = kSwipeStepDown1;
        }
        m_nGestureState = kSwipeStepDown2;
        break;
    case kTitleSwipeLeft:
        if (m_nGestureState == kSwipeStepRight1) {
            m_nGestureState = kSwipeStepLeft2;
        } else if (m_nGestureState == kSwipeStepDown2) {
            m_nGestureState = kSwipeStepLeft1;
        }
        break;
    case kTitleSwipeRight:
        if (m_nGestureState == kSwipeStepLeft2) {
            m_nGestureState = kSwipeStepRight2;
        } else if (m_nGestureState == kSwipeStepLeft1) {
            m_nGestureState = kSwipeStepRight1;
        }
        break;
    case kTitleSwipeButtonA:
        if (m_nGestureState == kGestureStepAltButtonB) {
            // Completing the alternate branch toggles the hidden Hinabita campaign mode.
            m_nGestureState = kGestureStepAltComplete;
            SoundEffectManager::GetInstance()->PlayThemedSoundEffect(kSoundEffectTitleSecret);
            m_bGestureTriggered = true;
            m_bHinabitaMode = !m_bHinabitaMode;
            [[RBCampaignData sharedInstance] setHinabitaMode:m_bHinabitaMode];
            m_nGestureTimer = kReplayTimerValue;
            m_nTimerClear1 = 0;
            m_nTimerClear2 = 0;
            m_nGestureState = kSwipeStepNone;
            return 0;
        }
        if (m_nGestureState == kSwipeStepButtonB) {
            // Completing the main code toggles the swing direction and returns the sound handle.
            m_nGestureState = kSwipeStepComplete;
            const unsigned int handle =
                SoundEffectManager::GetInstance()->PlayThemedSoundEffect(kSoundEffectTitleSwing);
            m_bGestureTriggered = true;
            m_nGestureTimer = kReplayTimerValue;
            const bool wasSet = m_bSwingToggle;
            m_bSwingToggle = !m_bSwingToggle;
            m_nSwingDelta = wasSet ? -1 : 1;
            m_nGestureState = kSwipeStepNone;
            return handle;
        }
        break;
    case kTitleSwipeButtonB:
        if (m_nGestureState == kGestureStepAltRight2) {
            m_nGestureState = kGestureStepAltButtonB;
        } else if (m_nGestureState == kSwipeStepRight2) {
            m_nGestureState = kSwipeStepButtonB;
        }
        break;
    case kTitleSwipeAltLeft:
        if (m_nGestureState == kGestureStepAltRight1) {
            m_nGestureState = kGestureStepAltLeft2;
        } else if (m_nGestureState == kSwipeStepDown2) {
            m_nGestureState = kGestureStepAltLeft1;
        }
        break;
    case kTitleSwipeAltRight:
        if (m_nGestureState == kGestureStepAltLeft2) {
            m_nGestureState = kGestureStepAltRight2;
        } else if (m_nGestureState == kGestureStepAltLeft1) {
            m_nGestureState = kGestureStepAltRight1;
        }
        break;
    default:
        break;
    }
    // No sound handle was produced this step. (On these paths the binary leaves its object pointer
    // in the return register; no caller reads it, so a plain 0 is faithful to observed behaviour.)
    return 0;
}

void TitleScreenLayerClassic::CalculateFade(int nDeltaFrames) {
    /** @ghidraAddress 0x149ff4 */
    m_fadeChannel.Advance(static_cast<float>(nDeltaFrames));
}

void TitleScreenLayerClassic::AdvanceFadeValue(int nDeltaFrames) {
    /** @ghidraAddress 0x152548 */
    m_fadeValueChannel.Advance(static_cast<float>(nDeltaFrames));
}

float TitleScreenLayerClassic::ComputeSwingParticleX(float flBaseX, float flBaseY) const {
    /** @ghidraAddress 0x58570 */
    const double dx = flBaseX + kSwingPivotX;
    const double dy = flBaseY + kSwingPivotY;
    const double angle = std::atan2(dy, dx) + m_nSwingPhase * kSwingPhaseRadiansPerDegree;
    const double radius = std::sqrt(dx * dx + dy * dy);
    return static_cast<float>(radius * std::cos(static_cast<float>(angle)) + kSwingOriginX);
}

float TitleScreenLayerClassic::ComputeSwingParticleY(float flBaseX, float flBaseY) const {
    /** @ghidraAddress 0x58610 */
    const double dx = flBaseX + kSwingPivotX;
    const double dy = flBaseY + kSwingPivotY;
    const double angle = std::atan2(dy, dx) + m_nSwingPhase * kSwingPhaseRadiansPerDegree;
    const double radius = std::sqrt(dx * dx + dy * dy);
    return static_cast<float>(radius * std::sin(static_cast<float>(angle)) + kSwingOriginY);
}
