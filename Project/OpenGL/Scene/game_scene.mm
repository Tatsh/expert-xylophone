//
//  game_scene.mm
//  REFLEC BEAT plus
//
//  The gameplay scene, rb::GameScene. Reconstructed from Ghidra project rb458, program rb458.
//  @ghidraAddress values are relative to the program image base.
//

#include "game_scene.h"

#include <cassert>
#include <cstdlib>
#include <new>

#import <QuartzCore/QuartzCore.h>
#import <UIKit/UIKit.h>

#import "AppDelegate.h"
#import "AudioManager.h"
#import "MusicData.h"
#import "RBBGMManager.h"
#import "RBBonusData.h"
#import "RBExperienceData.h"
#import "RBTutorialManager.h"
#import "RBUserSettingData.h"
#import "RBViewController.h"
#import "ReplayData.h"
#include "ScoreTracker.h"
#include "alt_frame_layer.h"
#include "background_sprite_manager.h"
#include "bg_layer.h"
#include "classicthemelayer.h"
#include "clear_gauge_layer.h"
#include "colette_theme_layer.h"
#include "deviceenvironment.h"
#include "engineruntime.h"
#include "event_effect_layer.h"
#include "fade_overlay_layer.h"
#include "full_combo_classic_layer.h"
#include "full_combo_colette_layer.h"
#include "full_combo_limelight_layer.h"
#include "gamesystem.h"
#include "judge_effect_layer.h"
#include "leveltables.h"
#include "limelight_effect_layer.h"
#include "limelight_result_layer.h"
#include "limelight_theme_layer.h"
#include "main_frame_layer.h"
#include "music_sheet.h"
#include "neTexture.h"
#include "note_effect_mgr.h"
#include "note_replay.h"
#include "note_result_layer.h"
#include "number_effect_layer.h"
#include "number_layer.h"
#include "pause_gauge_layer.h"
#include "play_color_layer.h"
#include "playerfieldlayer.h"
#include "playtimer.h"
#include "rbffnoterecord.h"
#include "reflec_gauge_layer.h"
#include "result_window_classic_layer.h"
#include "result_window_colette_layer.h"
#include "soundeffectmanager.h"
#include "thema_marker_layer.h"
#include "tutorial_guide_layer.h"

