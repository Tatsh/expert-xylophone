//
//  play_task.mm
//  REFLEC BEAT plus
//
//  The gameplay task. Reconstructed from Ghidra project rb458, program rb458. @ghidraAddress values
//  are relative to the program image base.
//

#include "play_task.h"

#include <new>

#import <QuartzCore/QuartzCore.h>

#import "AppDelegate.h"
#import "RBBGMManager.h"
#import "RBBonusData.h"
#import "RBExperienceData.h"
#import "RBTutorialManager.h"
#import "RBUserSettingData.h"
#include "ScoreTracker.h"
#include "alt_frame_layer.h"
#include "background_sprite_manager.h"
#include "bg_layer.h"
#include "classicthemelayer.h"
#include "clear_gauge_layer.h"
#include "colette_theme_layer.h"
#include "event_effect_layer.h"
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
#include "number_layer.h"
#include "pause_gauge_layer.h"
#include "play_color_layer.h"
#include "playerfieldlayer.h"
#include "playtimer.h"
#include "reflec_gauge_layer.h"
#include "result_window_classic_layer.h"
#include "result_window_colette_layer.h"
#include "soundeffectmanager.h"
#include "thema_marker_layer.h"

// The initial state the constructor seeds; the state machine advances from here on the first frame.
static constexpr int kInitialState = 2;

// The play states this step selects between: the note-play wait state and the past-effect state.
static constexpr int kStateWaitNotes = 5;
static constexpr int kStatePastEffect = 6;

// The playing state the preview resumes into.
static constexpr int kStatePlaying = 0x11;

// The result-theme display state EnterResultThemeState advances to.
static constexpr int kStateResultTheme = 0xb;

// The gameplay-presentation state StartGameplayPresentation advances to, the intro-voice cue it
// plays, and the fade-in duration (in milliseconds) it primes the layers with.
static constexpr int kStatePresenting = 7;
static constexpr int kIntroVoiceCue = 2;
static constexpr float kPresentationFadeInDuration = 1000.0f; // @ghidraAddress 0x2f8540

// The play-ready state AdvanceToPlayReadyState advances to, and the gauge grow-animation from-value
// (also the marker fade-in's marker value) it primes the layers with.
static constexpr int kStatePlayReady = 4;
static constexpr float kGaugeGrowFromValue = 450.0f; // @ghidraAddress 0x308dd8

// The result-voice cue and the clear-cue sound-effect slots, and the clear-rate threshold at or above
// which the clear cue plays.
static constexpr int kResultVoiceCue = 0x13;
static constexpr int kClearCueSoundEffect = 8;
static constexpr float kClearRateThreshold = 0.7f; // @ghidraAddress 0x2fd008

// The theme identifiers selecting the full-combo layer whose effect flags a playback reset clears.
static constexpr int kThemaClassic = 0;
static constexpr int kThemaLimelight = 1;
static constexpr int kThemaColette = 2;

// The three result-window text-instancer slots whose textures are cleared at teardown.
static constexpr int kResultTextSlot0 = 2;
static constexpr int kResultTextSlot1 = 3;
static constexpr int kResultTextSlot2 = 4;

// The themed voice bank the result screen loads.
static constexpr int kResultVoiceId = 2;

// The player side the result bonuses are computed for (the single-player side).
static constexpr unsigned int kResultSide = 1;

// The score-record cell holding the miss count, and its values: full-combo (0), one miss (1), two or
// more misses (2).
static constexpr unsigned int kMissCell = 6;
static constexpr int kMissFullCombo = 0;
static constexpr int kMissOne = 1;
static constexpr int kMissTwo = 2;

// The minimum clear rank (of the B/A/AA/AAA/AAAP ladder) that earns the clear bonus.
static constexpr int kMinClearRank = 2;

// The clear ranks, in ladder order, selecting the rank bonus.
static constexpr int kRankB = 1;
static constexpr int kRankA = 2;
static constexpr int kRankAA = 3;
static constexpr int kRankAAA = 4;
static constexpr int kRankAAAP = 5;

// The pastel-field bonus types (the field-10 statistic must be zero for either to apply).
static constexpr int kPastelBonusNormal = 1;
static constexpr int kPastelBonusBlack = 2;

// The last playable level: reaching its threshold stops the level-up unlock loop.
static constexpr unsigned int kNoLevelThreshold = 0xffffffff;

namespace {
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
} // namespace

/** @ghidraAddress 0x14a21c */
PlayTask::PlayTask() {
    // The UI-layer base constructor ran first and the compiler installed the vtable; seed the play
    // state (the base fields and the reserved sub-state are already zero-initialised).
    m_nState = 0;
    m_nPlayTime = 0;
    m_nInitialState = kInitialState;
}

