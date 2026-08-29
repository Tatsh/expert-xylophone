#include "note_result_layer.h"

#include <cassert>
#include <cmath>

#include "bg_layer.h"
#include "engineglobals.h"
#include "gamesystem.h"
#include "neRender.h"
#include "neRenderer.h"
#include "neSpriteInstancing.h"
#include "neTexture.h"
#include "sprite_uv_table.h"

static NoteResultLayer *g_pNoteResultLayer = nullptr; // @ghidraAddress 0x3df238

namespace {

constexpr int kInitialState = 1;
constexpr float kInitialScale = 1.0f;

constexpr const char *kAtlasTextureName = "00_texture/gm_parts2";
constexpr unsigned int kSpriteCapacity = 0x40;
constexpr float kBaseSizePad = 1.0f;
constexpr float kBaseSizePhone = 0.5f;

constexpr int kRowCount = 4;
constexpr int kColumnCount = 3;
constexpr float kLayoutHalf = 0.5f;
constexpr float kColumnsNear[kColumnCount] = {-0.5f, 0.0f, 0.5f};
constexpr float kColumnsFar[kColumnCount] = {-0.8f, 0.0f, 0.8f};
// @ghidraAddress 0x30f850 = 115.2, 0x2ef180 = 96.0, 0x30f848 = -115.2, 0x30f844 = -96.0
constexpr float kRowBaseTop = 115.2f;
constexpr float kRowBaseUpperMid = 96.0f;
constexpr float kRowBaseLowerMid = -115.2f;
constexpr float kRowBaseBottom = -96.0f;

constexpr int kMaxDigits = 5;
constexpr int kDigitBase = 10;
// Digit glyphs follow the seven star-frame records.
constexpr int kDigitRecordBase = 7;

constexpr float kFrameCycleDivisor = 33.3333321f; // @ghidraAddress 0x2fee10
constexpr float kAlphaScale = 255.0f;             // @ghidraAddress 0x2eed00
constexpr float kQuadLifetime = 1000.0f;          // @ghidraAddress 0x2f8540
constexpr int kSpinFrameCount = 4;

constexpr int kFrameKindTwo = 5;
constexpr int kFrameKindOne = 4;
constexpr int kFrameKindOther = 6;

constexpr int kGameTypeSinglePlayer = 1;

constexpr float kDigitAdvance = 10.0f;

constexpr unsigned int kColorMax = 255;

} // namespace

/** @ghidraAddress 0x189294 */
NoteResultLayer::NoteResultLayer() {
    m_pTexture = nullptr;
    m_pSprites = nullptr;
    m_nSpriteCount = 0;
    for (int nQuad = 0; nQuad < kPositionCount; ++nQuad) {
        m_aQuadPos[nQuad] = S_VECTOR2{};
        m_aQuads[nQuad] = ResultQuad{};
    }
    m_nState = kInitialState;
    m_bCreated = false;
    m_flScaleA = kInitialScale;
    m_flScaleB = kInitialScale;
}

/** @ghidraAddress 0x1892fc */
NoteResultLayer *NoteResultLayer::shared() {
    if (g_pNoteResultLayer == nullptr) {
        g_pNoteResultLayer = new NoteResultLayer();
    }
    return g_pNoteResultLayer;
}

/** @ghidraAddress 0x1895e8 */
void NoteResultLayer::Create(unsigned int nPos, int nJudge, int nNumber) {
    assert(static_cast<int>(nPos) >= 0 && nPos < kPositionCount);
    assert(nJudge >= 0 && nJudge < kJudgeTypeCount);

    ResultQuad &quad = m_aQuads[nPos];
    quad.bActive = true;
    quad.nJudge = nJudge;
    quad.flTimer = 0.0f;
    quad.nNumber = nNumber;
}

/** @ghidraAddress 0x1895d4 */
void NoteResultLayer::SetScale(float flValue, int nWhich) {
    if (nWhich != 0) {
        m_flScaleB = flValue;
    } else {
        m_flScaleA = flValue;
    }
}

// @ghidraAddress 0x30f858
const StarSpriteDescriptor g_aStarGlyphTablePad[] = {
    {{29.0f, 12.0f}, {58.0f, 24.0f}, 201},
    {{29.0f, 12.0f}, {58.0f, 24.0f}, 202},
    {{29.0f, 12.0f}, {58.0f, 24.0f}, 203},
    {{29.0f, 12.0f}, {58.0f, 24.0f}, 204},
    {{39.0f, 12.0f}, {78.0f, 24.0f}, 205},
    {{41.0f, 12.0f}, {82.0f, 24.0f}, 206},
    {{29.0f, 12.0f}, {58.0f, 24.0f}, 207},
    {{0.0f, 8.0f}, {12.0f, 16.0f}, 208},
    {{0.0f, 8.0f}, {12.0f, 16.0f}, 209},
    {{0.0f, 8.0f}, {12.0f, 16.0f}, 210},
    {{0.0f, 8.0f}, {12.0f, 16.0f}, 211},
    {{0.0f, 8.0f}, {12.0f, 16.0f}, 212},
    {{0.0f, 8.0f}, {12.0f, 16.0f}, 213},
    {{0.0f, 8.0f}, {12.0f, 16.0f}, 214},
    {{0.0f, 8.0f}, {12.0f, 16.0f}, 215},
    {{0.0f, 8.0f}, {12.0f, 16.0f}, 216},
    {{0.0f, 8.0f}, {12.0f, 16.0f}, 217},
};

