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
#include "vectormath.h"

// @ghidraAddress 0x2ef668
extern const SpriteUvEntry g_aScoreGaugeUvTable[];

// @ghidraAddress 0x30dfa0
const LongNoteSpriteType g_aLongNoteSpriteTypes[kLongNoteSpriteTypeCount] = {
    {0, 29.0f, 0.0f, 58.0f, 27.0f, 23},   {0, 29.0f, 0.0f, 58.0f, 27.0f, 24},
    {0, 29.0f, 0.0f, 58.0f, 27.0f, 25},   {0, 29.0f, 0.0f, 58.0f, 27.0f, 26},
    {0, 29.0f, 27.0f, 58.0f, 27.0f, 27},  {0, 29.0f, 27.0f, 58.0f, 27.0f, 28},
    {0, 29.0f, 27.0f, 58.0f, 27.0f, 29},  {0, 29.0f, 27.0f, 58.0f, 27.0f, 30},
    {1, 31.0f, 17.0f, 62.0f, 50.0f, 35},  {1, 31.0f, 17.0f, 62.0f, 50.0f, 36},
    {1, 31.0f, 17.0f, 62.0f, 50.0f, 37},  {1, 31.0f, 17.0f, 62.0f, 50.0f, 38},
    {1, 31.0f, 31.0f, 62.0f, 31.0f, 39},  {1, 31.0f, 31.0f, 62.0f, 31.0f, 40},
    {1, 31.0f, 31.0f, 62.0f, 31.0f, 41},  {1, 31.0f, 31.0f, 62.0f, 31.0f, 42},
    {2, 50.0f, 55.0f, 100.0f, 88.0f, 43}, {2, 50.0f, 55.0f, 100.0f, 88.0f, 44},
    {2, 50.0f, 55.0f, 100.0f, 88.0f, 45}, {2, 50.0f, 55.0f, 100.0f, 88.0f, 46},
    {0, 40.0f, 0.0f, 80.0f, 18.0f, 31},   {0, 40.0f, 0.0f, 80.0f, 18.0f, 32},
    {0, 40.0f, 0.0f, 80.0f, 18.0f, 33},   {0, 40.0f, 0.0f, 80.0f, 18.0f, 34},
    {0, 29.0f, 0.0f, 58.0f, 27.0f, 47},   {0, 29.0f, 0.0f, 58.0f, 27.0f, 48},
    {0, 29.0f, 27.0f, 58.0f, 27.0f, 49},  {0, 29.0f, 27.0f, 58.0f, 27.0f, 50},
    {1, 31.0f, 17.0f, 62.0f, 50.0f, 53},  {1, 31.0f, 17.0f, 62.0f, 50.0f, 54},
    {1, 31.0f, 31.0f, 62.0f, 31.0f, 55},  {1, 31.0f, 31.0f, 62.0f, 31.0f, 56},
    {2, 50.0f, 55.0f, 100.0f, 88.0f, 57}, {2, 50.0f, 55.0f, 100.0f, 88.0f, 58},
    {0, 40.0f, 0.0f, 80.0f, 18.0f, 51},   {0, 40.0f, 0.0f, 80.0f, 18.0f, 52},
};

static LongNoteLayer *g_pLongNoteLayer = nullptr; // @ghidraAddress 0x3def00

static int g_nLongNoteDrawCount = 0; // @ghidraAddress 0x3def08

namespace {

// @ghidraAddress 0x3ceaa0
constexpr const char *kTextureName = "00_texture/gm_parts1";

constexpr int kAdditiveBlendMode = 1;

constexpr int kTexParamSlotHigh = 1;
constexpr int kTexParamSlotLow = 0;
constexpr int kTexParamEnabled = 1;

} // namespace

/** @ghidraAddress 0x1812a0 */
LongNoteLayer::LongNoteLayer() {
    m_flPulseClock = -1.0f;
}

/** @ghidraAddress 0x181310 */
LongNoteLayer *LongNoteLayer::shared() {
    if (g_pLongNoteLayer == nullptr) {
        g_pLongNoteLayer = new LongNoteLayer();
    }
    return g_pLongNoteLayer;
}

/** @ghidraAddress 0x181360 */
void LongNoteLayer::LoadSprites() {
    if (m_bBuilt) {
        return;
    }

    BgLayer *pBackgroundLayer = BgLayer::GetBackgroundLayer();
    ne::C_RENDER *pParent = pBackgroundLayer->GetBackgroundRenderObject();

    m_pTexture = ne::C_TEXTURE::FindOrLoadCached(kTextureName);

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

    // A full pool drops the note.
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
constexpr float kPulsePeriod = 66.66666412f;               // @ghidraAddress 0x2fee08
constexpr float kPulseWrap = -66.66666412f;                // @ghidraAddress 0x2fee0c
constexpr float kPulseSpritePhase = 33.33333206f;          // @ghidraAddress 0x2fee10
constexpr float kFrameAlphaTable[] = {255.0f, 128.0f};     // @ghidraAddress 0x2fee30
constexpr double kConnectorAngleBias = 1.5707963267948966; // @ghidraAddress 0x2fedd8
constexpr float kMinConnectorLength = 1.0f;
constexpr int kPlayColorSecond = 1;
constexpr int kOffsetBody0 = 0;
constexpr int kOffsetBody1 = 4;
constexpr int kOffsetBody2 = 8;
constexpr int kOffsetBody3 = 0xc;
constexpr int kOffsetPulse = 0x10;
constexpr int kOffsetTail = 0x14;
constexpr int kAltOffsetBody0 = 0x18;
constexpr int kAltOffsetBody1 = 0x1a;
constexpr int kAltOffsetBody2 = 0x1c;
constexpr int kAltOffsetBody3 = 0x1e;
constexpr int kAltOffsetPulse = 0x20;
constexpr int kAltOffsetTail = 0x22;
constexpr int kFirstSelectorTypeShift = 2;
} // namespace

/** @ghidraAddress 0x181510 */
void LongNoteLayer::BuildLongNoteConnectorSprites(float flDelta) {
    for (int nBatch = 0; nBatch < kBatchCount; ++nBatch) {
        m_aSpriteCounts[nBatch] = 0;
    }
    m_flPulseClock += flDelta;
    while (m_flPulseClock > kPulsePeriod) {
        m_flPulseClock += kPulseWrap;
    }

    GameSystem *pGameSystem = GameSystem::GetGameSystem();
    const bool bColorIsOne = pGameSystem->GetPlayColor() == kPlayColorSecond;
    const float flCrossAlpha = pGameSystem->GetRivalAlpha();
    const float flSideFactor0 = bColorIsOne ? flCrossAlpha : 1.0f;
    const float flSideFactor1 = bColorIsOne ? 1.0f : flCrossAlpha;
    const float flBaseScale = pGameSystem->GetSheetRadiusScaled();

    for (int nSlot = 0; nSlot < kNoteRecordCount; ++nSlot) {
        NoteRecord &record = m_aNoteRecords[nSlot];
        if (nSlot >= g_nLongNoteDrawCount) {
            record.bActive = false;
            continue;
        }
        if (!record.bActive) {
            continue;
        }
        record.bActive = false;

        S_VECTOR2 vConnector = record.startPoint;
        SubtractVector2(&vConnector, &record.endPoint);
        const float flLength = Vector2Length(&vConnector);
        float flAngle = 0.0f;
        if (record.nFlagE != 0) {
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

    for (int nBatch = 0; nBatch < kBatchCount; ++nBatch) {
        m_apSprites[nBatch]->SetSpriteCount(m_aSpriteCounts[nBatch]);
    }
    g_nLongNoteDrawCount = 0;
}
