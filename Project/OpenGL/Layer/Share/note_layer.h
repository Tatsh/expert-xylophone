/**
 * @file
 * The shared note particle-layer base, @c NoteLayer.
 */

#pragma once

#include "playfieldlayerbase.h"

struct S_VECTOR2;

namespace ne {
class C_TEXTURE;
class C_SPRITE_INSTANCING_2D;
} // namespace ne

// The shared particle active index, reset when a note layer is constructed and advanced as particles
// spawn.
extern int g_nParticleActiveIndex; // @ghidraAddress 0x3df228

/**
 * @brief The shared base for the note particle layers.
 *
 * Owns a pooled-particle system drawn through three sprite batches: a 256-slot particle pool, the
 * per-batch instancers, counts, and capacities, and three scrolling animation phases. @c LongNoteLayer
 * derives from it, adding the long-note-specific spawn and connector logic. The base provides the
 * per-frame @c Update pass (which advances the scroll phases and emits each live particle's sprites)
 * and the low-level @c CreateSprite emitter. The class carries no RTTI (it is non-polymorphic), so the
 * name is inferred from its embedded @c note_layer.mm path. The trailing @c // +0xNN comments document
 * the original 32-bit offsets for reference only.
 */
class NoteLayer : public PlayFieldLayerBase {
public:
    // The number of pooled particles, the number of sprite batches, and the number of scroll phases.
    static constexpr int kParticleCount = 256;
    static constexpr int kBatchCount = 3;
    static constexpr int kScrollPhaseCount = 3;

    /**
     * @brief Advances the scroll phases and emits every live particle's sprites for the frame.
     *
     * Advances the three scrolling animation phases (each wrapped into its range), derives the frame's
     * rotation and a triangle-wave global fade, and reads the play colour to pick the two per-lane
     * colour multipliers. It then walks the particle pool up to the shared active index: each live slot
     * is consumed (its active flag cleared) and, by its kind, emits the sprite quad(s) that make it up
     * through @c CreateSprite. Finally it publishes each batch's slot count to its instancer and resets
     * the shared active index.
     * @param flDelta The frame's elapsed time.
     * @ghidraAddress 0x188cc0
     */
    void Update(float flDelta);

    /**
     * @brief Emits one particle sprite of the given type into its batch, if the batch has room.
     *
     * Looks the type up in the descriptor table for its anchor, size, and UV-table index and the
     * per-type batch index, then appends a sprite at @p pPosition with the given scale (applied to
     * both axes), rotation, and alpha. The colour is always opaque white modulated by @p nAlpha. A
     * no-op once the batch is full.
     * @param nType The sprite type (0 through 11).
     * @param pPosition The sprite position.
     * @param nAlpha The sprite alpha.
     * @param flScale The sprite scale factor.
     * @param flRotation The sprite rotation, in radians.
     * @ghidraAddress 0x189104
     */
    void CreateSprite(
        int nType, const S_VECTOR2 *pPosition, int nAlpha, float flScale, float flRotation);

protected:
    /** @brief One pooled particle (28 bytes): its active flag, kind, position, rotation, and scale. */
    struct Particle {
        bool bActive = {};                 // +0x00: whether the slot holds a live particle.
        unsigned char aReserved01[3] = {}; // +0x01
        int nKind = {};                    // +0x04: the particle kind (0 through 11).
        float flX = {};                    // +0x08: the particle X.
        float flY = {};                    // +0x0c: the particle Y.
        float flRotation = {};             // +0x10: the particle rotation, in radians.
        float flScaleX = {};               // +0x14: the particle X scale.
        float flScaleY = {};               // +0x18: the particle Y scale.
    };

    ne::C_TEXTURE *m_pTexture = {};                            // +0x08: the particle atlas.
    ne::C_SPRITE_INSTANCING_2D *m_apSprites[kBatchCount] = {}; // +0x10: the three sprite batches.
    int m_anBatchCount[kBatchCount] = {};                      // +0x28: each batch's live count.
    int m_anBatchCapacity[kBatchCount] = {};                   // +0x34: each batch's capacity.
    bool m_bBuilt = {};                           // +0x40: set once the batches are built.
    unsigned char m_aReserved41[3] = {};          // +0x41
    float m_aScrollPhase[kScrollPhaseCount] = {}; // +0x44: the three scroll phases.
    Particle m_aParticles[kParticleCount] = {};   // +0x50: the pooled particles.
};

// code: language=C++
// kate: hl C++;
// vim: set ft=cpp :
