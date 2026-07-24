#include "full_combo_classic_layer.h"

#include <cassert>

#include "../Share/bg_layer.h"
#include "neRender.h"
#include "neSpriteInstancing.h"
#include "neTexture.h"

// The process-wide Classic full-combo layer, created lazily by shared().
static FullComboClassicLayer *g_pFullComboClassicLayer = nullptr; // @ghidraAddress 0x3dd078

namespace {

// The atlas the full-combo sprites draw from (@ghidraAddress 0x3ceaa8).
constexpr const char *kTextureName = "00_texture/gm_parts2";

// The sprite capacity each of the layer's instancers is built with.
constexpr unsigned int kSlotCapacity = 0x40;

// The additive blend-mode identifier the sprites use.
constexpr int kAdditiveBlendMode = 1;

// The two texture-environment parameter slots the builder seeds (to 1 each), and that value.
constexpr int kTexParamSlotHigh = 1;
constexpr int kTexParamSlotLow = 0;
constexpr int kTexParamEnabled = 1;

} // namespace

/** @ghidraAddress 0x10f280 */
FullComboClassicLayer::FullComboClassicLayer() = default;

/** @ghidraAddress 0x10f2dc */
FullComboClassicLayer *FullComboClassicLayer::shared() {
    if (g_pFullComboClassicLayer == nullptr) {
        // The binary allocates the raw 0x50-byte object and runs the constructor, which chains the
        // base-layer constructor and zero-clears the layer's state.
        g_pFullComboClassicLayer = new FullComboClassicLayer();
    }
    return g_pFullComboClassicLayer;
}

/** @ghidraAddress 0x10f32c */
void FullComboClassicLayer::InitializeBackgroundSprites() {
    if (m_bBuilt) {
        return;
    }

    // The sprites hang beneath the shared background layer's render object rather than the global
    // scene root.
    BgLayer *pBackgroundLayer = BgLayer::GetBackgroundLayer();
    ne::C_RENDER *pParent = pBackgroundLayer->GetBackgroundRenderObject();

    m_pTexture = ne::C_TEXTURE::FindOrLoadCached(kTextureName);

    // Build one sprite instancer per slot, attach it under the background render object, make it
    // visible, bind the atlas, clear its sprite count, put it in additive blend, and enable its two
    // texture-environment parameters.
    for (int nSlot = 0; nSlot < kSpriteSlotCount; ++nSlot) {
        ne::C_SPRITE_INSTANCING *pSprite = ne::CreateWorldSpriteBatch(kSlotCapacity);
        m_apSprites[nSlot] = pSprite;
        pParent->AttachChild(pSprite);
        pSprite->SetVisible(true);
        pSprite->SetRefCountedMember(m_pTexture);
        pSprite->SetSpriteCount(0);
        pSprite->SetBlendMode(kAdditiveBlendMode);
        pSprite->SetTexParam(kTexParamSlotHigh, kTexParamEnabled);
        pSprite->SetTexParam(kTexParamSlotLow, kTexParamEnabled);
    }

    m_bBuilt = true;
}

/** @ghidraAddress 0x10f3f4 */
void FullComboClassicLayer::CreateFullComboClassic(unsigned int nColor) {
    assert(static_cast<int>(nColor) >= 0 && nColor < kColorCount);
    EffectRecord &effect = m_aEffects[nColor];
    effect.m_bActive = true;
    effect.m_nTimer = 0;
    effect.m_bFlag2 = false;
}
