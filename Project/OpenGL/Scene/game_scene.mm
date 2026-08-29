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
#include "just_reflec_effect_layer.h"
#include "leveltables.h"
#include "limelight_effect_layer.h"
#include "limelight_result_layer.h"
#include "limelight_theme_layer.h"
#include "long_note_layer.h"
#include "main_frame_layer.h"
#include "music_sheet.h"
#include "neDebugLog.h"
#include "neRender.h"
#include "neTexture.h"
#include "note_born_layer.h"
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
#include "shotsoundmanager.h"
#include "slide_note_layer.h"
#include "slide_note_result_layer.h"
#include "soundeffectmanager.h"
#include "thema_marker_layer.h"
#include "touch_point.h"
#include "touchmanager.h"
#include "tutorial_guide_layer.h"

namespace {

constexpr int kInitialMode = 2;

constexpr int kAlternatePlayMode = 1;

// Each set bit is a state index whose scene ignores a pause request.
constexpr int kStateBound = 0x14;
constexpr unsigned int kIgnorePauseStateMask = 0xd7c03;
constexpr int kActivePlayState = 0x11;

constexpr int kSoundEffectDecide = 1;

constexpr float kSceneFadeDuration = 1000.0f;

constexpr int kPauseExitState = 0xe;
constexpr int kMusicReleaseState = 0xd;
constexpr int kGameSceneState13 = 0x13;

constexpr int kStateWaitNotes = 5;
constexpr int kStatePastEffect = 6;

constexpr int kStatePlaying = 0x11;

constexpr int kStateResultTheme = 0xb;

constexpr int kStatePresenting = 7;
constexpr int kIntroVoiceCue = 2;
constexpr float kPresentationFadeInDuration = 1000.0f; // @ghidraAddress 0x2f8540

constexpr int kStateNotePlay = 8;

constexpr int kStateResetPlayback = 1;
constexpr int kExitDelay = 0x5dc;

constexpr int kStateBindChart = 2;
constexpr int kGhostStyleReplay = 1;

constexpr int kStatePlayReady = 4;
constexpr float kGaugeGrowFromValue = 450.0f; // @ghidraAddress 0x308dd8

constexpr int kResultVoiceCue = 0x13;
constexpr int kClearCueSoundEffect = 8;
constexpr float kClearRateThreshold = 0.7f; // @ghidraAddress 0x2fd008

constexpr int kThemaClassic = 0;
constexpr int kThemaLimelight = 1;
constexpr int kThemaColette = 2;

constexpr int kResultTextSlot0 = 2;
constexpr int kResultTextSlot1 = 3;
constexpr int kResultTextSlot2 = 4;

constexpr int kResultVoiceId = 2;

constexpr unsigned int kResultSide = 1;

constexpr int kDifficultyBasic = 0;
constexpr int kDifficultyMedium = 1;
constexpr int kDifficultyHard = 2;
constexpr int kDifficultySpecial = 3;

constexpr unsigned int kMissCell = 6;
constexpr int kMissFullCombo = 0;
constexpr int kMissOne = 1;
constexpr int kMissTwo = 2;

constexpr int kMinClearRank = 2;

constexpr int kRankB = 1;
constexpr int kRankA = 2;
constexpr int kRankAA = 3;
constexpr int kRankAAA = 4;
constexpr int kRankAAAP = 5;

constexpr int kPastelBonusNormal = 1;
constexpr int kPastelBonusBlack = 2;

constexpr unsigned int kNoLevelThreshold = 0xffffffff;

constexpr float kNoteLineScale = 1000.0f;       // @ghidraAddress 0x2f8540
constexpr float kNoteSpawnLookahead = -1500.0f; // @ghidraAddress 0x308b60

constexpr unsigned int kNoteHasPairFlag = 1u << 3;

constexpr int kHeadNoteStartTime = -1;
constexpr int kNotDueScanLimit = 10;

struct SharedResultBonuses {
    float flClear = 0.0f;
    float flMiss = 0.0f;
    float flRank = 0.0f;
    float flFirstPlay = 0.0f; // Includes the pastel-field bonus when one applies.
};

SharedResultBonuses
ComputeSharedResultBonuses(GameSystem *pGameSystem, ScoreTracker *pTracker, RBBonusData *pBonus) {
    SharedResultBonuses out;

    if (pTracker->GetPlayRecordRank(kResultSide) >= kMinClearRank) {
        out.flClear = pBonus.clearBonus;
    }

    const int nMisses = pTracker->GetPlayRecordCell(kResultSide, kMissCell);
    if (nMisses == kMissTwo) {
        out.flMiss = pBonus.miss2Bonus;
    } else if (nMisses == kMissOne) {
        out.flMiss = pBonus.miss1Bonus;
    } else if (nMisses == kMissFullCombo) {
        out.flMiss = pBonus.fullComboBonus;
    }

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

// Only the iPad's single-player game types (0 and 2) take the full-detail sheet.
bool UsesFullDetailSheet(GameSystem *pGameSystem) {
    return IsPad() && (pGameSystem->GetGameType() | 2) == 2;
}

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
    m_nState = 0;
    m_nPlayTime = 0;
    m_nMode = kInitialMode;
}

/** @ghidraAddress 0x12ee88 */
void GameScene::GetInstance(GameScene **ppOut) {
    if (*ppOut == nullptr) {
        GameScene *pScene = new GameScene();
        pScene->InsertSorted(1);
        *ppOut = pScene;
    }
}

/** @ghidraAddress 0x14aff8 */
void GameScene::AdvanceGameSceneStateFrom11() {
    if (m_nState == kActivePlayState) {
        m_nState = kActivePlayState + 1;
        m_nPlayTime = 0;
    }
}

/** @ghidraAddress 0x14afec */
void GameScene::SetGameSceneState13() {
    m_nState = kGameSceneState13;
    m_nPlayTime = 0;
}

/** @ghidraAddress 0x14a510 */
void GameScene::ClearLayerStateField() {
    m_nState = 0;
    m_nPlayTime = 0;
}

namespace {

// @ghidraAddress 0x2fd008
constexpr float kThemedScorePosition = 0.70f;
constexpr float kDefaultScorePosition = 1.0f;

constexpr int kSideLeft = 0;
constexpr int kSideRight = 1;

constexpr int kGameTypeSingle = 0;
constexpr int kGameTypeVersus = 1;
constexpr int kGameTypeReplay = 2;

constexpr int kThemaClassic = 0;
constexpr int kThemaLimelight = 1;
constexpr int kThemaColette = 2;

constexpr int kModeNormal = 0;

// @ghidraAddress 0x308de0 and 0x308dec
constexpr int kSheetRadiusPhone[] = {96, 80, 68};
constexpr int kSheetRadiusPad[] = {72, 62, 52};

// The binary indexes this table though every entry maps to itself.
// @ghidraAddress 0x308df8
constexpr int kPlayColorByDifficulty[] = {0, 1, 2, 3};

constexpr float kPresentationDelay = 500.0f;
constexpr float kIntroSecondDelay = 700.0f;
constexpr float kReadyDelay = 2500.0f;

constexpr float kEffectShown = 1.0f;
constexpr float kEffectHidden = 0.0f;

} // namespace

/** @ghidraAddress 0x14a518 */
void GameScene::Init() {
    (void)ne::C_TEXTURE::GetCacheList(); // Yes, the binary discards this call's result.
    ne::C_TEXTURE::ReloadAll();

    // The Colette layers are absent from this sweep in the binary.
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
    JustReflecEffectLayer::shared()->RefreshThema();
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
    // The binary refreshes these layers a second time.
    BgLayer::GetBackgroundLayer()->RefreshThema();
    AltFrameLayer::shared()->RefreshThema();
    MainFrameLayer::shared()->RefreshThema();
    ExplosionEffectLayer::shared()->RefreshThema();
    BoundsEffectLayer::shared()->SetStyle();
    EventEffectLayer::shared()->RefreshThema();
    TutorialGuideLayer::shared()->RefreshThema();

    GameSystem *pGameSystem = GameSystem::GetGameSystem();
    const int nGameType = pGameSystem->GetGameType();

    const float flScorePosition = (m_nThema == kThemaColette || m_nThema == kThemaLimelight) ?
                                      kThemedScorePosition :
                                      kDefaultScorePosition;
    PlayerFieldLayer::shared()->SetScorePosition(flScorePosition, kSideLeft);
    PlayerFieldLayer::shared()->SetScorePosition(flScorePosition, kSideRight);

    const float flBoundsSize = RBUserSettingData.sharedInstance.boundsEffectSize;
    const float flDamageSize = RBUserSettingData.sharedInstance.damageEffectSize;
    const float flExplosionSize = RBUserSettingData.sharedInstance.explosionEffectSize;
    BoundsEffectLayer::shared()->SetEffectSize(flBoundsSize);
    DamageEffectLayer::shared()->SetEffectSize(flDamageSize);
    ExplosionEffectLayer::shared()->SetEffectSize(flExplosionSize);

    const int nExplosionType = pGameSystem->GetExplosionType();
    ExplosionEffectLayer::shared()->SetEffectType(kSideLeft, nExplosionType);
    ExplosionEffectLayer::shared()->SetEffectType(kSideRight, nExplosionType);

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

    const int *pSheetRadius = IsPad() ? kSheetRadiusPad : kSheetRadiusPhone;
    pGameSystem->SetSheetRadius(static_cast<float>(pSheetRadius[pGameSystem->GetNoteType()]));

    const int nGaugeStyle = RBUserSettingData.sharedInstance.gaugeStyle;
    ReflecGaugeLayer::shared()->SetGaugeStyle(nGaugeStyle);
    ClearGaugeLayer::shared()->SetGaugeStyle(nGaugeStyle);

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
            // The binary reads the same field into both slots.
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
    if (!pGameSystem->GetBgmPlaying()) {
        return;
    }
    pGameSystem->SetBgmPlaying(false);
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
    if (pGameSystem->GetPaused()) {
        return;
    }

    const int nState = m_nState;
    if (nState < kStateBound) {
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

    pGameSystem->SetPaused(true);
    PlayTimer::shared()->MarkPaused(CACurrentMediaTime());
    if (pGameSystem->GetBgmPlaying()) {
        [[RBBGMManager getInstance] PauseMusic:0.0f];
    }
}

/** @ghidraAddress 0x14b5b8 */
void GameScene::CheckAutoPauseByNotePosition() {
    // Bands are in 1024x-scaled screen space; x thresholds are in the 768-wide note space.
    constexpr int kScrollFixedShift = 10;
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
        if (m_pPauseGauge != nullptr) {
            m_pPauseGauge->ClearCharging();
        }
        return true;
    }
    if (!m_bPauseGaugeHeld && m_pPauseGauge != nullptr) {
        m_pPauseGauge->SetCharging();
    }
    return false;
}

/** @ghidraAddress 0x14f0dc */
void GameScene::ComputeResultBonusesAndExperience() {
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

        pGameSystem->SetResultLevelExp(nLevel, nExp, nGained);

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

        pTables->SetLevelExp(nLevel, nExp);
        LevelTables::SavePlayerLevelData(pTables->GetLevelExpRecord());
    }

