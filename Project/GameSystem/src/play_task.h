/**
 * @file
 * The gameplay task, @c PlayTask.
 */

#pragma once

#include "game_ui_layer_base.h"

#ifdef __OBJC__
@class NSData;
#else
typedef struct objc_object NSData;
#endif

class MusicSheet;
class PauseGaugeLayer;

/**
 * @brief The gameplay task: the per-frame state machine that drives a play session from set-up
 * through the notes to the result screen and exit.
 *
 * A process-wide singleton registered in the engine task list at priority 1. It derives from
 * @c GameUiLayerBase (and thus the @c ne::C_TASK node) and overrides the per-frame callback with its
 * state-machine dispatch. The trailing @c // +0xNN comments document the original member offsets for
 * reference only; the tail sub-state fields between the recovered members are still being worked out.
 */
class PlayTask : public GameUiLayerBase {
public:
    /**
     * @brief Returns the singleton gameplay task, constructing it (and registering it in the task
     * list at priority 1) on first use.
     * @param ppOut The caller-held slot that holds, and receives, the singleton pointer.
     * @ghidraAddress 0x12ee88
     */
    static void GetInstance(PlayTask **ppOut);

    /**
     * @brief Ticks the pause gauge and reports whether gameplay is active this frame.
     *
     * When the game is not paused, releases any pause-gauge charge and returns true. When paused,
     * charges the gauge (unless it is being held) and returns false.
     * @return @c true when gameplay is active (unpaused), @c false when paused.
     * @ghidraAddress 0x14b6e0
     */
    bool RefreshPauseGaugeAndGetActiveFlag();

    /**
     * @brief Computes the result-screen bonuses and awards experience, per active theme.
     *
     * For the Classic theme it advances the player level/experience progression (unlocking new custom
     * items for each level gained) and stores the results on the game system. For the Limelight and
     * Colette themes it accumulates the clear, miss, rank, first-play, and pastel-field bonuses (plus
     * early-play and hot-music bonuses for Colette), stores each component on the active result layer,
     * adds the total to the player's experience, and saves.
     * @ghidraAddress 0x14f0dc
     */
    void ComputeResultBonusesAndExperience();

    /**
     * @brief Enters the result-theme display state: initialises the active theme's grade/score-gauge
     * display, starts the result-voice cue, plays the clear cue when the play cleared (rate at or
     * above the clear threshold, or a tutorial play), and advances to the result-theme state.
     * @ghidraAddress 0x14be88
     */
    void EnterResultThemeState();

    /**
     * @brief Starts the gameplay presentation once play time has begun: plays the intro-voice cue,
     * runs the active theme's intro layer, and fades in the background, player-field score, and
     * judge-effect layers, then advances to the presenting state.
     * @ghidraAddress 0x14b86c
     */
    void StartGameplayPresentation();

    /**
     * @brief Waits for the intro delay to elapse, then primes all play-field layers (note-result
     * layout, frame, thema marker, play-colour gauge grow, and the reflec and clear gauges) and
     * advances to the play-ready state.
     * @ghidraAddress 0x14b734
     */
    void AdvanceToPlayReadyState();

    /**
     * @brief Resets and hides every play-field render layer (end of song or teardown): fades out the
     * shared layers and resets the active theme's full-combo, effect, and result layers.
     * @ghidraAddress 0x14d23c
     */
    void ResetAllPlayFieldLayers();

    /**
     * @brief Loads the selected difficulty's note sheet and music, binding them for playback.
     * @ghidraAddress 0x14ab94
     */
    void LoadMusicAndSheet();

    /**
     * @brief Waits for the active theme's intro animation to finish, then starts the background music
     * and the play timer, activates the due notes, and (in a tutorial) starts the guide, advancing to
     * the note-play state.
     * @ghidraAddress 0x14b914
     */
    void BeginMusicPlaybackAndTimer();

    /**
     * @brief Activates every note whose lead-in has been reached for the current play time.
     * @ghidraAddress 0x14d4d8
     */
    void ActivateDueNotes();

    /**
     * @brief After the exit delay elapses, tears down the play field and returns to the music list:
     * resets the play-field layers, releases the result textures, resets playback, shows the music
     * list, flushes the texture cache, and advances to the exit state.
     * @ghidraAddress 0x14c5bc
     */
    void ExitToMusicList();

    /**
     * @brief After the exit delay elapses, reloads the music and sheet for a restart (retry): resets
     * the play-field layers, shuts down the note-effect system, reseeds the RNG (from the replay when
     * the ghost is enabled), rebinds the chart, and advances to the load state.
     * @ghidraAddress 0x14c690
     */
    void ReloadMusicForRestart();

