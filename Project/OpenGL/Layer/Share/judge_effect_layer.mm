#include "judge_effect_layer.h"

#include "bg_layer.h"
#include "curve.h"
#include "deviceenvironment.h"
#include "engineglobals.h"
#include "gamesystem.h"
#include "neRender.h"
#include "neSpriteInstancing.h"
#include "neTexture.h"
#include "s_vector2.h"
#include "sprite_uv_table.h"

static JudgeEffectLayer *g_pJudgeEffectLayer = nullptr; // @ghidraAddress 0x3def28

namespace {

// @ghidraAddress 0x3ceaa8
constexpr const char *kTextureName = "00_texture/gm_parts2";

constexpr float kFadeOpaque = 1.0f;
constexpr float kFadeTransparent = 0.0f;

constexpr float kInitialScale = 1.0f;

constexpr unsigned int kColorMax = 255;

struct JudgeGlyphMetrics {
    float flAnchorX;
    float flAnchorY;
    float flSizeX; // Also the pen advance.
    float flSizeY;
    int nUvFrameIndex;
};

constexpr int kJudgeGlyphCount = 26;

constexpr JudgeGlyphMetrics kJudgeGlyphMetricsPad[kJudgeGlyphCount] = {
    {0.0f, 0.0f, 102.0f, 8.0f, 0xda}, {0.0f, 0.0f, 102.0f, 8.0f, 0xdb},
    {0.0f, 0.0f, 75.0f, 8.0f, 0xdc},  {0.0f, 0.0f, 75.0f, 8.0f, 0xdd},
    {0.0f, 0.0f, 6.0f, 8.0f, 0xde},   {0.0f, 0.0f, 6.0f, 8.0f, 0xdf},
    {0.0f, 0.0f, 6.0f, 8.0f, 0xe0},   {0.0f, 0.0f, 6.0f, 8.0f, 0xe1},
    {0.0f, 0.0f, 6.0f, 8.0f, 0xe2},   {0.0f, 0.0f, 6.0f, 8.0f, 0xe3},
    {0.0f, 0.0f, 6.0f, 8.0f, 0xe4},   {0.0f, 0.0f, 6.0f, 8.0f, 0xe5},
    {0.0f, 0.0f, 6.0f, 8.0f, 0xe6},   {0.0f, 0.0f, 6.0f, 8.0f, 0xe7},
    {0.0f, 0.0f, 6.0f, 8.0f, 0xe8},   {0.0f, 0.0f, 6.0f, 8.0f, 0xe9},
    {0.0f, 0.0f, 6.0f, 8.0f, 0xea},   {0.0f, 0.0f, 6.0f, 8.0f, 0xeb},
    {0.0f, 0.0f, 6.0f, 8.0f, 0xec},   {0.0f, 0.0f, 6.0f, 8.0f, 0xed},
    {0.0f, 0.0f, 6.0f, 8.0f, 0xee},   {0.0f, 0.0f, 6.0f, 8.0f, 0xef},
    {0.0f, 0.0f, 6.0f, 8.0f, 0xf0},   {0.0f, 0.0f, 6.0f, 8.0f, 0xf1},
    {0.0f, 0.0f, 6.0f, 8.0f, 0xf2},   {0.0f, 0.0f, 6.0f, 8.0f, 0xf3},
}; // @ghidraAddress 0x30e370

constexpr JudgeGlyphMetrics kJudgeGlyphMetricsPhone[kJudgeGlyphCount] = {
    {0.0f, 5.0f, 74.0f, 10.0f, 0x15b}, {0.0f, 5.0f, 74.0f, 10.0f, 0x15c},
    {0.0f, 5.0f, 52.0f, 10.0f, 0x15d}, {0.0f, 5.0f, 52.0f, 10.0f, 0x15e},
    {0.0f, 5.0f, 8.0f, 10.0f, 0x15f},  {0.0f, 5.0f, 8.0f, 10.0f, 0x160},
    {0.0f, 5.0f, 8.0f, 10.0f, 0x161},  {0.0f, 5.0f, 8.0f, 10.0f, 0x162},
    {0.0f, 5.0f, 8.0f, 10.0f, 0x163},  {0.0f, 5.0f, 8.0f, 10.0f, 0x164},
    {0.0f, 5.0f, 8.0f, 10.0f, 0x165},  {0.0f, 5.0f, 8.0f, 10.0f, 0x166},
    {0.0f, 5.0f, 8.0f, 10.0f, 0x167},  {0.0f, 5.0f, 8.0f, 10.0f, 0x168},
    {0.0f, 5.0f, 10.0f, 10.0f, 0x169}, {0.0f, 5.0f, 8.0f, 10.0f, 0x16a},
    {0.0f, 5.0f, 8.0f, 10.0f, 0x16b},  {0.0f, 5.0f, 8.0f, 10.0f, 0x16c},
    {0.0f, 5.0f, 8.0f, 10.0f, 0x16d},  {0.0f, 5.0f, 8.0f, 10.0f, 0x16e},
    {0.0f, 5.0f, 8.0f, 10.0f, 0x16f},  {0.0f, 5.0f, 8.0f, 10.0f, 0x170},
    {0.0f, 5.0f, 8.0f, 10.0f, 0x171},  {0.0f, 5.0f, 8.0f, 10.0f, 0x172},
    {0.0f, 5.0f, 8.0f, 10.0f, 0x173},  {0.0f, 5.0f, 10.0f, 10.0f, 0x174},
}; // @ghidraAddress 0x30e578

constexpr int kJudgeColorTypePink = 1; // JUST / JUST REFLEC.
constexpr int kJudgeColorTypeCyan = 2;
constexpr unsigned int kJudgePinkRed = 0xff;
constexpr unsigned int kJudgePinkGreen = 0xa5;
constexpr unsigned int kJudgePinkBlue = 0xf8;
constexpr unsigned int kJudgeCyanRed = 0xa8;
constexpr unsigned int kJudgeCyanGreen = 0xfc;
constexpr unsigned int kJudgeCyanBlue = 0xff;

constexpr int kLaneCount = 2;
constexpr int kMaxScoreDigits = 6;

constexpr float kPopupLifetime = 3600.0f;

constexpr float kAlphaScale = 255.0f;

// A non-zero entry flips the pop-out to the left and rotates the label a half turn.
// @ghidraAddress 0x30e338
constexpr unsigned char kPopDirectionFlip[] = {0, 0, 1, 0, 0, 0, 0, 0};

constexpr float kLabelRotationFlipped = 3.1415927f;

// Each curve is a flat run of {x, y} keyframes.
// @ghidraAddress 0x30e340
constexpr float kPopOffsetCurve[] = {0.0f, 100.0f, 300.0f, 0.0f};
// @ghidraAddress 0x30e350
constexpr float kAlphaCurve[] = {0.0f, 0.0f, 300.0f, 1.0f, 3300.0f, 1.0f, 3600.0f, 0.0f};

constexpr float kLayoutInsetLeft = -384.0f; // 0x2f8568
constexpr float kLayoutSpanTop = 1024.0f;   // 0x309164
constexpr float kLayoutRowOffset = 54.0f;   // 0x30e334
constexpr float kLayoutInsetTop = -512.0f;  // 0x2f8570
constexpr float kLayoutMirrorSpan = 768.0f; // 0x2fd04c
constexpr float kLayoutBaseX = 490.0f;      // 0x3def30 (lazily seeded)
constexpr float kLayoutBaseY = 590.0f;      // 0x3def34 (lazily seeded)
constexpr float kPhoneLaneX = 106.0f;       // 0x42d40000
constexpr int kPhoneLaneHalfSpan = 71;      // 0x47

constexpr unsigned int kPointsLabelGlyphColorA = 0xe;
constexpr unsigned int kPointsLabelGlyphColorB = 0x19;
constexpr unsigned int kDigitGlyphBaseColorA = 4;
constexpr unsigned int kDigitGlyphBaseColorB = 0xf;

constexpr int kLabelColorTypeColorA = kJudgeColorTypePink;
constexpr int kLabelColorTypeColorB = kJudgeColorTypeCyan;

} // namespace