    if (m_nThema == kThemaLimelight) {
        GameSystem *pGameSystem = GameSystem::GetGameSystem();
        ScoreTracker *pTracker = ScoreTracker::shared();
        RBBonusData *pBonus = RBBonusData.sharedInstance;
        const SharedResultBonuses bonuses =
            ComputeSharedResultBonuses(pGameSystem, pTracker, pBonus);

        RBExperienceData *pExperience = RBExperienceData.sharedInstance;
        const float flExperience = [pExperience getPoint];
        LimelightResultLayer::shared()->SetResultBonuses(
            bonuses.flClear, bonuses.flMiss, bonuses.flRank, bonuses.flFirstPlay, flExperience);

        [pExperience
            addPoint:bonuses.flClear + bonuses.flMiss + bonuses.flRank + bonuses.flFirstPlay];
        [RBExperienceData.sharedInstance save];
    }

    if (m_nThema == kThemaColette) {
        GameSystem *pGameSystem = GameSystem::GetGameSystem();
        ScoreTracker *pTracker = ScoreTracker::shared();
        RBBonusData *pBonus = RBBonusData.sharedInstance;
        const SharedResultBonuses bonuses =
            ComputeSharedResultBonuses(pGameSystem, pTracker, pBonus);

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
    if (m_nThema == kThemaColette) {
        ColetteThemeLayer::shared()->ResetGradeDisplayState();
    } else if (m_nThema == kThemaLimelight) {
        LimelightThemeLayer::shared()->InitializeGradeDisplayState();
    } else if (m_nThema == kThemaClassic) {
        ClassicThemeLayer::shared()->InitializeScoreGaugeState();
    }

    SoundEffectManager::GetInstance()->PlayThemedVoice(kResultVoiceCue);

    if (ScoreTracker::shared()->GetPlayRecordRate(kResultSide) >= kClearRateThreshold ||
        [RBTutorialManager isTutorialPlay]) {
        SoundEffectManager::GetInstance()->PlayThemedSoundEffect(kClearCueSoundEffect);
    }

    m_nState = kStateResultTheme;
    m_nPlayTime = 0;
}

namespace {
constexpr int kResultReadyVoiceCue = 6;
constexpr int kResultVoiceMark = 1000;
constexpr int kResultConfirmSoundEffect = 1;
constexpr float kResultStopMusicFade = 1.5f;
// The status the binary sets once the result is submitted is the music-select tutorial status.
constexpr unsigned int kTutorialResultSeenStatus = RBTutorialStatusMusicSelectSeen;
constexpr unsigned int kTutorialInPlayStatusMax = 0x16;
constexpr unsigned int kSubmitScoreCell = 0;
constexpr unsigned int kSubmitJustReflecCell = 7;
} // namespace

/** @ghidraAddress 0x14c27c */
void GameScene::FinalizeResultAndSubmitScore(int nDeltaFrames) {
    // Fires once, on the frame the play time crosses the mark.
    if (m_nPlayTime > kResultVoiceMark && m_nPlayTime - nDeltaFrames <= kResultVoiceMark) {
        SoundEffectManager::GetInstance()->PlayThemedVoice(kResultReadyVoiceCue);
    }

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
    // step.
    if (GameSystem::GetGameSystem()->GetMenuTutorialActive() &&
        RBTutorialManager.getCurrentStatus <= kTutorialInPlayStatusMax) {
        return;
    }

    SoundEffectManager::GetInstance()->PlayThemedSoundEffect(kResultConfirmSoundEffect);
    [RBBGMManager.getInstance StopMusic:kResultStopMusicFade];
    if (m_nThema == kThemaColette) {
        ResultWindowColetteLayer::shared()->ClearResultConfirmed();
    } else if (m_nThema == kThemaLimelight) {
        LimelightResultLayer::shared()->ClearResultConfirmed();
    } else if (m_nThema == kThemaClassic) {
        ResultWindowClassicLayer::shared()->ClearCustomizeReloadFlag();
    }

    ScoreTracker *pTracker = ScoreTracker::shared();
    const unsigned int nScore = pTracker->GetPlayRecordCell(kResultSide, kSubmitScoreCell);
    const unsigned int nJustReflec =
        pTracker->GetPlayRecordCell(kResultSide, kSubmitJustReflecCell);
    const unsigned int nNotes = static_cast<unsigned int>(pTracker->GetTotalNotes());
    GameSystem *pGameSystem = GameSystem::GetGameSystem();
    const unsigned int nDifficulty = static_cast<unsigned int>(pGameSystem->GetDifficulty());
    MusicData *pMusicData = AppDelegate.appDelegate.musicData;
    const unsigned int nMusicId = static_cast<unsigned int>(pMusicData.MusicID);
    if ((!pGameSystem->GetUserFullCombo() || !pGameSystem->GetCpuFullCombo()) &&
        !pGameSystem->GetFullJustReflec()) {
        [RBServerAPIManager playedV2APIWithMusicID:nMusicId
                                               dif:nDifficulty
                                              note:nNotes
                                                jr:nJustReflec
                                             score:nScore];

        if ([RBUserSettingData.sharedInstance getTutorialStatus:kTutorialResultSeenStatus] == 0) {
            [RBUserSettingData.sharedInstance updateTutorialStatus:kTutorialResultSeenStatus
                                                             value:1];
        }
        if (pGameSystem->GetMenuTutorialActive()) {
            [RBTutorialManager
                updateStatus:static_cast<RBTutorialStatus>(kTutorialResultSeenStatus)];
            // The binary materialises the guide singleton only to destroy it.
            // @ghidraAddress 0x14c53c
            (void)TutorialGuideLayer::shared();
            TutorialGuideLayer::destroyShared();
            pGameSystem->SetMenuTutorialActive(false);
        }
    }

    FadeOverlayLayer::shared()->StartFadeIn(kPresentationFadeInDuration);
    m_nState = kMusicReleaseState;
    m_nPlayTime = 0;
}

namespace {
constexpr int kResultBuildDelay = 500;
constexpr unsigned int kResultInstancerArtwork = 2;
constexpr unsigned int kResultInstancerMusicName = 3;
constexpr unsigned int kResultInstancerArtistName = 4;
constexpr float kResultShowTweenDuration = 500.0f; // @ghidraAddress 0x2feff4
constexpr int kStateResultSubmit = 0xc;
constexpr int kResultVoiceBank = 6;
constexpr unsigned int kTutorialResultStartStatus = 0x13;

// Sentinel music id of the no-song auto-play demo, which loops its background music.
constexpr int kPreviewMusicID = 999999999;
} // namespace

/** @ghidraAddress 0x14bf30 */
void GameScene::LoadResultScreenAndMusic() {
    if (m_nPlayTime <= kResultBuildDelay) {
        return;
    }

    if (m_nThema == kThemaClassic && ClassicThemeLayer::shared()->IsAnimActive()) {
        return;
    }
    if (m_nThema == kThemaLimelight && LimelightThemeLayer::shared()->IsGradeVisible()) {
        return;
    }
    if (m_nThema == kThemaColette && ColetteThemeLayer::shared()->IsGradeVisible()) {
        return;
    }

    GameSystem *pGameSystem = GameSystem::GetGameSystem();
    pGameSystem->LoadArtworkTexture(AppDelegate.appDelegate.musicData);
    pGameSystem->LoadArtistNameTexture(AppDelegate.appDelegate.musicData);

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

    SoundEffectManager::GetInstance()->LoadThemedVoiceData(kResultVoiceBank);
    [RBBGMManager.getInstance LoadMusicResultWithLoop:YES];
    [RBBGMManager.getInstance PlayMusic:0.0f];
    m_nState = kStateResultSubmit;
    m_nPlayTime = 0;

    if (GameSystem::GetGameSystem()->GetMenuTutorialActive()) {
        [RBTutorialManager updateStatus:static_cast<RBTutorialStatus>(kTutorialResultStartStatus)];
        TutorialGuideLayer::shared()->Reset();
    }
}

/** @ghidraAddress 0x14b86c */
void GameScene::StartGameplayPresentation() {
    if (m_nPlayTime <= 0) {
        return;
    }

    SoundEffectManager::GetInstance()->PlayThemedVoice(kIntroVoiceCue);
    if (m_nThema == kThemaColette) {
        NumberLayer::shared()->SetReady();
    } else if (m_nThema == kThemaLimelight) {
        LimelightEffectLayer::shared()->SetActiveAndResetCounter();
    } else if (m_nThema == kThemaClassic) {
        BackgroundSpriteManager::shared()->SetActiveAndResetCounter();
    }

    BgLayer::GetBackgroundLayer()->StartBackgroundFadeIn(kPresentationFadeInDuration);
    PlayerFieldLayer::shared()->StartScoreFadeIn(kPresentationFadeInDuration);
    JudgeEffectLayer::shared()->StartFadeIn(kPresentationFadeInDuration);

    m_nState = kStatePresenting;
    m_nPlayTime = 0;
}

/** @ghidraAddress 0x14b734 */
void GameScene::AdvanceToPlayReadyState() {
    if (static_cast<float>(m_nPlayTime) <= m_flPresentationDelay) {
        return;
    }

    NoteResultLayer::shared()->BuildQuadPositions();

    if (m_bIsPad) {
        AltFrameLayer::shared()->StartFadeIn(kPresentationFadeInDuration);
    } else {
        MainFrameLayer::shared()->BuildGeometry();
        MainFrameLayer::shared()->StartFadeIn(kPresentationFadeInDuration);
    }

    ThemaMarkerLayer::shared()->StartFadeIn(kPresentationFadeInDuration, kGaugeGrowFromValue);
    ThemaMarkerLayer::shared()->RenderThemaMarkerFrame();

    PlayColorLayer::shared()->StartGaugeGrowAnimation(kPresentationFadeInDuration,
                                                      kGaugeGrowFromValue);
    PlayColorLayer::shared()->SyncGaugeValuesFromGameSystem();

    ReflecGaugeLayer::shared()->StartFadeIn(kPresentationFadeInDuration);
    ClearGaugeLayer::shared()->StartFadeIn(kPresentationFadeInDuration);

    m_nState = kStatePlayReady;
    m_nPlayTime = 0;
}

/** @ghidraAddress 0x14b914 */
void GameScene::BeginMusicPlaybackAndTimer() {
    if (IsThemeIntroStillAnimating(m_nThema)) {
        return;
    }

    GameSystem *pGameSystem = GameSystem::GetGameSystem();

    if (!pGameSystem->GetBgmPlaying()) {
        [RBBGMManager.getInstance PlayMusic:0.0f];
        GameSystem::GetGameSystem()->SetBgmPlaying(true);
        [UIViewController attemptRotationToDeviceOrientation];
    }
    PlayTimer::shared()->StartPlayback(CACurrentMediaTime(), true);

    ActivateDueNotes();
    m_flFirstPathSpeed = m_pMusicSheet->GetFirstPathSpeed();

    if (pGameSystem->GetMenuTutorialActive()) {
        TutorialGuideLayer::shared()->Start();
        TutorialGuideLayer::shared()->StartFadeIn();
    }

    m_nState = kStateNotePlay;
    m_nPlayTime = 0;
}

/** @ghidraAddress 0x14d4d8 */
void GameScene::ActivateDueNotes() {
    NoteEffectMgr *pMgr = NoteEffectMgr::shared();
    PlayTimer *pTimer = PlayTimer::shared();

    // The lookahead offset makes notes spawn shortly before they reach the line.
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

        // Only head notes spawn here, and a head paired with a tail waits until its tail is due.
        if (pRecord->GetStartTime() != kHeadNoteStartTime) {
            continue;
        }
        const NoteChainLink &link = pRecord->GetChainLink();
        const bool bHasPair =
            (pRecord->GetFlags() & kNoteHasPairFlag) != 0 && link.GetPartner() != 0;
        if (bHasPair) {
            RbffNoteRecord *pPair = m_pMusicSheet->GetNoteRecordByIndex(link.GetChainId());
            if (static_cast<float>(pPair->GetTimeA()) > flLine) {
                continue;
            }
        }

        pMgr->ActivateNoteByIndex(nIndex);
        if (nNotDue < 1) {
            nLastSpawned = nIndex;
        }
    }

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

