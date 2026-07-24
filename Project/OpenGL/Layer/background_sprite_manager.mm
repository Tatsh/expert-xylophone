#include "background_sprite_manager.h"

#include "Share/bg_layer.h"
#include "neRender.h"
#include "neSpriteInstancing.h"
#include "neTexture.h"

// The process-wide background sprite manager, created lazily by shared().
static BackgroundSpriteManager *g_pBackgroundManager = nullptr; // @ghidraAddress 0x3dcad8

namespace {

// The atlas the background sprites draw from (@ghidraAddress 0x3ceaa8).
constexpr const char *kTextureName = "00_texture/gm_parts2";

// The per-slot sprite-instancer capacities (@ghidraAddress 0x301cc8).
constexpr unsigned int kSlotCapacities[] = {3, 11, 11};

// The additive blend-mode identifier the outer two slots use.
constexpr int kAdditiveBlendMode = 1;

} // namespace

/** @ghidraAddress 0x10a7d8 */
BackgroundSpriteManager::BackgroundSpriteManager() = default;

/** @ghidraAddress 0x10a81c */
BackgroundSpriteManager *BackgroundSpriteManager::shared() {
    if (g_pBackgroundManager == nullptr) {
        // The binary allocates the raw 0x40-byte object and runs the constructor, which chains the
        // base-layer constructor and zero-clears the manager's state.
        g_pBackgroundManager = new BackgroundSpriteManager();
    }
    return g_pBackgroundManager;
}

/** @ghidraAddress 0x10a86c */
void BackgroundSpriteManager::BuildBackgroundSpriteNodes() {
    if (m_bBuilt) {
        return;
    }

    // The sprites hang beneath the shared background layer's render object rather than the global
    // scene root.
    BgLayer *pBackgroundLayer = BgLayer::GetBackgroundLayer();
    ne::C_RENDER *pParent = pBackgroundLayer->GetBackgroundRenderObject();

    m_pTexture = ne::C_TEXTURE::FindOrLoadCached(kTextureName);

    // Build one sprite instancer per slot, attach it under the background render object, make it
    // visible, bind the atlas, seed its sprite count, and flag additive blend on the outer two slots
    // (every slot but the middle one).
    for (int nSlot = 0; nSlot < kSpriteSlotCount; ++nSlot) {
        ne::C_SPRITE_INSTANCING *pSprite = ne::CreateSpriteInstancer(kSlotCapacities[nSlot]);
        pParent->AttachChild(pSprite);
        pSprite->SetVisible(true);
        pSprite->SetRefCountedMember(m_pTexture);
        pSprite->SetSpriteCount(m_aSpriteCounts[nSlot]);
        if (nSlot != 1) {
            pSprite->SetBlendMode(kAdditiveBlendMode);
        }
        m_apSprites[nSlot] = pSprite;
    }

    m_bBuilt = true;
}
