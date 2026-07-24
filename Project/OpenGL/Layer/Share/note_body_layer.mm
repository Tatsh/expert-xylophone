#include "note_body_layer.h"

#include "bg_layer.h"
#import "neEngineBridge.h"
#include "neRender.h"
#include "neSpriteInstancing.h"
#include "neTexture.h"

// The process-wide note-body layer, created lazily by shared().
static NoteBodyLayer *g_pNoteBodyLayer = nullptr; // @ghidraAddress 0x3def00

// The shared note-body draw count, reset when the layer's sprites are built.
static int g_nNoteBodyDrawCount = 0; // @ghidraAddress 0x3def08

namespace {

// The atlas the note bodies draw from (@ghidraAddress 0x3ceaa0).
constexpr const char *kTextureName = "00_texture/gm_parts1";

// The additive blend-mode identifier the outer two batches use.
constexpr int kAdditiveBlendMode = 1;

// The two texture-environment parameter slots the builder seeds (to 1 each), and that value.
constexpr int kTexParamSlotHigh = 1;
constexpr int kTexParamSlotLow = 0;
constexpr int kTexParamEnabled = 1;

} // namespace

/** @ghidraAddress 0x1812a0 */
NoteBodyLayer::NoteBodyLayer() {
    m_flBaseOffset = -1.0f;
}

/** @ghidraAddress 0x181310 */
NoteBodyLayer *NoteBodyLayer::shared() {
    if (g_pNoteBodyLayer == nullptr) {
        // The binary allocates the raw 0x480-byte object and runs the constructor.
        g_pNoteBodyLayer = new NoteBodyLayer();
    }
    return g_pNoteBodyLayer;
}

/** @ghidraAddress 0x181360 */
void NoteBodyLayer::LoadNoteBodySprites() {
    if (m_bBuilt) {
        return;
    }

    // The sprites hang beneath the shared background layer's render object rather than the global
    // scene root.
    BgLayer *pBackgroundLayer = BgLayer::GetBackgroundLayer();
    ne::C_RENDER *pParent = pBackgroundLayer->GetBackgroundRenderObject();

    m_pTexture = ne::C_TEXTURE::FindOrLoadCached(kTextureName);

    // Build the three sprite batches, attach each under the background render object, make it
    // visible, bind the atlas, clear its sprite count, flag additive blend on the outer two, and,
    // except on the tutorial hardware, enable each batch's two texture-environment parameters.
    for (int nBatch = 0; nBatch < kBatchCount; ++nBatch) {
        ne::C_SPRITE_INSTANCING *pSprite = ne::CreateWorldSpriteBatch(kSpriteCapacity);
        m_apSprites[nBatch] = pSprite;
        pParent->AttachChild(pSprite);
        pSprite->SetVisible(true);
        pSprite->SetRefCountedMember(m_pTexture);
        pSprite->SetSpriteCount(0);
        if (nBatch != 1) {
            pSprite->SetBlendMode(kAdditiveBlendMode);
        }
        if (!IsHardwareType9()) {
            pSprite->SetTexParam(kTexParamSlotHigh, kTexParamEnabled);
            pSprite->SetTexParam(kTexParamSlotLow, kTexParamEnabled);
        }
    }

    m_bBuilt = true;
    g_nNoteBodyDrawCount = 0;
}
