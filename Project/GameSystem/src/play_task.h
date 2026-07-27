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
    unsigned char m_aReserved74[8] = {};    // +0x74
    float m_flReadyDelay = {};              // +0x7c: the intro ready-delay threshold, in play time.
    unsigned char m_aReserved80[8] = {};    // +0x80
    int m_nThema = {};                      // +0x88: the active theme (0 Classic, 1 Limelight, 2
                                            //        Colette), selecting the full-combo layer.
    unsigned char m_aReserved8c[4] = {};    // +0x8c: trailing play state to the 0x90-byte size.
};

// code: language=C++
// kate: hl C++;
// vim: set ft=cpp :
