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

#import <GameKit/GameKit.h>
#import <QuartzCore/QuartzCore.h>
#import <UIKit/UIKit.h>

#import "AppDelegate.h"
#import "AudioManager.h"
#import "MusicData.h"
#import "RBBGMManager.h"
#import "RBBonusData.h"
#import "RBCoreDataManager.h"
#import "RBExperienceData.h"
#import "RBServerAPIManager.h"
#import "RBTutorialManager.h"
#import "RBUserSettingData.h"
#import "RBViewController.h"
#import "ReplayData.h"
#import "ReplayNote.h"
#import "ScoreData.h"
#include "ScoreTracker.h"
#include "alt_frame_layer.h"
#include "background_sprite_manager.h"
#include "bg_layer.h"
#include "bounds_effect_layer.h"
#include "chain_connector_layer.h"
#include "classicthemelayer.h"
#include "clear_gauge_layer.h"
#include "colette_theme_layer.h"
#include "damage_effect_layer.h"
#include "deviceenvironment.h"
#include "engineruntime.h"
#include "event_effect_layer.h"
#include "explosion_effect_layer.h"
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
#include "long_note_layer.h"
#include "main_frame_layer.h"
#include "music_sheet.h"
#include "neTexture.h"
#include "note_born_layer.h"
#include "note_charge_layer.h"
#include "note_effect_mgr.h"
#include "note_glow_layer.h"
#include "note_layer.h"
#include "note_model.h"
#include "note_replay.h"
#include "note_result_layer.h"
#include "note_trail_layer.h"
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
#include "slide_note_layer.h"
#include "slide_note_result_layer.h"
#include "soundeffectmanager.h"
#include "thema_marker_layer.h"
#include "touch_point.h"
#include "touchmanager.h"
#include "tutorial_guide_layer.h"

