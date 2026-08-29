/**
 * @file
 * The note-spawn ("born") effect layer, @c NoteBornLayer.
 */

#pragma once

#include "playfieldlayerbase.h"
#include "s_vector2.h"

namespace ne {
class C_TEXTURE;
class C_SPRITE_INSTANCING_2D;
} // namespace ne

/**
 * The note-spawn ("born") effect layer: the burst sprites shown as notes spawn.
 *
 * A process-wide singleton, built on first access, deriving from @c PlayFieldLayerBase. It owns one
 * additively-blended sprite instancer drawing from the @c gm_parts1 atlas and a pool of per-burst
 * effect records, each claimed by @c Create at a note's spawn position and animated by
 * @c RenderScoreGaugeEffects until its alpha reaches zero.
 *
 * The class carries no RTTI; the name comes from the @c __FILE__ path embedded in @c Create's
 * assertions (@c OpenGL/Layer/Share/note_born_layer.mm), which is the naming authority. The
 * trailing
 * @c // +0xNN comments document the original offsets for reference only.
 *
 * Reconstructed type @c NoteBornLayer: engine effect layer, 0xa30 bytes.
 */
class NoteBornLayer : public PlayFieldLayerBase {
public:
    /** The number of pooled spawn-burst effect records. */
    static constexpr int kEffectRecordCount = 128;

    /**
     * The number of player colours a spawn effect may take (the valid colour range is
     * @c [0, kPlayerColorMax)).
     */
    static constexpr int kPlayerColorMax = 2;

    /**
     * The process-wide note-spawn layer, created on first use.
     * @return The shared layer.
     * @ghidraAddress 0x18546c
     */
    static NoteBornLayer *shared();

    /**
     * Builds the spawn-burst sprite batch and binds its atlas on first use.
     *
     * Loads the @c gm_parts1 atlas, creates the world sprite batch sized to the layer's capacity,
     * attaches it under the background layer, makes it visible, and flags its 3D path; on a
     * non-tutorial build it also seeds two texture parameters. Guarded so it runs only once.
     * @ghidraAddress 0x1854bc
     */
    void LoadSprites();

    /**
     * Spawns a burst effect at @p flX, @p flY for a note of the given colour.
     *
     * Claims the first inactive pool slot and seeds it: marks it active, records whether the colour
     * is the second player colour (which selects the burst's atlas row), stores the position, and
     * resets the animation timer. A full pool drops the effect. Asserts the colour is in
     * @c [0, kPlayerColorMax).
     * @param nColor The note's player colour (0 or 1).
     * @param flX The effect's X position.
     * @param flY The effect's Y position.
     * @ghidraAddress 0x185564
     */
    void Create(int nColor, float flX, float flY);

    /**
     * Advances and redraws every live spawn-burst effect for the frame.
     *
     * Resets the live slot count, then for each pooled record: advances its animation timer,
     * samples the scale and alpha animation curves, deactivates the record once its alpha reaches
     * zero, and otherwise emits its burst sprite at the sampled scale and alpha. Finally publishes
     * the slot count to the instancer.
     * @param flDelta The frame's elapsed time.
     * @ghidraAddress 0x185600
     */
    void RenderScoreGaugeEffects(float flDelta);

private:
    /**
     * Constructs the layer: chains the base constructor, clears the sprite header and the
     * pooled effect records, and seeds the default scale pair to one.
     * @ghidraAddress 0x185408
     */
    NoteBornLayer();

    /**
     * Emits one spawn-burst sprite into the batch's next slot.
     *
     * Looks up the burst's atlas UV by its colour row, positions it with a fixed 31-pixel anchor
     * and size, applies the given scale, tints it opaque white at @p nAlpha, and advances the live
     * slot count.
     * @param nColorRow The burst's colour row (selects the atlas UV row).
     * @param flScale The uniform sprite scale.
     * @param position The burst screen position.
     * @param nAlpha The sprite alpha.
     * @ghidraAddress 0x1856e0
     */
    void
    EmitBurstSprite(unsigned int nColorRow, float flScale, const S_VECTOR2 &position, int nAlpha);

    struct EffectRecord {
        bool bActive = {}; /*!< Whether the record holds a live burst. +0x00 */
        // unsigned char aReserved01[3] = {}; // +0x01
        /**
         * Non-zero when the note's colour is the second player colour. +0x04
         *
         * It also selects the burst's atlas UV row.
         */
        unsigned int nColorRow = {};
        S_VECTOR2 position; /*!< The burst's screen position. +0x08 */
        float flTimer = {}; /*!< The burst's animation timer. +0x10 */
    };

    ne::C_TEXTURE *m_pTexture = {};             // +0x08: the gm_parts1 atlas.
    ne::C_SPRITE_INSTANCING_2D *m_pSprite = {}; // +0x10
    int m_nSlotCount = {};                      // +0x18
    int m_nCapacity = {};                       // +0x1c
    bool m_bLoaded = {};                        // +0x20
    // unsigned char m_aReserved21[3] = {};        // +0x21
    EffectRecord m_aEffects[kEffectRecordCount] = {}; // +0x24
    float m_aScale[2] = {};                           // +0xa24: seeded to one.
    // unsigned char m_aReservedA2c[4] = {}; // +0xa2c
};

// code: language=Objective-C++
// kate: hl Objective-C++;
// vim: set ft=objcpp :