/** @ghidraAddress 0x184bb0 */
JudgeEffectLayer::JudgeEffectLayer() {
    m_flScaleX = kInitialScale;
    m_flScaleY = kInitialScale;
}

/** @ghidraAddress 0x184c28 */
JudgeEffectLayer *JudgeEffectLayer::shared() {
    if (g_pJudgeEffectLayer == nullptr) {
        g_pJudgeEffectLayer = new JudgeEffectLayer();
    }
    return g_pJudgeEffectLayer;
}

/** @ghidraAddress 0x184c78 */
void JudgeEffectLayer::LoadJudgeEffectSprites() {
    if (m_bBuilt) {
        return;
    }

    BgLayer *pBackgroundLayer = BgLayer::GetBackgroundLayer();
    ne::C_RENDER *pParent = pBackgroundLayer->GetBackgroundRenderObject();

    m_pTexture = ne::C_TEXTURE::FindOrLoadCached(kTextureName);

    m_pSprite = ne::CreateWorldSpriteBatch(kSpriteCapacity);
    pParent->AttachChild(m_pSprite);
    m_pSprite->SetVisible(true);
    m_pSprite->SetRefCountedMember(m_pTexture);
    m_pSprite->SetSpriteCount(m_nSpriteCount);

    m_bBuilt = true;
}