// @ghidraAddress 0x30f9ac
const StarSpriteDescriptor g_aStarGlyphTablePhone[] = {
    {{32.0f, 13.0f}, {64.0f, 26.0f}, 330},
    {{32.0f, 13.0f}, {64.0f, 26.0f}, 331},
    {{32.0f, 13.0f}, {64.0f, 26.0f}, 332},
    {{32.0f, 13.0f}, {64.0f, 26.0f}, 333},
    {{42.0f, 13.0f}, {84.0f, 26.0f}, 334},
    {{44.0f, 13.0f}, {88.0f, 26.0f}, 335},
    {{32.0f, 13.0f}, {64.0f, 26.0f}, 336},
    {{0.0f, 10.0f}, {16.0f, 20.0f}, 337},
    {{0.0f, 10.0f}, {16.0f, 20.0f}, 338},
    {{0.0f, 10.0f}, {16.0f, 20.0f}, 339},
    {{0.0f, 10.0f}, {16.0f, 20.0f}, 340},
    {{0.0f, 10.0f}, {16.0f, 20.0f}, 341},
    {{0.0f, 10.0f}, {16.0f, 20.0f}, 342},
    {{0.0f, 10.0f}, {16.0f, 20.0f}, 343},
    {{0.0f, 10.0f}, {16.0f, 20.0f}, 344},
    {{0.0f, 10.0f}, {16.0f, 20.0f}, 345},
    {{0.0f, 10.0f}, {16.0f, 20.0f}, 346},
};

/** @ghidraAddress 0x1893f0 */
void NoteResultLayer::BuildQuadPositions() {
    struct RowLayout {
        const float *pColumns;
        float flSlope;
        float flBaseY;
    };
    const RowLayout aRows[kRowCount] = {
        {kColumnsNear, g_flPlayfieldNearLaneSlope, kRowBaseTop},
        {kColumnsFar, g_flPlayfieldFarLaneSlope, kRowBaseUpperMid},
        {kColumnsNear, g_flPlayfieldNearLaneSlopeNeg, kRowBaseLowerMid},
        {kColumnsFar, g_flPlayfieldFarLaneSlopeNeg, kRowBaseBottom},
    };

    GameSystem *pGameSystem = GameSystem::GetGameSystem();
    const float flSheetPosX = pGameSystem->GetSheetPosX();
    const float flSheetPosY = pGameSystem->GetSheetPosY();
    for (int nQuad = 0; nQuad < kPositionCount; ++nQuad) {
        const RowLayout &row = aRows[nQuad / kColumnCount];
        const int nColumn = nQuad % kColumnCount;
        m_aQuadPos[nQuad].x = row.pColumns[nColumn] * flSheetPosX * kLayoutHalf;
        m_aQuadPos[nQuad].y = row.flSlope * flSheetPosY * kLayoutHalf + row.flBaseY;
    }
}

/** @ghidraAddress 0x18934c */
void NoteResultLayer::CreateSpriteInstancer() {
    if (m_bCreated) {
        return;
    }

    m_flBaseSize = IsPad() ? kBaseSizePad : kBaseSizePhone;

    BuildQuadPositions();

    m_pTexture = ne::C_TEXTURE::FindOrLoadCached(kAtlasTextureName);

    // Screen-space batch: the call at 0x1893ac is CreateSpriteInstancer, not the world batch.
    m_pSprites = ne::CreateSpriteInstancer(kSpriteCapacity);
    ne::C_RENDER *pParent = BgLayer::GetBackgroundLayer()->GetBackgroundRenderObject();
    pParent->AttachChild(m_pSprites);
    m_pSprites->SetVisible(true);
    m_pSprites->SetRefCountedMember(m_pTexture);
    m_pSprites->SetSpriteCount(0);

    m_bCreated = true;
}

/** @ghidraAddress 0x189aec */
void NoteResultLayer::EmitStarSprite(float flSize,
                                     const S_VECTOR2 &position,
                                     bool bFlip,
                                     unsigned int nAlpha,
                                     const StarSpriteDescriptor &descriptor) {
    const SpriteUvEntry &uv = g_aSpriteUvTable[descriptor.nAtlasFrame];

    m_pSprites->SetVertexPosition(m_nSpriteCount, position);
    m_pSprites->SetSpriteAnchor(m_nSpriteCount, descriptor.anchor);
    m_pSprites->SetSpriteSize(m_nSpriteCount, descriptor.size);
    m_pSprites->SetSpriteUvOrigin(m_nSpriteCount, S_VECTOR2{uv.flOriginU, uv.flOriginV});
    m_pSprites->SetSpriteUvSize(m_nSpriteCount, S_VECTOR2{uv.flSizeU, uv.flSizeV});
    m_pSprites->SetSpriteRotation(m_nSpriteCount, bFlip ? static_cast<float>(M_PI) : 0.0f);
    m_pSprites->SetSpriteScale(m_nSpriteCount, flSize, flSize);
    m_pSprites->SetSpriteColor(m_nSpriteCount, kColorMax, kColorMax, kColorMax, nAlpha);

    ++m_nSpriteCount;
}

