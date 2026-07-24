#include "note_charge_layer.h"

#include "bg_layer.h"
#import "deviceenvironment.h"
#include "neRender.h"
#include "neSpriteInstancing.h"
#include "neTexture.h"

// The process-wide note-charge layer, created lazily by shared().
static NoteChargeLayer *g_pNoteChargeLayer = nullptr; // @ghidraAddress 0x3deef8

namespace {

// The atlas the charge notes draw from (@ghidraAddress 0x3ceaa0).
constexpr const char *kTextureName = "00_texture/gm_parts1";

// The per-group sprite capacities the constructor sums into the instancer capacity (@ghidraAddress
// 0x30dee0).
constexpr int kGroupCapacities[] = {32, 32, 256, 256, 256, 256, 256, 256};

// The additive blend-mode identifier the charge batch uses.
constexpr int kAdditiveBlendMode = 1;

// The two texture-environment parameter slots the builder seeds (to 1 each), and that value.
constexpr int kTexParamSlotHigh = 1;
constexpr int kTexParamSlotLow = 0;
constexpr int kTexParamEnabled = 1;

} // namespace

/** @ghidraAddress 0x180b54 */
NoteChargeLayer::NoteChargeLayer() {
    // The instancer capacity is the sum of the per-group capacity table.
    for (int nGroup = 0;
         nGroup < static_cast<int>(sizeof(kGroupCapacities) / sizeof(*kGroupCapacities));
         ++nGroup) {
        m_nSpriteCapacity += kGroupCapacities[nGroup];
    }
}

/** @ghidraAddress 0x180bf8 */
NoteChargeLayer *NoteChargeLayer::shared() {
    if (g_pNoteChargeLayer == nullptr) {
        // The binary allocates the raw 0x1b38-byte object and runs the constructor.
        g_pNoteChargeLayer = new NoteChargeLayer();
    }
    return g_pNoteChargeLayer;
}

/** @ghidraAddress 0x180c48 */
void NoteChargeLayer::LoadNoteChargeSprites() {
    if (m_bBuilt) {
        return;
    }

    // The sprite hangs beneath the shared background layer's render object rather than the global
    // scene root.
    BgLayer *pBackgroundLayer = BgLayer::GetBackgroundLayer();
    ne::C_RENDER *pParent = pBackgroundLayer->GetBackgroundRenderObject();

    m_pTexture = ne::C_TEXTURE::FindOrLoadCached(kTextureName);

    m_pSprite = ne::CreateWorldSpriteBatch(static_cast<unsigned int>(m_nSpriteCapacity));
    pParent->AttachChild(m_pSprite);
    m_pSprite->SetVisible(true);
    m_pSprite->SetRefCountedMember(m_pTexture);
    m_pSprite->SetSpriteCount(0);
    m_pSprite->SetBlendMode(kAdditiveBlendMode);
    if (!GetIsHardwareType9Flag()) {
        m_pSprite->SetTexParam(kTexParamSlotHigh, kTexParamEnabled);
        m_pSprite->SetTexParam(kTexParamSlotLow, kTexParamEnabled);
    }

    m_bBuilt = true;
}
