/**
 * @file
 * The slide-note render layer, @c SlideNoteLayer.
 */

#pragma once

#include "playfieldlayerbase.h"

namespace ne {
class C_SPRITE_INSTANCING;
class C_TEXTURE;
} // namespace ne

/**
 * @brief One slide-note trail record: the per-note trail state the layer animates and draws.
 *
 * A 44-byte record; the constructor clears the active flag and the leading 16-byte block. The
 * remaining fields are the trail's animation state, still being worked out. The trailing
 * @c // +0xNN comments document the byte offsets within the record.
 */
struct SlideNoteTrail {
    bool bActive = {};                  // +0x00: whether the trail slot is in use.
    unsigned char aReserved01[11] = {}; // +0x01: further trail state before the animated block.
    unsigned char aAnimBlock[16] = {};  // +0x0c: the animated trail block cleared on construct.
    unsigned char aReserved1c[16] = {}; // +0x1c: the remaining trail state.
};

/**
 * @brief The slide-note render layer: animates and draws the slide (long-note) trails.
 *
 * A @c PlayFieldLayerBase subclass holding three sprite batches and a pool of slide-trail records.
 * The trailing @c // +0xNN comments document the original member offsets for reference only; the
 * animation fields between the recovered members are reserved until the animate/draw family is
 * reconstructed.
 */
class SlideNoteLayer : public PlayFieldLayerBase {
public:
    // The number of sprite batches the layer owns and the number of slide-trail records it pools.
    static constexpr int kBatchCount = 3;
    static constexpr int kTrailCount = 80;

    /**
     * @brief Returns the slide-note layer singleton, constructing it on first use.
     * @ghidraAddress 0x95a90
     */
    static SlideNoteLayer *shared();

    /**
     * @brief Constructs (and resets) the layer: chains the base constructor, clears the built flag
     * and the invalid-clock sentinel, zeroes every slide-trail record, clears the three sprite
     * batches and their counts, and resets the shared active-trail count.
     * @ghidraAddress 0x95a18
     */
    SlideNoteLayer();

    /**
     * @brief Builds the three slide-note sprite batches under the background render object (once).
     *
     * Loads the gm_parts1 atlas, creates each batch, attaches it, makes it visible, binds the atlas,
     * and resets its count; batches 0 and 2 use additive blending, and on the newer hardware each
     * batch's wrap sampler parameters are set.
     * @ghidraAddress 0x95ae0
     */
    void BuildSprites();

private:
    ne::C_TEXTURE *m_pTexture = {};                         // +0x08: the slide-trail atlas.
    ne::C_SPRITE_INSTANCING *m_apBatches[kBatchCount] = {}; // +0x10: the trail sprite batches.
    int m_anBatchCount[kBatchCount] = {};                   // +0x28: each batch's sprite count.
    bool m_bBuilt = {};                                     // +0x34: whether the sprites are built.
    unsigned char m_aReserved35[3] = {};                    // +0x35
    float m_flLastClock = {};                   // +0x38: the last sample clock (-1 when invalid).
    unsigned char m_aReserved3c[4] = {};        // +0x3c
    SlideNoteTrail m_aTrails[kTrailCount] = {}; // +0x40: the slide-trail record pool.
    unsigned char m_aReservedTail[8] = {};      // +0xe00: trailing layer state to the 0xe08 size.
};

/**
 * @brief The number of active slide-note trails, reset by the layer constructor.
 * @ghidraAddress 0x3dc650
 */
extern int g_nActiveSlideTrailCount;

// code: language=C++
// kate: hl C++;
// vim: set ft=cpp :