    /**
     * @brief Sets up the note-chart preview presentation: applies the note-manager theme, primes every
     * play-field layer to its shown state, loads the chart (or a synthetic default when no music is
     * selected), starts the play timer and background music, shows the preview, and advances to the
     * playing state.
     * @ghidraAddress 0x14c848
     */
    void SetupPreviewPlayback();

private:
    /**
     * @brief Constructs the task: chains the UI-layer base constructor, installs the play dispatch
     * table, zero-clears the play state, and seeds the initial state to 2.
     * @ghidraAddress 0x14a21c
     */
    PlayTask();

    /**
     * @brief The play state that waits out the intro ready-delay, then starts the notes.
     *
     * Once the accumulated play time passes the ready-delay threshold, it either advances to the
     * wait state (when no pastel bonus is active) or starts the event effect and advances past it.
     * @ghidraAddress 0x14b818
     */
    void WaitForIntroThenStartNotes();

    /**
     * @brief Resumes preview playback after an interruption: advances to the playing state, restarts
     * the background music if it was playing, and un-pauses the play timer.
     * @ghidraAddress 0x14cd90
     */
    void ResumePreviewPlayback();

    /**
     * @brief Releases the result-screen textures and clears the frame textures at teardown.
     *
     * Clears the on-screen frame's bound texture (the alternate frame on iPad, the main frame
     * elsewhere), clears the active theme result layer's three text-instancer textures, and releases
     * the three cached result-text textures held on the game system.
     * @ghidraAddress 0x14f9a4
     */
    void ReleaseResultTexturesAndFrames();

    /**
     * @brief Allocates a default note chart, seeds it from the game system, and binds it as the
     * active chart (used for the auto-play preview, when there is no selected music).
     * @ghidraAddress 0x14facc
     */
    void BuildChartReaderFromGameSystem();

    /**
     * @brief Parses a difficulty's note-sheet data into a fresh chart and binds it as the active
     * chart.
     * @param sheetData The sheet @c NSData for the selected difficulty.
     * @ghidraAddress 0x14fb24
     */
    void LoadNoteSheet(NSData *sheetData);

    /**
     * @brief Binds a parsed chart as the active chart: tears down the previous chart, stores the new
     * one, hands it to the note-effect manager, seeds the score tracker's note count, and resets
     * playback.
     * @param pMusicSheet The parsed chart to bind (ownership passes to the task).
     * @ghidraAddress 0x14fcd8
     */
    void BindMusicSheetToNoteMgr(MusicSheet *pMusicSheet);

    /**
     * @brief Stops and reloads the background music with a result-screen (non-looping) track, then
     * loads the themed result voice data.
     *
     * The receiver is unused; the method is a member only because the binary threads the task pointer
     * through its caller.
     * @param musicData The result-track music resource data.
     * @ghidraAddress 0x14fbd4
     */
    void LoadResultBgmForMusic(NSData *musicData);

    /**
     * @brief Tears down the active note chart: resets playback, clears the note-effect manager's
     * chart, and destroys the owned chart object.
     * @ghidraAddress 0x14ab4c
     */
    void ShutdownNoteEffectSystem();

    /**
     * @brief Resets note-playback state at the start of a (re)play: resets the note models, applies
     * the replay ghost when enabled, reassigns note colours, clears the play cursor, and resets the
     * gauge, score, and full-combo layers.
     * @param bApplyGhost Whether to apply the ghost/replay data.
     * @ghidraAddress 0x14d3b4
     */
    void ResetNotePlaybackState(bool bApplyGhost);

    int m_nState = {};                   // +0x4c: the current state-machine state (dispatched each
                                         //        frame).
    int m_nPlayTime = {};                // +0x50: the accumulated play time.
    int m_nPlayCursor = {};              // +0x54: the play cursor, cleared on a playback reset.
    MusicSheet *m_pMusicSheet = {};      // +0x58: the owned active note chart, or null.
    unsigned char m_aReserved5c[4] = {}; // +0x5c
    float m_flFirstPathSpeed = {};       // +0x60: the chart's first path speed, cached at set-up.
    bool m_bPauseGaugeHeld = {};         // +0x64: whether the pause gauge is being held down.
    unsigned char m_aReserved65[0x03] = {}; // +0x65
    PauseGaugeLayer *m_pPauseGauge = {};    // +0x68: the owned pause-gauge layer, or null.
    int m_nInitialState = {};               // +0x70: the state the task starts in (2).
    float m_flPresentationDelay = {};       // +0x74: the play-ready intro threshold, in play time.
    unsigned char m_aReserved78[4] = {};    // +0x78
    float m_flReadyDelay = {};              // +0x7c: the intro ready-delay threshold, in play time.
    unsigned char m_aReserved80[8] = {};    // +0x80
    int m_nThema = {};                      // +0x88: the active theme (0 Classic, 1 Limelight, 2
                                            //        Colette), selecting the full-combo layer.
    unsigned char m_aReserved8c[4] = {};    // +0x8c: trailing play state to the 0x90-byte size.
};

// code: language=C++
// kate: hl C++;
// vim: set ft=cpp :
