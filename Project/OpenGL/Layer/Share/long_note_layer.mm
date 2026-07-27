//
//  long_note_layer.mm
//  REFLEC BEAT plus
//
//  The long-note particle effect layer (LongNoteLayer). Reconstructed from Ghidra project rb458,
//  program rb458. @ghidraAddress values are relative to the program image base.
//

#include "long_note_layer.h"

#include "bg_layer.h"
#include "neRender.h"
#include "neSpriteInstancing.h"
#include "neTexture.h"

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

// The atlas the particle sprites draw from.
constexpr const char *kAtlasTextureName = "00_texture_gm_parts1";

// The particle batches draw additively; the middle batch seeds two texture parameters.
constexpr int kAdditiveBlendMode = 1;
constexpr int kTexParamValue = 1;
} // namespace

// The shared particle active index, reset when the layer is constructed and advanced as particles
// spawn.
int g_nParticleActiveIndex = {}; // @ghidraAddress 0x3df228

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
        m_anBatchCapacity[kBatchSeedIndex[i]] += kBatchSeedCount[i];
    }
}

/** @ghidraAddress 0x188954 */
void LongNoteLayer::CreateSpriteBatches() {
    if (m_bBuilt) {
        return;
    }

    ne::C_RENDER *pParent = BgLayer::GetBackgroundLayer()->GetBackgroundRenderObject();
    m_pTexture = ne::C_TEXTURE::FindOrLoadCached(kAtlasTextureName);
    for (int i = 0; i < kBatchCount; ++i) {
        ne::C_SPRITE_INSTANCING_2D *pSprite =
            ne::CreateWorldSpriteBatch(static_cast<unsigned int>(m_anBatchCapacity[i]));
        m_apSprites[i] = pSprite;
        pParent->AttachChild(pSprite);
        pSprite->SetVisible(true);
        pSprite->SetRefCountedMember(m_pTexture);
        pSprite->SetSpriteCount(0);
        // The outer two batches (0 and 2) draw additively.
        if (i != 1) {
            pSprite->SetBlendMode(kAdditiveBlendMode);
        }
        // The middle batch seeds two texture parameters on a non-tutorial build.
        if (i == 1 && !IsHardwareType9()) {
            pSprite->SetTexParam(1, kTexParamValue);
            pSprite->SetTexParam(0, kTexParamValue);
        }
    }

    m_bBuilt = true;
    g_nParticleActiveIndex = 0;
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
