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
    int m_nState = {}; // +0x4c
};

// code: language=C++
// kate: hl C++;
// vim: set ft=cpp :