/** @ghidraAddress 0x14b6e0 */
bool PlayTask::RefreshPauseGaugeAndGetActiveFlag() {
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
void PlayTask::ComputeResultBonusesAndExperience() {
    // Classic theme: advance the level/experience progression and unlock custom items.
    if (m_nThema == kThemaClassic) {
        LevelTables *pTables = LevelTables::GetInstance();
        GameSystem *pGameSystem = GameSystem::GetGameSystem();
        ScoreTracker *pTracker = ScoreTracker::shared();

        int nLevel = pTables->GetCurrentLevel();
        int nExp = pTables->GetCurrentExp();
        const float flRate = pTracker->GetPlayRecordRate(kResultSide);
        const bool bAllJudged = pTracker->IsSideAllNotesJudged(kResultSide);
        const int nGained = ComputeLevelExpStep(flRate,
                                                pTables,
                                                pGameSystem->GetDifficultyLevel(),
                                                bAllJudged,
                                                pGameSystem->GetIsFirstPlay());

        // Publish the starting level/experience and the gained amount to the game system.
        pGameSystem->SetResultLevelExp(nLevel, nExp, nGained);

        // Roll the gained experience into the level, unlocking a new custom item for each level up,
        // until the next threshold is unreachable (the level cap).
        unsigned int nThreshold = GetLevelExpThreshold(pTables, nLevel);
        if (nThreshold != kNoLevelThreshold) {
            nExp += nGained;
            // The binary compares the experience against the threshold as signed values.
            while (nExp >= static_cast<int>(nThreshold)) {
                nExp -= static_cast<int>(nThreshold);
                ++nLevel;
                nThreshold = GetLevelExpThreshold(pTables, nLevel);
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
        SavePlayerLevelData(pTables->GetLevelExpRecord());
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
void PlayTask::EnterResultThemeState() {
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
void PlayTask::StartGameplayPresentation() {
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
void PlayTask::AdvanceToPlayReadyState() {
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

/** @ghidraAddress 0x14b818 */
void PlayTask::WaitForIntroThenStartNotes() {
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
void PlayTask::ResumePreviewPlayback() {
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

/** @ghidraAddress 0x12ee88 */
void PlayTask::GetInstance(PlayTask **ppOut) {
    if (*ppOut == nullptr) {
        PlayTask *pTask = new PlayTask();
        // Register the task in the engine's per-frame list at priority 1.
        pTask->InsertSorted(1);
        *ppOut = pTask;
    }
}

/** @ghidraAddress 0x14f9a4 */
void PlayTask::ReleaseResultTexturesAndFrames() {
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
void PlayTask::BuildChartReaderFromGameSystem() {
    // Build a synthetic default chart (the auto-play preview path, when no music is selected).
    MusicSheet *pSheet = new MusicSheet();
    pSheet->BuildDefaultNoteChart(GameSystem::GetGameSystem());
    BindMusicSheetToNoteMgr(pSheet);
}

/** @ghidraAddress 0x14fb24 */
void PlayTask::LoadNoteSheet(NSData *sheetData) {
    // Parse the selected difficulty's sheet data into a fresh chart and bind it.
    MusicSheet *pSheet = new MusicSheet();
    pSheet->ParseNoteChartFile(sheetData.bytes, GameSystem::GetGameSystem());
    BindMusicSheetToNoteMgr(pSheet);
}

/** @ghidraAddress 0x14fcd8 */
void PlayTask::BindMusicSheetToNoteMgr(MusicSheet *pMusicSheet) {
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
void PlayTask::LoadResultBgmForMusic(NSData *musicData) {
    // Swap the background music to the result track: stop, release, then load it non-looping.
    [RBBGMManager.getInstance StopMusic:0.0f];
    [RBBGMManager.getInstance RelaseMusic];
    [RBBGMManager.getInstance LoadMusic:musicData Loop:NO];
    // Load the themed result voice bank (voice id 2 = result).
    SoundEffectManager::GetInstance()->LoadThemedVoiceData(kResultVoiceId);
}

/** @ghidraAddress 0x14ab4c */
void PlayTask::ShutdownNoteEffectSystem() {
    ResetNotePlaybackState(false);
    NoteEffectMgr::shared()->SetActiveMusicSheet(nullptr);
    // Destroy the owned chart, if any.
    if (m_pMusicSheet != nullptr) {
        delete m_pMusicSheet;
        m_pMusicSheet = nullptr;
    }
}

/** @ghidraAddress 0x14d3b4 */
void PlayTask::ResetNotePlaybackState(bool bApplyGhost) {
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
