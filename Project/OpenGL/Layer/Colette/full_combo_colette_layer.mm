#include "full_combo_colette_layer.h"

#include "../Share/bg_layer.h"
#import "neEngineBridge.h"
#include "neRender.h"
#include "neSpriteInstancing.h"
#include "neTexture.h"

// The process-wide Colette full-combo layer, created lazily by shared().
static FullComboColetteLayer *g_pFullComboColetteLayer = nullptr; // @ghidraAddress 0x3dc668

namespace {

// The atlas the layer loads into all three of its texture fields (@ghidraAddress 0x3ceaa8).
constexpr const char *kTextureName = "00_texture/gm_parts2";

// The per-slot sprite-instancer capacities (@ghidraAddress 0x2ff050).
constexpr unsigned int kSlotCapacities[] = {32, 256, 32};

// The per-slot texture-field selector (@ghidraAddress 0x2ff05c): the index into the layer's three
// texture fields for each slot.
constexpr int kSlotTextureField[] = {0, 1, 2};

// The slot that receives additive blend mode, and that mode's identifier.
constexpr int kAdditiveBlendSlot = 1;
constexpr int kAdditiveBlendMode = 1;

// The two texture-environment parameter slots the builder seeds (to 1 each), and that value.
constexpr int kTexParamSlotHigh = 1;
constexpr int kTexParamSlotLow = 0;
constexpr int kTexParamEnabled = 1;

} // namespace

/** @ghidraAddress 0x9b18c */
FullComboColetteLayer *FullComboColetteLayer::shared() {
    if (g_pFullComboColetteLayer == nullptr) {
        // The binary allocates the raw 0x68-byte object and runs its initialiser, which chains the
        // base-layer constructor and seeds the layer's state.
        g_pFullComboColetteLayer = new FullComboColetteLayer();
    }
    return g_pFullComboColetteLayer;
}

/** @ghidraAddress 0x9b1dc */
void FullComboColetteLayer::InitializeBackgroundSpriteLayers() {
    if (m_bBuilt) {
        return;
    }

    // The sprites hang beneath the shared background layer's render object rather than the global
    // scene root.
    BgLayer *pBackgroundLayer = BgLayer::GetBackgroundLayer();
    ne::C_RENDER *pParent = pBackgroundLayer->GetBackgroundRenderObject();

    m_pTexture0 = ne::C_TEXTURE::FindOrLoadCached(kTextureName);
    m_pTexture1 = ne::C_TEXTURE::FindOrLoadCached(kTextureName);
    m_pTexture2 = ne::C_TEXTURE::FindOrLoadCached(kTextureName);

    ne::C_TEXTURE *const apTextureFields[] = {m_pTexture0, m_pTexture1, m_pTexture2};

    // Build one sprite instancer per slot, attach it under the background render object, make it
    // visible, bind its mapped atlas, clear its sprite count, put the middle slot in additive blend,
    // and enable each slot's two texture-environment parameters.
    for (int nSlot = 0; nSlot < kSpriteSlotCount; ++nSlot) {
        ne::C_SPRITE_INSTANCING *pSprite = ne::CreateWorldSpriteBatch(kSlotCapacities[nSlot]);
        m_apSprites[nSlot] = pSprite;
        pParent->AttachChild(pSprite);
        pSprite->SetVisible(true);
        pSprite->SetRefCountedMember(apTextureFields[kSlotTextureField[nSlot]]);
        pSprite->SetSpriteCount(0);
        if (nSlot == kAdditiveBlendSlot) {
            pSprite->SetBlendMode(kAdditiveBlendMode);
        }
        pSprite->SetTexParam(kTexParamSlotHigh, kTexParamEnabled);
        pSprite->SetTexParam(kTexParamSlotLow, kTexParamEnabled);
    }

    m_bBuilt = true;
}