/** @ghidraAddress 0x184d48 */
void JudgeEffectLayer::TriggerJudgeEffect(unsigned int nLane,
                                          unsigned int nScore,
                                          unsigned int nJudgeType) {
    JudgeRecord &record = m_aJudgeRecords[nLane];
    record.m_nJudgeType = nJudgeType;
    record.m_flTimer = 0.0f;
    record.m_bActive = true;
    record.m_nScore = nScore;
}

/** @ghidraAddress 0x185288 */
void JudgeEffectLayer::EmitDigitSprite(unsigned int nGlyphIndex,
                                       const S_VECTOR2 *pPosition,
                                       unsigned int nAlpha,
                                       int nColorType,
                                       float flRotation) {
    const JudgeGlyphMetrics &glyph =
        IsPad() ? kJudgeGlyphMetricsPad[nGlyphIndex] : kJudgeGlyphMetricsPhone[nGlyphIndex];
    const SpriteUvEntry &uv = g_aSpriteUvTable[glyph.nUvFrameIndex];

    m_pSprite->SetSpritePosition(m_nSpriteCount, *pPosition);
    m_pSprite->SetSpriteAnchor(m_nSpriteCount, S_VECTOR2{glyph.flAnchorX, glyph.flAnchorY});
    m_pSprite->SetSpriteSize(m_nSpriteCount, S_VECTOR2{glyph.flSizeX, glyph.flSizeY});
    m_pSprite->SetSpriteUvOrigin(m_nSpriteCount, S_VECTOR2{uv.flOriginU, uv.flOriginV});
    m_pSprite->SetSpriteUvSize(m_nSpriteCount, S_VECTOR2{uv.flSizeU, uv.flSizeV});
    m_pSprite->SetSpriteRotation(m_nSpriteCount, flRotation);

    unsigned int nRed = kColorMax;
    unsigned int nGreen = kColorMax;
    unsigned int nBlue = kColorMax;
    if (nColorType == kJudgeColorTypePink) {
        nRed = kJudgePinkRed;
        nGreen = kJudgePinkGreen;
        nBlue = kJudgePinkBlue;
    } else if (nColorType == kJudgeColorTypeCyan) {
        nRed = kJudgeCyanRed;
        nGreen = kJudgeCyanGreen;
        nBlue = kJudgeCyanBlue;
    }
    m_pSprite->SetSpriteColor(m_nSpriteCount, nRed, nGreen, nBlue, nAlpha);

    ++m_nSpriteCount;
}

