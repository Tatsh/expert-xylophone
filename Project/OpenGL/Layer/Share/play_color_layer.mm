#include "play_color_layer.h"

#include "bg_layer.h"
#include "neRender.h"
#include "neSpriteInstancing.h"
#include "neTexture.h"
#import "s_vector2.h"

// The process-wide play-colour layer, created lazily by shared().
static PlayColorLayer *g_pPlayColorLayer = nullptr; // @ghidraAddress 0x3dc5a0

namespace {

// The atlas the gauge parts draw from (@ghidraAddress 0x3ceaa0).
constexpr const char *kTextureName = "00_texture/gm_parts1";

// Which batch each part group draws into (@ghidraAddress 0x2fe8a0).
constexpr int kGroupBatch[] = {0, 0, 0, 0, 0, 0, 0, 0, 1, 1};

// How many sprites each part group emits (@ghidraAddress 0x2fe8c8).
constexpr int kGroupPartCount[] = {6, 6, 6, 6, 3, 3, 6, 6, 3, 3};

// One gauge part's source rect (anchor, size) and mapped UV rect (origin, size), combining the
// source-rect table (@ghidraAddress 0x2fe900) with the UV table it indexes (@ghidraAddress
// 0x2ef668).
struct GaugePart {
    float flAnchorX;
    float flAnchorY;
    float flSizeW;
    float flSizeH;
    float flUvOriginU;
    float flUvOriginV;
    float flUvSizeU;
    float flUvSizeV;
};
constexpr GaugePart kGaugeParts[] = {
    {32.0f, 32.0f, 64.0f, 64.0f, 0.00195f, 0.31055f, 0.09766f, 0.09766f},
    {32.0f, 32.0f, 64.0f, 64.0f, 0.00195f, 0.31055f, 0.09766f, 0.09766f},
    {25.0f, 20.0f, 50.0f, 50.0f, 0.20117f, 0.31055f, 0.07031f, 0.06641f},
    {25.0f, 20.0f, 50.0f, 50.0f, 0.27344f, 0.31055f, 0.07031f, 0.06641f},
    {31.0f, 9.0f, 62.0f, 18.0f, 0.20312f, 0.37891f, 0.01953f, 0.02734f},
    {31.0f, 9.0f, 62.0f, 18.0f, 0.22852f, 0.37891f, 0.01953f, 0.02734f},
    {32.0f, 32.0f, 64.0f, 64.0f, 0.10156f, 0.31055f, 0.09766f, 0.09766f},
    {32.0f, 32.0f, 64.0f, 64.0f, 0.10156f, 0.31055f, 0.09766f, 0.09766f},
    {31.0f, 31.0f, 62.0f, 62.0f, 0.89062f, 0.09961f, 0.06055f, 0.06055f},
    {31.0f, 31.0f, 62.0f, 62.0f, 0.89062f, 0.09961f, 0.06055f, 0.06055f},
};

// The additive-style vertex flag the gauge batches set.
constexpr int kVertexFlagMode = 1;

} // namespace

/** @ghidraAddress 0x83460 */
PlayColorLayer::PlayColorLayer() {
    // Seed the transform block's scales to 1 (offsets +0x90/+0x98/+0x9c in the binary).
    m_aTransform[7] = 1.0f;

    // Assign each part group a non-overlapping index range within its batch, accumulating each
    // batch's total capacity as it goes.
    for (int nGroup = 0; nGroup < kPartGroupCount; ++nGroup) {
        const int nBatch = kGroupBatch[nGroup];
        m_aPartBaseIndex[nGroup] = m_aBatchCapacity[nBatch];
        m_aBatchCapacity[nBatch] += kGroupPartCount[nGroup];
    }
}

/** @ghidraAddress 0x8350c */
PlayColorLayer *PlayColorLayer::shared() {
    if (g_pPlayColorLayer == nullptr) {
        // The binary allocates the raw 0xa0-byte object and runs the constructor.
        g_pPlayColorLayer = new PlayColorLayer();
    }
    return g_pPlayColorLayer;
}

/** @ghidraAddress 0x8355c */
void PlayColorLayer::BuildGaugePartsSpriteBatches() {
    if (m_bBuilt) {
        return;
    }

    // The batches hang beneath the shared background layer's render object rather than the global
    // scene root.
    BgLayer *pBackgroundLayer = BgLayer::GetBackgroundLayer();
    ne::C_RENDER *pParent = pBackgroundLayer->GetBackgroundRenderObject();

    m_pTexture = ne::C_TEXTURE::FindOrLoadCached(kTextureName);

    // Build the two batches, each sized to hold all the part groups routed to it, and set the
    // additive-style vertex flag on each.
    for (int nBatch = 0; nBatch < kBatchCount; ++nBatch) {
        ne::C_SPRITE_INSTANCING *pSprite =
            ne::CreateWorldSpriteBatch(static_cast<unsigned int>(m_aBatchCapacity[nBatch]));
        m_apSprites[nBatch] = pSprite;
        pParent->AttachChild(pSprite);
        pSprite->SetVisible(true);
        pSprite->SetRefCountedMember(m_pTexture);
        pSprite->SetSpriteCount(m_aBatchCapacity[nBatch]);
        pSprite->SetBlendMode(kVertexFlagMode);
    }

    // Emit each part group's sprites into its batch.
    for (int nGroup = 0; nGroup < kPartGroupCount; ++nGroup) {
        for (int nPart = 0; nPart < kGroupPartCount[nGroup]; ++nPart) {
            EmitGaugePartSprite(0.0f,
                                0.0f,
                                1.0f,
                                1.0f,
                                0.0f,
                                static_cast<unsigned int>(kGroupBatch[nGroup]),
                                static_cast<unsigned int>(nGroup),
                                0);
        }
    }

    m_bBuilt = true;
}

/** @ghidraAddress 0x83684 */
void PlayColorLayer::EmitGaugePartSprite(float flPosX,
                                         float flPosY,
                                         float flScaleX,
                                         float flScaleY,
                                         float flRotation,
                                         unsigned int nBatchIndex,
                                         unsigned int nPartIndex,
                                         unsigned int nAlpha) {
    if (nBatchIndex >= static_cast<unsigned int>(kBatchCount) ||
        nPartIndex >= static_cast<unsigned int>(kPartGroupCount)) {
        return;
    }
    ne::C_SPRITE_INSTANCING *pBatch = m_apSprites[nBatchIndex];
    const int nIndex = pBatch->GetSpriteCount();
    if (nIndex >= static_cast<int>(pBatch->GetCapacity())) {
        return;
    }

    const GaugePart &part = kGaugeParts[nPartIndex];
    pBatch->SetSpritePosition(nIndex, S_VECTOR2{flPosX, flPosY});
    pBatch->SetSpriteAnchor(nIndex, S_VECTOR2{part.flAnchorX, part.flAnchorY});
    pBatch->SetSpriteSize(nIndex, S_VECTOR2{part.flSizeW, part.flSizeH});
    pBatch->SetSpriteUvOrigin(nIndex, S_VECTOR2{part.flUvOriginU, part.flUvOriginV});
    pBatch->SetSpriteUvSize(nIndex, S_VECTOR2{part.flUvSizeU, part.flUvSizeV});
    pBatch->SetSpriteScale(nIndex, flScaleX, flScaleY);
    pBatch->SetSpriteRotation(nIndex, flRotation);
    pBatch->SetSpriteColor(nIndex, 0xff, 0xff, 0xff, nAlpha);
    pBatch->SetSpriteCount(nIndex + 1);
}
