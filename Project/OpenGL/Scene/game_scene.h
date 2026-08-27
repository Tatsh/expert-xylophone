/**
 * @file
 * The gameplay scene, @c rb::GameScene (RTTI @c N2rb9GameSceneE).
 */

#pragma once

#include "basescene.h"

#ifdef __OBJC__
@class NSData;
#else
typedef struct objc_object NSData;
#endif

class PauseGaugeLayer;

namespace rb {

class CMusicSheet2;

/**
 * @brief The gameplay scene: the per-frame state machine that drives a play session from set-up
 * through the notes to the result screen and exit.
 *
 * A process-wide singleton registered in the engine task list at priority 1, cached in the game
 * system's leading scene pointer (@c GameSystem::GetCurrentScene). It derives from @c rb::BaseScene
 * (and thus the @c ne::C_TASK node) and overrides the per-frame callback with its state-machine
 * dispatch. The trailing @c // +0xNN comments document the original member offsets for reference
 * only; the tail sub-state fields between the recovered members are still being worked out.
 */
class GameScene : public BaseScene {
public:
    /**
     * @brief Returns the scene's current state.
     * @return The scene's current state.
     */
    int GetState() const {
        return m_nState;
    }
    /**
     * @brief Sets the scene's play mode (0 normal, 1 alternate).
     * @param nMode The play mode.
     */
    void SetMode(int nMode) {
        m_nMode = nMode;
    }
    /**
     * @brief Sets the scene's state and clears its accumulated play time.
     * @param nState The scene state to enter.
     */
    void SetState(int nState) {
        m_nState = nState;
        m_nPlayTime = 0;
    }

    /**
     * @brief Returns the singleton gameplay scene, constructing it (and registering it in the task
     * list at priority 1) on first use.
     * @param ppOut The caller-held slot that holds, and receives, the singleton pointer (the game
     *        system's leading scene pointer).
     * @ghidraAddress 0x12ee88
     */
    static void GetInstance(GameScene **ppOut);

    /**
     * @brief Fully releases the current music and voice resources.
     *
     * A no-op while the background music is still marked active (it must be stopped first);
     * otherwise it stops and releases the music and releases the audio manager's voices. Takes no
     * scene, acting only on the music and audio singletons, but belongs to the scene's music
     * lifecycle.
     * @ghidraAddress 0x14b2f8
     */
    static void ReleaseBgmAndVoice();

    /**
     * @brief Initialises the scene for the current play mode: builds every play-field layer, seeds
     * the play state, and binds the chart.
     * @ghidraAddress 0x14a518
     */
    void Init();

    /**
     * @brief Loads the current song's music-name texture and installs it into the active frame
     * layer.
     *
     * Renders the current song's name into the game system's music-name texture, then binds that
     * texture into the alternate-frame layer on an iPad, or the main-frame layer on the phone.
     * @ghidraAddress 0x14aec4
     */
    void LoadMusicNameAndFrameTexture();

    /**
     * @brief Advances this scene from state 0x11 to 0x12.
     * @ghidraAddress 0x14aff8
     */
    void AdvanceGameSceneStateFrom11();
    /**
     * @brief Sets this scene's state to 0x13.
     * @ghidraAddress 0x14afec
     */
    void SetGameSceneState13();
    /**
     * @brief Pauses the play timer and background music when this scene is interrupted.
     * @ghidraAddress 0x14b010
     */
    void PausePlayTimerAndBgm();

    /**
     * @brief Auto-pauses gameplay when notes converge on both incoming buttons (a tilt/obstruction
     * heuristic).
     *
     * Skips when already paused. For each active touch, normalises its position by the owning view
     * size and, when the touch is inside the hit band, records whether a note converges toward the
     * left or the right button (an inward drift over a hundred units). If both sides converge and
     * the scene is in play mode, it pauses the play timer and background music.
     * @ghidraAddress 0x14b5b8
     */
    void CheckAutoPauseByNotePosition();

