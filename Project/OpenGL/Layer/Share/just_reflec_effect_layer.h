/**
 * @file
 * The just-reflec effect layer, @c JustReflecEffectLayer.
 */

#pragma once

#include "playfieldlayerbase.h"
#include "s_vector2.h"

namespace ne {
class C_TEXTURE;
class C_SPRITE_INSTANCING_2D;
} // namespace ne

/**
 * The just-reflec effect layer (the just-timing charge-note build-up graphics).
 *
 * A process-wide singleton, built on first access, deriving from @c PlayFieldLayerBase. It owns one
 * atlas and one sprite instancer, drawn beneath the shared background layer, that presents the
 * charge-note graphics, plus a large table of per-charge records. Its instancer capacity is the sum
 * of a per-group capacity table computed by the constructor. The class carries no RTTI (it is
 * non-polymorphic), so the name is taken from the embedded @c __FILE__ basename
 * (@c just_reflec_effect_layer.mm) that its own assertions carry rather than confirmed from the
 * runtime metadata. Only the sprite-batch fields are modelled so far; the record table is kept as a
 * reserved span. The trailing @c // +0xNN comments document the original 32-bit offsets for
 * reference only.
 */
class JustReflecEffectLayer : public PlayFieldLayerBase {
public:
    /**
     * The process-wide just-reflec effect layer, created on first use.
     * @return The shared layer.
     * @ghidraAddress 0x180bf8
     */
    static JustReflecEffectLayer *shared();

    /**
     * Lazily builds the note-charge sprite: loads the gm_parts1 atlas and creates the sprite
     * instancer sized to the accumulated capacity (attaching it under the background layer's render
     * object, making it visible, binding the atlas, flagging additive blend, and, except on the
     * tutorial hardware, enabling its two texture-environment parameters).
     *
     * Guarded so the sprite is built only once.
     * @ghidraAddress 0x180c48
     */
    void LoadNoteChargeSprites();

    /**
     * The player colours a charge or particle may carry, asserted by @c Create and
     * @c CreateParticle (the valid colour range is @c [0, kPlayerColorMax)).
     */
    static constexpr int kPlayerColorMax = 2;
    /** The number of pooled charge records. */
    static constexpr int kChargeCount = 0x20;
    /** The number of pooled burst particles. */
    static constexpr int kParticleCount = 0x100;
    /** The number of sprite graphics @c CreateSprite can emit. */
    static constexpr int kSpriteTypeCount = 8;

    /**
     * Queues a charge record for a player colour at the given position and geometry.
     *
     * Finds the first free charge slot (up to @c kChargeCount) and stores the colour and the four
     * geometry floats; drops the charge when the pool is full.
     * @param nColor The player colour (0 or 1).
     * @param flX The charge X.
     * @param flY The charge Y.
     * @param flA A geometry parameter.
     * @param flB A geometry parameter.
     * @ghidraAddress 0x180cf4
     */
    void Create(int nColor, float flX, float flY, float flA, float flB);

    /**
     * Spawns a burst particle for a player colour near the given position.
     *
     * Finds the first free particle slot (up to @c kParticleCount), stores the colour and an offset
     * position (each axis offset by a random value in [-32, 32)), and seeds a randomised lifetime
     * (longer for colour 1).
     * @param nColor The player colour (0 or 1).
     * @param pPosition The base spawn position.
     * @ghidraAddress 0x180d8c
     */
    void CreateParticle(int nColor, const S_VECTOR2 *pPosition);

    /**
     * Advances the layer one frame: steps the two spin phases, emits each active charge
     * (plus a phase-driven number of burst particles), then ages and emits each active particle,
     * clearing both pools' spent entries.
     * @param flDeltaSeconds The frame delta in seconds.
     * @ghidraAddress 0x180ed4
     */
    void Update(float flDeltaSeconds);

    /**
     * Emits one charge sprite of the given type into the batch at the running write index.
     * @param nType The sprite graphic (0 through @c kSpriteTypeCount - 1).
     * @param pPosition The sprite position.
     * @param nAlpha The sprite alpha.
     * @param flRotation The sprite rotation, in radians.
     * @param flScale The sprite scale (applied to both axes).
     * @ghidraAddress 0x181140
     */
    void CreateSprite(int nType,
                      const S_VECTOR2 *pPosition,
                      unsigned int nAlpha,
                      float flRotation,
                      float flScale);

private:
    /**
     * Constructs the layer, chaining the base constructor, zero-clearing its record tables,
     * and accumulating the per-group capacity table into the instancer capacity.
     * @ghidraAddress 0x180b54
     */
    JustReflecEffectLayer();

    struct ChargeRecord {
        bool bActive = {};       /*!< Whether the slot holds a live charge. +0x00 */
        int nColor = {};         /*!< The player colour. +0x04 */
        S_VECTOR2 position = {}; /*!< The charge position. +0x08 */
        float flA = {};          /*!< The sprite rotation. +0x10 */
        float flB = {};          /*!< The alpha-weight geometry parameter. +0x14 */
    };

    struct BurstParticle {
        bool bActive = {}; /*!< Whether the slot holds a live particle. +0x00 */
        int nColor = {};   /*!< The player colour. +0x04 */
        int nSpriteType =
            {}; /*!< The sprite type (a randomised lifetime slot 2 through 7). +0x08 */
        S_VECTOR2 position = {}; /*!< The particle position. +0x0c */
        float flAge = {};        /*!< The elapsed age. +0x14 */
    };

    ne::C_TEXTURE *m_pTexture = {};             // +0x08: the gm_parts1 atlas.
    ne::C_SPRITE_INSTANCING_2D *m_pSprite = {}; // +0x10
    int m_nSpriteCount = {};                    // +0x18
    int m_nSpriteCapacity = {};                 // +0x1c: accumulated from the per-group table.
    bool m_bBuilt = {};                         // +0x20
    // +0x21: three reserved padding bytes.
    float m_flSpinPhaseA = {};                       // +0x24: wrapped to 400/3.
    float m_flSpinPhaseB = {};                       // +0x28: wrapped to 50/3.
    ChargeRecord m_aCharges[kChargeCount] = {};      // +0x2c
    BurstParticle m_aParticles[kParticleCount] = {}; // +0x32c: to +0x1b2c.
    unsigned char m_aReservedTail[0xc] = {};         // +0x1b2c: trailing state to the 0x1b38 size.
};
