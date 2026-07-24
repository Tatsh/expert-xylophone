#include "result_window_colette_layer.h"

#include "neSpriteInstancing.h"
#include "neTexture.h"

// The process-wide Colette result-window layer, created lazily by shared().
static ResultWindowColetteLayer *g_pColetteResultLayer = nullptr; // @ghidraAddress 0x3dc598

namespace {

// The texture-name table entries the result window loads (@ghidraAddress 0x3cea80 and 0x3ceab0).
constexpr const char *kBackgroundTextureName = "00_texture/sel_bg";
constexpr const char *kPartsTextureName = "00_texture/result_parts";

// The per-slot sprite-instancer capacities (@ghidraAddress 0x2fe874). Slot 1 (the parts atlas) holds
// the most sprites; the rest are small fixed banks.
constexpr unsigned int kSlotCapacities[] = {1, 500, 1, 1, 1, 2, 2, 1};

// The slot that draws the result-parts atlas, and the slot that draws the overlay texture. The
// per-slot source table (@ghidraAddress 0x2fe854) selects the layer texture field for each: slot 1
// binds the parts atlas (+0x18) and slot 7 binds the overlay (+0x20).
constexpr int kPartsSlot = 1;
constexpr int kOverlaySlot = 7;

// The fixed glyph-table base indices and parts scale the builder stamps into the layer.
constexpr int kGlyphBaseA = 0x4e;
constexpr int kGlyphBaseB = 0x45;
constexpr int kGlyphBaseC = 0x3a;
constexpr float kPartsScale = 1.0f;

} // namespace

/** @ghidraAddress 0x73edc */
ResultWindowColetteLayer *ResultWindowColetteLayer::shared() {
    if (g_pColetteResultLayer == nullptr) {
        // The binary allocates the raw 0x180-byte object and runs the constructor, which chains the
        // base-layer constructor and zero-clears the layer's state.
        g_pColetteResultLayer = new ResultWindowColetteLayer();
    }
    return g_pColetteResultLayer;
}

/** @ghidraAddress 0x73f2c */
void ResultWindowColetteLayer::InitializeResultWindowSprites() {
    if (m_bBuilt) {
        return;
    }

    m_nGlyphBaseA = kGlyphBaseA;
    m_nGlyphBaseB = kGlyphBaseB;
    m_nGlyphBaseC = kGlyphBaseC;
    m_flPartsScale = kPartsScale;

    m_pBackgroundTexture = ne::C_TEXTURE::FindOrLoadCached(kBackgroundTextureName);
    m_pPartsTexture = ne::C_TEXTURE::FindOrLoadCached(kPartsTextureName);

    // Build one sprite instancer per slot, register it in the global scene tree, make it visible,
    // and reset its sprite count. The parts slot binds the parts atlas and the overlay slot binds
    // the overlay texture (which the builder leaves unset, so it binds null here).
    for (int nSlot = 0; nSlot < kSlotCount; ++nSlot) {
        m_apSlots[nSlot] = ne::CreateWorldSpriteBatch(kSlotCapacities[nSlot]);
        m_apSlots[nSlot]->RegisterGlobal();
        m_apSlots[nSlot]->SetVisible(true);
        if (nSlot == kOverlaySlot) {
            m_apSlots[nSlot]->SetRefCountedMember(m_pOverlayTexture);
        } else if (nSlot == kPartsSlot) {
            m_apSlots[nSlot]->SetRefCountedMember(m_pPartsTexture);
        }
        m_apSlots[nSlot]->SetSpriteCount(0);
    }

    m_bBuilt = true;
}
