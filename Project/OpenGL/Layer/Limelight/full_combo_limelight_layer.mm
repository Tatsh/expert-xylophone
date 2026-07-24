#include "full_combo_limelight_layer.h"

#include <cassert>

#include "../Share/bg_layer.h"
#include "neRender.h"
#include "neSpriteInstancing.h"
#include "neTexture.h"

// The process-wide Limelight full-combo layer, created lazily by shared().
static FullComboLimelightLayer *g_pFullComboLimelightLayer = nullptr; // @ghidraAddress 0x3ddc40

namespace {

// The full-combo atlases the layer loads (@ghidraAddress 0x3ceaf0 and 0x3ceaa8). The last two slots
// share the gm_parts2 atlas.
constexpr const char *kEffectTextureName = "00_texture/ti_parts_eff";
constexpr const char *kPartsTextureName = "00_texture/gm_parts2";

// The per-slot sprite-instancer capacities (@ghidraAddress 0x306260).
constexpr unsigned int kSlotCapacities[] = {256, 32, 32};

// The per-slot texture-field selector (@ghidraAddress 0x30626c): the index into the layer's three
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

/** @ghidraAddress 0x1228e4 */
FullComboLimelightLayer *FullComboLimelightLayer::shared() {
    if (g_pFullComboLimelightLayer == nullptr) {
        // The binary allocates the raw 0x68-byte object and runs its initialiser, which chains the
        // base-layer constructor and seeds the layer's state.
        g_pFullComboLimelightLayer = new FullComboLimelightLayer();
    }
    return g_pFullComboLimelightLayer;
}

/** @ghidraAddress 0x122934 */
void FullComboLimelightLayer::LoadTexturesAndBatchesForLimelightLayer() {
    if (m_bBuilt) {
        return;
    }

    // The sprites hang beneath the shared background layer's render object rather than the global
    // scene root.
    BgLayer *pBackgroundLayer = BgLayer::GetBackgroundLayer();
    ne::C_RENDER *pParent = pBackgroundLayer->GetBackgroundRenderObject();

    m_pEffectTexture = ne::C_TEXTURE::FindOrLoadCached(kEffectTextureName);
    m_pPartsTexture = ne::C_TEXTURE::FindOrLoadCached(kPartsTextureName);
    m_pPartsTexture2 = ne::C_TEXTURE::FindOrLoadCached(kPartsTextureName);

    ne::C_TEXTURE *const apTextureFields[] = {m_pEffectTexture, m_pPartsTexture, m_pPartsTexture2};

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

/** @ghidraAddress 0x122a44 */
void FullComboLimelightLayer::CreateFullComboLimelight(unsigned int nColor) {
    assert(static_cast<int>(nColor) >= 0 && nColor < kColorCount);
    EffectRecord &effect = m_aEffects[nColor];
    effect.m_bActive = true;
    effect.m_nTimer = 0;
    effect.m_bFlag2 = false;
}
