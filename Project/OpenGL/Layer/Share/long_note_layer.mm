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

// The process-wide long-note layer, created lazily by shared().
static LongNoteLayer *g_pLongNoteLayer = nullptr; // @ghidraAddress 0x3def00

// The shared note-body draw count, reset when the layer's sprites are built.
static int g_nLongNoteDrawCount = 0; // @ghidraAddress 0x3def08

namespace {

// The atlas the note bodies draw from (@ghidraAddress 0x3ceaa0).
constexpr const char *kTextureName = "00_texture/gm_parts1";

// The additive blend-mode identifier the outer two batches use.
constexpr int kAdditiveBlendMode = 1;

// The two texture-environment parameter slots the builder seeds (to 1 each), and that value.
constexpr int kTexParamSlotHigh = 1;
constexpr int kTexParamSlotLow = 0;
constexpr int kTexParamEnabled = 1;

} // namespace

/** @ghidraAddress 0x1812a0 */
LongNoteLayer::LongNoteLayer() {
    m_flBaseOffset = -1.0f;
}

/** @ghidraAddress 0x181310 */
LongNoteLayer *LongNoteLayer::shared() {
    if (g_pLongNoteLayer == nullptr) {
        // The binary allocates the raw 0x480-byte object and runs the constructor.
        g_pLongNoteLayer = new LongNoteLayer();
    }
    return g_pLongNoteLayer;
}

/** @ghidraAddress 0x181360 */
void LongNoteLayer::LoadSprites() {
    if (m_bBuilt) {
        return;
    }

    // The sprites hang beneath the shared background layer's render object rather than the global
    // scene root.
    BgLayer *pBackgroundLayer = BgLayer::GetBackgroundLayer();
    ne::C_RENDER *pParent = pBackgroundLayer->GetBackgroundRenderObject();

    m_pTexture = ne::C_TEXTURE::FindOrLoadCached(kTextureName);

    // Build the three sprite batches, attach each under the background render object, make it
    // visible, bind the atlas, clear its sprite count, flag additive blend on the outer two, and,
    // except on the tutorial hardware, enable each batch's two texture-environment parameters.
    for (int nBatch = 0; nBatch < kBatchCount; ++nBatch) {
        ne::C_SPRITE_INSTANCING_2D *pSprite = ne::CreateWorldSpriteBatch(kSpriteCapacity);
        m_apSprites[nBatch] = pSprite;
        pParent->AttachChild(pSprite);
        pSprite->SetVisible(true);
        pSprite->SetRefCountedMember(m_pTexture);
        pSprite->SetSpriteCount(0);
        if (nBatch != 1) {
            pSprite->SetBlendMode(kAdditiveBlendMode);
        }
        if (!IsHardwareType9()) {
            pSprite->SetTexParam(kTexParamSlotHigh, kTexParamEnabled);
            pSprite->SetTexParam(kTexParamSlotLow, kTexParamEnabled);
        }
    }

    m_bBuilt = true;
    g_nLongNoteDrawCount = 0;
}

namespace {
// The player-colour count the spawner asserts against.
constexpr int kPlayerColorMax = 2;
} // namespace

/** @ghidraAddress 0x181440 */
void LongNoteLayer::Create(int nColor,
                           unsigned char nFlagA,
                           unsigned char nFlagB,
                           float flStartX,
                           float flStartY,
                           float flEndX,
                           float flEndY,
                           unsigned char nFlagC,
                           unsigned char nFlagD,
                           float flAlphaScale,
                           unsigned char nFlagE,
                           float flRotation) {
    assert(nColor >= 0 && nColor < kPlayerColorMax);

    // Scan the pool from its head for a free slot; a full pool drops the note.
    for (int nSlot = g_nLongNoteDrawCount; nSlot < kNoteRecordCount; ++nSlot) {
        NoteRecord &record = m_aNoteRecords[nSlot];
        if (!record.bActive) {
            record.nColor = nColor;
            record.bActive = true;
            record.nFlagA = nFlagA;
            record.nFlagB = nFlagB;
            record.startPoint.x = flStartX;
            record.startPoint.y = flStartY;
            record.endPoint.x = flEndX;
            record.endPoint.y = flEndY;
            record.nFlagC = nFlagC;
            record.nFlagD = nFlagD;
            record.flAlphaScale = flAlphaScale;
            record.nFlagE = nFlagE;
            record.flRotation = flRotation;
            ++g_nLongNoteDrawCount;
            return;
        }
    }
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
    const int nIndex = m_aSpriteCounts[spriteType.nBatchIndex];

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

    ++m_aSpriteCounts[spriteType.nBatchIndex];
}

