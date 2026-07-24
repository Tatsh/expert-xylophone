//
//  title_swipe_state.mm
//  REFLEC BEAT plus
//
//  The title-screen hidden-swipe/flick state machines: instance methods of the two title layer
//  classes. A directional swipe id advances a small integer state along an expected sequence;
//  completing the sequence toggles a hidden mode and plays a themed sound effect. Objective-C++
//  because the sound path reaches the ne engine bridge and the Hinabita toggle reaches RBCampaignData.
//
//  Reconstructed from Ghidra project rb458, program rb458. @ghidraAddress values are relative to
//  the program image base.
//

#import "title_swipe_state.h"

#import "RBCampaignData.h"
#import "neEngineBridge.h"

// The themed sound-effect slot the hidden swipe fires on completion (the secret/credits jingle).
static constexpr int kSoundEffectTitleSecret = 0xd;
// The themed sound-effect slot the flick-gesture swing toggle fires.
static constexpr int kSoundEffectTitleSwing = 0xe;

// The state a completed swipe/gesture sequence reaches, and the timer value the completion rewinds.
static constexpr int kSwipeCompleteState = 10;
static constexpr int kReplayTimerValue = 0x24fa;

void TitleScreenLayer::AdvanceSwipeState(int iSwipeEvent) {
    /** @ghidraAddress 0x152cc8 */
    switch (iSwipeEvent) {
    case 0:
        if (m_nSwipeState != 1) {
            if (m_nSwipeState != 0) {
                return;
            }
            m_nSwipeState = 1;
        }
        m_nSwipeState = 2;
        return;
    case 1:
        if (m_nSwipeState != 3) {
            if (m_nSwipeState != 2) {
                return;
            }
            m_nSwipeState = 3;
        }
        m_nSwipeState = 4;
        return;
    case 2:
        if (m_nSwipeState == 6) {
            m_nSwipeState = 7;
        } else if (m_nSwipeState == 4) {
            m_nSwipeState = 5;
        }
        return;
    case 3:
        if (m_nSwipeState == 7) {
            m_nSwipeState = 8;
        } else if (m_nSwipeState == 5) {
            m_nSwipeState = 6;
        }
        return;
    case 4:
        // Completing the sequence (state 9 -> 10) fires the secret effect and latches the flag.
        if (m_nSwipeState == 9) {
            m_nSwipeState = kSwipeCompleteState;
            SoundEffectManager::GetInstance()->PlayThemedSoundEffect(kSoundEffectTitleSecret);
            m_bSwipeTriggered = true;
        }
        return;
    case 5:
        if (m_nSwipeState == 8) {
            m_nSwipeState = 9;
        }
        return;
    default:
        return;
    }
}

unsigned int TitleScreenLayer::AdvanceGestureState(int inputCode) {
    /** @ghidraAddress 0x597a8 */
    switch (inputCode) {
    case 0:
        if (m_nGestureState != 1) {
            if (m_nGestureState != 0) {
                break;
            }
            m_nGestureState = 1;
        }
        m_nGestureState = 2;
        break;
    case 1:
        if (m_nGestureState != 3) {
            if (m_nGestureState != 2) {
                break;
            }
            m_nGestureState = 3;
        }
        m_nGestureState = 4;
        break;
    case 2:
        if (m_nGestureState == 6) {
            m_nGestureState = 7;
        } else if (m_nGestureState == 4) {
            m_nGestureState = 5;
        }
        break;
    case 3:
        if (m_nGestureState == 7) {
            m_nGestureState = 8;
        } else if (m_nGestureState == 5) {
            m_nGestureState = 6;
        }
        break;
    case 4:
        if (m_nGestureState == 0x13) {
            // Completing sequence A toggles the hidden Hinabita campaign mode.
            m_nGestureState = 0x14;
            SoundEffectManager::GetInstance()->PlayThemedSoundEffect(kSoundEffectTitleSecret);
            m_bGestureTriggered = true;
            m_bHinabitaMode = !m_bHinabitaMode;
            [[RBCampaignData sharedInstance] setHinabitaMode:m_bHinabitaMode];
            m_nGestureTimer = kReplayTimerValue;
            m_nTimerClear1 = 0;
            m_nTimerClear2 = 0;
            m_nGestureState = 0;
            return 0;
        }
        if (m_nGestureState == 9) {
            // Completing sequence B toggles the swing direction and returns the sound handle.
            m_nGestureState = kSwipeCompleteState;
            const unsigned int handle =
                SoundEffectManager::GetInstance()->PlayThemedSoundEffect(kSoundEffectTitleSwing);
            m_bGestureTriggered = true;
            m_nGestureTimer = kReplayTimerValue;
            const bool wasSet = m_bSwingToggle;
            m_bSwingToggle = !m_bSwingToggle;
            m_nSwingDelta = wasSet ? -1 : 1;
            m_nGestureState = 0;
            return handle;
        }
        break;
    case 5:
        if (m_nGestureState == 0x12) {
            m_nGestureState = 0x13;
        } else if (m_nGestureState == 8) {
            m_nGestureState = 9;
        }
        break;
    case 6:
        if (m_nGestureState == 0x10) {
            m_nGestureState = 0x11;
        } else if (m_nGestureState == 4) {
            m_nGestureState = 0xf;
        }
        break;
    case 7:
        if (m_nGestureState == 0x11) {
            m_nGestureState = 0x12;
        } else if (m_nGestureState == 0xf) {
            m_nGestureState = 0x10;
        }
        break;
    default:
        break;
    }
    // No sound handle was produced this step. (On these paths the binary leaves its object pointer
    // in the return register; no caller reads it, so a plain 0 is faithful to observed behaviour.)
    return 0;
}

void TitleScreenLayer2::AdvanceSwipeState(int iSwipeEvent) {
    /** @ghidraAddress 0x1549b8 */
    switch (iSwipeEvent) {
    case 0:
        if (m_nSwipeState != 1) {
            if (m_nSwipeState != 0) {
                return;
            }
            m_nSwipeState = 1;
        }
        m_nSwipeState = 2;
        return;
    case 1:
        if (m_nSwipeState != 3) {
            if (m_nSwipeState != 2) {
                return;
            }
            m_nSwipeState = 3;
        }
        m_nSwipeState = 4;
        return;
    case 2:
        if (m_nSwipeState == 6) {
            m_nSwipeState = 7;
        } else if (m_nSwipeState == 4) {
            m_nSwipeState = 5;
        }
        return;
    case 3:
        if (m_nSwipeState == 7) {
            m_nSwipeState = 8;
        } else if (m_nSwipeState == 5) {
            m_nSwipeState = 6;
        }
        return;
    case 4:
        // Completing the sequence fires the secret effect, latches the flag, and rewinds timer.
        if (m_nSwipeState == 9) {
            m_nSwipeState = kSwipeCompleteState;
            SoundEffectManager::GetInstance()->PlayThemedSoundEffect(kSoundEffectTitleSecret);
            m_bSwipeTriggered = true;
            m_nSwipeTimer = kReplayTimerValue;
        }
        return;
    case 5:
        if (m_nSwipeState == 8) {
            m_nSwipeState = 9;
        }
        return;
    default:
        return;
    }
}
