#include "note_trail_layer.h"

#include "bg_layer.h"
#include "neRender.h"
#include "neSpriteInstancing.h"
#include "neTexture.h"

// The process-wide note-trail layer, created lazily by shared().
static NoteTrailLayer *g_pNoteTrailLayer = nullptr; // @ghidraAddress 0x3def20

// A shared note-trail counter the constructor resets.
static int g_nNoteTrailCounter = 0; // @ghidraAddress 0x3def18

namespace {

// The atlas the note trails draw from (@ghidraAddress 0x3ceaa0).
constexpr const char *kTextureName = "00_texture/gm_parts1";

// The additive blend-mode identifier the trail batch uses.
constexpr int kAdditiveBlendMode = 1;

// The two texture-environment parameter slots the builder seeds (to 1 each), and that value.
constexpr int kTexParamSlotHigh = 1;
constexpr int kTexParamSlotLow = 0;
constexpr int kTexParamEnabled = 1;

} // namespace

/** @ghidraAddress 0x1846b0 */
NoteTrailLayer::NoteTrailLayer() {
    g_nNoteTrailCounter = 0;
}

/** @ghidraAddress 0x184708 */
NoteTrailLayer *NoteTrailLayer::shared() {
    if (g_pNoteTrailLayer == nullptr) {
        // The binary allocates the raw 0x2b0-byte object and runs the constructor.
        g_pNoteTrailLayer = new NoteTrailLayer();
    }
    return g_pNoteTrailLayer;
}

/** @ghidraAddress 0x184758 */
void NoteTrailLayer::LoadNoteTrailSprites() {
    if (m_bBuilt) {
        return;
    }

    // The sprite hangs beneath the shared background layer's render object rather than the global
    // scene root.
    BgLayer *pBackgroundLayer = BgLayer::GetBackgroundLayer();
    ne::C_RENDER *pParent = pBackgroundLayer->GetBackgroundRenderObject();

    m_pTexture = ne::C_TEXTURE::FindOrLoadCached(kTextureName);

    m_pSprite = ne::CreateWorldSpriteBatch(kSpriteCapacity);
    pParent->AttachChild(m_pSprite);
    m_pSprite->SetVisible(true);
    m_pSprite->SetRefCountedMember(m_pTexture);
    m_pSprite->SetSpriteCount(0);
    m_pSprite->SetBlendMode(kAdditiveBlendMode);
    if (!IsHardwareType9()) {
        m_pSprite->SetTexParam(kTexParamSlotHigh, kTexParamEnabled);
        m_pSprite->SetTexParam(kTexParamSlotLow, kTexParamEnabled);
    }

    m_bBuilt = true;
}