namespace {
// The pulse clock's period and its negative (subtracted to wrap) (@ghidraAddress 0x2fee08/0x2fee0c).
constexpr float kPulsePeriod = 66.66666412f;
constexpr float kPulseWrap = -66.66666412f;
// The pulse phase below which the flagged extra connector sprite is drawn (@ghidraAddress 0x2fee10).
constexpr float kPulseSpritePhase = 33.33333206f;
// The frame-alpha table (@ghidraAddress 0x2fee30), indexed by the record's fourth flag byte.
constexpr float kFrameAlphaTable[] = {255.0f, 128.0f};
// The quarter-turn added to the connector's travel-direction angle (@ghidraAddress 0x2fedd8).
constexpr double kConnectorAngleBias = 1.5707963267948966;
// The length at or above which the connector is long enough to carry an angle and a tail sprite.
constexpr float kMinConnectorLength = 1.0f;
// The player colour whose own side keeps full intensity.
constexpr int kPlayColorSecond = 1;
// The sprite-type offsets each connector emits, relative to the record's base type. The four body
// segments always draw; the pulse segment draws only while the record is flagged and the pulse clock
// is in its first half, and the tail only once the connector is long enough.
constexpr int kOffsetBody0 = 0;
constexpr int kOffsetBody1 = 4;
constexpr int kOffsetBody2 = 8;
constexpr int kOffsetBody3 = 0xc;
constexpr int kOffsetPulse = 0x10;
constexpr int kOffsetTail = 0x14;
// The same six sprites in the alternate (second-selector) set, which is packed two apart.
constexpr int kAltOffsetBody0 = 0x18;
constexpr int kAltOffsetBody1 = 0x1a;
constexpr int kAltOffsetBody2 = 0x1c;
constexpr int kAltOffsetBody3 = 0x1e;
constexpr int kAltOffsetPulse = 0x20;
constexpr int kAltOffsetTail = 0x22;
// The base sprite type is the note colour, shifted by this when the first selector is set.
constexpr int kFirstSelectorTypeShift = 2;
} // namespace