    /**
     * @brief Scene-mode-enter callback: enters normal play mode and initialises the scene.
     *
     * Sets the mode to normal, runs @c Init, and advances to state 2.
     * @ghidraAddress 0x14af90
     */
    void EnterModeNormal();
    /**
     * @brief Scene-mode-enter callback: enters alternate play mode and initialises the scene.
     *
     * Sets the mode to alternate, runs @c Init, and advances to state 0x10.
     * @ghidraAddress 0x14afbc
     */
    void EnterModeAlt();

    /**
     * @brief Resumes the play timer and background music after an interruption.
     *
     * The counterpart to @c PausePlayTimerAndBgm; a no-op unless the game is paused. Acts only on
     * the game-system and play-timer singletons, so it takes no scene.
     * @ghidraAddress 0x14b144
     */
    static void ResumePlayTimerAndBgm();
    /**
     * @brief Re-enters alternate play mode on the current scene when the game system has one
     * active.
     *
     * A render-loop resume hook: when the game system holds a current scene, runs the alternate
     * mode-enter callback on it; otherwise does nothing.
     * @ghidraAddress 0x8c884
     * @ghidraAddress 0x8c8a8
     */
    static void ResumeRenderLoopIfActive();
    /**
     * @brief Resets the scene's state field to zero.
     * @ghidraAddress 0x14a510
     */
    void ClearLayerStateField();

    /**
     * @brief Stops the background music and re-enables device auto-rotation, once, when the scene
     * is torn down or interrupted.
     * @ghidraAddress 0x14b228
     */
    void StopBgmAndAllowRotation();

    /**
     * @brief Transitions the scene into the pause-exit state: stops the BGM, resumes the play
     * timer, starts the fade-in overlay, and advances to state 0xe.
     * @ghidraAddress 0x14b1ec
     */
    void EnterPauseExitState();

    /**
     * @brief Transitions the scene into the music-release state: stops the BGM, releases the music
     * and voice resources, resumes the play timer, starts the fade-in overlay, and advances to
     * state 0xd.
     * @ghidraAddress 0x14b2b8
     */
    void EnterMusicReleaseState();

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
     * For the Classic theme it advances the player level/experience progression (unlocking new
     * custom items for each level gained) and stores the results on the game system. For the
     * Limelight and Colette themes it accumulates the clear, miss, rank, first-play, and
     * pastel-field bonuses (plus early-play and hot-music bonuses for Colette), stores each
     * component on the active result layer, adds the total to the player's experience, and saves.
     * @ghidraAddress 0x14f0dc
     */
    void ComputeResultBonusesAndExperience();

    /**
     * @brief Enters the result-theme display state: initialises the active theme's
     * grade/score-gauge display, starts the result-voice cue, plays the clear cue when the play
     * cleared (rate at or above the clear threshold, or a tutorial play), and advances to the
     * result-theme state.
     * @ghidraAddress 0x14be88
     */
    void EnterResultThemeState();

    /**
     * @brief Finalises the result screen and submits the score once the player confirms it.
     *
     * Fires the result voice cue near the one-second mark, then waits until the active theme's
     * result window reports the confirm tap. On confirm (outside an early tutorial) it plays the
     * confirm sound, stops the music, clears the theme's confirm latch, and — unless this was a
     * full-combo or full-just-reflec play — submits the play to the server, marks the tutorial's
     * result step done and tears down the tutorial guide, then starts the fade-in and advances to
     * the exit-to-list state.
     * @param nDeltaFrames The elapsed frame count this tick.
     * @ghidraAddress 0x14c27c
     */
    void FinalizeResultAndSubmitScore(int nDeltaFrames);

    /**
     * @brief Builds the result screen and starts the result music, once the play has settled.
     *
     * After half a second of play time and once the active theme's intro layer has finished
     * animating, it loads the song artwork and artist-name textures, pushes the played song into
     * the result state, and — per theme — binds the three result-window sprite-instancer textures,
     * resets the result flags, starts the show tween, and clears the confirm latch. It then loads
     * the result voice, starts the looping result BGM, and advances to the result-submit state; in
     * a tutorial play it also advances the tutorial and resets the guide.
     * @ghidraAddress 0x14bf30
     */
    void LoadResultScreenAndMusic();