    NoteEffectMgr::shared()->ApplyTheme();
    NoteResultLayer::shared()->BuildQuadPositions();

    if (m_bIsPad) {
        AltFrameLayer::shared()->StartFadeIn(0.0f);
    } else {
        MainFrameLayer::shared()->StartFadeIn(0.0f);
        MainFrameLayer::shared()->SetMainFrameEnabled(false);
    }

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

    const bool bHasMusic = [AppDelegate.appDelegate musicData] != nil;
    if (bHasMusic) {
        LoadMusicAndSheet();
    } else {
        BuildChartReaderFromGameSystem();
    }
    m_flFirstPathSpeed = m_pMusicSheet->GetFirstPathSpeed();

    PlayTimer *pTimer = PlayTimer::shared();
    bool bRunning = false;
    if (bHasMusic && !pGameSystem->GetBgmPlaying()) {
        [RBBGMManager.getInstance PlayMusic:0.0f];
        GameSystem::GetGameSystem()->SetBgmPlaying(true);
        [UIViewController attemptRotationToDeviceOrientation];
        bRunning = true;
    }
    pTimer->StartPlayback(CACurrentMediaTime(), bRunning);

    [AppDelegate.appDelegate.viewController showPreview];
    m_nState = kStatePlaying;
    m_nPlayTime = 0;
}

