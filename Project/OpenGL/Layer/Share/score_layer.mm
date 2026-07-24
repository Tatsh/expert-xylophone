#include "score_layer.h"

#include "bg_layer.h"
#include "neRender.h"
#include "neSpriteInstancing.h"
#include "neTexture.h"

// The process-wide score/combo layer, created lazily by shared().
static ScoreLayer *g_pScoreLayer = nullptr; // @ghidraAddress 0x3df2c8

namespace {

// The atlas the score/combo sprites draw from (@ghidraAddress 0x3ceaa8).
constexpr const char *kTextureName = "00_texture/gm_parts2";

// Which batch each part group's capacity accumulates into (@ghidraAddress 0x30fc58).
constexpr int kGroupBatch[] = {0, 1, 2, 1, 2, 3};

// How many sprites each part group contributes to its batch (@ghidraAddress 0x30fc70).
constexpr int kGroupPartCount[] = {2, 5, 5, 5, 5, 2};

// The batch that receives the vertex flag, and that flag value.
constexpr int kVertexFlagBatch = 2;
constexpr int kVertexFlagMode = 1;

} // namespace

/** @ghidraAddress 0x18a7d0 */
ScoreLayer::ScoreLayer() {
    m_aScales[0] = 1.0f;
    m_aScales[1] = 1.0f;

    // Accumulate each part group's sprite count into its batch's capacity, recording each group's
    // base index within that batch.
    for (int i = 0; i < kPartGroupCount; ++i) {
        const int nBatch = kGroupBatch[i];
        m_aPartBaseIndex[i] = m_aBatchCapacity[nBatch];
        m_aBatchCapacity[nBatch] += kGroupPartCount[i];
    }
}

/** @ghidraAddress 0x18a88c */
ScoreLayer *ScoreLayer::shared() {
    if (g_pScoreLayer == nullptr) {
        // The binary allocates the raw 0xa0-byte object and runs the constructor.
        g_pScoreLayer = new ScoreLayer();
    }
    return g_pScoreLayer;
}

/** @ghidraAddress 0x18a8dc */
void ScoreLayer::CreateGaugeSliderSprites() {
    if (m_bBuilt) {
        return;
    }

    m_pTexture = ne::C_TEXTURE::FindOrLoadCached(kTextureName);

    // Build the four batches, each sized to its accumulated capacity, attach each under the
    // background layer's render object, make it visible, bind the atlas, and clear its frame index;
    // the third batch also sets its vertex flag.
    for (int i = 0; i < kBatchCount; ++i) {
        ne::C_SPRITE_INSTANCING *pSprite =
            ne::CreateWorldSpriteBatch(static_cast<unsigned int>(m_aBatchCapacity[i]));
        m_apSprites[i] = pSprite;
        BgLayer *pBackgroundLayer = BgLayer::GetBackgroundLayer();
        ne::C_RENDER *pParent = pBackgroundLayer->GetBackgroundRenderObject();
        pParent->AttachChild(pSprite);
        pSprite->SetVisible(true);
        pSprite->SetRefCountedMember(m_pTexture);
        pSprite->SetSpriteCount(0);
        if (i == kVertexFlagBatch) {
            pSprite->SetBlendMode(kVertexFlagMode);
        }
    }

    m_bBuilt = true;
}