    /**
     * @brief Advances the note-chart preview a frame, looping it when the clock runs past the
     * chart.
     *
     * The preview-playing state handler. While the Limelight full-combo effect is not blocking and
     * the play clock has run past the chart's end (its scaled position past the chart end time,
     * less the spawn look-ahead), it loops the preview: reseeds the RNG, resets note playback, and
     * restarts the play timer — for the no-song demo (the sentinel music id) it also restarts the
     * looping demo BGM and drives the timer from the music, otherwise it starts a free-running
     * timer. Otherwise it advances one frame: ticks the number-effect layer, the play timer, and
     * the note-effect processing, then activates the notes now due.
     * @param nDeltaFrames The elapsed frame count this tick.
     * @ghidraAddress 0x14cb4c
     */
    void AdvancePreviewPlaybackFrame(int nDeltaFrames);

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
     * @brief Resets and hides every play-field render layer (end of song or teardown): fades out
     * the shared layers and resets the active theme's full-combo, effect, and result layers.
     * @ghidraAddress 0x14d23c
     */
    void ResetAllPlayFieldLayers();

    /**
     * @brief Loads the selected difficulty's note sheet and music, binding them for playback.
     * @ghidraAddress 0x14ab94
     */
    void LoadMusicAndSheet();

    /**
     * @brief Waits for the active theme's intro animation to finish, then starts the background
     * music and the play timer, activates the due notes, and (in a tutorial) starts the guide,
     * advancing to the note-play state.
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
     * @brief After the exit delay elapses, reloads the music and sheet for a restart (retry):
     * resets the play-field layers, shuts down the note-effect system, reseeds the RNG (from the
     * replay when the ghost is enabled), rebinds the chart, and advances to the load state.
     * @ghidraAddress 0x14c690
     */
    void ReloadMusicForRestart();

    /**
     * @brief Sets up the note-chart preview presentation: applies the note-manager theme, primes
     * every play-field layer to its shown state, loads the chart (or a synthetic default when no
     * music is selected), starts the play timer and background music, shows the preview, and
     * advances to the playing state.
     * @ghidraAddress 0x14c848
     */
    void SetupPreviewPlayback();

    /**
     * @brief Closes the note-chart preview and returns to the music list.
     *
     * Shuts down the note-effect system, stops the background music and re-enables rotation when a
     * music is selected, resets the play-field layers, fades out and frees the number-effect layer,
     * hides the preview through the app's root view controller, flushes the texture cache, and
     * advances to the exit state.
     * @ghidraAddress 0x14ce34
     */
    void ClosePreviewAndReturnToList();

private:
    /**
     * @brief Constructs the scene: chains the scene-base constructor, installs the play dispatch
     * table, zero-clears the play state, and seeds the initial mode to 2.
     * @ghidraAddress 0x14a21c
     */
    GameScene();

    /**
     * @brief The play state that waits out the intro ready-delay, then starts the notes.
     *
     * Once the accumulated play time passes the ready-delay threshold, it either advances to the
     * wait state (when no pastel bonus is active) or starts the event effect and advances past it.
     * @ghidraAddress 0x14b818
     */
    void WaitForIntroThenStartNotes();

    /**
     * @brief Resumes preview playback after an interruption: advances to the playing state,
     * restarts the background music if it was playing, and un-pauses the play timer.
     * @ghidraAddress 0x14cd90
     */
    void ResumePreviewPlayback();

