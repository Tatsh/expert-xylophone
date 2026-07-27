//
//  long_note_layer.mm
//  REFLEC BEAT plus
//
//  The long-note particle effect layer (LongNoteLayer). Reconstructed from Ghidra project rb458,
//  program rb458. @ghidraAddress values are relative to the program image base.
//

#include "long_note_layer.h"

namespace {
// The particle kinds: type 1 spawns kind 7, every other type kind 6.
constexpr int kParticleKindDefault = 6;
constexpr int kParticleKindAlt = 7;
constexpr int kParticleTypeAlt = 1;

// The per-batch capacity seed tables: for each of the twelve entries, the destination batch index
// and the count added to that batch's capacity (@ghidraAddress 0x30f6f4 indices, 0x30f724 counts).
constexpr int kBatchSeedIndex[] = {0, 1, 1, 1, 1, 1, 1, 2, 1, 1, 1, 1};
constexpr int kBatchSeedCount[] = {512, 256, 256, 256, 256, 256, 256, 512, 256, 256, 256, 256};
constexpr int kBatchSeedEntryCount = 12;
} // namespace

// The shared particle active index, reset when the layer is constructed and advanced as particles
// spawn.
int g_nParticleActiveIndex = {}; // @ghidraAddress 0x3df228

// The per-batch sprite capacities the constructor accumulates from the seed tables.
static int g_anLongNoteBatchCapacity[LongNoteLayer::kBatchCount] = {};

// The process-wide long-note particle layer, created lazily by shared().
static LongNoteLayer *g_pLongNoteLayer = nullptr; // @ghidraAddress 0x3df230

/** @ghidraAddress 0x188904 */
LongNoteLayer *LongNoteLayer::shared() {
    if (g_pLongNoteLayer == nullptr) {
        g_pLongNoteLayer = new LongNoteLayer();
    }
    return g_pLongNoteLayer;
}

/** @ghidraAddress 0x188850 */
LongNoteLayer::LongNoteLayer() {
    // The base constructor and member initialisers clear the header and particle pool; reset the
    // shared active index and accumulate each batch's capacity from the seed tables.
    g_nParticleActiveIndex = 0;
    for (int i = 0; i < kBatchSeedEntryCount; ++i) {
        g_anLongNoteBatchCapacity[kBatchSeedIndex[i]] += kBatchSeedCount[i];
    }
}

/** @ghidraAddress 0x188c50 */
void LongNoteLayer::SpawnParticle(float flX, float flY, float flScaleX, float flScaleY, int nType) {
    const int nKind = nType == kParticleTypeAlt ? kParticleKindAlt : kParticleKindDefault;
    // Scan from the shared active index for a free slot; a full pool drops the particle.
    for (int nSlot = g_nParticleActiveIndex; nSlot < kParticleCount; ++nSlot) {
        Particle &particle = m_aParticles[nSlot];
        if (!particle.bActive) {
            particle.nKind = nKind;
            particle.bActive = true;
            particle.flX = flX;
            particle.flY = flY;
            particle.flReserved10 = 0.0f;
            particle.flScaleX = flScaleX;
            particle.flScaleY = flScaleY;
            ++g_nParticleActiveIndex;
            return;
        }
    }
}
