//
//  long_note_layer.mm
//  REFLEC BEAT plus
//
//  The long-note particle effect layer (LongNoteLayer). Reconstructed from Ghidra project rb458,
//  program rb458. @ghidraAddress values are relative to the program image base.
//

#include "long_note_layer.h"

#include <cassert>

#include "bg_layer.h"
#include "long_note_sprite_table.h"
#include "neRender.h"
#include "neSpriteInstancing.h"
#include "neTexture.h"
#include "s_vector2.h"
#include "sprite_uv_table.h"

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

// The shared sprite-UV atlas the sprite types index (@ghidraAddress 0x2ef668).
extern const SpriteUvEntry g_aScoreGaugeUvTable[];

// The long-note sprite-type layout table (declared in long_note_sprite_table.h): read-only ROM
// data transcribed from the binary at 0x30dfa0.
const LongNoteSpriteType g_aLongNoteSpriteTypes[kLongNoteSpriteTypeCount] = {
    // {batchIndex, anchorX, anchorY, sizeW, sizeH, uvIndex}
    {0, 29f, 0f, 58f, 27f, 23},   // 0
    {0, 29f, 0f, 58f, 27f, 24},   // 1
    {0, 29f, 0f, 58f, 27f, 25},   // 2
    {0, 29f, 0f, 58f, 27f, 26},   // 3
    {0, 29f, 27f, 58f, 27f, 27},  // 4
    {0, 29f, 27f, 58f, 27f, 28},  // 5
    {0, 29f, 27f, 58f, 27f, 29},  // 6
    {0, 29f, 27f, 58f, 27f, 30},  // 7
    {1, 31f, 17f, 62f, 50f, 35},  // 8
    {1, 31f, 17f, 62f, 50f, 36},  // 9
    {1, 31f, 17f, 62f, 50f, 37},  // 10
    {1, 31f, 17f, 62f, 50f, 38},  // 11
    {1, 31f, 31f, 62f, 31f, 39},  // 12
    {1, 31f, 31f, 62f, 31f, 40},  // 13
    {1, 31f, 31f, 62f, 31f, 41},  // 14
    {1, 31f, 31f, 62f, 31f, 42},  // 15
    {2, 50f, 55f, 100f, 88f, 43}, // 16
    {2, 50f, 55f, 100f, 88f, 44}, // 17
    {2, 50f, 55f, 100f, 88f, 45}, // 18
    {2, 50f, 55f, 100f, 88f, 46}, // 19
    {0, 40f, 0f, 80f, 18f, 31},   // 20
    {0, 40f, 0f, 80f, 18f, 32},   // 21
    {0, 40f, 0f, 80f, 18f, 33},   // 22
    {0, 40f, 0f, 80f, 18f, 34},   // 23
    {0, 29f, 0f, 58f, 27f, 47},   // 24
    {0, 29f, 0f, 58f, 27f, 48},   // 25
    {0, 29f, 27f, 58f, 27f, 49},  // 26
    {0, 29f, 27f, 58f, 27f, 50},  // 27
    {1, 31f, 17f, 62f, 50f, 53},  // 28
    {1, 31f, 17f, 62f, 50f, 54},  // 29
    {1, 31f, 31f, 62f, 31f, 55},  // 30
    {1, 31f, 31f, 62f, 31f, 56},  // 31
    {2, 50f, 55f, 100f, 88f, 57}, // 32
    {2, 50f, 55f, 100f, 88f, 58}, // 33
    {0, 40f, 0f, 80f, 18f, 51},   // 34
    {0, 40f, 0f, 80f, 18f, 52},   // 35
};

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

/** @ghidraAddress 0x1818b4 */
void LongNoteLayer::CreateSprite(int nType,
                                 const S_VECTOR2 *pPosition,
                                 unsigned int nAlpha,
                                 float flLength,
                                 float flRotation,
                                 float flScale) {
    assert(nType >= 0);
    assert(nType < kLongNoteSpriteTypeCount);

    const LongNoteSpriteType &spriteType = g_aLongNoteSpriteTypes[nType];
    const SpriteUvEntry &uv = g_aScoreGaugeUvTable[spriteType.nUvIndex];
    ne::C_SPRITE_INSTANCING_2D *pBatch = m_apSprites[spriteType.nBatchIndex];
    const int nIndex = m_anBatchCount[spriteType.nBatchIndex];

    pBatch->SetSpritePosition(nIndex, *pPosition);
    pBatch->SetSpriteAnchor(nIndex, S_VECTOR2{spriteType.flAnchorX, spriteType.flAnchorY});
    pBatch->SetSpriteUvOrigin(nIndex, S_VECTOR2{uv.flOriginU, uv.flOriginV});
    pBatch->SetSpriteUvSize(nIndex, S_VECTOR2{uv.flSizeU, uv.flSizeV});
    pBatch->SetSpriteRotation(nIndex, flRotation);
    pBatch->SetSpriteColor(nIndex, 0xff, 0xff, 0xff, nAlpha);

    // The stretchable body types (below 0x14, and 0x18..0x21) size to the layout height and scale
    // both axes; the fixed-length types take their height from the length argument and draw at unit
    // y-scale.
    const bool bBodyType = nType < kLongNoteBodyBoundLow ||
                           (nType >= kLongNoteBodyRangeStart && nType < kLongNoteBodyRangeEnd);
    float flScaleY;
    if (bBodyType) {
        pBatch->SetSpriteSize(nIndex, S_VECTOR2{spriteType.flSizeW, spriteType.flSizeH});
        flScaleY = flScale;
    } else {
        pBatch->SetSpriteSize(nIndex, S_VECTOR2{spriteType.flSizeW, flLength});
        flScaleY = 1.0f;
    }
    pBatch->SetSpriteScale(nIndex, flScale, flScaleY);

    ++m_anBatchCount[spriteType.nBatchIndex];
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
