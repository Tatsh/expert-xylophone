/**
 * @file
 * The slide-note render layer, @c SlideNoteLayer.
 */

#pragma once

#include "playfieldlayerbase.h"

struct S_VECTOR2;

namespace ne {
class C_SPRITE_INSTANCING_2D;
class C_TEXTURE;
} // namespace ne

/**
 * @brief One slide-note trail record: the per-note trail state the layer animates and draws.
 *
 * A 44-byte record seeded by @c Create with the trail's colour, its two endpoints, and its
 * per-endpoint flags. The trailing @c // +0xNN comments document the byte offsets within the record.
 */
struct SlideNoteTrail {
    bool bActive = {};         // +0x00: whether the trail slot is in use.
    unsigned char nFlagA = {}; // +0x01: the first per-trail flag byte.
    // +0x02..+0x03 is alignment padding.
    unsigned char aPad02[2] = {}; // +0x02
    int nKind = {};               // +0x04: the trail kind/type.
    int nColor = {};              // +0x08: the note colour (0 or 1).
    float flStartX = {};          // +0x0c: the trail's start X.
    unsigned int nPacked10 = {};  // +0x10: a packed four-byte field (per-endpoint sub-flags).
    float flStartY = {};          // +0x14: the trail's start Y.
    float flEndX = {};            // +0x18: the trail's end X.
    unsigned char nFlagB = {};    // +0x1c: the second per-trail flag byte.
    unsigned char nFlagC = {};    // +0x1d: the third per-trail flag byte.
    unsigned char nFlagD = {};    // +0x1e: the fourth per-trail flag byte.
    // +0x1f is alignment padding.
    unsigned char aPad1f[1] = {}; // +0x1f
    float flEndY = {};            // +0x20: the trail's end Y.
    float flRotation = {};     // +0x24: the trail rotation (pi when the note is on the far side).
    unsigned char nFlagE = {}; // +0x28: the fifth per-trail flag byte.
    // +0x29..+0x2b is alignment padding to the 44-byte stride.
    unsigned char aPad29[3] = {}; // +0x29
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
    // The number of player colours a trail may take (the valid colour range is [0, kPlayerColorMax)).
    static constexpr int kPlayerColorMax = 2;

    /**
     * @brief Returns the slide-note layer singleton, constructing it on first use.
     * @ghidraAddress 0x95a90
     */
    static SlideNoteLayer *shared();

    /**
     * @brief Spawns a slide-note trail into the pool, seeding its colour, endpoints, and flags.
     *
     * Claims the first inactive pooled trail from the shared active-trail cursor and seeds it: the
     * kind, colour, start and end positions, the per-trail flag bytes, a packed sub-flag word, and a
     * rotation of a half-turn when the note is on the opposite play side (else none). A full pool
     * drops the trail. Asserts the colour is in @c [0, kPlayerColorMax).
     * @param nColor The note's player colour (0 or 1).
     * @param nFlagA The first per-trail flag byte.
     * @param nKind The trail kind/type.
     * @param flStartX The trail's start X.
     * @param nPacked10 The packed four-byte sub-flag field.
     * @param flStartY The trail's start Y.
     * @param flEndX The trail's end X.
     * @param nFlagB The second per-trail flag byte.
     * @param nFlagC The third per-trail flag byte.
     * @param nFlagE The fifth per-trail flag byte.
     * @param flEndY The trail's end Y.
     * @param nFlagD The fourth per-trail flag byte.
     * @ghidraAddress 0x95bc0
     */
    void Create(int nColor,
                unsigned char nFlagA,
                int nKind,
                float flStartX,
                unsigned int nPacked10,
                float flStartY,
                float flEndX,
                unsigned char nFlagB,
                unsigned char nFlagC,
                unsigned char nFlagE,
                float flEndY,
                unsigned char nFlagD);

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

    /**
     * @brief Emits one trail sprite of the given type into its batch.
     *
     * Looks up the sprite type's batch, anchor, size, and UV-table index from the layout table, then
     * appends a sprite at @p pPosition with the given alpha, rotation, and scale. The head/tail types
     * (below @c kSlideNoteGlowTypeBase) size to the layout height and scale both axes by @p flScale;
     * the glow types (@c kSlideNoteGlowTypeBase and up) take their height from @p flLength, scale x by
     * @p flScale, and draw at unit y-scale. The colour is always opaque white modulated by @p nAlpha.
     * @param nType The sprite type (0 through 15).
     * @param pPosition The sprite position.
     * @param nAlpha The sprite alpha.
     * @param flLength The sprite height for the glow types (unused by the head/tail types).
     * @param flRotation The sprite rotation, in radians.
     * @param flScale The sprite scale factor (applied to both axes for the head/tail types, x only
     *        for the glow types).
     * @ghidraAddress 0x96164
     */
    void CreateSprite(int nType,
                      const S_VECTOR2 *pPosition,
                      unsigned int nAlpha,
                      float flLength,
                      float flRotation,
                      float flScale);

private:
    ne::C_TEXTURE *m_pTexture = {};                            // +0x08: the slide-trail atlas.
    ne::C_SPRITE_INSTANCING_2D *m_apBatches[kBatchCount] = {}; // +0x10: the trail sprite batches.
    int m_anBatchCount[kBatchCount] = {};                      // +0x28: each batch's sprite count.
    bool m_bBuilt = {};                         // +0x34: whether the sprites are built.
    unsigned char m_aReserved35[3] = {};        // +0x35
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
