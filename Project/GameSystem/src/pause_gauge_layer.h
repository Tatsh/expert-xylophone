/**
 * @file
 * The pause-gauge play-field layer, @c PauseGaugeLayer.
 */

#pragma once

#include "game_ui_layer_base.h"

/**
 * @brief The pause-gauge layer: the per-lane gauge shown while the game is paused.
 *
 * A @c GameUiLayerBase subclass registered as a per-frame task. It owns two sprite instancers and a
 * parts texture, holds a per-lane geometry and active-flag block, and charges a gauge while the
 * game is held paused. Only the members the reconstructed methods touch are modelled; the sprite
 * slots, lane tables, and per-lane geometry between them are reserved until the render family is
 * reconstructed. The trailing @c // +0xNN comments document the original member offsets for
 * reference only.
 */
class PauseGaugeLayer : public GameUiLayerBase {
public:
    /**
     * @brief Marks the gauge as charging on first entry, playing the charge-start sound effect.
     *
     * A no-op when it is already charging.
     * @ghidraAddress 0x150e58
     */
    void SetCharging();

    /**
     * @brief Clears the charging flag, returning the gauge to its unpaused state.
     * @ghidraAddress 0x150e84
     */
    void ClearCharging();

private:
    // +0x4b..+0xa3: the task/vtable state, sprite slots, lane tables, and per-lane geometry the
    // render family uses, not yet modelled.
    unsigned char m_aReserved4b[0x59] = {}; // +0x4b
    bool m_bCharging = {};                  // +0xa4: whether the pause gauge is charging.
};

// code: language=C++
// kate: hl C++;
// vim: set ft=cpp :
