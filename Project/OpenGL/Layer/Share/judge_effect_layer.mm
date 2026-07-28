#include "judge_effect_layer.h"

#include "bg_layer.h"
#include "deviceenvironment.h"
#include "neRender.h"
#include "neSpriteInstancing.h"
#include "neTexture.h"
#include "s_vector2.h"
#include "sprite_uv_table.h"

// The process-wide judge-effect layer, created lazily by shared().
static JudgeEffectLayer *g_pJudgeEffectLayer = nullptr; // @ghidraAddress 0x3def28

namespace {

// The atlas the judge effect draws from (@ghidraAddress 0x3ceaa8).
constexpr const char *kTextureName = "00_texture/gm_parts2";

// The fade channel's fully-opaque and fully-transparent endpoints.
constexpr float kFadeOpaque = 1.0f;
constexpr float kFadeTransparent = 0.0f;

// The scale pair the constructor seeds.
constexpr float kInitialScale = 1.0f;

// The maximum value of an opaque colour channel.
constexpr unsigned int kColorMax = 255;

// One judgement-glyph metrics record: the glyph's sprite anchor and pixel size, and the shared UV
// atlas frame it draws from. The score digits, the JUST/JR labels, and the judgement labels are all
// laid out through this table (the 20-byte stride matches the binary).
struct JudgeGlyphMetrics {
    float flAnchorX;   // +0x00: the glyph's anchor X.
    float flAnchorY;   // +0x04: the glyph's anchor Y.
    float flSizeX;     // +0x08: the glyph's pixel width (also the pen advance).
    float flSizeY;     // +0x0c: the glyph's pixel height.
    int nUvFrameIndex; // +0x10: the frame into the shared sprite UV atlas.
};

// The number of glyph records in each platform's judgement-glyph table.
constexpr int kJudgeGlyphCount = 26;

// The judgement-glyph metrics tables, one per platform (the iPad set and the phone set), selected at
// emit time by the hardware check. Read-only ROM data embedded in the binary.
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

// The judgement-glyph colour tints, selected by the emitted glyph's colour type.
constexpr int kJudgeColorTypePink = 1; // JUST / JUST REFLEC.
constexpr int kJudgeColorTypeCyan = 2;
constexpr unsigned int kJudgePinkRed = 0xff;
constexpr unsigned int kJudgePinkGreen = 0xa5;
constexpr unsigned int kJudgePinkBlue = 0xf8;
constexpr unsigned int kJudgeCyanRed = 0xa8;
constexpr unsigned int kJudgeCyanGreen = 0xfc;
constexpr unsigned int kJudgeCyanBlue = 0xff;

} // namespace

/** @ghidraAddress 0x184bb0 */
JudgeEffectLayer::JudgeEffectLayer() {
    // The base constructor and the zero-initialised members clear the texture, sprite, fade channel,
    // and per-lane records; the constructor then seeds the scale pair to one.
    m_flScaleX = kInitialScale;
    m_flScaleY = kInitialScale;
}

/** @ghidraAddress 0x184c28 */
JudgeEffectLayer *JudgeEffectLayer::shared() {
    if (g_pJudgeEffectLayer == nullptr) {
        // The binary allocates the raw 0x60-byte object and runs the constructor, which chains the
        // base-layer constructor and seeds the layer's state (two scales to 1).
        g_pJudgeEffectLayer = new JudgeEffectLayer();
    }
    return g_pJudgeEffectLayer;
}

/** @ghidraAddress 0x184c78 */
void JudgeEffectLayer::LoadJudgeEffectSprites() {
    if (m_bBuilt) {
        return;
    }

    // The sprite hangs beneath the shared background layer's render object rather than the global
    // scene root.
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
    // The iPad and phone builds use different glyph metrics tables.
    const JudgeGlyphMetrics &glyph =
        IsPad() ? kJudgeGlyphMetricsPad[nGlyphIndex] : kJudgeGlyphMetricsPhone[nGlyphIndex];
    const SpriteUvEntry &uv = g_aSpriteUvTable[glyph.nUvFrameIndex];

    m_pSprite->SetSpritePosition(m_nSpriteCount, *pPosition);
    m_pSprite->SetSpriteAnchor(m_nSpriteCount, S_VECTOR2{glyph.flAnchorX, glyph.flAnchorY});
    m_pSprite->SetSpriteSize(m_nSpriteCount, S_VECTOR2{glyph.flSizeX, glyph.flSizeY});
    m_pSprite->SetSpriteUvOrigin(m_nSpriteCount, S_VECTOR2{uv.flOriginU, uv.flOriginV});
    m_pSprite->SetSpriteUvSize(m_nSpriteCount, S_VECTOR2{uv.flSizeU, uv.flSizeV});
    m_pSprite->SetSpriteRotation(m_nSpriteCount, flRotation);

    // The JUST/JUST REFLEC label draws pink, the second special type cyan, everything else white.
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
