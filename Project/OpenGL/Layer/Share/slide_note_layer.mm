//
//  slide_note_layer.mm
//  REFLEC BEAT plus
//
//  The slide-note render layer (SlideNoteLayer). Reconstructed from Ghidra project rb458, program
//  rb458. @ghidraAddress values are relative to the program image base.
//

#include "slide_note_layer.h"

#include "bg_layer.h"
#include "neRender.h"
#include "neSpriteInstancing.h"
#include "neTexture.h"

// The process-wide slide-note layer, created lazily by shared().
static SlideNoteLayer *g_pSlideNoteLayer = nullptr; // @ghidraAddress 0x3dc658

// The number of active slide-note trails, shared with the trail animator.
int g_nActiveSlideTrailCount = 0; // @ghidraAddress 0x3dc650

namespace {
// The invalid-clock sentinel the layer starts with (no sample taken yet).
constexpr float kInvalidClock = -1.0f;

// The slide-note trail atlas and each batch's sprite capacity.
constexpr const char *kTrailTextureName = "00_texture/gm_parts1";
constexpr unsigned int kBatchCapacity = 0xf0;

// The additive blend mode, and the two sampler wrap parameters set on the newer hardware.
constexpr int kBlendModeAdditive = 1;
constexpr int kTexParamWrapT = 1;
constexpr int kTexParamWrapS = 0;
constexpr int kTexWrapRepeat = 1;
} // namespace

/** @ghidraAddress 0x95a18 */
SlideNoteLayer::SlideNoteLayer() {
    // The base constructor cached the device flags and theme; every trail record, sprite batch,
    // batch count, and the leading pointer start zero from their member initialisers, matching the
    // binary's field-by-field clears.
    m_bBuilt = false;
    m_flLastClock = kInvalidClock;
    g_nActiveSlideTrailCount = 0;
}

/** @ghidraAddress 0x95ae0 */
void SlideNoteLayer::BuildSprites() {
    if (m_bBuilt) {
        return;
    }
    // The trails hang beneath the shared background layer's render object.
    ne::C_RENDER *pParent = BgLayer::GetBackgroundLayer()->GetBackgroundRenderObject();
    m_pTexture = ne::C_TEXTURE::FindOrLoadCached(kTrailTextureName);
    for (int nBatch = 0; nBatch < kBatchCount; ++nBatch) {
        ne::C_SPRITE_INSTANCING_2D *pBatch = ne::CreateWorldSpriteBatch(kBatchCapacity);
        m_apBatches[nBatch] = pBatch;
        pParent->AttachChild(pBatch);
        pBatch->SetVisible(true);
        pBatch->SetRefCountedMember(m_pTexture);
        pBatch->SetSpriteCount(0);
        // Batches 0 and 2 draw with additive blending.
        if ((nBatch & ~2) == 0) {
            pBatch->SetBlendMode(kBlendModeAdditive);
        }
        // The newer hardware needs the trail atlas's wrap sampler parameters set explicitly.
        if (!IsHardwareType9()) {
            pBatch->SetTexParam(kTexParamWrapT, kTexWrapRepeat);
            pBatch->SetTexParam(kTexParamWrapS, kTexWrapRepeat);
        }
    }
    m_bBuilt = true;
    g_nActiveSlideTrailCount = 0;
}

/** @ghidraAddress 0x95a90 */
SlideNoteLayer *SlideNoteLayer::shared() {
    if (g_pSlideNoteLayer == nullptr) {
        // The binary allocates the raw 0xe08-byte object and runs the constructor.
        g_pSlideNoteLayer = new SlideNoteLayer();
    }
    return g_pSlideNoteLayer;
}
