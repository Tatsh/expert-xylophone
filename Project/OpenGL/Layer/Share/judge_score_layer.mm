//
//  judge_score_layer.mm
//  REFLEC BEAT plus
//
//  The judgement-score effect layer (JudgeScoreLayer). Reconstructed from Ghidra project rb458,
//  program rb458. @ghidraAddress values are relative to the program image base.
//

#include "judge_score_layer.h"

#include "bg_layer.h"
#include "curve.h"
#include "neRender.h"
#include "neSpriteInstancing.h"
#include "neTexture.h"
#include "sprite_uv_table.h"

// The score-gauge burst atlas UV table, indexed by the burst UV row. Read-only data embedded in the
// binary (a distinct atlas from the shared sprite UV table).
extern const SpriteUvEntry g_aScoreGaugeUvTable[]; // @ghidraAddress 0x2ef668

namespace {
// The atlas the score-burst sprites draw from.
constexpr const char *kAtlasTextureName = "00_texture_gm_parts1";

// The default scale pair the constructor seeds.
constexpr float kInitialScale = 1.0f;

// The additive blend mode the sprite batch draws with.
constexpr int kAdditiveBlendMode = 1;

// The two texture parameters seeded on a non-tutorial build: parameter one and parameter zero, each
// set to one.
constexpr int kTexParamOne = 1;
constexpr int kTexParamValue = 1;

// The burst sprite's fixed anchor and pixel size (@ghidraAddress 0x30e780 = 62.0; the anchor is
// half of it).
constexpr float kBurstAnchor = 31.0f;
constexpr float kBurstSize = 62.0f;

// The maximum value of an opaque colour channel.
constexpr unsigned int kColorMax = 255;

// The burst UV row for each effect index (@ghidraAddress 0x30e7b0).
constexpr int kBurstUvRow[] = {0x49, 0x4a};

// Scales a unit-interval curve value into an 8-bit alpha (@ghidraAddress 0x2eed00).
constexpr float kAlphaByteScale = 255.0f;

// The burst scale-over-time curve: {time, scale} pairs the animation timer samples (@ghidraAddress
// 0x30e788).
constexpr float kBurstScaleCurve[] = {0.0f, 1.0f, 666.66669f, 1.4f};
constexpr int kBurstScaleCurvePairs = 2;

// The burst alpha-over-time curve: {time, alpha} pairs; the burst deactivates when the alpha reaches
// zero (@ghidraAddress 0x30e798).
constexpr float kBurstAlphaCurve[] = {0.0f, 1.0f, 133.33333f, 1.0f, 666.66669f, 0.0f};
constexpr int kBurstAlphaCurvePairs = 3;
} // namespace

// The process-wide judgement-score layer, created lazily by shared().
static JudgeScoreLayer *g_pJudgeScoreLayer = nullptr; // @ghidraAddress 0x3def40

/** @ghidraAddress 0x18546c */
JudgeScoreLayer *JudgeScoreLayer::shared() {
    if (g_pJudgeScoreLayer == nullptr) {
        g_pJudgeScoreLayer = new JudgeScoreLayer();
    }
    return g_pJudgeScoreLayer;
}

/** @ghidraAddress 0x185408 */
JudgeScoreLayer::JudgeScoreLayer() {
    // The base constructor and member initialisers clear the sprite header and pooled records; the
    // default scale pair seeds to one.
    m_aScale[0] = kInitialScale;
    m_aScale[1] = kInitialScale;
}

/** @ghidraAddress 0x1856e0 */
void JudgeScoreLayer::EmitBurstSprite(unsigned int nEffectIndex,
                                      float flScale,
                                      const S_VECTOR2 &position,
                                      int nAlpha) {
    const SpriteUvEntry &uv = g_aScoreGaugeUvTable[kBurstUvRow[nEffectIndex]];

    m_pSprite->SetSpritePosition(m_nSlotCount, position);
    m_pSprite->SetSpriteAnchor(m_nSlotCount, S_VECTOR2{kBurstAnchor, kBurstAnchor});
    m_pSprite->SetSpriteSize(m_nSlotCount, S_VECTOR2{kBurstSize, kBurstSize});
    m_pSprite->SetSpriteUvOrigin(m_nSlotCount, S_VECTOR2{uv.flOriginU, uv.flOriginV});
    m_pSprite->SetSpriteUvSize(m_nSlotCount, S_VECTOR2{uv.flSizeU, uv.flSizeV});
    m_pSprite->SetSpriteScale(m_nSlotCount, flScale, flScale);
    m_pSprite->SetSpriteColor(
        m_nSlotCount, kColorMax, kColorMax, kColorMax, static_cast<unsigned int>(nAlpha));

    ++m_nSlotCount;
}

/** @ghidraAddress 0x1854bc */
void JudgeScoreLayer::LoadSprites() {
    if (m_bLoaded) {
        return;
    }

    ne::C_RENDER *pParent = BgLayer::GetBackgroundLayer()->GetBackgroundRenderObject();
    m_pTexture = ne::C_TEXTURE::FindOrLoadCached(kAtlasTextureName);
    m_pSprite = ne::CreateWorldSpriteBatch(static_cast<unsigned int>(m_nCapacity));
    pParent->AttachChild(m_pSprite);
    m_pSprite->SetVisible(true);
    m_pSprite->SetRefCountedMember(m_pTexture);
    m_pSprite->SetSpriteCount(0);
    m_pSprite->SetBlendMode(kAdditiveBlendMode);

    // A non-tutorial build seeds two texture parameters (the tutorial build leaves them default).
    if (!IsHardwareType9()) {
        m_pSprite->SetTexParam(kTexParamOne, kTexParamValue);
        m_pSprite->SetTexParam(0, kTexParamValue);
    }

    m_bLoaded = true;
}

/** @ghidraAddress 0x185600 */
void JudgeScoreLayer::RenderScoreGaugeEffects(float flDelta) {
    m_nSlotCount = 0;
    for (auto &record : m_aEffects) {
        if (!record.bActive) {
            continue;
        }
        record.flTimer += flDelta;
        const float flScale =
            CalculateCurveInterpolation(kBurstScaleCurve, kBurstScaleCurvePairs, record.flTimer);
        const float flAlpha =
            CalculateCurveInterpolation(kBurstAlphaCurve, kBurstAlphaCurvePairs, record.flTimer);
        if (flAlpha <= 0.0f) {
            record.bActive = false;
            continue;
        }
        EmitBurstSprite(record.nEffectIndex,
                        flScale,
                        record.position,
                        static_cast<int>(flAlpha * kAlphaByteScale));
    }
    m_pSprite->SetSpriteCount(m_nSlotCount);
}