/** @ghidraAddress 0x181510 */
void LongNoteLayer::BuildLongNoteConnectorSprites(float flDelta) {
    // Restart the batch counts and advance the shared pulse clock, wrapping it into its period.
    for (int nBatch = 0; nBatch < kBatchCount; ++nBatch) {
        m_aSpriteCounts[nBatch] = 0;
    }
    m_flPulseClock += flDelta;
    while (m_flPulseClock > kPulsePeriod) {
        m_flPulseClock += kPulseWrap;
    }

    // The two per-side alpha factors: the note's own side keeps full intensity, the far side dims to
    // the game system's cross-side alpha (chosen by which side is the current play colour).
    GameSystem *pGameSystem = GameSystem::GetGameSystem();
    const bool bColorIsOne = pGameSystem->GetPlayColor() == kPlayColorSecond;
    const float flCrossAlpha = pGameSystem->GetRivalAlpha();
    const float flSideFactor0 = bColorIsOne ? flCrossAlpha : 1.0f;
    const float flSideFactor1 = bColorIsOne ? 1.0f : flCrossAlpha;
    const float flBaseScale = pGameSystem->GetSheetRadiusScaled();

    for (int nSlot = 0; nSlot < kNoteRecordCount; ++nSlot) {
        NoteRecord &record = m_aNoteRecords[nSlot];
        // Slots past the shared draw count are retired without drawing.
        if (nSlot >= g_nLongNoteDrawCount) {
            record.bActive = false;
            continue;
        }
        if (!record.bActive) {
            continue;
        }
        record.bActive = false;

        // The connector vector between the record's two endpoints, its length, and its angle.
        S_VECTOR2 vConnector = record.startPoint;
        SubtractVector2(&vConnector, &record.endPoint);
        const float flLength = Vector2Length(&vConnector);
        float flAngle = 0.0f;
        if (record.nFlagE != 0) {
            // A flagged record carries its own rotation instead of deriving one.
            flAngle = record.flRotation;
        } else if (flLength >= kMinConnectorLength) {
            flAngle = static_cast<float>(
                std::atan2(static_cast<double>(-vConnector.y), static_cast<double>(vConnector.x)) +
                kConnectorAngleBias);
        }

        const float flFrameAlpha = kFrameAlphaTable[record.nFlagD];
        const float flSideFactor = record.nColor == 0 ? flSideFactor0 : flSideFactor1;
        const int nBaseAlpha = static_cast<int>(flFrameAlpha * flSideFactor);
        const auto nAlpha = static_cast<unsigned int>(
            static_cast<int>(record.flAlphaScale * static_cast<float>(nBaseAlpha)));

        // The base sprite type is the note colour, shifted when the first selector is set.
        const int nBaseType =
            record.nFlagA == 0 ? record.nColor : record.nColor + kFirstSelectorTypeShift;
        const bool bPulseSprite = record.nFlagC != 0 && m_flPulseClock < kPulseSpritePhase;

        if (record.nFlagB != 0 && record.nFlagA == 0) {
            CreateSprite(nBaseType + kAltOffsetBody0,
                         &record.startPoint,
                         nAlpha,
                         flLength,
                         flAngle,
                         flBaseScale);
            CreateSprite(nBaseType + kAltOffsetBody1,
                         &record.endPoint,
                         nAlpha,
                         flLength,
                         flAngle,
                         flBaseScale);
            CreateSprite(nBaseType + kAltOffsetBody2,
                         &record.startPoint,
                         nAlpha,
                         flLength,
                         flAngle,
                         flBaseScale);
            CreateSprite(nBaseType + kAltOffsetBody3,
                         &record.endPoint,
                         nAlpha,
                         flLength,
                         flAngle,
                         flBaseScale);
            if (bPulseSprite) {
                CreateSprite(nBaseType + kAltOffsetPulse,
                             &record.endPoint,
                             nAlpha,
                             flLength,
                             flAngle,
                             flBaseScale);
            }
            if (flLength >= kMinConnectorLength) {
                CreateSprite(nBaseType + kAltOffsetTail,
                             &record.endPoint,
                             nAlpha,
                             flLength,
                             flAngle,
                             flBaseScale);
            }
        } else {
            CreateSprite(nBaseType + kOffsetBody0,
                         &record.startPoint,
                         nAlpha,
                         flLength,
                         flAngle,
                         flBaseScale);
            CreateSprite(
                nBaseType + kOffsetBody1, &record.endPoint, nAlpha, flLength, flAngle, flBaseScale);
            CreateSprite(nBaseType + kOffsetBody2,
                         &record.startPoint,
                         nAlpha,
                         flLength,
                         flAngle,
                         flBaseScale);
            CreateSprite(
                nBaseType + kOffsetBody3, &record.endPoint, nAlpha, flLength, flAngle, flBaseScale);
            if (bPulseSprite) {
                CreateSprite(nBaseType + kOffsetPulse,
                             &record.endPoint,
                             nAlpha,
                             flLength,
                             flAngle,
                             flBaseScale);
            }
            if (flLength >= kMinConnectorLength) {
                CreateSprite(nBaseType + kOffsetTail,
                             &record.endPoint,
                             nAlpha,
                             flLength,
                             flAngle,
                             flBaseScale);
            }
        }
    }

    // Publish each batch's emitted count and release the shared pool.
    for (int nBatch = 0; nBatch < kBatchCount; ++nBatch) {
        m_apSprites[nBatch]->SetSpriteCount(m_aSpriteCounts[nBatch]);
    }
    g_nLongNoteDrawCount = 0;
}