/** @ghidraAddress 0x14ce34 */
void GameScene::ClosePreviewAndReturnToList() {
    ShutdownNoteEffectSystem();

    if ([AppDelegate.appDelegate musicData] != nil) {
        StopBgmAndAllowRotation();
    }
    ResetAllPlayFieldLayers();

    NumberEffectLayer::shared()->StartFadeOut(0.0f);
    NumberEffectLayer::FreeInstance();

    [AppDelegate.appDelegate.viewController hidePreview];
    (void)ne::C_TEXTURE::GetCacheList(); // The binary discards this call's result.
    ne::C_TEXTURE::ReleaseAllHandles();

    m_nState = kStateResetPlayback;
    m_nPlayTime = 0;
}

/** @ghidraAddress 0x14c5bc */
void GameScene::ExitToMusicList() {
    if (m_nPlayTime <= kExitDelay) {
        return;
    }

    ResetAllPlayFieldLayers();
    ReleaseResultTexturesAndFrames();
    ResetNotePlaybackState(false);

    [AppDelegate.appDelegate.viewController showMusicListView];
    (void)ne::C_TEXTURE::GetCacheList(); // The binary discards this call's result.
    ne::C_TEXTURE::ReleaseAllHandles();

    m_nState = kStateResetPlayback;
    m_nPlayTime = 0;
}