/** @ghidraAddress 0x1896a4 */
void NoteResultLayer::Update(float flDeltaTime) {
    m_nSpriteCount = 0;

    GameSystem *pGameSystem = GameSystem::GetGameSystem();
    const int nGameType = pGameSystem->GetGameType();
    const StarSpriteDescriptor *pTable = IsPad() ? g_aStarGlyphTablePad : g_aStarGlyphTablePhone;

    for (int nQuad = 0; nQuad < kPositionCount; ++nQuad) {
        ResultQuad &quad = m_aQuads[nQuad];
        if (!quad.bActive) {
            continue;
        }

        float flTimer = quad.flTimer + flDeltaTime;
        if (flTimer <= 0.0f) {
            flTimer = 0.0f;
        }
        quad.flTimer = flTimer;
        if (flTimer > kQuadLifetime) {
            quad.bActive = false;
            continue;
        }

        // The first half of the quads are the near rows, which belong to side 0.
        const bool bLeftGroup = nQuad < (kPositionCount / 2);
        const bool bMirror = nGameType == kGameTypeSinglePlayer && bLeftGroup;

        float aProjected[] = {m_aQuadPos[nQuad].x, m_aQuadPos[nQuad].y, 0.0f, 1.0f};
        ProjectWorldToScreenCurrent(aProjected);
        const float flScreenScale = pGameSystem->GetScreenScale();
        const float flScreenX = aProjected[0] / flScreenScale;
        const float flScreenY = aProjected[1] / flScreenScale;

        const float flGroupScale = bLeftGroup ? m_flScaleA : m_flScaleB;
        const unsigned int nAlpha = static_cast<unsigned int>(flGroupScale * kAlphaScale);

        const float flStarShift =
            bMirror ? m_flBaseSize * kDigitAdvance : m_flBaseSize * -kDigitAdvance;

        int nFrame;
        if (quad.nJudge == 2) {
            nFrame = kFrameKindTwo;
        } else if (quad.nJudge == 1) {
            nFrame = kFrameKindOne;
        } else if (quad.nJudge == 0) {
            nFrame = static_cast<int>(flTimer / kFrameCycleDivisor) % kSpinFrameCount;
        } else {
            nFrame = kFrameKindOther;
        }
        if (nFrame < 0) {
            nFrame = 0;
        }

        S_VECTOR2 starPos{flScreenX, flScreenY + flStarShift};
        EmitStarSprite(m_flBaseSize, starPos, bMirror, nAlpha, pTable[nFrame]);

        int aDigits[kMaxDigits] = {};
        int nDigitCount = 0;
        int nRemaining = quad.nNumber;
        for (int i = 0; i < kMaxDigits; ++i) {
            aDigits[i] = nRemaining % kDigitBase;
            if (aDigits[i] > 0) {
                nDigitCount = i + 1;
            }
            nRemaining /= kDigitBase;
        }

        float flTotalWidth = 0.0f;
        for (int i = 0; i < nDigitCount; ++i) {
            const StarSpriteDescriptor &glyph = pTable[aDigits[i] + kDigitRecordBase];
            flTotalWidth += m_flBaseSize + m_flBaseSize + glyph.size.x * m_flBaseSize;
        }

        float flDigitY;
        float flDigitOffset;
        if (bMirror) {
            flDigitY = flScreenY - m_flBaseSize * kDigitAdvance;
            flDigitOffset = flTotalWidth * kLayoutHalf;
        } else {
            flDigitY = flScreenY + m_flBaseSize * kDigitAdvance;
            flDigitOffset = flTotalWidth * -kLayoutHalf;
        }
        float flDigitX = flDigitOffset + flScreenX;

        for (int i = nDigitCount; i > 0; --i) {
            const StarSpriteDescriptor &glyph = pTable[aDigits[i - 1] + kDigitRecordBase];
            S_VECTOR2 digitPos{flDigitX, flDigitY};
            EmitStarSprite(m_flBaseSize, digitPos, bMirror, nAlpha, glyph);
            const float flGlyphWidth = glyph.size.x * m_flBaseSize;
            if (bMirror) {
                flDigitX = flDigitX - flGlyphWidth + m_flBaseSize * -2.0f;
            } else {
                flDigitX = flDigitX + flGlyphWidth + (m_flBaseSize + m_flBaseSize);
            }
        }
    }

    m_pSprites->SetSpriteCount(m_nSpriteCount);
}
