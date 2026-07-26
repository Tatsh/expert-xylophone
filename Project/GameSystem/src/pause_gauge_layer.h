/**
 * @file
 * The pause-gauge play-field layer, @c PauseGaugeLayer.
 */

#pragma once

#include "game_ui_layer_base.h"

namespace ne {
class C_SPRITE_INSTANCING;
class C_TEXTURE;
} // namespace ne

/**
 * @brief One pause-gauge rectangle size: the width and height of a lane's gauge hit rectangle.
 */
struct PauseGaugeRectSize {
    int nWidth = {};  // +0x00: the rectangle width.
    int nHeight = {}; // +0x04: the rectangle height.
};

/**
 * @brief One lane's pause-gauge geometry: the gauge-rectangle centre and its dimmed-lane flag.
 *
 * The trailing @c // +0xNN comments document the byte offsets within the 16-byte per-lane entry.
 */
struct PauseGaugeLaneGeometry {
    float flCenterX = {};              // +0x00: the gauge rectangle's centre x.
    float flCenterY = {};              // +0x04: the gauge rectangle's centre y.
    unsigned char aReserved08[4] = {}; // +0x08: further per-lane state.
    bool bDimmed = {};                 // +0x0c: whether the lane's gauge is drawn dimmed.
    unsigned char aReserved0d[3] = {}; // +0x0d
};

/**
 * @brief The pause-gauge layer: the per-lane gauge shown while the game is paused.
 *
 * A @c GameUiLayerBase subclass registered as a per-frame task. It owns two sprite instancers and a
 * parts texture, and charges a per-lane gauge while the game is held paused. The trailing
 * @c // +0xNN comments document the original member offsets for reference only.
 */
class PauseGaugeLayer : public GameUiLayerBase {
public:
    using LaneGeometry = PauseGaugeLaneGeometry;

    // The number of sprite slots (a gauge slot and a parts slot), the number of lane-slot ids, and
    // the number of lanes the gauge draws a rectangle for.
    static constexpr int kSlotCount = 2;
    static constexpr int kLaneSlotCount = 13;
    static constexpr int kLaneCount = 3;

    /**
     * @brief Constructs the pause-gauge layer: chains the UI-layer base, installs the task dispatch
     * table, clears the state and charging flag, seeds the active-lane mask, distributes the per-lane
     * sprite-slot ids from the lane-group table, and loads the sprites.
     * @ghidraAddress 0x1508b4
     */
    PauseGaugeLayer();

    /**
     * @brief Destroys the layer: releases the parts atlas and flags each owned sprite instancer for
     * the scene walker to delete.
     *
     * The binary emits a non-deleting destructor body (@c 0x150a7c) and a deleting variant
     * (@c 0x150b00) that runs it then frees the object; both are this destructor.
     * @ghidraAddress 0x150a7c
     * @ghidraAddress 0x150b00
     */
    ~PauseGaugeLayer() override;

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

    /**
     * @brief The per-frame task callback: a no-op for the pause gauge (its rendering is driven
     * externally).
     * @ghidraAddress 0x1508b0
     */
    void OnFrame(void *pFrameArg) override;

    /**
     * @brief Hit-tests a point against a lane's pause-gauge rectangle.
     *
     * The rectangle is centred on the lane's geometry centre, sized from the per-device size table
     * (the font-variant device uses the variant table, otherwise the default), with the width and
     * height applied as round-toward-zero half-extents.
     * @param flX The point x.
     * @param flY The point y.
     * @param nLaneIndex The lane to test.
     * @return @c true when the point lies within the lane's gauge rectangle.
     * @ghidraAddress 0x1512fc
     */
    bool CheckPointInRect(float flX, float flY, unsigned int nLaneIndex) const;

private:
    /**
     * @brief Loads the pause-gauge parts atlas and builds one sprite instancer per slot for the
     * current theme.
     * @ghidraAddress 0x150994
     */
    void LoadSprites();

    int m_nState = {};                                     // +0x4c: the layer's build/render state.
    ne::C_TEXTURE *m_pTexture = {};                        // +0x50: the pause-gauge parts atlas.
    ne::C_SPRITE_INSTANCING *m_apSprites[kSlotCount] = {}; // +0x58: the gauge and parts instancers.
    int m_aSlotCapacity[kSlotCount] = {};                  // +0x68: each slot's sprite capacity.
    int m_aLaneSlotId[kLaneSlotCount] = {};                // +0x70: the per-lane sprite-slot index.
    bool m_bCharging = {};                                 // +0xa4: whether the gauge is charging.
    unsigned long m_qwActiveMask = {}; // +0xa8: the packed active-lane mask (seeded 0x4ffffffff).
    LaneGeometry m_aLaneGeometry[kLaneCount] = {}; // +0xb0: the per-lane gauge centre and flag.
    int m_nThema = {};                             // +0xe0: the cached UI theme.
};

// The per-lane gauge rectangle sizes, seeded at startup from the read-only source constants. The
// font-variant device uses the variant table; every other device uses the default table.
extern PauseGaugeRectSize
    g_aPauseGaugeRectVariant[PauseGaugeLayer::kLaneCount]; // @ghidraAddress 0x3dbe90
extern PauseGaugeRectSize
    g_aPauseGaugeRectDefault[PauseGaugeLayer::kLaneCount]; // @ghidraAddress 0x3dbeb0

// code: language=C++
// kate: hl C++;
// vim: set ft=cpp :
