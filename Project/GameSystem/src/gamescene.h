/**
 * @file
 * The active game scene, @c GameScene.
 */

#pragma once

/**
 * The active game scene. The application queries and advances its state through the free scene
 * helpers below; only the state accessor it reads is modelled here.
 */
class GameScene {
public:
    /** @brief Returns the scene's current state. */
    int GetState() const {
        return m_nState;
    }
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
     * @brief Resets the scene's state field to zero.
     * @ghidraAddress 0x14a510
     */
    void ClearLayerStateField();

    /**
     * @brief Stops the background music and re-enables device auto-rotation, once, when the scene is
     * torn down or interrupted.
     * @ghidraAddress 0x14b228
     */
    void StopBgmAndAllowRotation();

    /**
     * @brief Transitions the scene into the pause-exit state: stops the BGM, resumes the play timer,
     * starts the fade-in overlay, and advances to state 0xe.
     * @ghidraAddress 0x14b1ec
     */
    void EnterPauseExitState();

    /**
     * @brief Transitions the scene into the music-release state: stops the BGM, releases the music
     * and voice resources, resumes the play timer, starts the fade-in overlay, and advances to state
     * 0xd.
     * @ghidraAddress 0x14b2b8
     */
    void EnterMusicReleaseState();

private:
    int m_nState = {};        // +0x4c: the scene's current state.
    int m_nStateSubStep = {}; // +0x50: a per-state sub-step, cleared whenever the state is set.
    // +0x54..+0x5f: further scene state, still being worked out.
    unsigned char m_aReserved54[0xc] = {}; // +0x54
    int m_nBgmVoiceHandle = {};            // +0x60: the active BGM voice handle, cleared on stop.
};

/**
 * @brief Resumes the play timer and background music after an interruption.
 *
 * The counterpart to @c GameScene::PausePlayTimerAndBgm; a no-op unless the game is paused. Unlike
 * the pause side it takes no scene, since it acts only on the game-system and play-timer singletons.
 * @ghidraAddress 0x14b144
 */
void ResumePlayTimerAndBgm(void);

/**
 * @brief The pause-menu Resume action: resumes play when a scene is active and plays the confirm
 *        sound effect.
 * @ghidraAddress 0x15139c
 */
void HandlePauseResume(void);

/**
 * @brief Fully releases the current music and voice resources.
 *
 * A no-op while the background music is still marked active (it must be stopped first); otherwise it
 * stops and releases the music and releases the audio manager's voices.
 * @ghidraAddress 0x14b2f8
 */
void ReleaseBgmAndVoice(void);

/**
 * @brief Ensures the device is generating orientation-change notifications.
 *
 * A scene-mode-enter callback that turns on @c UIDevice orientation notifications, looping until the
 * device reports they are being generated.
 * @ghidraAddress 0x93b50
 */
void EnsureOrientationNotificationsEnabled(void);

// code: language=C++
// kate: hl C++;
// vim: set ft=cpp :
