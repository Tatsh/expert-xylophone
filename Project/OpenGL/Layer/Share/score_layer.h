/**
 * @file
 * The score/combo layer, @c ScoreLayer.
 */

#pragma once

#include "playfieldlayerbase.h"

namespace ne {
class C_TEXTURE;
class C_SPRITE_INSTANCING;
} // namespace ne

/**
 * @brief The score/combo layer (the gauge slider and score/combo digits).
 *
 * A process-wide singleton, built on first access, deriving from @c PlayFieldLayerBase. It owns one
 * atlas and four sprite instancers, drawn beneath the shared background layer, that present the
 * gauge slider and score digits. The class carries no RTTI (it is non-polymorphic), so the name is
 * inferred from its singleton getter rather than confirmed from the runtime metadata. The trailing
 * @c // +0xNN comments document the original 32-bit offsets for reference only.
 */
class ScoreLayer : public PlayFieldLayerBase {
public:
    // The number of gauge/slider sprite instancers the layer builds.
    static constexpr int kBatchCount = 4;
    // The number of part groups whose capacities the constructor accumulates.
    static constexpr int kPartGroupCount = 6;

    /**
     * @brief The process-wide score/combo layer, created on first use.
     * @return The shared layer.
     * @ghidraAddress 0x18a88c
     */
    static ScoreLayer *shared();

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

private:
    /**
     * @brief Constructs the layer, chaining the base constructor, seeding its transform scales, and
     * accumulating each batch's per-group capacities.
     * @ghidraAddress 0x18a7d0
     */
    ScoreLayer();

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
    float m_aScales[2] = {};                // +0x78: two scales the constructor seeds to 1.
    unsigned char m_aReserved80[0x20] = {}; // +0x80: further state, still being worked out.
};

// code: language=C++
// kate: hl C++;
// vim: set ft=cpp :
