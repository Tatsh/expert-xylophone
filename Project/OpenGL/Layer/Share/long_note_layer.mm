//
//  long_note_layer.mm
//  REFLEC BEAT plus
//
//  The long-note particle effect layer (LongNoteLayer). Reconstructed from Ghidra project rb458,
//  program rb458. @ghidraAddress values are relative to the program image base.
//

#include "long_note_layer.h"

#include <cassert>
#include <cmath>

#include "bg_layer.h"
#include "gamesystem.h"
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
    {0, 29.0f, 0.0f, 58.0f, 27.0f, 23},   // 0
    {0, 29.0f, 0.0f, 58.0f, 27.0f, 24},   // 1
    {0, 29.0f, 0.0f, 58.0f, 27.0f, 25},   // 2
    {0, 29.0f, 0.0f, 58.0f, 27.0f, 26},   // 3
    {0, 29.0f, 27.0f, 58.0f, 27.0f, 27},  // 4
    {0, 29.0f, 27.0f, 58.0f, 27.0f, 28},  // 5
    {0, 29.0f, 27.0f, 58.0f, 27.0f, 29},  // 6
    {0, 29.0f, 27.0f, 58.0f, 27.0f, 30},  // 7
    {1, 31.0f, 17.0f, 62.0f, 50.0f, 35},  // 8
    {1, 31.0f, 17.0f, 62.0f, 50.0f, 36},  // 9
    {1, 31.0f, 17.0f, 62.0f, 50.0f, 37},  // 10
    {1, 31.0f, 17.0f, 62.0f, 50.0f, 38},  // 11
    {1, 31.0f, 31.0f, 62.0f, 31.0f, 39},  // 12
    {1, 31.0f, 31.0f, 62.0f, 31.0f, 40},  // 13
    {1, 31.0f, 31.0f, 62.0f, 31.0f, 41},  // 14
    {1, 31.0f, 31.0f, 62.0f, 31.0f, 42},  // 15
    {2, 50.0f, 55.0f, 100.0f, 88.0f, 43}, // 16
    {2, 50.0f, 55.0f, 100.0f, 88.0f, 44}, // 17
    {2, 50.0f, 55.0f, 100.0f, 88.0f, 45}, // 18
    {2, 50.0f, 55.0f, 100.0f, 88.0f, 46}, // 19
    {0, 40.0f, 0.0f, 80.0f, 18.0f, 31},   // 20
    {0, 40.0f, 0.0f, 80.0f, 18.0f, 32},   // 21
    {0, 40.0f, 0.0f, 80.0f, 18.0f, 33},   // 22
    {0, 40.0f, 0.0f, 80.0f, 18.0f, 34},   // 23
    {0, 29.0f, 0.0f, 58.0f, 27.0f, 47},   // 24
    {0, 29.0f, 0.0f, 58.0f, 27.0f, 48},   // 25
    {0, 29.0f, 27.0f, 58.0f, 27.0f, 49},  // 26
    {0, 29.0f, 27.0f, 58.0f, 27.0f, 50},  // 27
    {1, 31.0f, 17.0f, 62.0f, 50.0f, 53},  // 28
    {1, 31.0f, 17.0f, 62.0f, 50.0f, 54},  // 29
    {1, 31.0f, 31.0f, 62.0f, 31.0f, 55},  // 30
    {1, 31.0f, 31.0f, 62.0f, 31.0f, 56},  // 31
    {2, 50.0f, 55.0f, 100.0f, 88.0f, 57}, // 32
    {2, 50.0f, 55.0f, 100.0f, 88.0f, 58}, // 33
    {0, 40.0f, 0.0f, 80.0f, 18.0f, 51},   // 34
    {0, 40.0f, 0.0f, 80.0f, 18.0f, 52},   // 35
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
            particle.flRotation = 0.0f;
            particle.flScaleX = flScaleX;
            particle.flScaleY = flScaleY;
            ++g_nParticleActiveIndex;
            return;
        }
    }
}

namespace {
// The two note end types the spawner accepts.
constexpr int kEndTypeHead = 0;
constexpr int kEndTypeTail = 1;
// The player-colour count.
constexpr int kPlayerColorMax = 2;
// The quarter-turn added to a tail particle's travel-direction angle (@ghidraAddress 0x2fedd8).
constexpr double kTailAngleBias = 1.5707963267948966;
// The half-turn a head particle is mirrored by when its colour differs from the play colour
// (@ghidraAddress 0x2fe894).
constexpr float kHeadMirrorRotation = 3.1415927f;
// The tail particle sprite kinds, by colour.
constexpr int kTailKindColor0 = 4;
constexpr int kTailKindColor1 = 5;
} // namespace

/** @ghidraAddress 0x188a48 */
void LongNoteLayer::Create(int nColor,
                           int nEndType,
                           int nShapeFlagA,
                           int nShapeFlagB,
                           int bSpawnTrail,
                           float flX,
                           float flY,
                           float flDirX,
                           float flDirY,
                           float flScaleX,
                           float flScaleY) {
    assert(nColor >= 0 && nColor < kPlayerColorMax);
    assert(nEndType >= 0 && nEndType < kPlayerColorMax);

    int nKind;
    float flRotation;
    if (nEndType != kEndTypeHead) {
        // A tail faces its travel direction, a quarter turn past the raw angle.
        nKind = nColor == 1 ? kTailKindColor1 : kTailKindColor0;
        flRotation = static_cast<float>(
            std::atan2(static_cast<double>(-flDirY), static_cast<double>(flDirX)) + kTailAngleBias);
    } else {
        // A head selects one of four fixed kinds from the two shape flags, per colour.
        if (nColor == 1) {
            nKind = nShapeFlagA != 0 ? (nShapeFlagB != 0 ? 9 : 8) : (nShapeFlagB != 0 ? 2 : 0);
        } else {
            nKind = nShapeFlagA != 0 ? (nShapeFlagB != 0 ? 0xb : 0xa) : (nShapeFlagB != 0 ? 3 : 1);
        }
        // It is mirrored a half turn when its colour differs from the current play colour.
        flRotation =
            GameSystem::GetGameSystem()->GetPlayColor() == nColor ? 0.0f : kHeadMirrorRotation;
    }

    // Store the particle in the first free pool slot from the shared active index.
    for (int nSlot = g_nParticleActiveIndex; nSlot < kParticleCount; ++nSlot) {
        Particle &particle = m_aParticles[nSlot];
        if (!particle.bActive) {
            particle.nKind = nKind;
            particle.bActive = true;
            particle.flX = flX;
            particle.flY = flY;
            particle.flRotation = flRotation;
            particle.flScaleX = flScaleX;
            particle.flScaleY = flScaleY;
            ++g_nParticleActiveIndex;
            // Optionally spawn a trailing particle at the same position and scale.
            if (bSpawnTrail != 0) {
                SpawnParticle(flX, flY, flScaleX, flScaleY, nColor);
            }
            return;
        }
    }
}
