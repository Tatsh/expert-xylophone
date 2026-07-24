#include "judge_effect_layer.h"

#include "bg_layer.h"
#import "neEngineBridge.h"
#include "neRender.h"
#include "neSpriteInstancing.h"
#include "neTexture.h"

// The process-wide judge-effect layer, created lazily by shared().
static JudgeEffectLayer *g_pJudgeEffectLayer = nullptr; // @ghidraAddress 0x3def28

namespace {

// The atlas the judge effect draws from (@ghidraAddress 0x3ceaa8).
constexpr const char *kTextureName = "00_texture/gm_parts2";

} // namespace

/** @ghidraAddress 0x184bb0 */
JudgeEffectLayer::JudgeEffectLayer() = default;

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