    /**
     * @brief Releases the result-screen textures and clears the frame textures at teardown.
     *
     * Clears the on-screen frame's bound texture (the alternate frame on iPad, the main frame
     * elsewhere), clears the active theme result layer's three text-instancer textures, and
     * releases the three cached result-text textures held on the game system.
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
     * @brief Binds a parsed chart as the active chart: tears down the previous chart, stores the
     * new one, hands it to the note-effect manager, seeds the score tracker's note count, and
     * resets playback.
     * @param pMusicSheet The parsed chart to bind (ownership passes to the scene).
     * @ghidraAddress 0x14fcd8
     */
    void BindMusicSheetToNoteMgr(CMusicSheet2 *pMusicSheet);

    /**
     * @brief Stops and reloads the background music with a result-screen (non-looping) track, then
     * loads the themed result voice data.
     *
     * The receiver is unused; the method is a member only because the binary threads the scene
     * pointer through its caller.
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

    /**
     * @brief Persists the finished play's score to the Core Data record and writes its replay
     * ghost.
     *
     * Fetches (or creates) the current song's @c ScoreData record, tallies the per-lane judgement
     * counts (including each slide note's per-point results) and computes the base-score total,
     * then — for the played difficulty's columns — stores the score, achievement rate, and rank
     * when they beat the stored best (raising the new-record flag), and marks a full combo. When
     * anything changed it recomputes the record's tamper hash; it always refreshes the last-play
     * date and bumps the play counter, then saves the managed object context (skipping the
     * tutorial-song sentinel). Finally, when no replay exists yet for this tune and difficulty or
     * the score improved, it builds a @c ReplayData ghost (tune, difficulty, seed, note count,
     * score, combo, judgement cells, rate, date, and user) with a @c ReplayNote per played note —
     * nesting a sub-note per slide point — and saves it.
     * @ghidraAddress 0x14d600
     */
    void PersistScoreAndSaveReplay();

    /**
     * @brief Builds every play-field layer's sprites for the active UI theme.
     *
     * Refreshes the cached theme from the user settings when it has changed, then walks the shared
     * play-field layers in turn — background, the iPad alt-frame or the phone main frame, player
     * field, judge effect, thema marker, play colour, reflec and clear gauges, judge score, chain
     * connector, the note body, long-note, trail, slide, slide-result, and charge layers, the
     * damage and bounds effects, the note result, explosion, and glow layers — asking each
     * singleton to build its sprites. It then runs the theme's own set (Classic, Limelight, or
     * Colette) and the fade overlay. Finally, on the first call it constructs the pause-gauge layer
     * and registers it in the engine's per-frame listener list at priority 2.
     * @ghidraAddress 0x14a298
     */
    void InitializePlayFieldLayersForTheme();

    /**
     * @brief Advances and renders every play-field layer for one frame.
     *
     * Computes the intro fade level first: fully lit until the chart's first path speed is set,
     * after which it is the fractional part of the note path evaluated at the current scroll line,
     * clamped to zero through one. That level drives the reflec gauge's brightness, the thema
     * marker's danger level, and the play-colour gauge fill. It then ticks the score tracker and
     * advances each shared layer — player field, judge effect, background, gauges, thema marker,
     * play colour, the bounds, explosion, damage, and glow effects, the judge score, note result,
     * note body, trail, slide, slide-result, charge, long-note, and chain layers, and the iPad alt
     * frame or the phone main frame — by @p nDeltaFrames. Finally it runs the active theme's own
     * layer set (with the tutorial guide while the menu tutorial is active) and the fade overlay.
     * @param nDeltaFrames The elapsed frame count, zero while the game is paused.
     * @ghidraAddress 0x14cf5c
     */
    void RenderAllPlayFieldLayers(int nDeltaFrames);

    /**
     * @brief Runs one frame of the note-play state, and finishes the play once the chart ends.
     *
     * Ticks the play timer, processes the active notes, and activates the notes now due. It returns
     * early while the active theme's full-combo effect is still animating, and again until the play
     * clock's scroll line passes the chart's end time. Past that it stops the music, releases the
     * BGM and voice, and computes the per-lane clear rate and grade, then either (for the
     * versus/CPU game type, an out-of-range song, or the tutorial sentinel) republishes the
     * player's level and experience and loads a rank-keyed voice cue, or loads the theme's clear or
     * failure voice cue and — unless a full-combo flag is already raised — persists the score,
     * reports the total to Game Center, and computes the result bonuses. Either way it advances to
     * the result-theme state.
     * @ghidraAddress 0x14ba48
     */
    void ExecMain();

