/**
 * @file
 * The note-charge layer, @c NoteChargeLayer.
 */

#pragma once

#include "playfieldlayerbase.h"

struct S_VECTOR2;

namespace ne {
class C_TEXTURE;
class C_SPRITE_INSTANCING_2D;
} // namespace ne

/**
 * @brief The note-charge layer (the charge-note build-up graphics).
 *
 * A process-wide singleton, built on first access, deriving from @c PlayFieldLayerBase. It owns one
 * atlas and one sprite instancer, drawn beneath the shared background layer, that presents the
 * charge-note graphics, plus a large table of per-charge records. Its instancer capacity is the sum
 * of a per-group capacity table computed by the constructor. The class carries no RTTI (it is
 * non-polymorphic), so the name is inferred from its singleton getter rather than confirmed from the
 * runtime metadata. Only the sprite-batch fields are modelled so far; the record table is kept as a
 * reserved span. The trailing @c // +0xNN comments document the original 32-bit offsets for
 * reference only.
 */
class NoteChargeLayer : public PlayFieldLayerBase {
public:
    /**
     * @brief The process-wide note-charge layer, created on first use.
     * @return The shared layer.
     * @ghidraAddress 0x180bf8
     */
    static NoteChargeLayer *shared();

    /**
     * @brief Lazily builds the note-charge sprite: loads the gm_parts1 atlas and creates the sprite
     * instancer sized to the accumulated capacity (attaching it under the background layer's render
     * object, making it visible, binding the atlas, flagging additive blend, and, except on the
     * tutorial hardware, enabling its two texture-environment parameters).
     *
     * Guarded so the sprite is built only once.
     * @ghidraAddress 0x180c48
     */
    void LoadNoteChargeSprites();

    // The player colours a charge/particle may carry (asserted by Create/CreateParticle), the number
    // of pooled charge records and burst particles, and the number of sprite graphics CreateSprite
    // can emit.
    static constexpr int kPlayerColorMax = 2;
    static constexpr int kChargeCount = 0x20;
    static constexpr int kParticleCount = 0x100;
    static constexpr int kSpriteTypeCount = 8;

    /**
     * @brief Queues a charge record for a player colour at the given position and geometry.
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
     * @brief Spawns a burst particle for a player colour near the given position.
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
     * @brief Advances the layer one frame: steps the two spin phases, emits each active charge (plus
     * a phase-driven number of burst particles), then ages and emits each active particle, clearing
     * both pools' spent entries.
     * @param flDeltaSeconds The frame delta in seconds.
     * @ghidraAddress 0x180ed4
     */
    void Update(float flDeltaSeconds);

    /**
     * @brief Emits one charge sprite of the given type into the batch at the running write index.
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
     * @brief Constructs the layer, chaining the base constructor, zero-clearing its record tables,
     * and accumulating the per-group capacity table into the instancer capacity.
     * @ghidraAddress 0x180b54
     */
    NoteChargeLayer();

    // One pooled charge record (24 bytes): its colour, position, and geometry.
    struct ChargeRecord {
        bool bActive = {};       // +0x00: whether the slot holds a live charge.
        int nColor = {};         // +0x04: the player colour.
        S_VECTOR2 position = {}; // +0x08: the charge position.
        float flA = {};          // +0x10: the sprite rotation.
        float flB = {};          // +0x14: the alpha-weight geometry parameter.
    };

    // One pooled burst particle (24 bytes): its colour, lifetime-slot sprite type, position, and age.
    struct BurstParticle {
        bool bActive = {};       // +0x00: whether the slot holds a live particle.
        int nColor = {};         // +0x04: the player colour.
        int nSpriteType = {};    // +0x08: the sprite type (a randomised lifetime slot 2 through 7).
        S_VECTOR2 position = {}; // +0x0c: the particle position.
        float flAge = {};        // +0x14: the elapsed age.
    };

    ne::C_TEXTURE *m_pTexture = {};             // +0x08: the gm_parts1 atlas.
    ne::C_SPRITE_INSTANCING_2D *m_pSprite = {}; // +0x10: the note-charge sprite instancer.
    int m_nSpriteCount = {};                    // +0x18: the instancer's live sprite count.
    int m_nSpriteCapacity = {}; // +0x1c: the accumulated instancer capacity (sprite count).
    bool m_bBuilt = {};         // +0x20: set once the sprite is built.
    // +0x21..+0x23 is alignment padding before the spin phases.
    unsigned char m_aReserved21[3] = {};        // +0x21
    float m_flSpinPhaseA = {};                  // +0x24: a spin phase, wrapped to 400/3.
    float m_flSpinPhaseB = {};                  // +0x28: a spin phase, wrapped to 50/3.
    ChargeRecord m_aCharges[kChargeCount] = {}; // +0x2c: the pooled charge records.
    BurstParticle m_aParticles[kParticleCount] =
        {};                                  // +0x32c: the pooled burst particles (to 0x1b2c).
    unsigned char m_aReservedTail[0xc] = {}; // +0x1b2c: trailing state to the 0x1b38 size.
};

// code: language=C++
// kate: hl C++;
// vim: set ft=cpp :
