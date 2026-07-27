/**
 * @file
 * The long-note particle effect layer, @c LongNoteLayer.
 */

#pragma once

#include "playfieldlayerbase.h"

namespace ne {
class C_TEXTURE;
class C_SPRITE_INSTANCING;
} // namespace ne

// The shared particle active index, reset when the layer is constructed and advanced as particles
// spawn.
extern int g_nParticleActiveIndex; // @ghidraAddress 0x3df228

/**
 * @brief The long-note particle effect layer: a 256-slot particle pool drawn through three sprite
 * batches.
 *
 * A process-wide singleton, built on first access, deriving from @c PlayFieldLayerBase. The class
 * carries no RTTI, so the name is inferred from its @c GetLongNoteLayer accessor. Only the fields the
 * reconstructed methods touch are modelled; the trailing @c // +0xNN comments document the original
 * offsets for reference only.
 * @ghidraAddress LongNoteLayer (engine effect layer, 0x1c50 bytes)
 */
class LongNoteLayer : public PlayFieldLayerBase {
public:
    // The number of pooled particles and the number of sprite batches.
    static constexpr int kParticleCount = 256;
    static constexpr int kBatchCount = 3;

    /**
     * @brief The process-wide long-note particle layer, created on first use.
     * @return The shared layer.
     * @ghidraAddress 0x188904
     */
    static LongNoteLayer *shared();

    /**
     * @brief Spawns a particle from the pool with a position, scale, and kind.
     *
     * Scans the pool from the shared active index for a free slot; on finding one it stores the
     * particle kind (7 for @p nType 1, else 6), position, and scale, and advances the active index.
     * A full pool drops the particle.
     * @param flX The spawn X.
     * @param flY The spawn Y.
     * @param flScaleX The particle X scale.
     * @param flScaleY The particle Y scale.
     * @param nType The particle type selector (1 selects kind 7, else kind 6).
     * @ghidraAddress 0x188c50
     */
    void SpawnParticle(float flX, float flY, float flScaleX, float flScaleY, int nType);

private:
    /**
     * @brief Constructs the layer: chains the base constructor, clears the header and particle pool,
     * resets the shared active index, and seeds each sprite batch's capacity from the seed tables.
     * @ghidraAddress 0x188850
     */
    LongNoteLayer();

    /** @brief One pooled particle (28 bytes): its active flag, kind, position, and scale. */
    struct Particle {
        bool bActive = {};                 // +0x00: whether the slot holds a live particle.
        unsigned char aReserved01[3] = {}; // +0x01
        int nKind = {};                    // +0x04: the particle kind (6 or 7).
        float flX = {};                    // +0x08: the particle X.
        float flY = {};                    // +0x0c: the particle Y.
        float flReserved10 = {};           // +0x10: a per-particle scratch value.
        float flScaleX = {};               // +0x14: the particle X scale.
        float flScaleY = {};               // +0x18: the particle Y scale.
    };

    ne::C_TEXTURE *m_pTexture = {};                         // +0x08: the particle atlas.
    ne::C_SPRITE_INSTANCING *m_apSprites[kBatchCount] = {}; // +0x10: the three sprite batches.
    unsigned char m_aReserved28[0x28] = {};                 // +0x28: batch counters and header.
    Particle m_aParticles[kParticleCount] = {}; // +0x50: the pooled particles (to 0x1c50).
};

// code: language=C++
// kate: hl C++;
// vim: set ft=cpp :
