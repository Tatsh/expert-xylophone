#import "gamescene.h"

#import <QuartzCore/QuartzCore.h>
#import <UIKit/UIKit.h>

#import "AudioManager.h"
#import "RBBGMManager.h"
#import "fade_overlay_layer.h"
#import "gamesystem.h"
#import "playtimer.h"
#import "soundeffectmanager.h"

namespace {

// The scene states below kStateBound that ignore a pause request: each set bit is a state index
// whose scene should not pause the play timer (menu, loading, and result states). State 0x11 (the
// active-play state) pauses without latching the game-wide paused flag; every other state takes the
// general path that also latches it.
constexpr int kStateBound = 0x14;
constexpr unsigned int kIgnorePauseStateMask = 0xd7c03;
constexpr int kActivePlayState = 0x11;

// The themed sound-effect slot for the decide/confirm cue.
constexpr int kSoundEffectDecide = 1;

// The scene-transition fade-in duration, in play-timer units.
constexpr float kSceneFadeDuration = 1000.0f;

// The scene states the exit transitions advance into.
constexpr int kPauseExitState = 0xe;
constexpr int kMusicReleaseState = 0xd;
constexpr int kGameSceneState13 = 0x13;

} // namespace

/** @ghidraAddress 0x14aff8 */
void GameScene::AdvanceGameSceneStateFrom11() {
    // Only the active-play state advances; the binary's 64-bit store also clears the sub-step.
    if (m_nState == kActivePlayState) {
        m_nState = kActivePlayState + 1;
        m_nStateSubStep = 0;
    }
}

/** @ghidraAddress 0x14afec */
void GameScene::SetGameSceneState13() {
    // The binary's 64-bit store sets the state and clears the sub-step together.
    m_nState = kGameSceneState13;
    m_nStateSubStep = 0;
}

/** @ghidraAddress 0x14a510 */
void GameScene::ClearLayerStateField() {
    // The binary clears the state and its sub-step together with one 64-bit store.
    m_nState = 0;
    m_nStateSubStep = 0;
}

/** @ghidraAddress 0x14b228 */
void GameScene::StopBgmAndAllowRotation() {
    GameSystem *pGameSystem = GameSystem::GetGameSystem();
    // Only act while the background music is still marked playing.
    if (!pGameSystem->GetBgmPlaying()) {
        return;
    }
    pGameSystem->SetBgmPlaying(false);
    // Re-enable device auto-rotation, which play locks out.
    [UIViewController attemptRotationToDeviceOrientation];
    [[RBBGMManager getInstance] StopMusic:0.0f];
    m_nBgmVoiceHandle = 0;
}

/** @ghidraAddress 0x14b1ec */
void GameScene::EnterPauseExitState() {
    StopBgmAndAllowRotation();
    ResumePlayTimerAndBgm();
    FadeOverlayLayer::shared()->StartFadeIn(kSceneFadeDuration);
    m_nState = kPauseExitState;
    m_nStateSubStep = 0;
}

/** @ghidraAddress 0x14b2b8 */
void GameScene::EnterMusicReleaseState() {
    StopBgmAndAllowRotation();
    ReleaseBgmAndVoice();
    ResumePlayTimerAndBgm();
    FadeOverlayLayer::shared()->StartFadeIn(kSceneFadeDuration);
    m_nState = kMusicReleaseState;
    m_nStateSubStep = 0;
}

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

/** @ghidraAddress 0x15139c */
void HandlePauseResume(void) {
    // Resume play only when a scene is active, then play the pause-menu confirm effect.
    if (GameSystem::GetGameSystem()->GetCurrentScene() != nullptr) {
        ResumePlayTimerAndBgm();
    }
    SoundEffectManager::GetInstance()->PlayThemedSoundEffect(kSoundEffectDecide);
}

/** @ghidraAddress 0x14b2f8 */
void ReleaseBgmAndVoice(void) {
    // The music must already be stopped (its playing flag cleared) before its resources are freed.
    if (GameSystem::GetGameSystem()->GetBgmPlaying()) {
        return;
    }
    [[RBBGMManager getInstance] StopMusic:0.0f];
    [[RBBGMManager getInstance] RelaseMusic];
    [[AudioManager sharedManager] releaseVoice];
}
