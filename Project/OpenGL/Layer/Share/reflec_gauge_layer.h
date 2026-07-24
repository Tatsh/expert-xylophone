/**
 * @file
 * The Reflec gauge layer, @c ReflecGaugeLayer.
 */

#pragma once

#include "playfieldlayerbase.h"

namespace ne {
class C_TEXTURE;
class C_SPRITE_INSTANCING;
} // namespace ne

/**
 * @brief The Reflec gauge layer (the gauge slider and score/combo digits).
 *
 * A process-wide singleton, built on first access, deriving from @c PlayFieldLayerBase. It owns one
 * atlas and four sprite instancers, drawn beneath the shared background layer, that present the
 * gauge slider and score digits, and holds the per-side gauge value the scoring path drives. The
 * class name and source path are taken from the binary's embedded @c reflec_gauge_layer.mm assert.
 * The trailing @c // +0xNN comments document the original 32-bit offsets for reference only.
 */
class ReflecGaugeLayer : public PlayFieldLayerBase {
public:
    // The number of gauge/slider sprite instancers the layer builds.
    static constexpr int kBatchCount = 4;
    // The number of part groups whose capacities the constructor accumulates.
    static constexpr int kPartGroupCount = 6;
    // The number of player sides the gauge tracks.
    static constexpr int kSideCount = 2;

    /**
     * @brief The process-wide Reflec gauge layer, created on first use.
     * @return The shared layer.
     * @ghidraAddress 0x18a88c
     */
    static ReflecGaugeLayer *shared();

    /**
     * @brief Lazily builds the four gauge/slider sprite batches: loads the gm_parts2 atlas and
     * creates each instancer (attaching it under the background layer's render object, making it
     * visible, binding the atlas, and clearing its frame index), flagging the third batch's vertex
     * flag.
     *
     * Guarded so the batches are built only once.
     * @ghidraAddress 0x18a8dc
     */
    void CreateGaugeSliderSprites();

    /**
     * @brief Returns the gauge value for the given player colour.
     *
     * Maps the colour to a side (matching the current play side) and reads that side's value.
     * @param nColor The player colour (0 or 1).
     * @ghidraAddress 0x18ab18
     */
    float GetValue(int nColor) const;
    /**
     * @brief Sets the gauge value for the given player colour.
     *
     * Maps the colour to a side and stores the quantised, clamped value there.
     * @param flValue The requested value.
     * @param nColor The player colour (0 or 1).
     * @ghidraAddress 0x18a9d8
     */
    void SetValue(float flValue, int nColor);

    /**
     * @brief Reads a side's stored gauge value directly.
     * @param nSide The player side (0 or 1).
     * @ghidraAddress 0x18ab98
     */
    float GetValueBySide(unsigned int nSide) const;
    /**
     * @brief Stores a side's gauge value, quantised to the gauge step and clamped to the gauge range
     * (capping at the maximum unless the full-just-reflec flag is set).
     * @param flValue The requested value.
     * @param nSide The player side (0 or 1).
     * @ghidraAddress 0x18aa68
     */
    void SetValueBySide(float flValue, unsigned int nSide);

private:
    /**
     * @brief Constructs the layer, chaining the base constructor, seeding its transform scales, and
     * accumulating each batch's per-group capacities.
     * @ghidraAddress 0x18a7d0
     */
    ReflecGaugeLayer();

    /** @brief One player side's gauge state: its value plus a trailing per-side field. */
    struct SideGauge {
        float flValue = {};  // +0x00: the side's gauge value.
        int nReserved4 = {}; // +0x04: trailing per-side state.
    };

    ne::C_TEXTURE *m_pTexture = {}; // +0x08: the gm_parts2 atlas.
    ne::C_SPRITE_INSTANCING *m_apSprites[kBatchCount] =
        {};                                     // +0x10: the per-batch sprite instancers.
    int m_aBatchCapacity[kBatchCount] = {};     // +0x30: each batch's sprite capacity.
    int m_aPartBaseIndex[kPartGroupCount] = {}; // +0x40: each part group's base index.
    bool m_bBuilt = {};                         // +0x58: set once the batches are built.
    unsigned char m_aReserved59[0x1b] = {};     // +0x59: further state, still being worked out.
    bool m_bReserved74 = {};                    // +0x74: a byte flag the constructor zero-clears.
    // +0x75..+0x77 is alignment padding before the scales.
    // unsigned char m_aPad75[3]; // +0x75 (alignment padding, compiler-inserted)
    float m_aScales[2] = {};              // +0x78: two scales the constructor seeds to 1.
    unsigned char m_aReserved80[4] = {};  // +0x80: further state, still being worked out.
    SideGauge m_aSides[kSideCount] = {};  // +0x84: the per-side gauge state (stride 8).
    unsigned char m_aReserved94[12] = {}; // +0x94: trailing layer state.
};

/**
 * @brief Adds a delta to a player colour's Reflec gauge value.
 * @param flDelta The amount to add.
 * @param pGauge The gauge layer.
 * @param nColor The player colour.
 * @ghidraAddress 0x18abfc
 */
void AddReflecGaugeValue(float flDelta, ReflecGaugeLayer *pGauge, int nColor);
/**
 * @brief Subtracts a delta from a player's Reflec gauge value on the matching side.
 * @param flDelta The amount to subtract.
 * @param pGauge The gauge layer.
 * @param nPlayer The player id, compared against the current play side to pick the gauge side.
 * @ghidraAddress 0x18acb8
 */
void SubReflecGaugeValue(float flDelta, ReflecGaugeLayer *pGauge, int nPlayer);

// code: language=Objective-C++
// kate: hl Objective-C++;
// vim: set ft=objcpp :