/** @ghidraAddress 0x184d60 */
void JudgeEffectLayer::RenderJudgeScoreEffect(float flDelta) {
    m_nSpriteCount = 0;

    m_fadeChannel.Advance(flDelta);
    const float flFade = m_fadeChannel.GetCurrent();

    // The signed full height is rounded toward zero before halving.
    const int nHalfHeight =
        (g_nPlayfieldFullHeightY < 0 ? g_nPlayfieldFullHeightY + 1 : g_nPlayfieldFullHeightY) / 2;
    const float flHalfHeight = static_cast<float>(nHalfHeight);

    for (int nLane = 0; nLane < kLaneCount; ++nLane) {
        const float flLaneScale = nLane == 0 ? m_flScaleX : m_flScaleY;
        const float flFadeScale = flFade * flLaneScale;

        JudgeRecord &record = m_aJudgeRecords[nLane];
        if (!record.m_bActive) {
            continue;
        }
        record.m_flTimer += flDelta;
        if (record.m_flTimer >= kPopupLifetime) {
            record.m_bActive = false;
            continue;
        }

        const int nGameType = GameSystem::GetGameSystem()->GetGameType();
        const bool bFlip = kPopDirectionFlip[nLane + nGameType * kLaneCount] != 0;
        const float flLabelRotation = bFlip ? kLabelRotationFlipped : 0.0f;
        const float flDirection = bFlip ? -1.0f : 1.0f;

        const S_VECTOR2 aiPadBase[] = {
            {kLayoutBaseX + kLayoutInsetLeft,
             (kLayoutRowOffset - kLayoutBaseY) + kLayoutSpanTop + kLayoutInsetTop + flHalfHeight},
            {kLayoutBaseX + kLayoutInsetLeft, (kLayoutBaseY + kLayoutInsetTop) + flHalfHeight},
            // Game type 1 hangs off the playfield centre split, not the half-height.
            {(kLayoutMirrorSpan - kLayoutBaseX) + kLayoutInsetLeft,
             (kLayoutSpanTop - kLayoutBaseY) - static_cast<float>(g_nPlayfieldCentreSplit)},
            {kLayoutBaseX + kLayoutInsetLeft,
             kLayoutBaseY - static_cast<float>(g_nPlayfieldCentreSplit)},
            {kLayoutBaseX + kLayoutInsetLeft,
             (kLayoutRowOffset - kLayoutBaseY) + kLayoutSpanTop + kLayoutInsetTop + flHalfHeight},
            {kLayoutBaseX + kLayoutInsetLeft, (kLayoutBaseY + kLayoutInsetTop) + flHalfHeight},
        };
        const S_VECTOR2 aPhoneBase[] = {
            {kPhoneLaneX, static_cast<float>(nHalfHeight - kPhoneLaneHalfSpan)},
            {kPhoneLaneX, static_cast<float>(nHalfHeight + kPhoneLaneHalfSpan)},
        };
        const S_VECTOR2 &base =
            IsPad() ? aiPadBase[nGameType * kLaneCount + nLane] : aPhoneBase[nLane];

        const float flPopOffset = CalculateCurveInterpolation(kPopOffsetCurve, 2, record.m_flTimer);
        S_VECTOR2 pos{base.x + flDirection * flPopOffset, base.y};
        const float flAlphaCurve = CalculateCurveInterpolation(kAlphaCurve, 4, record.m_flTimer);

        const int nPlayColor = GameSystem::GetGameSystem()->GetPlayColor();
        const int nLaneColor = nLane == 1 ? nPlayColor : (nPlayColor == 0);

        const unsigned int nAlpha =
            static_cast<unsigned int>(static_cast<int>(flFadeScale * flAlphaCurve * kAlphaScale));

        const int nLabelColorType = nLaneColor == 1 ? kLabelColorTypeColorB : kLabelColorTypeColorA;
        EmitDigitSprite(record.m_nJudgeType, &pos, nAlpha, nLabelColorType, flLabelRotation);

        const JudgeGlyphMetrics *pMetrics =
            IsPad() ? kJudgeGlyphMetricsPad : kJudgeGlyphMetricsPhone;
        pos.x += flDirection + flDirection + flDirection * pMetrics[record.m_nJudgeType].flSizeX;
        const unsigned int nPointsLabel =
            nLaneColor == 0 ? kPointsLabelGlyphColorA : kPointsLabelGlyphColorB;
        EmitDigitSprite(nPointsLabel, &pos, nAlpha, 0, flLabelRotation);

        pMetrics = IsPad() ? kJudgeGlyphMetricsPad : kJudgeGlyphMetricsPhone;
        pos.x += flDirection + flDirection * pMetrics[nPointsLabel].flSizeX;

        int aDigits[kMaxScoreDigits] = {};
        int nRemaining = static_cast<int>(record.m_nScore);
        int nHighestPlace = 0;
        for (int nPlace = 0; nPlace < kMaxScoreDigits; ++nPlace) {
            const int nDigit = nRemaining % 10;
            aDigits[nPlace] = nDigit;
            if (nDigit > 0) {
                nHighestPlace = nPlace + 1;
            }
            nRemaining /= 10;
        }

        // A zero score still shows a single zero digit.
        const unsigned int nDigitBase =
            nLaneColor == 1 ? kDigitGlyphBaseColorB : kDigitGlyphBaseColorA;
        int nPlace = nHighestPlace < 1 ? 1 : nHighestPlace;
        for (; nPlace >= 1; --nPlace) {
            const unsigned int nGlyph = static_cast<unsigned int>(aDigits[nPlace - 1]) + nDigitBase;
            EmitDigitSprite(nGlyph, &pos, nAlpha, 0, flLabelRotation);
            pMetrics = IsPad() ? kJudgeGlyphMetricsPad : kJudgeGlyphMetricsPhone;
            pos.x += flDirection + flDirection * pMetrics[nGlyph].flSizeX;
        }
    }

    m_pSprite->SetSpriteCount(m_nSpriteCount);
}

/** @ghidraAddress 0x184d00 */
void JudgeEffectLayer::StartFadeIn(float flDuration) {
    m_fadeChannel.SetStart(m_fadeChannel.GetCurrent());
    m_fadeChannel.SetEnd(kFadeOpaque);
    m_fadeChannel.SetDuration(flDuration);
    m_fadeChannel.SetElapsed(0.0f);
    if (flDuration <= 0.0f) {
        m_fadeChannel.SetCurrent(kFadeOpaque);
    }
}

/** @ghidraAddress 0x184d28 */
void JudgeEffectLayer::StartFadeOut(float flDuration) {
    m_fadeChannel.SetStart(m_fadeChannel.GetCurrent());
    m_fadeChannel.SetEnd(kFadeTransparent);
    m_fadeChannel.SetDuration(flDuration);
    m_fadeChannel.SetElapsed(0.0f);
    if (flDuration <= 0.0f) {
        m_fadeChannel.SetCurrent(kFadeTransparent);
    }
}