/** @ghidraAddress 0x14c690 */
void GameScene::ReloadMusicForRestart() {
    if (m_nPlayTime <= kExitDelay) {
        return;
    }

    ResetAllPlayFieldLayers();
    ShutdownNoteEffectSystem();

    // A loaded replay reuses its recorded seed so the ghost re-plays identically.
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
    m_nPlayTime = 0;
}

/** @ghidraAddress 0x14d23c */
void GameScene::ResetAllPlayFieldLayers() {
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

    if (m_nThema == kThemaColette) {
        FullComboColetteLayer::shared()->ClearEffectFlags();
        NumberLayer::shared()->ClearReady(0.0f);
        ColetteThemeLayer::shared()->StartFadeOut(0.0f);
        ResultWindowColetteLayer::shared()->StartHideTween(0.0f);
        EventEffectLayer::shared()->FinishEffect(0.0f);
        TutorialGuideLayer::shared()->Stop(0.0f);
    } else if (m_nThema == kThemaLimelight) {
        FullComboLimelightLayer::shared()->ClearEffectFlags();
        LimelightEffectLayer::shared()->SetInactive(0.0f);
        LimelightThemeLayer::shared()->StartGradeAnimation(0.0f);
        LimelightResultLayer::shared()->ResetResultBonusAnimations(0.0f);
        EventEffectLayer::shared()->FinishEffect(0.0f);
    } else if (m_nThema == kThemaClassic) {
        FullComboClassicLayer::shared()->ClearEffectFlags();
        BackgroundSpriteManager::shared()->SetInactive(0.0f);
        ClassicThemeLayer::shared()->StartGaugeValueFade(0.0f);
        ResultWindowClassicLayer::shared()->ResetResultScoreAnimations(0.0f);
    }
}

