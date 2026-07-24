#include "limelight_theme_layer.h"

#include "../Share/bg_layer.h"
#include "neRender.h"
#include "neSpriteInstancing.h"
#include "neTexture.h"

// The process-wide Limelight-theme layer, created lazily by shared().
static LimelightThemeLayer *g_pLimelightThemeLayer = nullptr; // @ghidraAddress 0x3dd380

namespace {

// The full-combo atlases the layer loads (@ghidraAddress 0x3ceaa8, 0x3ceaf0, and 0x3ceb00).
constexpr const char *kPartsTextureName = "00_texture/gm_parts2";
constexpr const char *kEffectTextureName = "00_texture/ti_parts_eff";
constexpr const char *kWinTextureName = "00_texture/gm_win";

// The per-slot sprite-instancer capacities (@ghidraAddress 0x305404).
constexpr unsigned int kSlotCapacities[] = {1, 100, 100, 2};

// The per-slot texture-field selector (@ghidraAddress 0x305414): the index into the layer's three
// texture fields for each textured slot. Slot 0 binds no texture, so its entry is unused.
constexpr int kSlotTextureField[] = {-1, 0, 1, 2};

// The slot that receives additive blend mode, and that mode's identifier.
constexpr int kAdditiveBlendSlot = 3;
constexpr int kAdditiveBlendMode = 1;

} // namespace

/** @ghidraAddress 0x120630 */
LimelightThemeLayer::LimelightThemeLayer() = default;

/** @ghidraAddress 0x1206c8 */
LimelightThemeLayer *LimelightThemeLayer::shared() {
    if (g_pLimelightThemeLayer == nullptr) {
        // The binary allocates the raw 0x98-byte object and runs the constructor, which chains the
        // base-layer constructor and seeds the layer's state.
        g_pLimelightThemeLayer = new LimelightThemeLayer();
    }
    return g_pLimelightThemeLayer;
}

/** @ghidraAddress 0x120718 */
void LimelightThemeLayer::InitFullComboLayerTextures() {
    if (m_bBuilt) {
        return;
    }

    // The sprites hang beneath the shared background layer's render object rather than the global
    // scene root.
    BgLayer *pBackgroundLayer = BgLayer::GetBackgroundLayer();
    ne::C_RENDER *pParent = pBackgroundLayer->GetBackgroundRenderObject();

    m_pPartsTexture = ne::C_TEXTURE::FindOrLoadCached(kPartsTextureName);
    m_pEffectTexture = ne::C_TEXTURE::FindOrLoadCached(kEffectTextureName);
    m_pWinTexture = ne::C_TEXTURE::FindOrLoadCached(kWinTextureName);

    ne::C_TEXTURE *const apTextureFields[] = {m_pPartsTexture, m_pEffectTexture, m_pWinTexture};

    // Build one sprite instancer per slot, attach it under the background render object, and make it
    // visible. The first slot binds no texture; the rest bind their mapped atlas. Seed each slot's
    // sprite count and flag additive blend on the last slot.
    for (int nSlot = 0; nSlot < kSpriteSlotCount; ++nSlot) {
        ne::C_SPRITE_INSTANCING *pSprite = ne::CreateWorldSpriteBatch(kSlotCapacities[nSlot]);
        pParent->AttachChild(pSprite);
        pSprite->SetVisible(true);
        if (nSlot != 0) {
            pSprite->SetRefCountedMember(apTextureFields[kSlotTextureField[nSlot]]);
        }
        pSprite->SetSpriteCount(m_aSpriteCounts[nSlot]);
        if (nSlot == kAdditiveBlendSlot) {
            pSprite->SetBlendMode(kAdditiveBlendMode);
        }
        m_apSprites[nSlot] = pSprite;
    }

    m_bBuilt = true;
}
