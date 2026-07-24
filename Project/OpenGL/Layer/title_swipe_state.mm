//
//  title_swipe_state.mm
//  REFLEC BEAT plus
//
//  The title-screen hidden Konami-code state machines: instance methods of the two title layer
//  classes. A directional swipe (or the A/B input) advances a small step counter along the code
//  (up, up, down, down, left, right, left, right, B, A); completing it toggles a hidden mode and
//  plays a themed sound effect. Objective-C++ because the sound path reaches the ne engine bridge
//  and the Hinabita toggle reaches RBCampaignData.
//
//  Reconstructed from Ghidra project rb458, program rb458. @ghidraAddress values are relative to
//  the program image base.
//

#import "title_swipe_state.h"

#import "RBCampaignData.h"
#import "neEngineBridge.h"

// The themed sound-effect slot the completed Konami code fires (the secret/credits jingle).
static constexpr int kSoundEffectTitleSecret = 0xd;
// The themed sound-effect slot the flick-gesture swing toggle fires.
static constexpr int kSoundEffectTitleSwing = 0xe;

// The idle timer value the completion rewinds to.
static constexpr int kReplayTimerValue = 0x24fa;

void TitleScreenLayer::AdvanceSwipeState(int iSwipeEvent) {
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

unsigned int TitleScreenLayer::AdvanceGestureState(int inputCode) {
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

void TitleScreenLayer::CalculateFade(int nDeltaFrames) {
    /** @ghidraAddress 0x149ff4 */
    m_fadeChannel.Advance(static_cast<float>(nDeltaFrames));
}

void TitleScreenLayer::AdvanceFadeValue(int nDeltaFrames) {
    /** @ghidraAddress 0x152548 */
    m_fadeValueChannel.Advance(static_cast<float>(nDeltaFrames));
}

void TitleScreenLayer2::AdvanceSwipeState(int iSwipeEvent) {
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
