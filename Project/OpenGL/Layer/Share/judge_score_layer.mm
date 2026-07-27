//
//  judge_score_layer.mm
//  REFLEC BEAT plus
//
//  The judgement-score effect layer (JudgeScoreLayer). Reconstructed from Ghidra project rb458,
//  program rb458. @ghidraAddress values are relative to the program image base.
//

#include "judge_score_layer.h"

#include "bg_layer.h"
#include "neRender.h"
#include "neSpriteInstancing.h"
#include "neTexture.h"

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
