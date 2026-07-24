//
//  title_swipe_state.mm
//  REFLEC BEAT plus
//
//  The title-screen hidden-swipe state machines. A directional swipe id advances a small integer
//  state along an expected sequence; completing the sequence toggles a hidden mode and plays a
//  themed sound effect. Two variants exist: the theme-2 (Colette) title layer keeps its state at a
//  different offset from the classic title layer. The owning TitleScreenLayer classes are not
//  modelled yet, so each function takes the layer as an opaque pointer and works the state field at
//  its known offset. Objective-C++ because the sound path reaches the ne engine bridge.
//
//  Reconstructed from Ghidra project rb458, program rb458. @ghidraAddress values are relative to
//  the program image base.
//

#import "title_swipe_state.h"

#import "neEngineBridge.h"

namespace {

// The themed sound-effect slot the hidden swipe fires on completion (the secret/credits jingle).
constexpr int kSoundEffectTitleSecret = 0xd;

// The classic title layer keeps its swipe state at +0x160 and its completion flag at +0x164; the
// theme-2 title layer keeps them at +0x5c8 and +0x5cc.
constexpr int kClassicSwipeStateOffset = 0x160;
constexpr int kClassicSwipeTriggeredOffset = 0x164;
constexpr int kTheme2SwipeStateOffset = 0x5c8;
constexpr int kTheme2SwipeTriggeredOffset = 0x5cc;

// The rewound timer value the theme-2 variant writes on completion.
constexpr int kTheme2ReplayTimerValue = 0x24fa;
constexpr int kTheme2TimerOffset = 0x50;

int &StateAt(void *pLayer, int nOffset) {
    return *reinterpret_cast<int *>(static_cast<unsigned char *>(pLayer) + nOffset);
}

unsigned char &ByteAt(void *pLayer, int nOffset) {
    return *(static_cast<unsigned char *>(pLayer) + nOffset);
}

// The shared swipe sequence: each directional id advances the state from an expected predecessor,
// or bails when the sequence is broken. Returns the next state to store, or -1 to leave it
// unchanged (a broken or completing step the caller handles).
bool AdvanceSwipeSequence(int &state, int iSwipeEvent, int &nextState) {
    switch (iSwipeEvent) {
    case 0:
        if (state != 1) {
            if (state != 0) {
                return false;
            }
            state = 1;
        }
        nextState = 2;
        return true;
    case 1:
        if (state != 3) {
            if (state != 2) {
                return false;
            }
            state = 3;
        }
        nextState = 4;
        return true;
    case 2:
        if (state == 6) {
            nextState = 7;
        } else {
            if (state != 4) {
                return false;
            }
            nextState = 5;
        }
        return true;
    case 3:
        if (state == 7) {
            nextState = 8;
        } else {
            if (state != 5) {
                return false;
            }
            nextState = 6;
        }
        return true;
    case 5:
        if (state != 8) {
            return false;
        }
        nextState = 9;
        return true;
    default:
        return false;
    }
}

} // namespace

/** @ghidraAddress 0x152cc8 */
void AdvanceTitleSwipeState(void *pLayer, int iSwipeEvent) {
    int &state = StateAt(pLayer, kClassicSwipeStateOffset);
    if (iSwipeEvent == 4) {
        // Completing the sequence (state 9 -> 10) fires the secret effect and latches the trigger.
        if (state != 9) {
            return;
        }
        state = 10;
        SoundEffectManager::GetInstance()->PlayThemedSoundEffect(kSoundEffectTitleSecret);
        ByteAt(pLayer, kClassicSwipeTriggeredOffset) = 1;
        return;
    }
    int nextState = 0;
    if (AdvanceSwipeSequence(state, iSwipeEvent, nextState)) {
        state = nextState;
    }
}

/** @ghidraAddress 0x1549b8 */
void AdvanceTitle2SwipeState(void *pLayer, int iSwipeEvent) {
    int &state = StateAt(pLayer, kTheme2SwipeStateOffset);
    if (iSwipeEvent == 4) {
        // Completing the sequence (state 9 -> 10) fires the secret effect, latches the trigger, and
        // rewinds the layer's timer.
        if (state != 9) {
            return;
        }
        state = 10;
        SoundEffectManager::GetInstance()->PlayThemedSoundEffect(kSoundEffectTitleSecret);
        ByteAt(pLayer, kTheme2SwipeTriggeredOffset) = 1;
        StateAt(pLayer, kTheme2TimerOffset) = kTheme2ReplayTimerValue;
        return;
    }
    int nextState = 0;
    if (AdvanceSwipeSequence(state, iSwipeEvent, nextState)) {
        state = nextState;
    }
}