    /**
     * @brief Runs one tick of the play state machine.
     *
     * Clears the note position cache, checks whether a note has run far enough to auto-pause, and
     * refreshes the pause gauge — while the gauge holds the game paused the applied frame delta is
     * forced to zero, freezing the play clock. It then accumulates the applied delta into the play
     * time and dispatches the current state's handler, and finally renders every play-field layer
     * and advances the shot-sound retrigger timer.
     *
     * This is the scene's per-frame task callback: the binary's vtable at @c 0x35da40 holds it in
     * the @c ne::C_TASK @c OnFrame slot, so the engine task loop runs the state machine every
     * frame from boot (which is what consumes the initial state and builds the play-field layers
     * before the first play).
     * @param nElapsedMs The elapsed frame count this tick.
     * @ghidraAddress 0x14b3e8
     */
    void OnFrame(int nElapsedMs) override;

    int m_nState = {};                // +0x4c: the current state-machine state (dispatched each
                                      //        frame).
    int m_nPlayTime = {};             // +0x50: the accumulated play time.
    int m_nPlayCursor = {};           // +0x54: the play cursor, cleared on a playback reset.
    CMusicSheet2 *m_pMusicSheet = {}; // +0x58: the owned active note chart, or null.
    // unsigned char m_aReserved5c[4] = {}; // +0x5c
    float m_flFirstPathSpeed = {}; // +0x60: the chart's first path speed, cached at set-up,
                                   //        reset to 0 when the BGM stops.
    bool m_bPauseGaugeHeld = {};   // +0x64: whether the pause gauge is being held down.
    // unsigned char m_aReserved65[0x03] = {}; // +0x65
    PauseGaugeLayer *m_pPauseGauge = {}; // +0x68: the owned pause-gauge layer, or null.
    int m_nMode = {};                    // +0x70: the play mode (0 normal, 1 alternate; the
                                         //        constructor seeds 2).
    float m_flPresentationDelay = {};    // +0x74: the play-ready intro threshold, in play time.
    float m_flIntroSecondDelay = {};     // +0x78: the intro's second threshold, in play time,
                                         //        seeded to 700 beside the other two; no
                                         //        reconstructed reader yet.
    float m_flReadyDelay = {};           // +0x7c: the intro ready-delay threshold, in play time.
    int m_nResultScore = {};             // +0x80: the chart's result score, handed to the theme's
                                         //        result layer at set-up.
    int m_nResultScoreHi = {};           // +0x84: the second result score value, likewise.
    int m_nThema = {};                   // +0x88: the active theme (0 Classic, 1 Limelight, 2
                                         //        Colette), selecting the full-combo layer.
    // unsigned char m_aReserved8c[4] = {}; // +0x8c: trailing play state to the 0x90-byte size.
};

/**
 * @brief Ensures the device is generating orientation-change notifications.
 *
 * A scene-mode-enter callback that turns on @c UIDevice orientation notifications, looping until
 * the device reports they are being generated.
 * @ghidraAddress 0x93b50
 */
void EnsureOrientationNotificationsEnabled(void);

/**
 * @brief Reports the player's total score to the Game Center leaderboard.
 *
 * A no-op when Game Center is disabled or the local player is not authenticated. Otherwise it
 * builds a @c GKScore for the total-score leaderboard, sets it to the stored total score, and
 * reports it (with a no-op completion block).
 * @ghidraAddress 0x14ef34
 */
void ReportTotalScoreToGameCenter(void);

} // namespace rb

// code: language=C++
// kate: hl C++;
// vim: set ft=cpp :
