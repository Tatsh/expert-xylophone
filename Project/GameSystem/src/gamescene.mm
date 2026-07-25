#import "gamescene.h"

#import <QuartzCore/QuartzCore.h>

#import "RBBGMManager.h"
#import "gamesystem.h"
#import "playtimer.h"

namespace {

// The scene states below kStateBound that ignore a pause request: each set bit is a state index
// whose scene should not pause the play timer (menu, loading, and result states). State 0x11 (the
// active-play state) pauses without latching the game-wide paused flag; every other state takes the
// general path that also latches it.
constexpr int kStateBound = 0x14;
constexpr unsigned int kIgnorePauseStateMask = 0xd7c03;
constexpr int kActivePlayState = 0x11;

} // namespace

/** @ghidraAddress 0x14b010 */
void GameScene::PausePlayTimerAndBgm() {
    GameSystem *pGameSystem = GameSystem::GetGameSystem();
    // Already paused: nothing to do.
    if (pGameSystem->GetPaused()) {
        return;
    }

    const int nState = m_nState;
    if (nState < kStateBound) {
        // A state that ignores pause requests entirely.
        if ((1U << nState & kIgnorePauseStateMask) != 0) {
            return;
        }
        // The active-play state pauses the timer and BGM without latching the game-wide flag.
        if (nState == kActivePlayState) {
            PlayTimer::shared()->MarkPaused(CACurrentMediaTime());
            if (pGameSystem->GetBgmPlaying()) {
                [[RBBGMManager getInstance] PauseMusic:0.0f];
            }
            return;
        }
    }

    // The general pause path latches the game-wide paused flag as well.
    pGameSystem->SetPaused(true);
    PlayTimer::shared()->MarkPaused(CACurrentMediaTime());
    if (pGameSystem->GetBgmPlaying()) {
        [[RBBGMManager getInstance] PauseMusic:0.0f];
    }
}

/** @ghidraAddress 0x14b144 */
void ResumePlayTimerAndBgm(void) {
    GameSystem *pGameSystem = GameSystem::GetGameSystem();
    // Nothing to resume unless the game is paused.
    if (!pGameSystem->GetPaused()) {
        return;
    }

    pGameSystem->SetPaused(false);
    if (pGameSystem->GetBgmPlaying()) {
        [[RBBGMManager getInstance] PlayMusic:0.0f];
    }

    // Resume the timer, advancing its origin past the interval it spent paused.
    PlayTimer *pTimer = PlayTimer::shared();
    if (pTimer->IsPaused()) {
        pTimer->Resume(CACurrentMediaTime());
    }
}
