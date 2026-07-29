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
 * per-endpoint flags. The trailing @c // +0xNN comments document the byte offsets within the
 * record.
 */
struct SlideNoteTrail {
    bool bActive = {};         /*!< Whether the trail slot is in use. +0x00 */
    unsigned char nFlagA = {}; /*!< The first per-trail flag byte. +0x01 */
    // unsigned char aPad02[2] = {}; /*!< Alignment padding. +0x02..+0x03 */
    int nKind = {};  /*!< The trail kind/type. +0x04 */
    int nColor = {}; /*!< The note colour (0 or 1). +0x08 */
    // +0x0c..+0x18: the trail's two endpoints (the animated end at +0x0c, the target at +0x14); the
    // update draws the comet between them.
    float flEndX = {};         /*!< The animated endpoint X. +0x0c */
    float flEndY = {};         /*!< The animated endpoint Y. +0x10 */
    float flTargetX = {};      /*!< The target endpoint X. +0x14 */
    float flTargetY = {};      /*!< The target endpoint Y. +0x18 */
    unsigned char nFlagB = {}; /*!< The second per-trail flag byte. +0x1c */
    unsigned char nFlagC = {}; /*!< The third per-trail flag byte. +0x1d */
    unsigned char nFlagD = {}; /*!< The fourth per-trail flag byte. +0x1e */
    // unsigned char aPad1f[1] = {}; /*!< Alignment padding. +0x1f */
    float flAlphaScale = {}; /*!< A per-trail alpha/scale value seeded by Create. +0x20 */
    float flRotation = {};   /*!< The trail rotation (pi when the note is on the far side). +0x24 */
    unsigned char nFlagE = {}; /*!< The fifth per-trail flag byte. +0x28 */
    // unsigned char aPad29[3] = {}; /*!< Alignment padding to the 44-byte stride. +0x29..+0x2b */
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
    // The number of player colours a trail may take (the valid colour range is [0,
    // kPlayerColorMax)).
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
     * kind, colour, the animated and target endpoints, the per-trail flag bytes, the alpha/scale
     * value, and a rotation of a half-turn when the note is on the opposite play side (else none).
     * A full pool drops the trail. Asserts the colour is in @c [0, kPlayerColorMax).
     * @param nColor The note's player colour (0 or 1).
     * @param nFlagA The first per-trail flag byte.
     * @param nKind The trail kind/type.
     * @param flEndX The animated endpoint X.
     * @param flEndY The animated endpoint Y.
     * @param flTargetX The target endpoint X.
     * @param flTargetY The target endpoint Y.
     * @param flAlphaScale The per-trail alpha/scale value.
     * @param nFlagB The second per-trail flag byte.
     * @param nFlagC The third per-trail flag byte.
     * @param nFlagD The fourth per-trail flag byte.
     * @param nFlagE The fifth per-trail flag byte.
     * @ghidraAddress 0x95bc0
     */
    void Create(int nColor,
                unsigned char nFlagA,
                int nKind,
                float flEndX,
                float flEndY,
                float flTargetX,
                float flTargetY,
                float flAlphaScale,
                unsigned char nFlagB,
                unsigned char nFlagC,
                unsigned char nFlagD,
                unsigned char nFlagE);

    /**
     * @brief Advances and renders every active slide trail for one frame.
     *
     * Resets the batch counts, advances the shared pulse clock (wrapped to its period) and the
     * 0-to-29 frame counter (from which it derives a triangular fade factor and a scale-pulse
     * factor), and picks the two per-side alpha factors from the game system. For each active trail
     * it computes the comet vector between the trail's two endpoints, its length, and (once long
     * enough or flagged) its angle, then emits the trail's body, glow, and cap sprites — their
     * sprite kinds selected from the trail's flag bytes, colour, and kind — adding an extra sparkle
     * sprite during the early part of the pulse. Finally it publishes each batch's sprite count and
     * clears the shared active-trail count.
     * @param flDeltaTime The frame delta.
     * @ghidraAddress 0x95d14
     */
    void Update(float flDeltaTime);

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
     * Loads the gm_parts1 atlas, creates each batch, attaches it, makes it visible, binds the
     * atlas, and resets its count; batches 0 and 2 use additive blending, and on the newer hardware
     * each batch's wrap sampler parameters are set.
     * @ghidraAddress 0x95ae0
     */
    void BuildSprites();

    /**
     * @brief Emits one trail sprite of the given type into its batch.
     *
     * Looks up the sprite type's batch, anchor, size, and UV-table index from the layout table,
     * then appends a sprite at @p pPosition with the given alpha, rotation, and scale. The
     * head/tail types (below @c kSlideNoteGlowTypeBase) size to the layout height and scale both
     * axes by @p flScale; the glow types (@c kSlideNoteGlowTypeBase and up) take their height from
     * @p flLength, scale x by
     * @p flScale, and draw at unit y-scale. The colour is always opaque white modulated by @p
     * nAlpha.
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
    bool m_bBuilt = {}; // +0x34: whether the sprites are built.
    // unsigned char m_aReserved35[3] = {};        // +0x35
    float m_flLastClock = {};                   // +0x38: the pulse clock, wrapped to its period.
    int m_nFrameCounter = {};                   // +0x3c: the 0-to-29 per-frame animation counter.
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
