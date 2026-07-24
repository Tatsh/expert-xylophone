#include "limelight_result_layer.h"

#import "neEngineBridge.h"
#include "neRender.h"
#include "neSpriteInstancing.h"
#include "neTexture.h"

// The process-wide Limelight result-window layer, created lazily by shared().
static LimelightResultLayer *g_pLimelightResultLayer = nullptr; // @ghidraAddress 0x3de008

namespace {

// The atlases the result window loads (@ghidraAddress 0x3cea80 and 0x3ceab0).
constexpr const char *kBackgroundTextureName = "00_texture/sel_bg";
constexpr const char *kPartsTextureName = "00_texture/result_parts";

// The per-slot sprite-instancer capacities (@ghidraAddress 0x308a60). Slot 1 (the parts atlas) holds
// the most sprites; the rest are small fixed banks.
constexpr unsigned int kSlotCapacities[] = {1, 400, 1, 1, 1, 2, 2, 1};

// The per-slot texture-field selector (@ghidraAddress 0x308a40): the field index (0 = background,
// 1 = parts, 2 = overlay) into the layer's three texture fields for each slot that binds a texture.
// A slot binds a texture only when it is one of the first two or the last; the middle slots share
// the atlas already bound by the batch they mirror.
constexpr int kSlotTextureField[] = {0, 1, 4, 4, 4, 4, 4, 2};

// The base scale the builder seeds before creating the batches.
constexpr float kBaseScale = 0.7f;

// The slot range whose members do not bind a texture: slots kFirstUntexturedSlot through
// kFirstUntexturedSlot + kUntexturedSlotSpan - 1 (that is, slots 2 through 6).
constexpr int kFirstUntexturedSlot = 2;
constexpr int kUntexturedSlotSpan = 5;

} // namespace

/** @ghidraAddress 0x123d54 */
LimelightResultLayer *LimelightResultLayer::shared() {
    if (g_pLimelightResultLayer == nullptr) {
        // The binary allocates the raw 0x170-byte object and runs its initialiser, which chains the
        // base-layer constructor and seeds the layer's state.
        g_pLimelightResultLayer = new LimelightResultLayer();
    }
    return g_pLimelightResultLayer;
}

/** @ghidraAddress 0x123db0 */
void LimelightResultLayer::InitializePhoneSpriteInstancers() {
    if (m_bBuilt) {
        return;
    }

    m_nDefaultAlpha = 0;
    m_flBaseScale = kBaseScale;

    m_pBackgroundTexture = ne::C_TEXTURE::FindOrLoadCached(kBackgroundTextureName);
    m_pPartsTexture = ne::C_TEXTURE::FindOrLoadCached(kPartsTextureName);

    ne::C_TEXTURE *const apTextureFields[] = {
        m_pBackgroundTexture, m_pPartsTexture, m_pOverlayTexture};

    // Build one sprite instancer per slot, register it in the global scene tree, make it visible,
    // and clear its sprite count. The two edge slots bind a texture per the selector; the middle
    // slots (2 through 6) share the atlas of the batch they mirror, so they bind none here.
    for (int nSlot = 0; nSlot < kSpriteSlotCount; ++nSlot) {
        m_apSprites[nSlot] = ne::CreateSpriteInstancer(kSlotCapacities[nSlot]);
        m_apSprites[nSlot]->RegisterGlobal();
        m_apSprites[nSlot]->SetVisible(true);
        if (static_cast<unsigned int>(nSlot - kFirstUntexturedSlot) >= kUntexturedSlotSpan) {
            m_apSprites[nSlot]->SetRefCountedMember(apTextureFields[kSlotTextureField[nSlot]]);
        }
        m_apSprites[nSlot]->SetSpriteCount(0);
    }

    m_bBuilt = true;
}