namespace {

// The initial mode the constructor seeds; the state machine advances from here on the first frame.
constexpr int kInitialMode = 2;

// The alternate play mode, in which the auto-pause note-convergence heuristic is disabled.
constexpr int kAlternatePlayMode = 1;

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

// The state the exit transitions and the play-field entry step both advance to: its handler resets
// note playback. Also the play-time threshold (in play time) ExitToMusicList waits past before
// tearing down.
constexpr int kStateResetPlayback = 1;
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

namespace {

// The score-readout position the Limelight and Colette themes push the player field to; the Classic
// theme leaves it unscaled (@ghidraAddress 0x2fd008).
constexpr float kThemedScorePosition = 0.70f;
constexpr float kDefaultScorePosition = 1.0f;

// The play sides the score readout, gauge mirror, and theme layers are configured for.
constexpr int kSideLeft = 0;
constexpr int kSideRight = 1;

// The game types: the first and third configure the left side, the second the right. Any other value
// is a programming error and trips the binary's assertion.
constexpr int kGameTypeSingle = 0;
constexpr int kGameTypeVersus = 1;
constexpr int kGameTypeReplay = 2;

// The themes, selecting which theme and result layer the scene seeds.
constexpr int kThemaClassic = 0;
constexpr int kThemaLimelight = 1;
constexpr int kThemaColette = 2;

// The play mode that owns the chart; the others enter with one already bound.
constexpr int kModeNormal = 0;

// The note-sheet touch radius by note type, on the phone and on the iPad
// (@ghidraAddress 0x308de0 and 0x308dec).
constexpr int kSheetRadiusPhone[] = {96, 80, 68};
constexpr int kSheetRadiusPad[] = {72, 62, 52};

// The play colour by difficulty (@ghidraAddress 0x308df8). The binary indexes this table rather than
// passing the difficulty straight through, though every entry maps to itself.
constexpr int kPlayColorByDifficulty[] = {0, 1, 2, 3};

// The intro thresholds, in play time, the scene seeds for every mode.
constexpr float kPresentationDelay = 500.0f;
constexpr float kIntroSecondDelay = 700.0f;
constexpr float kReadyDelay = 2500.0f;

// The effect intensities the play-colour lane is driven at when the rival side is shown or hidden.
constexpr float kEffectShown = 1.0f;
constexpr float kEffectHidden = 0.0f;

} // namespace

/** @ghidraAddress 0x14a518 */
void GameScene::Init() {
    // Recover every cached texture first; the layers below bind them as they refresh.
    (void)ne::C_TEXTURE::GetCacheList(); // Yes, the binary discards this call's result.
    ne::C_TEXTURE::ReloadAll();

    // Re-read the player's theme into every play-field layer. The Colette layers are absent from
    // this sweep in the binary.
    BgLayer::GetBackgroundLayer()->RefreshThema();
    AltFrameLayer::shared()->RefreshThema();
    MainFrameLayer::shared()->RefreshThema();
    PlayerFieldLayer::shared()->RefreshThema();
    JudgeEffectLayer::shared()->RefreshThema();
    ThemaMarkerLayer::shared()->SetupMarkers();
    PlayColorLayer::shared()->RefreshThema();
    ReflecGaugeLayer::shared()->RefreshThema();
    ClearGaugeLayer::shared()->RefreshThema();
    NoteBornLayer::shared()->RefreshThema();
    ChainConnectorLayer::shared()->RefreshThema();
    LongNoteLayer::shared()->RefreshThema();
    NoteLayer::shared()->RefreshThema();
    NoteTrailLayer::shared()->RefreshThema();
    SlideNoteLayer::shared()->RefreshThema();
    SlideNoteResultLayer::shared()->RefreshThema();
    NoteChargeLayer::shared()->RefreshThema();
    DamageEffectLayer::shared()->SetBoundsDamageStyle();
    BoundsEffectLayer::shared()->SetStyle();
    NoteResultLayer::shared()->RefreshThema();
    ExplosionEffectLayer::shared()->RefreshThema();
    NoteGlowLayer::shared()->SetTexture();
    FullComboClassicLayer::shared()->RefreshThema();
    BackgroundSpriteManager::shared()->RefreshThema();
    ClassicThemeLayer::shared()->RefreshThema();
    ResultWindowClassicLayer::shared()->RefreshThema();
    FullComboLimelightLayer::shared()->RefreshThema();
    LimelightEffectLayer::shared()->RefreshThema();
    LimelightThemeLayer::shared()->RefreshThema();
    LimelightResultLayer::shared()->ResetThemeSelectState();
    FadeOverlayLayer::shared()->RefreshThema();
    // The background, frame, explosion, and bounds layers are refreshed a second time.
    BgLayer::GetBackgroundLayer()->RefreshThema();
    AltFrameLayer::shared()->RefreshThema();
    MainFrameLayer::shared()->RefreshThema();
    ExplosionEffectLayer::shared()->RefreshThema();
    BoundsEffectLayer::shared()->SetStyle();
    EventEffectLayer::shared()->RefreshThema();
    TutorialGuideLayer::shared()->RefreshThema();

    GameSystem *pGameSystem = GameSystem::GetGameSystem();
    const int nGameType = pGameSystem->GetGameType();

    // The two themed skins pull the score readout in; the Classic theme leaves it where it is.
    const float flScorePosition = (m_nThema == kThemaColette || m_nThema == kThemaLimelight) ?
                                      kThemedScorePosition :
                                      kDefaultScorePosition;
    PlayerFieldLayer::shared()->SetScorePosition(flScorePosition, kSideLeft);
    PlayerFieldLayer::shared()->SetScorePosition(flScorePosition, kSideRight);

    // The player's three effect-size preferences.
    const float flBoundsSize = RBUserSettingData.sharedInstance.boundsEffectSize;
    const float flDamageSize = RBUserSettingData.sharedInstance.damageEffectSize;
    const float flExplosionSize = RBUserSettingData.sharedInstance.explosionEffectSize;
    BoundsEffectLayer::shared()->SetEffectSize(flBoundsSize);
    DamageEffectLayer::shared()->SetEffectSize(flDamageSize);
    ExplosionEffectLayer::shared()->SetEffectSize(flExplosionSize);

    const int nExplosionType = pGameSystem->GetExplosionType();
    ExplosionEffectLayer::shared()->SetEffectType(kSideLeft, nExplosionType);
    ExplosionEffectLayer::shared()->SetEffectType(kSideRight, nExplosionType);

    // The iPad draws the alternate frame, the phone the main frame.
    if (IsPad()) {
        AltFrameLayer::shared()->SetFrameType(pGameSystem->GetFrameType());
        AltFrameLayer::shared()->SetFrameMode(pGameSystem->GetDifficulty());
        AltFrameLayer::shared()->SetAltFrameTexture(pGameSystem->GetMusicNameTexture());
    } else {
        MainFrameLayer::shared()->SetFrameType(pGameSystem->GetFrameType());
        MainFrameLayer::shared()->SetMarker(pGameSystem->GetDifficulty(),
                                            pGameSystem->GetDifficultyLevel());
        MainFrameLayer::shared()->SetMainFrameTexture(pGameSystem->GetMusicNameTexture());
        MainFrameLayer::shared()->SetMainFrameEnabled(true);
    }

    BgLayer::GetBackgroundLayer()->SetBackgroundType(pGameSystem->GetBackgroundType());

    // The touch radius is smaller on the iPad, whose play field is laid out larger.
    const int *pSheetRadius = IsPad() ? kSheetRadiusPad : kSheetRadiusPhone;
    pGameSystem->SetSheetRadius(static_cast<float>(pSheetRadius[pGameSystem->GetNoteType()]));

    const int nGaugeStyle = RBUserSettingData.sharedInstance.gaugeStyle;
    ReflecGaugeLayer::shared()->SetGaugeStyle(nGaugeStyle);
    ClearGaugeLayer::shared()->SetGaugeStyle(nGaugeStyle);

    // The versus game type plays the right side; the single and replay types the left. Any other
    // value trips the binary's assertion.
    if (nGameType != kGameTypeSingle && nGameType != kGameTypeVersus &&
        nGameType != kGameTypeReplay) {
        assert(0);
    }
    const int nSide = nGameType == kGameTypeVersus ? kSideRight : kSideLeft;
    PlayerFieldLayer::shared()->SetScoreSideFlag(nSide);
    ReflecGaugeLayer::shared()->SetMirrorSide(nSide);
    ClearGaugeLayer::shared()->SetTwoSideEnabled(nSide != 0);
    if (m_nThema == kThemaColette) {
        ColetteThemeLayer::shared()->SetSideCount(nSide);
    } else if (m_nThema == kThemaLimelight) {
        LimelightThemeLayer::shared()->SetSideCount(nSide);
    } else if (m_nThema == kThemaClassic) {
        ClassicThemeLayer::shared()->SetColor(nSide);
    }

    PlayColorLayer::shared()->SetPlayColorValue(
        kPlayColorByDifficulty[pGameSystem->GetDifficulty()]);
    ShutdownNoteEffectSystem();
    NoteEffectMgr::shared()->ApplyTheme();

    // Only the normal mode binds the chart here; the others enter with one already loaded.
    if (m_nMode == kModeNormal) {
        LoadMusicAndSheet();
        if (pGameSystem->GetFullJustReflec()) {
            m_nResultScore = m_pMusicSheet->GetSideObjectCount(kSideLeft);
            m_nResultScoreHi = m_pMusicSheet->GetSideObjectCount(kSideRight);
        } else {
            // Both slots take the same field; the binary reads it twice rather than pairing it
            // with a neighbour.
            m_nResultScore = m_pMusicSheet->GetJustReflecQuotaRemain();
            m_nResultScoreHi = m_pMusicSheet->GetJustReflecQuotaRemain();
        }

        if (m_nThema == kThemaColette) {
            ResultWindowColetteLayer::shared()->SetResultScores(m_nResultScore, m_nResultScoreHi);
        } else if (m_nThema == kThemaLimelight) {
            LimelightResultLayer::shared()->SetResultScores(m_nResultScore, m_nResultScoreHi);
        } else if (m_nThema == kThemaClassic) {
            ResultWindowClassicLayer::shared()->SetResultScores(m_nResultScore, m_nResultScoreHi);
        }

        LoadMusicNameAndFrameTexture();
    }

    m_flPresentationDelay = kPresentationDelay;
    m_flIntroSecondDelay = kIntroSecondDelay;
    m_flReadyDelay = kReadyDelay;

    // The rival side's effects are drawn at full strength in a versus play, or whenever the rival
    // alpha has been set; otherwise they are suppressed.
    const bool bRivalShown = nGameType == kGameTypeVersus || pGameSystem->GetRivalAlpha() != 0.0f;
    const float flEffect = bRivalShown ? kEffectShown : kEffectHidden;
    const int nLightLane = pGameSystem->GetPlayColor() == 0 ? 1 : 0;
    ExplosionEffectLayer::shared()->SetPlayColorAlpha(flEffect, kSideLeft);
    DamageEffectLayer::shared()->SetLaneValue(kSideLeft, flEffect);
    BoundsEffectLayer::shared()->SetLaneLightFlag(flEffect, nLightLane);
    NoteResultLayer::shared()->SetScale(flEffect, kSideLeft);
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

/** @ghidraAddress 0x14b5b8 */
void GameScene::CheckAutoPauseByNotePosition() {
    // The vertical hit-band the note must fall in (in the 1024x-scaled screen space), and the x
    // convergence threshold (in the 768-wide note space; the field midpoint is 384).
    constexpr int kScrollFixedShift = 10;     // The <<10 (1024x) scroll-space scale.
    constexpr float kNoteFieldWidth = 768.0f; // @ghidraAddress 0x2fd04c
    constexpr int kBandCurrentBase = 0x19c;
    constexpr int kBandCurrentSpan = 0xc8;
    constexpr int kBandBeginBase = 0x19d;
    constexpr int kBandBeginSpan = 0xc7;
    constexpr int kFieldMidpoint = 0x180;
    constexpr int kConvergeThreshold = 100;

    if (GameSystem::GetGameSystem()->GetPaused()) {
        return;
    }

    TouchManager *pTouchManager = TouchManager::FetchSharedSingleton();
    const int nCount = pTouchManager->GetActiveTouchCount();
    if (nCount < 1) {
        return;
    }

    bool bLeftConverged = false;
    bool bRightConverged = false;
    for (int i = 0; i < nCount; ++i) {
        const TouchPoint *pTouch = pTouchManager->GetActiveTouch(i);
        // Normalise the touch's y by the owning view height into the 1024x scroll space.
        const float flHeight = static_cast<float>(pTouch->nKey2);
        const int nCurrentY = static_cast<int>((static_cast<float>(pTouch->nCurrentY) / flHeight) *
                                               (1 << kScrollFixedShift));
        if (static_cast<unsigned int>(nCurrentY - kBandCurrentBase) > kBandCurrentSpan) {
            continue;
        }
        const int nBeginY = static_cast<int>((static_cast<float>(pTouch->nBeginY) / flHeight) *
                                             (1 << kScrollFixedShift));
        if (static_cast<unsigned int>(nBeginY - kBandBeginBase) > kBandBeginSpan) {
            continue;
        }

        // Normalise the x positions by the owning view width into the note field's width.
        const float flWidth = static_cast<float>(pTouch->nKey1);
        const int nCurrentX =
            static_cast<int>((static_cast<float>(pTouch->nCurrentX) / flWidth) * kNoteFieldWidth);
        const int nBeginX =
            static_cast<int>((static_cast<float>(pTouch->nBeginX) / flWidth) * kNoteFieldWidth);
        if (nBeginX < kFieldMidpoint && nCurrentX - nBeginX > kConvergeThreshold) {
            bLeftConverged = true;
        }
        if (nBeginX > kFieldMidpoint && nBeginX - nCurrentX > kConvergeThreshold) {
            bRightConverged = true;
        }
    }

    if (bLeftConverged && bRightConverged && m_nMode != kAlternatePlayMode) {
        PausePlayTimerAndBgm();
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

namespace {
// The themed voice cue fired as the result screen crosses the one-second mark, and the play-time
// mark (in play-time units) it fires at.
constexpr int kResultReadyVoiceCue = 6;
constexpr int kResultVoiceMark = 1000;
// The confirm sound played when the player acknowledges the result.
constexpr int kResultConfirmSoundEffect = 1;
// The fade-out time the result confirm stops the music over.
constexpr float kResultStopMusicFade = 1.5f;
// The tutorial status representing "music-select tutorial seen", set once the result is submitted,
// and the highest tutorial status still inside the in-play walkthrough (the result submit waits for
// the walkthrough to pass it).
constexpr unsigned int kTutorialResultSeenStatus = RBTutorialStatusMusicSelectSeen;
constexpr unsigned int kTutorialInPlayStatusMax = 0x16;
// The play-record cells the submit reads: the side-one score and its just-reflec count.
constexpr unsigned int kSubmitScoreCell = 0;
constexpr unsigned int kSubmitJustReflecCell = 7;
} // namespace

/** @ghidraAddress 0x14c27c */
void GameScene::FinalizeResultAndSubmitScore(int nDeltaFrames) {
    // Fire the result voice cue once, on the frame the play time crosses the one-second mark.
    if (m_nPlayTime > kResultVoiceMark && m_nPlayTime - nDeltaFrames <= kResultVoiceMark) {
        SoundEffectManager::GetInstance()->PlayThemedVoice(kResultReadyVoiceCue);
    }

    // Wait for the active theme's result window to report the confirm tap.
    bool bConfirmed = false;
    if (m_nThema == kThemaClassic) {
        bConfirmed = ResultWindowClassicLayer::shared()->GetCustomizeReloadFlag();
    } else if (m_nThema == kThemaLimelight) {
        bConfirmed = LimelightResultLayer::shared()->IsResultConfirmed();
    } else if (m_nThema == kThemaColette) {
        bConfirmed = ResultWindowColetteLayer::shared()->IsResultConfirmed();
    }
    if (!bConfirmed) {
        return;
    }

    // An early tutorial play holds the result screen open until the walkthrough passes its result
    // step; nothing is submitted until then.
    if (GameSystem::GetGameSystem()->GetMenuTutorialActive() != 0 &&
        RBTutorialManager.getCurrentStatus <= kTutorialInPlayStatusMax) {
        return;
    }

    // Acknowledge the confirm: play the sound, stop the music, and clear the theme's confirm latch.
    SoundEffectManager::GetInstance()->PlayThemedSoundEffect(kResultConfirmSoundEffect);
    [RBBGMManager.getInstance StopMusic:kResultStopMusicFade];
    if (m_nThema == kThemaColette) {
        ResultWindowColetteLayer::shared()->ClearResultConfirmed();
    } else if (m_nThema == kThemaLimelight) {
        LimelightResultLayer::shared()->ClearResultConfirmed();
    } else if (m_nThema == kThemaClassic) {
        ResultWindowClassicLayer::shared()->ClearCustomizeReloadFlag();
    }

    // Submit the play to the server unless it was a full-combo or full-just-reflec run.
    ScoreTracker *pTracker = ScoreTracker::shared();
    const unsigned int nScore = pTracker->GetPlayRecordCell(kResultSide, kSubmitScoreCell);
    const unsigned int nJustReflec =
        pTracker->GetPlayRecordCell(kResultSide, kSubmitJustReflecCell);
    const unsigned int nNotes = static_cast<unsigned int>(pTracker->GetTotalNotes());
    GameSystem *pGameSystem = GameSystem::GetGameSystem();
    const unsigned int nDifficulty = static_cast<unsigned int>(pGameSystem->GetDifficulty());
    const unsigned int nMusicId =
        static_cast<unsigned int>(AppDelegate.appDelegate.musicData.MusicID);
    if ((!pGameSystem->GetUserFullCombo() || !pGameSystem->GetCpuFullCombo()) &&
        !pGameSystem->GetFullJustReflec()) {
        [RBServerAPIManager playedV2APIWithMusicID:nMusicId
                                               dif:nDifficulty
                                              note:nNotes
                                                jr:nJustReflec
                                             score:nScore];

        // Mark the music-select tutorial seen the first time, and tear down the tutorial guide.
        if ([RBUserSettingData.sharedInstance getTutorialStatus:kTutorialResultSeenStatus] == 0) {
            [RBUserSettingData.sharedInstance updateTutorialStatus:kTutorialResultSeenStatus
                                                             value:1];
        }
        if (pGameSystem->GetMenuTutorialActive() != 0) {
            [RBTutorialManager
                updateStatus:static_cast<RBTutorialStatus>(kTutorialResultSeenStatus)];
            TutorialGuideLayer::destroyShared();
            pGameSystem->SetMenuTutorialActive(0);
        }
    }

    FadeOverlayLayer::shared()->StartFadeIn(kPresentationFadeInDuration);
    m_nState = kMusicReleaseState;
}

namespace {
// The play-time (in play-time units) the result screen waits past before it builds itself.
constexpr int kResultBuildDelay = 500;
// The result-window sprite-instancer slots the three loaded textures bind to.
constexpr unsigned int kResultInstancerArtwork = 2;
constexpr unsigned int kResultInstancerMusicName = 3;
constexpr unsigned int kResultInstancerArtistName = 4;
// The result show/open tween duration.
constexpr float kResultShowTweenDuration = 500.0f; // @ghidraAddress 0x2feff4
// The result-screen state the build advances to, the themed voice bank it loads, and the tutorial
// status it advances a tutorial play to.
constexpr int kStateResultSubmit = 0xc;
constexpr int kResultVoiceBank = 6;
constexpr unsigned int kTutorialResultStartStatus = 0x13;

// The sentinel music id of the no-song auto-play demo, which loops its background music rather than
// leaving it stopped.
constexpr int kPreviewMusicID = 999999999;
} // namespace

/** @ghidraAddress 0x14bf30 */
void GameScene::LoadResultScreenAndMusic() {
    if (m_nPlayTime <= kResultBuildDelay) {
        return;
    }

    // Wait for the active theme's intro/reveal to finish before building the result window.
    if (m_nThema == kThemaClassic && ClassicThemeLayer::shared()->IsAnimActive()) {
        return;
    }
    if (m_nThema == kThemaLimelight && LimelightThemeLayer::shared()->IsGradeVisible()) {
        return;
    }
    if (m_nThema == kThemaColette && ColetteThemeLayer::shared()->IsGradeVisible()) {
        return;
    }

    // Load the song artwork and artist-name textures for the result window (the music-name texture
    // was loaded during set-up).
    GameSystem *pGameSystem = GameSystem::GetGameSystem();
    pGameSystem->LoadArtworkTexture(AppDelegate.appDelegate.musicData);
    pGameSystem->LoadArtistNameTexture(AppDelegate.appDelegate.musicData);

    // Bind the three result-window instancer textures (artwork, music name, artist name), reset the
    // result flags, start the show tween, and clear the confirm latch — per theme.
    ne::C_TEXTURE *pArtwork = pGameSystem->GetArtworkTexture();
    ne::C_TEXTURE *pMusicName = pGameSystem->GetMusicNameTexture();
    ne::C_TEXTURE *pArtistName = pGameSystem->GetArtistNameTexture();
    if (m_nThema == kThemaColette) {
        ResultWindowColetteLayer *pResult = ResultWindowColetteLayer::shared();
        pResult->applySpriteInstancerTexture(kResultInstancerArtwork, pArtwork);
        pResult->applySpriteInstancerTexture(kResultInstancerMusicName, pMusicName);
        pResult->applySpriteInstancerTexture(kResultInstancerArtistName, pArtistName);
        pResult->InitializeResultScreenFlags();
        pResult->StartShowTween(kResultShowTweenDuration);
        pResult->ClearResultConfirmed();
    } else if (m_nThema == kThemaLimelight) {
        LimelightResultLayer *pResult = LimelightResultLayer::shared();
        pResult->SetPhoneInstancerTextureAndScale(kResultInstancerArtwork, pArtwork);
        pResult->SetPhoneInstancerTextureAndScale(kResultInstancerMusicName, pMusicName);
        pResult->SetPhoneInstancerTextureAndScale(kResultInstancerArtistName, pArtistName);
        pResult->InitializePhoneResultLayer();
        pResult->SetupOpenTweenPhone(kResultShowTweenDuration);
        pResult->ClearResultConfirmed();
    } else if (m_nThema == kThemaClassic) {
        ResultWindowClassicLayer *pResult = ResultWindowClassicLayer::shared();
        pResult->SetInstancerTextureAndRefreshSlots(kResultInstancerArtwork, pArtwork);
        pResult->SetInstancerTextureAndRefreshSlots(kResultInstancerMusicName, pMusicName);
        pResult->SetInstancerTextureAndRefreshSlots(kResultInstancerArtistName, pArtistName);
        pResult->ResetScoreDisplayState();
        pResult->StartResultScoreAnimations(kResultShowTweenDuration);
        pResult->ClearCustomizeReloadFlag();
    }

    // Load the result voice, start the looping result music, and advance to the submit state.
    SoundEffectManager::GetInstance()->LoadThemedVoiceData(kResultVoiceBank);
    [RBBGMManager.getInstance LoadMusicResultWithLoop:YES];
    [RBBGMManager.getInstance PlayMusic:0.0f];
    m_nState = kStateResultSubmit;

    // A tutorial play advances the walkthrough to the result step and resets the guide.
    if (GameSystem::GetGameSystem()->GetMenuTutorialActive() != 0) {
        [RBTutorialManager updateStatus:static_cast<RBTutorialStatus>(kTutorialResultStartStatus)];
        TutorialGuideLayer::shared()->Reset();
    }
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

/** @ghidraAddress 0x14ce34 */
void GameScene::ClosePreviewAndReturnToList() {
    ShutdownNoteEffectSystem();

    // Stop the music and re-enable rotation only when a music is selected.
    if ([AppDelegate.appDelegate musicData] != nil) {
        StopBgmAndAllowRotation();
    }
    ResetAllPlayFieldLayers();

    // Fade out and free the number-effect layer.
    NumberEffectLayer::shared()->StartFadeOut(0.0f);
    NumberEffectLayer::FreeInstance();

    // Hide the preview through the app's root view controller and flush the texture cache.
    [AppDelegate.appDelegate.viewController hidePreview];
    (void)ne::C_TEXTURE::GetCacheList(); // The binary discards this call's result.
    ReleaseAllCachedTextures();

    m_nState = kStateResetPlayback;
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

    m_nState = kStateResetPlayback;
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

/** @ghidraAddress 0x14cb4c */
void GameScene::AdvancePreviewPlaybackFrame(int nDeltaFrames) {
    // Loop the preview once its clock has run past the chart: only while the Limelight full-combo
    // effect is not blocking, and the chart end time has fallen behind the play clock's scaled
    // position (offset by the spawn look-ahead).
    const float flChartEnd = static_cast<float>(m_pMusicSheet->GetChartEndTime());
    const float flClockPos =
        PlayTimer::shared()->GetPlayTime() * kNoteLineScale + kNoteSpawnLookahead;
    if (!FullComboLimelightLayer::shared()->IsAnyEffectActive() && flChartEnd < flClockPos) {
        GameSystem::GetGameSystem()->SetRandSeed(static_cast<unsigned int>(rand()));
        ResetNotePlaybackState(false);

        PlayTimer *pTimer = PlayTimer::shared();
        if (AppDelegate.appDelegate.musicData.MusicID == kPreviewMusicID) {
            // The no-song demo loops its background music from the top and runs a music-driven timer.
            [RBBGMManager.getInstance StopMusic:0.0f];
            [RBBGMManager.getInstance SeekToTop];
            [RBBGMManager.getInstance PlayMusic:0.0f];
            GameSystem::GetGameSystem()->SetBgmPlaying(true);
            pTimer->StartPlayback(CACurrentMediaTime(), true);
        } else {
            pTimer->StartPlayback(CACurrentMediaTime(), false);
        }
        return;
    }

    // Otherwise advance one frame of the preview.
    NumberEffectLayer::shared()->Update(static_cast<float>(nDeltaFrames));
    PlayTimer::shared()->Update();
    NoteEffectMgr::shared()->ProcessActiveNotes();
    ActivateDueNotes();
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

    // Release and null the three cached song textures on the game system (artwork, music name, and
    // artist name).
    GameSystem *pGameSystem = GameSystem::GetGameSystem();
    if (pGameSystem->m_pArtworkTexture != nullptr) {
        pGameSystem->m_pArtworkTexture->Release();
        pGameSystem->m_pArtworkTexture = nullptr;
    }
    if (pGameSystem->m_pMusicNameTexture != nullptr) {
        pGameSystem->m_pMusicNameTexture->Release();
        pGameSystem->m_pMusicNameTexture = nullptr;
    }
    if (pGameSystem->m_pArtistNameTexture != nullptr) {
        pGameSystem->m_pArtistNameTexture->Release();
        pGameSystem->m_pArtistNameTexture = nullptr;
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
    ScoreTracker::shared()->SetTotalNotes(m_pMusicSheet->GetChartNoteCount(0));
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

/** @ghidraAddress 0x14aec4 */
void GameScene::LoadMusicNameAndFrameTexture() {
    GameSystem *pGameSystem = GameSystem::GetGameSystem();
    MusicData *musicData = [AppDelegate appDelegate].musicData;
    pGameSystem->LoadMusicNameTexture(musicData);

    // The iPad build uses the wide alternate-frame layer; the phone build uses the main-frame layer.
    if (IsPad()) {
        AltFrameLayer::shared()->SetAltFrameTexture(pGameSystem->GetMusicNameTexture());
    } else {
        MainFrameLayer::shared()->SetMainFrameTexture(pGameSystem->GetMusicNameTexture());
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

namespace {
// The listener-list priority the pause-gauge layer is registered at.
constexpr int kPauseGaugeListenerPriority = 2;

// The play states the dispatcher handles that no other step names: the entry state that builds the
// layers, the state a bound chart advances to, the state a finished play advances to, the state a
// restart re-enters, the preview set-up and resume states, and the second preview-exit state.
constexpr int kStateInit = 0;
constexpr int kStateChartBound = 3;
constexpr int kStatePlayFinished = 0xa;
constexpr int kStateRestartPlayback = 0xf;
constexpr int kStatePreviewSetup = 0x10;
constexpr int kStatePreviewResume = 0x12;
constexpr int kStatePreviewExit = 0x14;

// The game type identifying a networked match, whose result is never scored or banked.
constexpr int kGameTypeNetworkMatch = 1;

// The play-record's match outcome (judgement cell index 10).
constexpr int kMatchResultWin = 0;
constexpr int kMatchResultLose = 1;
constexpr int kMatchResultDraw = 2;

// The play colour drawn in blue; the other side is red.
constexpr int kPlayColorBlue = 1;

// The themed voice cues the end of a play loads, indexing the voice-name table.
constexpr int kVoiceCueTitle = 0;
constexpr int kVoiceCueWin = 3;
constexpr int kVoiceCueLose = 4;
constexpr int kVoiceCueDraw = 5;
constexpr int kVoiceCueBlueWin = 15;
constexpr int kVoiceCueRedWin = 16;

// The inclusive song-identifier window whose plays are scored, banked, and reported.
constexpr int kFirstScoredMusicId = 100000001;
constexpr int kLastScoredMusicId = 899999999;

// The base the intro fade level counts down from while the note path is still negative. The binary
// really does store negative zero here, so the level is the negated fractional part.
constexpr float kFadeInBase = -0.0f; // @ghidraAddress 0x308ddc

// The two player sides the judgement tally covers.
constexpr int kPlayerSideCount = 2;

// The judgement grades a note — or an individual slide point — resolves to.
enum JudgeGrade {
    kJudgeGradeJust = 0,
    kJudgeGradeGreat = 1,
    kJudgeGradeGood = 2,
    kJudgeGradeMiss = 3,
    kJudgeGradeCount = 4,
};

// The per-grade base-score weights, the just-reflec weight, and the low-miss bonuses that together
// make up a side's final score.
constexpr int kScoreJust = 3;
constexpr int kScoreGreat = 2;
constexpr int kScoreGood = 1;
constexpr int kScoreJustReflec = 10;
constexpr int kNoMissBonus = 50;
constexpr int kOneMissBonus = 25;
constexpr int kTwoMissBonus = 10;

// The miss tallies the three low-miss bonuses key on.
constexpr int kNoMisses = 0;
constexpr int kOneMiss = 1;
constexpr int kTwoMisses = 2;

// The note type whose judgement lives on its slide points rather than on the note itself.
constexpr int kSlideNoteType = 3;

// The play-record cells the persisted score and the replay header read.
constexpr unsigned int kRecordScoreCell = 0;
constexpr unsigned int kRecordComboCell = 1;
constexpr unsigned int kRecordJustCell = 3;
constexpr unsigned int kRecordGreatCell = 4;
constexpr unsigned int kRecordGoodCell = 5;
constexpr unsigned int kRecordMissCell = 6;
constexpr unsigned int kRecordJustReflecCell = 7;

// The highest legitimate stored rate: a record above it is treated as tampered and overwritten.
constexpr float kMaxStoredRate = 1.0f;

// The tutorial song's sentinel identifier, whose play is never written back to the store.
constexpr int kTutorialMusicId = 999999998;

// The judgement a replay note carries for a note the opposing side's ghost shot resolved.
constexpr int kGhostShotJudge = 5;
} // namespace

/** @ghidraAddress 0x14b3e8 */
void GameScene::RunPlayStateMachineDispatch(int nDeltaFrames) {
    NoteEffectMgr::shared()->ClearNotePositionCache();
    CheckAutoPauseByNotePosition();
    // While the pause gauge holds the game paused the applied delta is zero, freezing the play.
    const int nAppliedDelta = RefreshPauseGaugeAndGetActiveFlag() ? nDeltaFrames : 0;
    m_nPlayTime += nAppliedDelta;

    switch (m_nState) {
    case kStateInit:
        m_flFirstPathSpeed = 0.0f;
        InitializePlayFieldLayersForTheme();
        m_nState = kStateResetPlayback;
        m_nPlayTime = 0;
        break;
    case kStateRestartPlayback:
        m_nState = kStateResetPlayback;
        m_nPlayTime = 0;
        break;
    case kStateResetPlayback:
        // The state the exit transitions land on: it resets note playback without a ghost.
        ResetNotePlaybackState(false);
        break;
    case kStateBindChart:
        m_nState = kStateChartBound;
        m_nPlayTime = 0;
        break;
    case kStateChartBound:
        AdvanceToPlayReadyState();
        break;
    case kStatePlayReady:
        WaitForIntroThenStartNotes();
        break;
    case kStateWaitNotes:
        StartGameplayPresentation();
        break;
    case kStatePastEffect:
        // The event effect holds the presentation back until it has finished animating.
        if (!EventEffectLayer::shared()->IsEffectActive()) {
            m_nState = kStateWaitNotes;
            m_nPlayTime = 0;
        }
        break;
    case kStatePresenting:
        BeginMusicPlaybackAndTimer();
        break;
    case kStateNotePlay:
        ExecMain();
        break;
    case kStatePlayFinished:
        EnterResultThemeState();
        break;
    case kStateResultTheme:
        LoadResultScreenAndMusic();
        break;
    case kStateResultSubmit:
        FinalizeResultAndSubmitScore(nAppliedDelta);
        break;
    case kMusicReleaseState:
        ExitToMusicList();
        break;
    case kPauseExitState:
        ReloadMusicForRestart();
        break;
    case kStatePreviewSetup:
        SetupPreviewPlayback();
        break;
    case kStatePlaying:
        AdvancePreviewPlaybackFrame(nAppliedDelta);
        break;
    case kStatePreviewResume:
        ResumePreviewPlayback();
        break;
    case kGameSceneState13:
    case kStatePreviewExit:
        ClosePreviewAndReturnToList();
        break;
    default:
        // State 9 and anything above the last preview state have no handler.
        break;
    }

    RenderAllPlayFieldLayers(nAppliedDelta);
    // The retrigger timer takes the raw delta, not the pause-gated one.
    ShotSoundManager::GetInstance()->UpdateRetriggerTimer(static_cast<float>(nDeltaFrames));
}

/** @ghidraAddress 0x14ba48 */
void GameScene::ExecMain() {
    PlayTimer::shared()->Update();
    NoteEffectMgr::shared()->ProcessActiveNotes();
    ActivateDueNotes();

    // Hold the play open while the theme's full-combo effect is still animating.
    switch (m_nThema) {
    case kThemaColette:
        if (FullComboColetteLayer::shared()->IsAnyEffectActive()) {
            return;
        }
        break;
    case kThemaLimelight:
        if (FullComboLimelightLayer::shared()->IsAnyEffectActive()) {
            return;
        }
        break;
    case kThemaClassic:
        if (FullComboClassicLayer::shared()->IsAnyEffectActive()) {
            return;
        }
        break;
    default:
        break;
    }

    // Wait until the play clock's scroll line has run past the chart's end.
    const int nChartEndTime = m_pMusicSheet->GetChartEndTime();
    const float flScrollLine =
        PlayTimer::shared()->GetPlayTime() * kNoteLineScale + kNoteSpawnLookahead;
    if (flScrollLine <= static_cast<float>(nChartEndTime)) {
        return;
    }

    StopBgmAndAllowRotation();
    ReleaseBgmAndVoice();
    ScoreTracker::shared()->ComputeLaneClearRateAndGrade();

    // A network match never scores or banks a replay; it goes straight to the winner's voice cue.
    if (GameSystem::GetGameSystem()->GetGameType() != kGameTypeNetworkMatch) {
        // Pick the theme's win, lose, or draw voice cue.
        int nVoiceCue = kVoiceCueTitle;
        switch (m_nThema) {
        case kThemaColette:
            nVoiceCue = kVoiceCueWin;
            if (ScoreTracker::shared()->GetPlayRecordRate(kResultSide) < kClearRateThreshold) {
                // The tutorial always hears the clear cue, however it went.
                nVoiceCue = [RBTutorialManager isTutorialPlay] ? kVoiceCueWin : kVoiceCueLose;
            }
            break;
        case kThemaLimelight:
            nVoiceCue =
                (ScoreTracker::shared()->GetPlayRecordRate(kResultSide) < kClearRateThreshold) ?
                    kVoiceCueLose :
                    kVoiceCueWin;
            break;
        case kThemaClassic:
            nVoiceCue = kVoiceCueWin;
            if (ScoreTracker::shared()->GetPlayRecordField10(kResultSide) != kMatchResultWin) {
                nVoiceCue = (ScoreTracker::shared()->GetPlayRecordField10(kResultSide) ==
                             kMatchResultLose) ?
                                kVoiceCueLose :
                                kVoiceCueDraw;
            }
            break;
        default:
            break;
        }
        SoundEffectManager::GetInstance()->LoadThemedVoiceData(nVoiceCue);

        GameSystem *pGameSystem = GameSystem::GetGameSystem();
        if (pGameSystem->GetUserFullCombo() || pGameSystem->GetCpuFullCombo() ||
            pGameSystem->GetFullJustReflec()) {
            m_nState = kStatePlayFinished;
            m_nPlayTime = 0;
            return;
        }

        // Only a real (non-preview, non-tutorial) song's play is banked and reported.
        bool bComputeBonuses = false;
        const int nMusicId = AppDelegate.appDelegate.musicData.MusicID;
        if (nMusicId >= kFirstScoredMusicId &&
            AppDelegate.appDelegate.musicData.MusicID <= kLastScoredMusicId) {
            PersistScoreAndSaveReplay();
            (void)NSDate.date; // Yes, the binary discards this call's result.
            ReportTotalScoreToGameCenter();
            bComputeBonuses = true;
        } else if (AppDelegate.appDelegate.musicData.MusicID == kTutorialMusicId) {
            bComputeBonuses = true;
        }
        if (bComputeBonuses) {
            ComputeResultBonusesAndExperience();
            m_nState = kStatePlayFinished;
            m_nPlayTime = 0;
            return;
        }
        // A song outside both windows falls through to the network match's winner-cue path.
    }

    // Republish the stored level and experience with nothing gained, and clear the new-record flag.
    GameSystem *pGameSystem = GameSystem::GetGameSystem();
    LevelTables *pTables = LevelTables::GetInstance();
    pGameSystem->SetResultLevelExp(pTables->GetCurrentLevel(), pTables->GetCurrentExp(), 0);
    pGameSystem->SetNewRecord(false);

    // Cue the winning side's colour voice: the player's own colour when they won, the opponent's
    // when they lost, and the draw cue otherwise.
    const int nPlayColor = GameSystem::GetGameSystem()->GetPlayColor();
    const int nResult = ScoreTracker::shared()->GetPlayRecordField10(kResultSide);
    int nWinnerCue = kVoiceCueDraw;
    if (nResult != kMatchResultDraw) {
        if (nResult == kMatchResultLose) {
            nWinnerCue = (nPlayColor == kPlayColorBlue) ? kVoiceCueRedWin : kVoiceCueBlueWin;
        } else if (nResult == kMatchResultWin) {
            nWinnerCue = (nPlayColor != kPlayColorBlue) ? kVoiceCueRedWin : kVoiceCueBlueWin;
        } else {
            assert(0);
        }
    }
    SoundEffectManager::GetInstance()->LoadThemedVoiceData(nWinnerCue);

    m_nState = kStatePlayFinished;
    m_nPlayTime = 0;
}

/** @ghidraAddress 0x14cf5c */
void GameScene::RenderAllPlayFieldLayers(int nDeltaFrames) {
    // Until the chart's first path speed is known the play field is fully lit; after that the fade
    // level tracks the fractional part of the note path at the current scroll line.
    float flFadeLevel = 1.0f;
    if (m_flFirstPathSpeed > 0.0f) {
        const float flScrollLine =
            PlayTimer::shared()->GetPlayTime() * kNoteLineScale + kNoteSpawnLookahead;
        const float flPathValue =
            NoteEffectMgr::shared()->EvaluateNotePathAtTime(static_cast<int>(flScrollLine));
        // A negative path value fades in from the negative-zero base instead of down from one.
        const float flBase = (flPathValue < 0.0f) ? kFadeInBase : 1.0f;
        flFadeLevel = flBase - (flPathValue - static_cast<float>(static_cast<int>(flPathValue)));
        if (flFadeLevel < 0.0f) {
            flFadeLevel = 0.0f;
        } else if (flFadeLevel > 1.0f) {
            flFadeLevel = 1.0f;
        }
    }
    ReflecGaugeLayer::shared()->SetGaugeDisplayBrightness(flFadeLevel);
    ThemaMarkerLayer::shared()->SetDangerLevel(flFadeLevel);
    PlayColorLayer::shared()->SetGaugeFillLevel(flFadeLevel);
    ScoreTracker::shared()->TickGaugeState();

    const float flDelta = static_cast<float>(nDeltaFrames);
    PlayerFieldLayer::shared()->Update(flDelta);
    JudgeEffectLayer::shared()->RenderJudgeScoreEffect(flDelta);
    BgLayer::GetBackgroundLayer()->ProcessBackgroundLayer(flDelta);
    ReflecGaugeLayer::shared()->UpdateGaugeBar(flDelta);
    ClearGaugeLayer::shared()->Process(flDelta);
    ThemaMarkerLayer::shared()->RefreshMarkerAlpha(flDelta);
    PlayColorLayer::shared()->Update(flDelta);
    BoundsEffectLayer::shared()->Process(flDelta);
    ExplosionEffectLayer::shared()->Process(flDelta);
    NoteBornLayer::shared()->RenderScoreGaugeEffects(flDelta);
    NoteResultLayer::shared()->Update(flDelta);
    LongNoteLayer::shared()->BuildLongNoteConnectorSprites(flDelta);
    NoteTrailLayer::shared()->Update(flDelta);
    SlideNoteLayer::shared()->Update(flDelta);
    SlideNoteResultLayer::shared()->Update(flDelta);
    NoteChargeLayer::shared()->Update(flDelta);
    NoteLayer::shared()->Update(flDelta);
    // The frame delta is set up for this call too, but the chain layer takes no argument: it
    // overwrites the register from the game system before ever reading it.
    ChainConnectorLayer::shared()->Update();
    DamageEffectLayer::shared()->Process(flDelta);
    NoteGlowLayer::shared()->Process(flDelta);
    if (IsPad()) {
        AltFrameLayer::shared()->Process(flDelta);
    } else {
        MainFrameLayer::shared()->Process(flDelta);
    }

    switch (m_nThema) {
    case kThemaColette:
        FullComboColetteLayer::shared()->Update(flDelta);
        NumberLayer::shared()->Process(flDelta);
        ColetteThemeLayer::shared()->Update(flDelta);
        ResultWindowColetteLayer::shared()->Update(flDelta);
        EventEffectLayer::shared()->Update(flDelta);
        if (GameSystem::GetGameSystem()->GetMenuTutorialActive() != 0) {
            TutorialGuideLayer::shared()->Update(flDelta);
        }
        break;
    case kThemaLimelight:
        FullComboLimelightLayer::shared()->Update(flDelta);
        LimelightEffectLayer::shared()->UpdateEffect(flDelta);
        LimelightThemeLayer::shared()->UpdateGradeDisplay(flDelta);
        LimelightResultLayer::shared()->Update(flDelta);
        EventEffectLayer::shared()->Update(flDelta);
        break;
    case kThemaClassic:
        FullComboClassicLayer::shared()->Update(flDelta);
        BackgroundSpriteManager::shared()->Update(flDelta);
        ClassicThemeLayer::shared()->Update(flDelta);
        ResultWindowClassicLayer::shared()->Update(flDelta);
        break;
    default:
        break;
    }

    FadeOverlayLayer::shared()->Render(flDelta);
}

/** @ghidraAddress 0x14a298 */
void GameScene::InitializePlayFieldLayersForTheme() {
    // Re-read the active theme only when the user has changed it since the last play.
    if (m_nThema != static_cast<int>(RBUserSettingData.sharedInstance.thema)) {
        m_nThema = static_cast<int>(RBUserSettingData.sharedInstance.thema);
    }

    BgLayer::GetBackgroundLayer()->InitializeBackgroundLayer();
    // The iPad draws the alternate play-field frame; every other device draws the main frame.
    if (IsPad()) {
        AltFrameLayer::shared()->BuildSprites();
    } else {
        MainFrameLayer::shared()->BuildSprites();
    }
    PlayerFieldLayer::shared()->CreateScoreNumberSpriteBatch();
    JudgeEffectLayer::shared()->LoadJudgeEffectSprites();
    ThemaMarkerLayer::shared()->LoadThemaMarkerSprites();
    PlayColorLayer::shared()->BuildGaugePartsSpriteBatches();
    ReflecGaugeLayer::shared()->CreateGaugeSliderSprites();
    ClearGaugeLayer::shared()->CreateSprites();
    NoteBornLayer::shared()->LoadSprites();
    ChainConnectorLayer::shared()->CreateSprites();
    LongNoteLayer::shared()->LoadSprites();
    NoteLayer::shared()->CreateSpriteBatches();
    NoteTrailLayer::shared()->LoadNoteTrailSprites();
    SlideNoteLayer::shared()->BuildSprites();
    SlideNoteResultLayer::shared()->BuildSpriteBatch();
    NoteChargeLayer::shared()->LoadNoteChargeSprites();
    DamageEffectLayer::shared()->InitializeSprites();
    BoundsEffectLayer::shared()->InitializeSprites();
    NoteResultLayer::shared()->CreateSpriteInstancer();
    ExplosionEffectLayer::shared()->InitializeSprites();
    NoteGlowLayer::shared()->InitializeSprites();

    switch (m_nThema) {
    case kThemaColette:
        FullComboColetteLayer::shared()->InitializeBackgroundSpriteLayers();
        NumberLayer::shared()->InitializeNumberLayer();
        ColetteThemeLayer::shared()->CreateFcEffectSprites();
        ResultWindowColetteLayer::shared()->InitializeResultWindowSprites();
        EventEffectLayer::shared()->CreateEventEffectSprites();
        TutorialGuideLayer::shared()->BuildTutorialGuideSpriteTable();
        break;
    case kThemaLimelight:
        FullComboLimelightLayer::shared()->LoadTexturesAndBatchesForLimelightLayer();
        LimelightEffectLayer::shared()->InitializeBackgroundSprites();
        LimelightThemeLayer::shared()->InitFullComboLayerTextures();
        LimelightResultLayer::shared()->InitializePhoneSpriteInstancers();
        EventEffectLayer::shared()->CreateEventEffectSprites();
        break;
    case kThemaClassic:
        FullComboClassicLayer::shared()->InitializeBackgroundSprites();
        BackgroundSpriteManager::shared()->BuildBackgroundSpriteNodes();
        ClassicThemeLayer::shared()->InitializeBackgroundSceneNodes();
        ResultWindowClassicLayer::shared()->InitSpriteSetsLazy();
        break;
    default:
        break;
    }

    FadeOverlayLayer::shared()->EnsureInstancer();
    (void)ScoreTracker::shared(); // Yes, the binary discards this call's result.

    // The pause gauge is built once and left registered for the scene's lifetime.
    if (m_pPauseGauge == nullptr) {
        m_pPauseGauge = new PauseGaugeLayer();
        m_pPauseGauge->InsertSorted(kPauseGaugeListenerPriority);
    }
}

/** @ghidraAddress 0x14d600 */
void GameScene::PersistScoreAndSaveReplay() {
    NSManagedObjectContext *context = RBCoreDataManager.sharedInstance.managedObjectContext;
    GameSystem *pGameSystem = GameSystem::GetGameSystem();
    MusicData *pMusicData = AppDelegate.appDelegate.musicData;
    const int nMusicId = pMusicData.MusicID;
    ScoreData *record = [ScoreData getScoreData:static_cast<unsigned int>(nMusicId)
                         inManagedObjectContext:context];
    ScoreTracker *pTracker = ScoreTracker::shared();

    const int nPlaySide = pGameSystem->GetPlayColor();
    const int nNoteCount = m_pMusicSheet->GetNoteCount();
    const int nSideNoteCount = m_pMusicSheet->GetChartNoteCount(nPlaySide);
    // A perfect play scores three per note plus ten per just-reflec opportunity, over the no-miss
    // bonus.
    const int nMaxScore = m_pMusicSheet->GetJustReflecQuota() * kScoreJustReflec + kNoMissBonus +
                          nSideNoteCount * kScoreJust;

    // Tally both sides' judgements, counting a slide note's points individually.
    int aJudgeCounts[kPlayerSideCount][kJudgeGradeCount] = {};
    for (int nIndex = 0; nIndex < nNoteCount; ++nIndex) {
        NoteModel *pNote = NoteEffectMgr::shared()->FindNoteByIndex(nIndex);
        const int nSide = pNote->GetSide();
        if (pNote->GetType() == kSlideNoteType) {
            for (int nPoint = 0; nPoint < pNote->GetSlidePointCount(); ++nPoint) {
                // The binary does not range-check a slide point's grade the way it does a note's.
                ++aJudgeCounts[nSide][pNote->GetSlidePointJudge(nPoint)];
            }
        } else {
            const int nGrade = pNote->GetJudgeGrade();
            if (nGrade >= 0 && nGrade < kJudgeGradeCount) {
                ++aJudgeCounts[nSide][nGrade];
            }
        }
    }

    // Each side's just-reflec count comes from the tracker, whose side index is "is this my side".
    int aJustReflecCounts[kPlayerSideCount] = {};
    for (int nSide = 0; nSide < kPlayerSideCount; ++nSide) {
        aJustReflecCounts[nSide] = pTracker->GetPlayRecordCell(
            static_cast<unsigned int>(nSide == nPlaySide), kRecordJustReflecCell);
    }

    // Fold each side's tallies into its base score.
    int aBaseScores[kPlayerSideCount] = {};
    for (int nSide = 0; nSide < kPlayerSideCount; ++nSide) {
        int nMissBonus = 0;
        switch (aJudgeCounts[nSide][kJudgeGradeMiss]) {
        case kNoMisses:
            nMissBonus = kNoMissBonus;
            break;
        case kOneMiss:
            nMissBonus = kOneMissBonus;
            break;
        case kTwoMisses:
            nMissBonus = kTwoMissBonus;
            break;
        default:
            break;
        }
        aBaseScores[nSide] = nMissBonus + aJudgeCounts[nSide][kJudgeGradeJust] * kScoreJust +
                             aJudgeCounts[nSide][kJudgeGradeGreat] * kScoreGreat +
                             aJudgeCounts[nSide][kJudgeGradeGood] * kScoreGood +
                             aJustReflecCounts[nSide] * kScoreJustReflec;
    }

    // Read the stored best for the played difficulty's columns.
    NSNumber *storedScore = nil;
    NSNumber *storedRate = nil;
    switch (pGameSystem->GetDifficulty()) {
    case kDifficultyMedium:
        storedScore = record.scoMed;
        storedRate = record.arMed;
        break;
    case kDifficultyHard:
        storedScore = record.scoHar;
        storedRate = record.arHar;
        break;
    default:
        // Basic and Special share the basic columns.
        storedScore = record.scoBas;
        storedRate = record.arBas;
        break;
    }
    const int nStoredScore = storedScore.intValue;
    const float flStoredRate = storedRate.floatValue;

    // The recorded score is the smallest of what the tracker banked, what the tally computes, and
    // what the chart can award.
    int nFinalScore = pTracker->GetPlayRecordCell(kResultSide, kRecordScoreCell);
    if (nFinalScore > aBaseScores[nPlaySide]) {
        nFinalScore = aBaseScores[nPlaySide];
    }
    if (nFinalScore > nMaxScore) {
        nFinalScore = nMaxScore;
    }

    // Store it when the play beat the stored best, or when the stored best exceeds what the chart
    // can award (a tampered record).
    bool bDirty = false;
    if (nStoredScore > nMaxScore || nFinalScore > nStoredScore) {
        pGameSystem->SetNewRecord(true);
        switch (pGameSystem->GetDifficulty()) {
        case kDifficultyMedium:
            record.scoMed = @(nFinalScore);
            break;
        case kDifficultyHard:
            record.scoHar = @(nFinalScore);
            break;
        default:
            record.scoBas = @(nFinalScore);
            break;
        }
        bDirty = true;
    } else {
        pGameSystem->SetNewRecord(false);
    }

    // The rate and its rank follow the same rule against the stored rate.
    const float flRate = pTracker->GetPlayRecordRate(kResultSide);
    if (flStoredRate > kMaxStoredRate || flRate > flStoredRate) {
        const int nRank = pTracker->GetPlayRecordRank(kResultSide);
        switch (pGameSystem->GetDifficulty()) {
        case kDifficultyMedium:
            record.arMed = @(flRate);
            record.raMed = @(nRank);
            break;
        case kDifficultyHard:
            record.arHar = @(flRate);
            record.raHar = @(nRank);
            break;
        default:
            record.arBas = @(flRate);
            record.raBas = @(nRank);
            break;
        }
        bDirty = true;
    }

    // A side whose every note was judged is a full combo. This never dirties the record on its own.
    if (pTracker->IsSideAllNotesJudged(kResultSide)) {
        switch (pGameSystem->GetDifficulty()) {
        case kDifficultyMedium:
            record.fcMed = @YES;
            break;
        case kDifficultyHard:
            record.fcHar = @YES;
            break;
        default:
            record.fcBas = @YES;
            break;
        }
    }

    // Re-stamp the tamper hash only when a stored value actually changed.
    if (bDirty) {
        record.chksco = [ScoreData hashScore:record];
    }
    record.lastPlayDate = NSDate.date;
    switch (pGameSystem->GetDifficulty()) {
    case kDifficultyMedium:
        record.pcMed = @(record.pcMed.longLongValue + 1);
        break;
    case kDifficultyHard:
        record.pcHar = @(record.pcHar.longLongValue + 1);
        break;
    default:
        record.pcBas = @(record.pcBas.longLongValue + 1);
        break;
    }

    // The tutorial song's play is never written back to the store.
    if (pMusicData.MusicID != kTutorialMusicId) {
        NSError *error = nil;
        if (![context save:&error]) {
            NSArray *detailedErrors = error.userInfo[NSDetailedErrorsKey];
            for (NSError *detail in detailedErrors) {
                // The binary walks the detailed errors without acting on any of them.
                (void)detail;
            }
        }
    }

    // Write a replay ghost when this tune and difficulty has none yet, or the play set a record.
    if (![ReplayData isExistReplayData:nMusicId difficulty:pGameSystem->GetDifficulty()] ||
        pGameSystem->IsNewRecord()) {
        ReplayData *replay = [[ReplayData alloc] init];
        replay.tuneID = @(static_cast<unsigned int>(nMusicId));
        replay.diff = @(pGameSystem->GetDifficulty());
        replay.seed = @(pGameSystem->GetRandSeed());
        replay.cntNote = @(nSideNoteCount);
        replay.score = @(pTracker->GetPlayRecordCell(kResultSide, kRecordScoreCell));
        replay.cntCom = @(pTracker->GetPlayRecordCell(kResultSide, kRecordComboCell));
        replay.cntJust = @(pTracker->GetPlayRecordCell(kResultSide, kRecordJustCell));
        replay.cntGreat = @(pTracker->GetPlayRecordCell(kResultSide, kRecordGreatCell));
        replay.cntGood = @(pTracker->GetPlayRecordCell(kResultSide, kRecordGoodCell));
        replay.cntMiss = @(pTracker->GetPlayRecordCell(kResultSide, kRecordMissCell));
        replay.cntJR = @(pTracker->GetPlayRecordCell(kResultSide, kRecordJustReflecCell));
        // The replay header keeps the rate truncated to a whole number.
        replay.ar = @(static_cast<int>(pTracker->GetPlayRecordRate(kResultSide)));
        replay.playDate = NSDate.date;
        replay.user = AppDelegate.getServerData[0];

        NSMutableArray<ReplayNote *> *notes =
            [[NSMutableArray alloc] initWithCapacity:nSideNoteCount];
        for (int nIndex = 0; nIndex < nNoteCount; ++nIndex) {
            NoteModel *pNote = NoteEffectMgr::shared()->FindNoteByIndex(nIndex);
            if (pNote->GetSide() == nPlaySide) {
                ReplayNote *note = [[ReplayNote alloc] init];
                note.index = @(nIndex);
                note.type = @(pNote->GetType());
                note.judge = @(pNote->GetJudgeGrade());
                note.jr = @NO;
                note.longrate = @(pNote->GetShotProgress());
                if (pNote->GetType() == kSlideNoteType) {
                    NSMutableArray<ReplayNote *> *points =
                        [[NSMutableArray alloc] initWithCapacity:pNote->GetSlidePointCount()];
                    for (int nPoint = 0; nPoint < pNote->GetSlidePointCount(); ++nPoint) {
                        ReplayNote *point = [[ReplayNote alloc] init];
                        point.index = @(nPoint);
                        point.judge = @(pNote->GetSlidePointJudge(nPoint));
                        [points addObject:point];
                    }
                    note.slide = [points copy];
                }
                [notes addObject:note];
            } else if (pNote->IsShotResolved()) {
                // The opposing side contributes only the notes its ghost shot resolved.
                ReplayNote *note = [[ReplayNote alloc] init];
                note.index = @(nIndex);
                note.judge = @(kGhostShotJudge);
                note.jr = @(pNote->IsShotResolved());
                [notes addObject:note];
            }
        }
        replay.replay = [notes copy];
        [ReplayData saveReplayData:replay];
    }
}

/** @ghidraAddress 0x14ef34 */
void ReportTotalScoreToGameCenter(void) {
    // Skip entirely when Game Center is disabled for this build/device.
    if (!GetHasGameCenterFlag()) {
        return;
    }
    // Report only when the local player is authenticated.
    if (!GKLocalPlayer.localPlayer.isAuthenticated) {
        return;
    }

    const long long nTotalScore = [ScoreData totalScore];
    GKScore *score =
        [[GKScore alloc] initWithLeaderboardIdentifier:[AppDelegate totalScoreLeaderboardCategory]];
    score.value = nTotalScore;
    [GKScore reportScores:@[ score ]
        withCompletionHandler:^(NSError *_Nullable error){
            /** @ghidraAddress 0x35da80 */
            // A global no-op completion block; the report result is ignored.
        }];
}

} // namespace rb
