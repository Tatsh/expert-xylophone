#include "limelight_effect_layer.h"

#include "bg_layer.h"
#include "neRender.h"
#include "neSpriteInstancing.h"
#include "neTexture.h"

// The process-wide Limelight effect layer, created lazily by shared().
static LimelightEffectLayer *g_pLimelightEffectLayer = nullptr; // @ghidraAddress 0x3dd300

namespace {

// The background-effect atlases the layer loads (@ghidraAddress 0x3ceaa8 and 0x3ceaf0).
constexpr const char *kBackgroundTextureName = "00_texture/gm_parts2";
constexpr const char *kEffectTextureName = "00_texture/ti_parts_eff";

// The per-slot sprite-instancer capacities (@ghidraAddress 0x304210).
constexpr unsigned int kSlotCapacities[] = {12, 28};

// The per-slot texture-field selector (@ghidraAddress 0x304218): 0 binds the background atlas, 1
// binds the effect atlas.
constexpr int kSlotTextureField[] = {0, 1};

// The per-slot additive-blend flag (@ghidraAddress 0x304220): a non-zero entry puts the slot into
// additive blend mode.
constexpr bool kSlotAdditiveBlend[] = {false, false};

// The additive blend-mode identifier the flagged slots use.
constexpr int kAdditiveBlendMode = 1;

} // namespace

/** @ghidraAddress 0x11ff84 */
LimelightEffectLayer::LimelightEffectLayer() = default;

/** @ghidraAddress 0x11ffcc */
LimelightEffectLayer *LimelightEffectLayer::shared() {
    if (g_pLimelightEffectLayer == nullptr) {
        // The binary allocates the raw 0x48-byte object and runs the constructor, which chains the
        // base-layer constructor and zero-clears the layer's state.
        g_pLimelightEffectLayer = new LimelightEffectLayer();
    }
    return g_pLimelightEffectLayer;
}

/** @ghidraAddress 0x12001c */
void LimelightEffectLayer::InitializeBackgroundSprites() {
    if (m_bSpritesBuilt) {
        return;
    }

    // The sprites hang beneath the shared background layer's render object rather than the global
    // scene root.
    BgLayer *pBackgroundLayer = BgLayer::GetBackgroundLayer();
    ne::C_RENDER *pParent = pBackgroundLayer->GetBackgroundRenderObject();

    m_pBackgroundTexture = ne::C_TEXTURE::FindOrLoadCached(kBackgroundTextureName);
    m_pEffectTexture = ne::C_TEXTURE::FindOrLoadCached(kEffectTextureName);

    ne::C_TEXTURE *const apTextureFields[] = {m_pBackgroundTexture, m_pEffectTexture};

    // Build one sprite instancer per slot, attach it under the background render object, make it
    // visible, bind its atlas, seed its sprite count, and flag additive blend where requested.
    for (int nSlot = 0; nSlot < kSpriteSlotCount; ++nSlot) {
        ne::C_SPRITE_INSTANCING *pSprite = ne::CreateSpriteInstancer(kSlotCapacities[nSlot]);
        pParent->AttachChild(pSprite);
        pSprite->SetVisible(true);
        pSprite->SetRefCountedMember(apTextureFields[kSlotTextureField[nSlot]]);
        pSprite->SetSpriteCount(m_aSpriteCounts[nSlot]);
        if (kSlotAdditiveBlend[nSlot]) {
            pSprite->SetBlendMode(kAdditiveBlendMode);
        }
        m_apSprites[nSlot] = pSprite;
    }

    m_bSpritesBuilt = true;
}
