/**
 * @file
 * The pause-gauge play-field layer, @c PauseGaugeLayer.
 */

#pragma once

#include "game_ui_layer_base.h"

namespace ne {
class C_SPRITE_INSTANCING;
} // namespace ne
class neTexture;

/**
 * @brief The pause-gauge layer: the per-lane gauge shown while the game is paused.
 *
 * A @c GameUiLayerBase subclass registered as a per-frame task. It owns two sprite instancers and a
 * parts texture, and charges a per-lane gauge while the game is held paused. The per-lane sprite
 * geometry block is modelled as a reserved region until the sprite-emit and render family is
 * reconstructed. The trailing @c // +0xNN comments document the original member offsets for
 * reference only.
 */
class PauseGaugeLayer : public GameUiLayerBase {
public:
    // The number of sprite slots (a gauge slot and a parts slot) and the number of lane-slot ids.
    static constexpr int kSlotCount = 2;
    static constexpr int kLaneSlotCount = 13;

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
    int m_nState = {};                                     // +0x4c: the layer's build/render state.
    neTexture *m_pTexture = {};                            // +0x50: the pause-gauge parts atlas.
    ne::C_SPRITE_INSTANCING *m_apSprites[kSlotCount] = {}; // +0x58: the gauge and parts instancers.
    int m_aSlotCapacity[kSlotCount] = {};                  // +0x68: each slot's sprite capacity.
    int m_aLaneSlotId[kLaneSlotCount] = {};                // +0x70: the per-lane sprite-slot index.
    bool m_bCharging = {};                                 // +0xa4: whether the gauge is charging.
    unsigned long m_qwActiveMask = {}; // +0xa8: the packed active-lane mask (seeded 0x4ffffffff).
    // +0xb0: the per-lane sprite geometry block (x/y and flags per lane) the render family uses.
    unsigned char m_aSpriteBlock[0x30] = {};
    int m_nThema = {}; // +0xe0: the cached UI theme.
};

// code: language=C++
// kate: hl C++;
// vim: set ft=cpp :