/** @ghidraAddress 0x14b818 */
void GameScene::WaitForIntroThenStartNotes() {
    if (m_flReadyDelay >= static_cast<float>(m_nPlayTime)) {
        return;
    }
    if (GameSystem::GetGameSystem()->GetPastelBonusType() == 0) {
        m_nState = kStateWaitNotes;
    } else {
        EventEffectLayer::shared()->StartEffect();
        m_nState = kStatePastEffect;
    }
    m_nPlayTime = 0;
}

/** @ghidraAddress 0x14cd90 */
void GameScene::ResumePreviewPlayback() {
    m_nState = kStatePlaying;
    m_nPlayTime = 0;
    if (GameSystem::GetGameSystem()->GetBgmPlaying()) {
        [RBBGMManager.getInstance PlayMusic:0.0f];
    }
    PlayTimer *pTimer = PlayTimer::shared();
    if (pTimer->IsPaused()) {
        pTimer->Resume(CACurrentMediaTime());
    }
}

/** @ghidraAddress 0x14cb4c */
void GameScene::AdvancePreviewPlaybackFrame(int nDeltaFrames) {
    const float flChartEnd = static_cast<float>(m_pMusicSheet->GetChartEndTime());
    const float flClockPos =
        PlayTimer::shared()->GetPlayTime() * kNoteLineScale + kNoteSpawnLookahead;
    if (!FullComboLimelightLayer::shared()->IsAnyEffectActive() && flChartEnd < flClockPos) {
        GameSystem::GetGameSystem()->SetRandSeed(static_cast<unsigned int>(rand()));
        ResetNotePlaybackState(false);

        PlayTimer *pTimer = PlayTimer::shared();
        MusicData *pMusicData = AppDelegate.appDelegate.musicData;
        if (pMusicData.MusicID == kPreviewMusicID) {
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

    NumberEffectLayer::shared()->Update(static_cast<float>(nDeltaFrames));
    PlayTimer::shared()->Update();
    NoteEffectMgr::shared()->ProcessActiveNotes();
    ActivateDueNotes();
}

/** @ghidraAddress 0x14f9a4 */
void GameScene::ReleaseResultTexturesAndFrames() {
    if (m_bIsPad) {
        AltFrameLayer::shared()->SetAltFrameTexture(nullptr);
    } else {
        MainFrameLayer::shared()->SetMainFrameTexture(nullptr);
    }

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
    CMusicSheet2 *pSheet = new CMusicSheet2();
    pSheet->BuildDefaultNoteChart(GameSystem::GetGameSystem());
    BindMusicSheetToNoteMgr(pSheet);
}

/** @ghidraAddress 0x14fb24 */
void GameScene::LoadNoteSheet(NSData *sheetData) {
    CMusicSheet2 *pSheet = new CMusicSheet2();
    pSheet->ParseNoteChartFile(sheetData.bytes, GameSystem::GetGameSystem());
    BindMusicSheetToNoteMgr(pSheet);
}

/** @ghidraAddress 0x14fcd8 */
void GameScene::BindMusicSheetToNoteMgr(CMusicSheet2 *pMusicSheet) {
    ShutdownNoteEffectSystem();
    m_pMusicSheet = pMusicSheet;
    NoteEffectMgr *pMgr = NoteEffectMgr::shared();
    pMgr->SetActiveMusicSheet(m_pMusicSheet);
    pMgr->IterateNoteRecords();
    ScoreTracker::shared()->SetTotalNotes(m_pMusicSheet->GetChartNoteCount(0));
    ResetNotePlaybackState(true);
}

/** @ghidraAddress 0x14fbd4 */
void GameScene::LoadResultBgmForMusic(NSData *musicData) {
    [RBBGMManager.getInstance StopMusic:0.0f];
    [RBBGMManager.getInstance RelaseMusic];
    [RBBGMManager.getInstance LoadMusic:musicData Loop:NO];
    SoundEffectManager::GetInstance()->LoadThemedVoiceData(kResultVoiceId);
}

/** @ghidraAddress 0x14ab4c */
void GameScene::ShutdownNoteEffectSystem() {
    ResetNotePlaybackState(false);
    NoteEffectMgr::shared()->SetActiveMusicSheet(nullptr);
    if (m_pMusicSheet != nullptr) {
        delete m_pMusicSheet;
        m_pMusicSheet = nullptr;
    }
}

/** @ghidraAddress 0x14d3b4 */
void GameScene::ResetNotePlaybackState(bool bApplyGhost) {
    NoteEffectMgr::shared()->ResetAllNoteModels();

    if (bApplyGhost && [RBUserSettingData sharedInstance].ghostStyle == 1) {
        ApplyReplayGhostToNotes();
    }

    NoteEffectMgr::shared()->AssignNoteColors();
    m_nPlayCursor = 0;
    ScoreTracker::shared()->ResetLaneGaugeState();
    ReflecGaugeLayer::shared()->ResetSideGauges();
    ClearGaugeLayer::shared()->ClearValues();

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
    if (!pGameSystem->GetPaused()) {
        return;
    }

    pGameSystem->SetPaused(false);
    if (pGameSystem->GetBgmPlaying()) {
        [[RBBGMManager getInstance] PlayMusic:0.0f];
    }

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
constexpr int kPauseGaugeListenerPriority = 2;

constexpr int kStateInit = 0;
constexpr int kStateChartBound = 3;
constexpr int kStatePlayFinished = 0xa;
constexpr int kStateRestartPlayback = 0xf;
constexpr int kStatePreviewSetup = 0x10;
constexpr int kStatePreviewResume = 0x12;
constexpr int kStatePreviewExit = 0x14;

constexpr int kGameTypeNetworkMatch = 1;

// The play-record's match outcome (judgement cell index 10).
constexpr int kMatchResultWin = 0;
constexpr int kMatchResultLose = 1;
constexpr int kMatchResultDraw = 2;

constexpr int kPlayColorBlue = 1;

constexpr int kVoiceCueTitle = 0;
constexpr int kVoiceCueWin = 3;
constexpr int kVoiceCueLose = 4;
constexpr int kVoiceCueDraw = 5;
constexpr int kVoiceCueBlueWin = 15;
constexpr int kVoiceCueRedWin = 16;

// The inclusive song-identifier window whose plays are scored, banked, and reported.
constexpr int kFirstScoredMusicId = 100000001;
constexpr int kLastScoredMusicId = 899999999;

// The binary really does store negative zero here, so the level is the negated fractional part.
constexpr float kFadeInBase = -0.0f; // @ghidraAddress 0x308ddc

constexpr int kPlayerSideCount = 2;

enum JudgeGrade {
    kJudgeGradeJust = 0,
    kJudgeGradeGreat = 1,
    kJudgeGradeGood = 2,
    kJudgeGradeMiss = 3,
    kJudgeGradeCount = 4,
};

constexpr int kScoreJust = 3;
constexpr int kScoreGreat = 2;
constexpr int kScoreGood = 1;
constexpr int kScoreJustReflec = 10;
constexpr int kNoMissBonus = 50;
constexpr int kOneMissBonus = 25;
constexpr int kTwoMissBonus = 10;

constexpr int kNoMisses = 0;
constexpr int kOneMiss = 1;
constexpr int kTwoMisses = 2;

// The note type whose judgement lives on its slide points rather than on the note itself.
constexpr int kSlideNoteType = 3;

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
void GameScene::OnFrame(int nElapsedMs) {
    NoteEffectMgr::shared()->ClearNotePositionCache();
    CheckAutoPauseByNotePosition();
    // While the pause gauge holds the game paused the applied delta is zero, freezing the play.
    const int nAppliedDelta = RefreshPauseGaugeAndGetActiveFlag() ? nElapsedMs : 0;
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
    ShotSoundManager::GetInstance()->UpdateRetriggerTimer(static_cast<float>(nElapsedMs));
}

/** @ghidraAddress 0x14ba48 */
void GameScene::ExecMain() {
    PlayTimer::shared()->Update();
    NoteEffectMgr::shared()->ProcessActiveNotes();
    ActivateDueNotes();

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

        bool bComputeBonuses = false;
        MusicData *pPlayedMusic = [AppDelegate.appDelegate musicData];
        const int nMusicId = pPlayedMusic.MusicID;
        if (nMusicId >= kFirstScoredMusicId && nMusicId <= kLastScoredMusicId) {
            PersistScoreAndSaveReplay();
            (void)NSDate.date; // Yes, the binary discards this call's result.
            ReportTotalScoreToGameCenter();
            bComputeBonuses = true;
        } else if (nMusicId == kTutorialMusicId) {
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

    GameSystem *pGameSystem = GameSystem::GetGameSystem();
    LevelTables *pTables = LevelTables::GetInstance();
    pGameSystem->SetResultLevelExp(pTables->GetCurrentLevel(), pTables->GetCurrentExp(), 0);
    pGameSystem->SetNewRecord(false);

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
    // The fade level tracks the fractional part of the note path at the current scroll line.
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
    JustReflecEffectLayer::shared()->Update(flDelta);
    NoteLayer::shared()->Update(flDelta);
    // The binary sets up a frame delta here too, but the chain layer takes no argument.
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
        if (GameSystem::GetGameSystem()->GetMenuTutorialActive()) {
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
    NE_DBG(g_nDebugFrameCounter = 0);

    if (m_nThema != static_cast<int>(RBUserSettingData.sharedInstance.thema)) {
        m_nThema = static_cast<int>(RBUserSettingData.sharedInstance.thema);
    }

    BgLayer::GetBackgroundLayer()->InitializeBackgroundLayer();
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
    JustReflecEffectLayer::shared()->LoadNoteChargeSprites();
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
    const int nMaxScore = m_pMusicSheet->GetJustReflecQuota() * kScoreJustReflec + kNoMissBonus +
                          nSideNoteCount * kScoreJust;

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

    int nFinalScore = pTracker->GetPlayRecordCell(kResultSide, kRecordScoreCell);
    if (nFinalScore > aBaseScores[nPlaySide]) {
        nFinalScore = aBaseScores[nPlaySide];
    }
    if (nFinalScore > nMaxScore) {
        nFinalScore = nMaxScore;
    }

    // A stored best above what the chart can award is a tampered record and is overwritten.
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

    // The full-combo flag never dirties the record on its own.
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
    if (!GetHasGameCenterFlag()) {
        return;
    }
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
        }];
}

} // namespace rb