namespace {

// The initial mode the constructor seeds; the state machine advances from here on the first frame.
constexpr int kInitialMode = 2;

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

// The play states this step selects between: the note-play wait state and the past-effect state.
constexpr int kStateWaitNotes = 5;
constexpr int kStatePastEffect = 6;

// The playing state the preview resumes into.
constexpr int kStatePlaying = 0x11;

// The result-theme display state EnterResultThemeState advances to.
constexpr int kStateResultTheme = 0xb;

// The gameplay-presentation state StartGameplayPresentation advances to, the intro-voice cue it
// plays, and the fade-in duration (in milliseconds) it primes the layers with.
constexpr int kStatePresenting = 7;
constexpr int kIntroVoiceCue = 2;
constexpr float kPresentationFadeInDuration = 1000.0f; // @ghidraAddress 0x2f8540

// The note-play state BeginMusicPlaybackAndTimer advances to once the intro is done.
constexpr int kStateNotePlay = 8;

// The exit state ExitToMusicList advances to, and the play-time threshold (in play time) it waits
// past before tearing down.
constexpr int kStateExit = 1;
constexpr int kExitDelay = 0x5dc;

// The bind state ReloadMusicForRestart advances to, and the ghost style that seeds the RNG from a
// saved replay.
constexpr int kStateBindChart = 2;
constexpr int kGhostStyleReplay = 1;

// The play-ready state AdvanceToPlayReadyState advances to, and the gauge grow-animation from-value
// (also the marker fade-in's marker value) it primes the layers with.
constexpr int kStatePlayReady = 4;
constexpr float kGaugeGrowFromValue = 450.0f; // @ghidraAddress 0x308dd8

// The result-voice cue and the clear-cue sound-effect slots, and the clear-rate threshold at or above
// which the clear cue plays.
constexpr int kResultVoiceCue = 0x13;
constexpr int kClearCueSoundEffect = 8;
constexpr float kClearRateThreshold = 0.7f; // @ghidraAddress 0x2fd008

// The theme identifiers selecting the full-combo layer whose effect flags a playback reset clears.
constexpr int kThemaClassic = 0;
constexpr int kThemaLimelight = 1;
constexpr int kThemaColette = 2;

// The three result-window text-instancer slots whose textures are cleared at teardown.
constexpr int kResultTextSlot0 = 2;
constexpr int kResultTextSlot1 = 3;
constexpr int kResultTextSlot2 = 4;

// The themed voice bank the result screen loads.
constexpr int kResultVoiceId = 2;

// The player side the result bonuses are computed for (the single-player side).
constexpr unsigned int kResultSide = 1;

// The difficulties the chart loader selects a sheet and music track for. Special reuses the basic
// chart.
constexpr int kDifficultyBasic = 0;
constexpr int kDifficultyMedium = 1;
constexpr int kDifficultyHard = 2;
constexpr int kDifficultySpecial = 3;

// The score-record cell holding the miss count, and its values: full-combo (0), one miss (1), two or
// more misses (2).
constexpr unsigned int kMissCell = 6;
constexpr int kMissFullCombo = 0;
constexpr int kMissOne = 1;
constexpr int kMissTwo = 2;

// The minimum clear rank (of the B/A/AA/AAA/AAAP ladder) that earns the clear bonus.
constexpr int kMinClearRank = 2;

// The clear ranks, in ladder order, selecting the rank bonus.
constexpr int kRankB = 1;
constexpr int kRankA = 2;
constexpr int kRankAA = 3;
constexpr int kRankAAA = 4;
constexpr int kRankAAAP = 5;

// The pastel-field bonus types (the field-10 statistic must be zero for either to apply).
constexpr int kPastelBonusNormal = 1;
constexpr int kPastelBonusBlack = 2;

// The last playable level: reaching its threshold stops the level-up unlock loop.
constexpr unsigned int kNoLevelThreshold = 0xffffffff;

// The note-spawn scan converts the timer's play time to a scroll line (×1000) and looks 1500 units
// ahead; a note whose time is within the line spawns.
constexpr float kNoteLineScale = 1000.0f;       // @ghidraAddress 0x2f8540
constexpr float kNoteSpawnLookahead = -1500.0f; // @ghidraAddress 0x308b60

// The dwFlags bit marking a head note that is paired with a tail; the pair must also be due before
// the head spawns.
constexpr unsigned int kNoteHasPairFlag = 1u << 3;

// The head-note sentinel start time (an unpaired note), and how many consecutive not-yet-due notes
// end the scan.
constexpr int kHeadNoteStartTime = -1;
constexpr int kNotDueScanLimit = 10;

// The five result bonuses shared by the Limelight and Colette themes.
struct SharedResultBonuses {
    float flClear = 0.0f;
    float flMiss = 0.0f;
    float flRank = 0.0f;
    float flFirstPlay = 0.0f; // Includes the pastel-field bonus when one applies.
};

// Accumulates the clear, miss, rank, and first-play (plus pastel-field) bonuses common to the
// Limelight and Colette result screens.
SharedResultBonuses ComputeSharedResultBonuses(GameSystem *pGameSystem, ScoreTracker *pTracker) {
    RBBonusData *pBonus = RBBonusData.sharedInstance;
    SharedResultBonuses out;

    // Clear bonus: earned once the clear rank reaches A.
    if (pTracker->GetPlayRecordRank(kResultSide) >= kMinClearRank) {
        out.flClear = pBonus.clearBonus;
    }

    // Miss bonus: a full combo, a single miss, or two-or-more misses each earn a different bonus.
    const int nMisses = pTracker->GetPlayRecordCell(kResultSide, kMissCell);
    if (nMisses == kMissTwo) {
        out.flMiss = pBonus.miss2Bonus;
    } else if (nMisses == kMissOne) {
        out.flMiss = pBonus.miss1Bonus;
    } else if (nMisses == kMissFullCombo) {
        out.flMiss = pBonus.fullComboBonus;
    }

    // Rank bonus: one bonus per clear-rank tier.
    switch (pTracker->GetPlayRecordRank(kResultSide)) {
    case kRankB:
        out.flRank = pBonus.rankBBonus;
        break;
    case kRankA:
        out.flRank = pBonus.rankABonus;
        break;
    case kRankAA:
        out.flRank = pBonus.rankAABonus;
        break;
    case kRankAAA:
        out.flRank = pBonus.rankAAABonus;
        break;
    case kRankAAAP:
        out.flRank = pBonus.rankAAAPBonus;
        break;
    default:
        break;
    }

    // First-play bonus, plus a pastel-field bonus when the field-10 statistic is zero.
    if (pGameSystem->GetIsFirstPlay()) {
        out.flFirstPlay = pBonus.firstPlayBonus;
    }
    if (pTracker->GetPlayRecordField10(kResultSide) == 0) {
        if (pGameSystem->GetPastelBonusType() == kPastelBonusNormal) {
            out.flFirstPlay += pBonus.pastelBonus;
        } else if (pGameSystem->GetPastelBonusType() == kPastelBonusBlack) {
            out.flFirstPlay += pBonus.blackPastelBonus;
        }
    }

    return out;
}

// The chart loader uses the full-detail sheet (rather than the light one) only on iPad and only for
// the single-player game types (0 and 2); every other case takes the light sheet.
bool UsesFullDetailSheet(GameSystem *pGameSystem) {
    return IsPad() && (pGameSystem->GetGameType() | 2) == 2;
}

// Reports whether the active theme's intro animation is still playing, so gameplay must keep waiting.
bool IsThemeIntroStillAnimating(int nThema) {
    if (nThema == kThemaClassic) {
        return BackgroundSpriteManager::shared()->IsActive();
    }
    if (nThema == kThemaLimelight) {
        return LimelightEffectLayer::shared()->IsActive();
    }
    if (nThema == kThemaColette) {
        return NumberLayer::shared()->IsReady();
    }
    return false;
}

} // namespace

