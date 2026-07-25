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
     * @brief Pauses the play timer and background music when this scene is interrupted.
     * @ghidraAddress 0x14b010
     */
    void PausePlayTimerAndBgm();
    /**
     * @brief Resets the scene's state field to zero.
     * @ghidraAddress 0x14a510
     */
    void ClearLayerStateField();

private:
    int m_nState = {};        // +0x4c: the scene's current state.
    int m_nStateSubStep = {}; // +0x50: a per-state sub-step, cleared whenever the state is set.
};

/**
 * @brief Resumes the play timer and background music after an interruption.
 *
 * The counterpart to @c GameScene::PausePlayTimerAndBgm; a no-op unless the game is paused. Unlike
 * the pause side it takes no scene, since it acts only on the game-system and play-timer singletons.
 * @ghidraAddress 0x14b144
 */
void ResumePlayTimerAndBgm(void);

// code: language=C++
// kate: hl C++;
// vim: set ft=cpp :