namespace rb {

/** @ghidraAddress 0x14a21c */
GameScene::GameScene() {
    // The scene-base constructor ran first and the compiler installed the play dispatch vtable; seed
    // the play state (the base fields and the reserved sub-state are already zero-initialised).
    m_nState = 0;
    m_nPlayTime = 0;
    m_nMode = kInitialMode;
}

/** @ghidraAddress 0x12ee88 */
void GameScene::GetInstance(GameScene **ppOut) {
    if (*ppOut == nullptr) {
        GameScene *pScene = new GameScene();
        // Register the scene in the engine's per-frame list at priority 1.
        pScene->InsertSorted(1);
        *ppOut = pScene;
    }
}

/** @ghidraAddress 0x14aff8 */
void GameScene::AdvanceGameSceneStateFrom11() {
    // Only the active-play state advances; the binary's 64-bit store also clears the accumulated
    // play time.
    if (m_nState == kActivePlayState) {
        m_nState = kActivePlayState + 1;
        m_nPlayTime = 0;
    }
}

/** @ghidraAddress 0x14afec */
void GameScene::SetGameSceneState13() {
    // The binary's 64-bit store sets the state and clears the play time together.
    m_nState = kGameSceneState13;
    m_nPlayTime = 0;
}

/** @ghidraAddress 0x14a510 */
void GameScene::ClearLayerStateField() {
    // The binary clears the state and the play time together with one 64-bit store.
    m_nState = 0;
    m_nPlayTime = 0;
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
    m_flFirstPathSpeed = 0.0f;
}

/** @ghidraAddress 0x14b1ec */
void GameScene::EnterPauseExitState() {
    StopBgmAndAllowRotation();
    ResumePlayTimerAndBgm();
    FadeOverlayLayer::shared()->StartFadeIn(kSceneFadeDuration);
    m_nState = kPauseExitState;
    m_nPlayTime = 0;
}

/** @ghidraAddress 0x14b2b8 */
void GameScene::EnterMusicReleaseState() {
    StopBgmAndAllowRotation();
    ReleaseBgmAndVoice();
    ResumePlayTimerAndBgm();
    FadeOverlayLayer::shared()->StartFadeIn(kSceneFadeDuration);
    m_nState = kMusicReleaseState;
    m_nPlayTime = 0;
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

/** @ghidraAddress 0x14b6e0 */
bool GameScene::RefreshPauseGaugeAndGetActiveFlag() {
    if (!GameSystem::GetGameSystem()->GetPaused()) {
        // Not paused: release any charge and report gameplay active.
        if (m_pPauseGauge != nullptr) {
            m_pPauseGauge->ClearCharging();
        }
        return true;
    }
    // Paused: charge the gauge unless it is being held down, and report gameplay inactive.
    if (!m_bPauseGaugeHeld && m_pPauseGauge != nullptr) {
        m_pPauseGauge->SetCharging();
    }
    return false;
}

/** @ghidraAddress 0x14f0dc */
void GameScene::ComputeResultBonusesAndExperience() {
    // Classic theme: advance the level/experience progression and unlock custom items.
    if (m_nThema == kThemaClassic) {
        LevelTables *pTables = LevelTables::GetInstance();
        GameSystem *pGameSystem = GameSystem::GetGameSystem();
        ScoreTracker *pTracker = ScoreTracker::shared();

        int nLevel = pTables->GetCurrentLevel();
        int nExp = pTables->GetCurrentExp();
        const float flRate = pTracker->GetPlayRecordRate(kResultSide);
        const bool bAllJudged = pTracker->IsSideAllNotesJudged(kResultSide);
        const int nGained = LevelTables::ComputeLevelExpStep(
            flRate, pGameSystem->GetDifficultyLevel(), bAllJudged, pGameSystem->GetIsFirstPlay());

        // Publish the starting level/experience and the gained amount to the game system.
        pGameSystem->SetResultLevelExp(nLevel, nExp, nGained);

        // Roll the gained experience into the level, unlocking a new custom item for each level up,
        // until the next threshold is unreachable (the level cap).
        unsigned int nThreshold = LevelTables::GetLevelExpThreshold(nLevel);
        if (nThreshold != kNoLevelThreshold) {
            nExp += nGained;
            // The binary compares the experience against the threshold as signed values.
            while (nExp >= static_cast<int>(nThreshold)) {
                nExp -= static_cast<int>(nThreshold);
                ++nLevel;
                nThreshold = LevelTables::GetLevelExpThreshold(nLevel);
                RBUserSettingData.sharedInstance.newCustomItem = YES;
                [RBUserSettingData.sharedInstance save];
                if (nThreshold == kNoLevelThreshold) {
                    break;
                }
            }
            if (nThreshold == kNoLevelThreshold) {
                nExp = 0;
            }
        } else {
            nExp = 0;
        }

        // Persist the updated {level, experience} record.
        pTables->SetLevelExp(nLevel, nExp);
        LevelTables::SavePlayerLevelData(pTables->GetLevelExpRecord());
    }

    // Limelight theme: store the five shared bonuses and award their sum.
    if (m_nThema == kThemaLimelight) {
        GameSystem *pGameSystem = GameSystem::GetGameSystem();
        ScoreTracker *pTracker = ScoreTracker::shared();
        const SharedResultBonuses bonuses = ComputeSharedResultBonuses(pGameSystem, pTracker);

        RBExperienceData *pExperience = RBExperienceData.sharedInstance;
        const float flExperience = [pExperience getPoint];
        LimelightResultLayer::shared()->SetResultBonuses(
            bonuses.flClear, bonuses.flMiss, bonuses.flRank, bonuses.flFirstPlay, flExperience);

        [pExperience
            addPoint:bonuses.flClear + bonuses.flMiss + bonuses.flRank + bonuses.flFirstPlay];
        [RBExperienceData.sharedInstance save];
    }

    // Colette theme: the shared bonuses plus early-play and hot-music bonuses.
    if (m_nThema == kThemaColette) {
        GameSystem *pGameSystem = GameSystem::GetGameSystem();
        ScoreTracker *pTracker = ScoreTracker::shared();
        RBBonusData *pBonus = RBBonusData.sharedInstance;
        const SharedResultBonuses bonuses = ComputeSharedResultBonuses(pGameSystem, pTracker);

        float flEarlyPlay = 0.0f;
        if ([AppDelegate.appDelegate isEnableEarlyBonus]) {
            flEarlyPlay = pBonus.earlyPlayBonus;
        }
        float flHotMusic = 0.0f;
        if ([AppDelegate.appDelegate isEnableHotBonus]) {
            flHotMusic = pBonus.hotMusicBonus;
        }

        RBExperienceData *pExperience = RBExperienceData.sharedInstance;
        const float flExperience = [pExperience getPoint];
        ResultWindowColetteLayer::shared()->SetResultBonuses(bonuses.flClear,
                                                             bonuses.flMiss,
                                                             bonuses.flRank,
                                                             bonuses.flFirstPlay,
                                                             flHotMusic,
                                                             flEarlyPlay,
                                                             flExperience);

        [pExperience addPoint:bonuses.flClear + bonuses.flMiss + bonuses.flRank +
                              bonuses.flFirstPlay + flEarlyPlay + flHotMusic];
        [RBExperienceData.sharedInstance save];
    }
}

/** @ghidraAddress 0x14be88 */
void GameScene::EnterResultThemeState() {
    // Initialise the active theme's grade/score-gauge display state.
    if (m_nThema == kThemaColette) {
        ColetteThemeLayer::shared()->ResetGradeDisplayState();
    } else if (m_nThema == kThemaLimelight) {
        LimelightThemeLayer::shared()->InitializeGradeDisplayState();
    } else if (m_nThema == kThemaClassic) {
        ClassicThemeLayer::shared()->InitializeScoreGaugeState();
    }

    // Start the result-voice cue.
    SoundEffectManager::GetInstance()->PlayThemedVoice(kResultVoiceCue);

    // Play the clear cue when the play cleared: the achievement rate reached the clear threshold, or
    // this is a tutorial play.
    if (ScoreTracker::shared()->GetPlayRecordRate(kResultSide) >= kClearRateThreshold ||
        [RBTutorialManager isTutorialPlay]) {
        SoundEffectManager::GetInstance()->PlayThemedSoundEffect(kClearCueSoundEffect);
    }

    m_nState = kStateResultTheme;
}

/** @ghidraAddress 0x14b86c */
void GameScene::StartGameplayPresentation() {
    // Wait until play time has begun advancing.
    if (m_nPlayTime <= 0) {
        return;
    }

    // Play the intro-voice cue and run the active theme's intro layer.
    SoundEffectManager::GetInstance()->PlayThemedVoice(kIntroVoiceCue);
    if (m_nThema == kThemaColette) {
        NumberLayer::shared()->SetReady();
    } else if (m_nThema == kThemaLimelight) {
        LimelightEffectLayer::shared()->SetActiveAndResetCounter();
    } else if (m_nThema == kThemaClassic) {
        BackgroundSpriteManager::shared()->SetActiveAndResetCounter();
    }

    // Fade in the background, player-field score, and judge-effect layers together.
    BgLayer::GetBackgroundLayer()->StartBackgroundFadeIn(kPresentationFadeInDuration);
    PlayerFieldLayer::shared()->StartScoreFadeIn(kPresentationFadeInDuration);
    JudgeEffectLayer::shared()->StartFadeIn(kPresentationFadeInDuration);

    m_nState = kStatePresenting;
}

/** @ghidraAddress 0x14b734 */
void GameScene::AdvanceToPlayReadyState() {
    // Wait until play time passes the presentation intro threshold.
    if (static_cast<float>(m_nPlayTime) <= m_flPresentationDelay) {
        return;
    }

    // Build the note-result layout for the current chart.
    NoteResultLayer::shared()->BuildQuadPositions();

    // Build and fade in the on-screen frame (the alternate frame on iPad, the main frame elsewhere).
    if (m_bIsPad) {
        AltFrameLayer::shared()->StartFadeIn(kPresentationFadeInDuration);
    } else {
        MainFrameLayer::shared()->BuildGeometry();
        MainFrameLayer::shared()->StartFadeIn(kPresentationFadeInDuration);
    }

    // Fade in and rebuild the thema-marker frame.
    ThemaMarkerLayer::shared()->StartFadeIn(kPresentationFadeInDuration, kGaugeGrowFromValue);
    ThemaMarkerLayer::shared()->RenderThemaMarkerFrame();

    // Grow the play-colour gauge and resync its part positions.
    PlayColorLayer::shared()->StartGaugeGrowAnimation(kPresentationFadeInDuration,
                                                      kGaugeGrowFromValue);
    PlayColorLayer::shared()->SyncGaugeValuesFromGameSystem();

    // Fade in the reflec and clear gauges.
    ReflecGaugeLayer::shared()->StartFadeIn(kPresentationFadeInDuration);
    ClearGaugeLayer::shared()->StartFadeIn(kPresentationFadeInDuration);

    m_nState = kStatePlayReady;
}

/** @ghidraAddress 0x14b914 */
void GameScene::BeginMusicPlaybackAndTimer() {
    // Keep waiting until the active theme's intro animation has finished.
    if (IsThemeIntroStillAnimating(m_nThema)) {
        return;
    }

    GameSystem *pGameSystem = GameSystem::GetGameSystem();

    // Start the background music once, then start the play timer running from now.
    if (!pGameSystem->GetBgmPlaying()) {
        [RBBGMManager.getInstance PlayMusic:0.0f];
        GameSystem::GetGameSystem()->SetBgmPlaying(true);
        [UIViewController attemptRotationToDeviceOrientation];
    }
    PlayTimer::shared()->StartPlayback(CACurrentMediaTime(), true);

    // Activate the due notes and cache the chart's first path speed.
    ActivateDueNotes();
    m_flFirstPathSpeed = m_pMusicSheet->GetFirstPathSpeed();

    // In a tutorial play, start the guide and fade it in.
    if (pGameSystem->GetMenuTutorialActive() != 0) {
        TutorialGuideLayer::shared()->Start();
        TutorialGuideLayer::shared()->StartFadeIn();
    }

    m_nState = kStateNotePlay;
}

/** @ghidraAddress 0x14d4d8 */
void GameScene::ActivateDueNotes() {
    NoteEffectMgr *pMgr = NoteEffectMgr::shared();
    PlayTimer *pTimer = PlayTimer::shared();

    // The scroll line the notes are measured against: the play time scaled up, offset by the
    // lookahead so notes spawn shortly before they reach the line.
    const float flLine = pTimer->GetPlayTime() * kNoteLineScale + kNoteSpawnLookahead;

    int nLastSpawned = m_nPlayCursor;
    int nNotDue = 0;
    for (int nIndex = m_nPlayCursor; nIndex < m_pMusicSheet->GetNoteCount(); ++nIndex) {
        RbffNoteRecord *pRecord = m_pMusicSheet->GetNoteRecordByIndex(nIndex);
        if (pRecord == nullptr) {
            continue;
        }

        // A note not yet at the line does not spawn; stop scanning after enough of them in a row.
        if (static_cast<float>(pRecord->GetTimeA()) > flLine) {
            if (nNotDue >= kNotDueScanLimit) {
                break;
            }
            ++nNotDue;
            continue;
        }

        // Only head notes spawn here. A head paired with a tail (flag bit set and a chain-link timing
        // selector) waits until its tail is also due.
        if (pRecord->GetStartTime() != kHeadNoteStartTime) {
            continue;
        }
        const NoteChainLink &link = pRecord->GetChainLink();
        const bool bHasPair = (pRecord->GetFlags() & kNoteHasPairFlag) != 0 && link.nTimingSel != 0;
        if (bHasPair) {
            RbffNoteRecord *pPair = m_pMusicSheet->GetNoteRecordByIndex(link.nNoteIndex);
            if (static_cast<float>(pPair->GetTimeA()) > flLine) {
                continue;
            }
        }

        pMgr->ActivateNoteByIndex(nIndex);
        if (nNotDue < 1) {
            nLastSpawned = nIndex;
        }
    }

    // Advance the cursor past the notes spawned this pass.
    if (nLastSpawned >= m_nPlayCursor) {
        m_nPlayCursor = nLastSpawned;
    }
}

/** @ghidraAddress 0x14ab94 */
void GameScene::LoadMusicAndSheet() {
    GameSystem *pGameSystem = GameSystem::GetGameSystem();
    MusicData *pMusicData = [AppDelegate.appDelegate musicData];
    const bool bFullSheet = UsesFullDetailSheet(pGameSystem);

    NSData *pSheet = nil;
    NSData *pMusic = nil;
    switch (pGameSystem->GetDifficulty()) {
    case kDifficultyBasic:
    case kDifficultySpecial:
        pSheet = bFullSheet ? pMusicData.sheetBasic : pMusicData.sheetBasicLight;
        pMusic = pMusicData.musicBasic;
        break;
    case kDifficultyMedium:
        pSheet = bFullSheet ? pMusicData.sheetMedium : pMusicData.sheetMediumLight;
        pMusic = pMusicData.musicMedium;
        break;
    case kDifficultyHard:
        pSheet = bFullSheet ? pMusicData.sheetHard : pMusicData.sheetHardLight;
        pMusic = pMusicData.musicHard;
        break;
    default:
        assert(0);
    }

    LoadNoteSheet(pSheet);
    LoadResultBgmForMusic(pMusic);
}

/** @ghidraAddress 0x14c848 */
void GameScene::SetupPreviewPlayback() {
    GameSystem *pGameSystem = GameSystem::GetGameSystem();

    // Apply the current theme to the note manager and build the note-result layout.
    NoteEffectMgr::shared()->ApplyTheme();
    NoteResultLayer::shared()->BuildQuadPositions();

    // Prime the on-screen frame (the alternate frame on iPad, the main frame elsewhere), shown at
    // once; the main frame is also enabled.
    if (m_bIsPad) {
        AltFrameLayer::shared()->StartFadeIn(0.0f);
    } else {
        MainFrameLayer::shared()->StartFadeIn(0.0f);
        MainFrameLayer::shared()->SetMainFrameEnabled(false);
    }

    // Prime the thema-marker, play-colour gauge, and gauge/background/score/judge layers to their
    // fully-shown state.
    ThemaMarkerLayer::shared()->StartFadeIn(0.0f, 0.0f);
    ThemaMarkerLayer::shared()->RenderThemaMarkerFrame();
    ThemaMarkerLayer::shared()->SetDangerLevel(1.0f);
    PlayColorLayer::shared()->StartGaugeGrowAnimation(0.0f, 0.0f);
    PlayColorLayer::shared()->SyncGaugeValuesFromGameSystem();
    PlayColorLayer::shared()->SetGaugeFillLevel(1.0f);
    ReflecGaugeLayer::shared()->StartFadeIn(0.0f);
    ClearGaugeLayer::shared()->StartFadeIn(0.0f);
    BgLayer::GetBackgroundLayer()->StartBackgroundFadeIn(0.0f);
    PlayerFieldLayer::shared()->StartScoreFadeIn(0.0f);
    JudgeEffectLayer::shared()->StartFadeIn(0.0f);
    NumberEffectLayer::shared()->CreateSpriteInstancers();
    NumberEffectLayer::shared()->StartFadeIn(0.0f);
    NumberEffectLayer::shared()->SetBrightness(pGameSystem->GetBackgroundBrightness());

    // Load the selected chart, or a synthetic default when no music is selected.
    const bool bHasMusic = [AppDelegate.appDelegate musicData] != nil;
    if (bHasMusic) {
        LoadMusicAndSheet();
    } else {
        BuildChartReaderFromGameSystem();
    }
    m_flFirstPathSpeed = m_pMusicSheet->GetFirstPathSpeed();

    // Start the play timer, beginning the background music when there is a chart and it is not already
    // playing.
    PlayTimer *pTimer = PlayTimer::shared();
    bool bRunning = false;
    if (bHasMusic && !pGameSystem->GetBgmPlaying()) {
        [RBBGMManager.getInstance PlayMusic:0.0f];
        GameSystem::GetGameSystem()->SetBgmPlaying(true);
        [UIViewController attemptRotationToDeviceOrientation];
        bRunning = true;
    }
    pTimer->StartPlayback(CACurrentMediaTime(), bRunning);

    // Show the preview through the app's root view controller and advance to the playing state.
    [AppDelegate.appDelegate.viewController showPreview];
    m_nState = kStatePlaying;
}

/** @ghidraAddress 0x14c5bc */
void GameScene::ExitToMusicList() {
    // Wait out the exit delay before tearing down.
    if (m_nPlayTime <= kExitDelay) {
        return;
    }

    ResetAllPlayFieldLayers();
    ReleaseResultTexturesAndFrames();
    ResetNotePlaybackState(false);

    // Return to the music list and flush the texture cache.
    [AppDelegate.appDelegate.viewController showMusicListView];
    (void)ne::C_TEXTURE::GetCacheList(); // The binary discards this call's result.
    ReleaseAllCachedTextures();

    m_nState = kStateExit;
}

/** @ghidraAddress 0x14c690 */
void GameScene::ReloadMusicForRestart() {
    // Wait out the exit delay before restarting.
    if (m_nPlayTime <= kExitDelay) {
        return;
    }

    ResetAllPlayFieldLayers();
    ShutdownNoteEffectSystem();

    // Reseed the RNG for the new play; when the ghost is enabled and a replay is loaded, reuse the
    // replay's recorded seed so the ghost re-plays identically.
    GameSystem *pGameSystem = GameSystem::GetGameSystem();
    pGameSystem->SetRandSeed(static_cast<unsigned int>(rand()));
    if (RBUserSettingData.sharedInstance.ghostStyle == kGhostStyleReplay) {
        ReplayData *pReplay = AppDelegate.appDelegate.replayData;
        if (pReplay != nil) {
            pGameSystem->SetRandSeed(pReplay.seed.unsignedIntValue);
        }
    }

    LoadMusicAndSheet();
    m_nState = kStateBindChart;
}

/** @ghidraAddress 0x14d23c */
void GameScene::ResetAllPlayFieldLayers() {
    // Fade out the shared play-field layers immediately.
    PlayerFieldLayer::shared()->StartScoreFadeOut(0.0f);
    JudgeEffectLayer::shared()->StartFadeOut(0.0f);
    BgLayer::GetBackgroundLayer()->StartBackgroundFadeOut(0.0f);
    ReflecGaugeLayer::shared()->StartFadeOut(0.0f);
    ClearGaugeLayer::shared()->StartFadeOut(0.0f);
    ThemaMarkerLayer::shared()->StartFadeOut(0.0f);
    PlayColorLayer::shared()->StartShrinkAnimation(0.0f);
    FadeOverlayLayer::shared()->StartFadeOut(0.0f);
    if (m_bIsPad) {
        AltFrameLayer::shared()->StartFadeOut(0.0f);
    } else {
        MainFrameLayer::shared()->StartFadeOut(0.0f);
    }

    // Reset the active theme's full-combo, effect, and result layers.
    if (m_nThema == kThemaColette) {
        FullComboColetteLayer::shared()->ClearEffectFlags();
        NumberLayer::shared()->ClearReady();
        ColetteThemeLayer::shared()->StartFadeOut(0.0f);
        ResultWindowColetteLayer::shared()->StartHideTween(0.0f);
        EventEffectLayer::shared()->FinishEffect();
        TutorialGuideLayer::shared()->Stop();
    } else if (m_nThema == kThemaLimelight) {
        FullComboLimelightLayer::shared()->ClearEffectFlags();
        LimelightEffectLayer::shared()->SetInactive();
        LimelightThemeLayer::shared()->StartGradeAnimation(0.0f);
        LimelightResultLayer::shared()->ResetResultBonusAnimations(0.0f);
        EventEffectLayer::shared()->FinishEffect();
    } else if (m_nThema == kThemaClassic) {
        FullComboClassicLayer::shared()->ClearEffectFlags();
        BackgroundSpriteManager::shared()->SetInactive();
        ClassicThemeLayer::shared()->StartGaugeValueFade(0.0f);
        ResultWindowClassicLayer::shared()->ResetResultScoreAnimations(0.0f);
    }
}

/** @ghidraAddress 0x14b818 */
void GameScene::WaitForIntroThenStartNotes() {
    // Wait until the accumulated play time passes the intro ready-delay threshold.
    if (m_flReadyDelay >= static_cast<float>(m_nPlayTime)) {
        return;
    }
    if (GameSystem::GetGameSystem()->GetPastelBonusType() == 0) {
        m_nState = kStateWaitNotes;
    } else {
        EventEffectLayer::shared()->StartEffect();
        m_nState = kStatePastEffect;
    }
}

/** @ghidraAddress 0x14cd90 */
void GameScene::ResumePreviewPlayback() {
    m_nState = kStatePlaying;
    if (GameSystem::GetGameSystem()->GetBgmPlaying()) {
        [RBBGMManager.getInstance PlayMusic:0.0f];
    }
    // Un-pause the play timer, shifting its origin forward by the interval it spent paused.
    PlayTimer *pTimer = PlayTimer::shared();
    if (pTimer->IsPaused()) {
        pTimer->Resume(CACurrentMediaTime());
    }
}

/** @ghidraAddress 0x14f9a4 */
void GameScene::ReleaseResultTexturesAndFrames() {
    // Clear the on-screen frame's bound texture: the alternate frame on iPad, the main frame
    // elsewhere.
    if (m_bIsPad) {
        AltFrameLayer::shared()->SetAltFrameTexture(nullptr);
    } else {
        MainFrameLayer::shared()->SetMainFrameTexture(nullptr);
    }

    // Clear the active theme result layer's three text-instancer textures (slots 2, 3, and 4).
    if (m_nThema == kThemaColette) {
        ResultWindowColetteLayer::shared()->applySpriteInstancerTexture(kResultTextSlot0, nullptr);
        ResultWindowColetteLayer::shared()->applySpriteInstancerTexture(kResultTextSlot1, nullptr);
        ResultWindowColetteLayer::shared()->applySpriteInstancerTexture(kResultTextSlot2, nullptr);
    } else if (m_nThema == kThemaLimelight) {
        LimelightResultLayer::shared()->SetPhoneInstancerTextureAndScale(kResultTextSlot0, nullptr);
        LimelightResultLayer::shared()->SetPhoneInstancerTextureAndScale(kResultTextSlot1, nullptr);
        LimelightResultLayer::shared()->SetPhoneInstancerTextureAndScale(kResultTextSlot2, nullptr);
    } else if (m_nThema == kThemaClassic) {
        ResultWindowClassicLayer::shared()->SetInstancerTextureAndRefreshSlots(kResultTextSlot0,
                                                                               nullptr);
        ResultWindowClassicLayer::shared()->SetInstancerTextureAndRefreshSlots(kResultTextSlot1,
                                                                               nullptr);
        ResultWindowClassicLayer::shared()->SetInstancerTextureAndRefreshSlots(kResultTextSlot2,
                                                                               nullptr);
    }

    // Release and null the three cached result-screen text textures on the game system.
    GameSystem *pGameSystem = GameSystem::GetGameSystem();
    if (pGameSystem->m_pResultTextTexture1 != nullptr) {
        pGameSystem->m_pResultTextTexture1->Release();
        pGameSystem->m_pResultTextTexture1 = nullptr;
    }
    if (pGameSystem->m_pMusicNameTexture != nullptr) {
        pGameSystem->m_pMusicNameTexture->Release();
        pGameSystem->m_pMusicNameTexture = nullptr;
    }
    if (pGameSystem->m_pResultTextTexture2 != nullptr) {
        pGameSystem->m_pResultTextTexture2->Release();
        pGameSystem->m_pResultTextTexture2 = nullptr;
    }
}

/** @ghidraAddress 0x14facc */
void GameScene::BuildChartReaderFromGameSystem() {
    // Build a synthetic default chart (the auto-play preview path, when no music is selected).
    CMusicSheet2 *pSheet = new CMusicSheet2();
    pSheet->BuildDefaultNoteChart(GameSystem::GetGameSystem());
    BindMusicSheetToNoteMgr(pSheet);
}

/** @ghidraAddress 0x14fb24 */
void GameScene::LoadNoteSheet(NSData *sheetData) {
    // Parse the selected difficulty's sheet data into a fresh chart and bind it.
    CMusicSheet2 *pSheet = new CMusicSheet2();
    pSheet->ParseNoteChartFile(sheetData.bytes, GameSystem::GetGameSystem());
    BindMusicSheetToNoteMgr(pSheet);
}

/** @ghidraAddress 0x14fcd8 */
void GameScene::BindMusicSheetToNoteMgr(CMusicSheet2 *pMusicSheet) {
    // Tear down any previous chart, store the new one, and hand it to the note-effect manager.
    ShutdownNoteEffectSystem();
    m_pMusicSheet = pMusicSheet;
    NoteEffectMgr *pMgr = NoteEffectMgr::shared();
    pMgr->SetActiveMusicSheet(m_pMusicSheet);
    pMgr->IterateNoteRecords();
    // Seed the score tracker's total-note count from the chart, then reset playback with the ghost.
    ScoreTracker::shared()->SetTotalNotes(m_pMusicSheet->GetChartNoteCount());
    ResetNotePlaybackState(true);
}

/** @ghidraAddress 0x14fbd4 */
void GameScene::LoadResultBgmForMusic(NSData *musicData) {
    // Swap the background music to the result track: stop, release, then load it non-looping.
    [RBBGMManager.getInstance StopMusic:0.0f];
    [RBBGMManager.getInstance RelaseMusic];
    [RBBGMManager.getInstance LoadMusic:musicData Loop:NO];
    // Load the themed result voice bank (voice id 2 = result).
    SoundEffectManager::GetInstance()->LoadThemedVoiceData(kResultVoiceId);
}

/** @ghidraAddress 0x14ab4c */
void GameScene::ShutdownNoteEffectSystem() {
    ResetNotePlaybackState(false);
    NoteEffectMgr::shared()->SetActiveMusicSheet(nullptr);
    // Destroy the owned chart, if any.
    if (m_pMusicSheet != nullptr) {
        delete m_pMusicSheet;
        m_pMusicSheet = nullptr;
    }
}

/** @ghidraAddress 0x14d3b4 */
void GameScene::ResetNotePlaybackState(bool bApplyGhost) {
    NoteEffectMgr::shared()->ResetAllNoteModels();

    // On a fresh play, apply the saved replay ghost when the user's ghost style selects it.
    if (bApplyGhost && [RBUserSettingData sharedInstance].ghostStyle == 1) {
        ApplyReplayGhostToNotes();
    }

    NoteEffectMgr::shared()->AssignNoteColors();
    m_nPlayCursor = 0;
    ScoreTracker::shared()->ResetLaneGaugeState();
    ReflecGaugeLayer::shared()->ResetSideGauges();
    ClearGaugeLayer::shared()->ClearValues();

    // Clear the active theme's full-combo effect flags.
    if (m_nThema == kThemaColette) {
        FullComboColetteLayer::shared()->ClearEffectFlags();
    } else if (m_nThema == kThemaLimelight) {
        FullComboLimelightLayer::shared()->ClearEffectFlags();
    } else if (m_nThema == kThemaClassic) {
        FullComboClassicLayer::shared()->ClearEffectFlags();
    }
}

/** @ghidraAddress 0x14af90 */
void GameScene::EnterModeNormal() {
    SetMode(0);
    Init();
    SetState(2);
}

/** @ghidraAddress 0x14afbc */
void GameScene::EnterModeAlt() {
    SetMode(1);
    Init();
    SetState(0x10);
}

/** @ghidraAddress 0x14b144 */
void GameScene::ResumePlayTimerAndBgm() {
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

/**
 * @ghidraAddress 0x8c884
 * @ghidraAddress 0x8c8a8
 */
void GameScene::ResumeRenderLoopIfActive() {
    GameScene *pScene = GameSystem::GetGameSystem()->GetCurrentScene();
    if (pScene != nullptr) {
        pScene->EnterModeAlt();
    }
}

/** @ghidraAddress 0x14b2f8 */
void GameScene::ReleaseBgmAndVoice() {
    // The music must already be stopped (its playing flag cleared) before its resources are freed.
    if (GameSystem::GetGameSystem()->GetBgmPlaying()) {
        return;
    }
    [[RBBGMManager getInstance] StopMusic:0.0f];
    [[RBBGMManager getInstance] RelaseMusic];
    [[AudioManager sharedManager] releaseVoice];
}

/** @ghidraAddress 0x93b50 */
void EnsureOrientationNotificationsEnabled(void) {
    UIDevice *device = UIDevice.currentDevice;
    while (!device.isGeneratingDeviceOrientationNotifications) {
        [device beginGeneratingDeviceOrientationNotifications];
    }
}

} // namespace rb
