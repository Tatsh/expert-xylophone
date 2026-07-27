//
//  note_glow_layer.mm
//  REFLEC BEAT plus
//
//  The note-glow effect layer (NoteGlowLayer). Reconstructed from Ghidra project rb458, program
//  rb458. @ghidraAddress values are relative to the program image base.
//

#include "note_glow_layer.h"

#include "bg_layer.h"
#include "neRender.h"
#include "neSpriteInstancing.h"
#include "neTexture.h"

namespace {
// The default scale pair the constructor seeds.
constexpr float kInitialScale = 1.0f;

// The atlas the glow sprites draw from.
constexpr const char *kAtlasTextureName = "00_texture_gm_parts1";

// The glow sprite batch holds two sprites and draws additively.
constexpr int kSpriteCapacity = 2;
constexpr int kAdditiveBlendMode = 1;
} // namespace

// The process-wide note-glow layer, created lazily by shared().
static NoteGlowLayer *g_pNoteGlowLayer = nullptr; // @ghidraAddress 0x3deb40

/** @ghidraAddress 0x1769a8 */
NoteGlowLayer *NoteGlowLayer::shared() {
    if (g_pNoteGlowLayer == nullptr) {
        g_pNoteGlowLayer = new NoteGlowLayer();
    }
    return g_pNoteGlowLayer;
}

/** @ghidraAddress 0x176964 */
NoteGlowLayer::NoteGlowLayer() {
    // The base constructor and member initialisers clear the sprite header and count state; the
    // default scale pair seeds to one.
    m_aScale[0] = kInitialScale;
    m_aScale[1] = kInitialScale;
}

/** @ghidraAddress 0x176a84 */
void NoteGlowLayer::SetTexture() {
    RefreshThema();
    // The texture only binds once the sprite instancer exists.
    if (m_pSprite != nullptr) {
        m_pTexture = ne::C_TEXTURE::FindOrLoadCached(kAtlasTextureName);
        m_pSprite->SetRefCountedMember(m_pTexture);
    }
}

/** @ghidraAddress 0x1769f8 */
void NoteGlowLayer::InitializeSprites() {
    if (m_bLoaded) {
        return;
    }

    ne::C_RENDER *pParent = BgLayer::GetBackgroundLayer()->GetBackgroundRenderObject();
    m_pTexture = ne::C_TEXTURE::FindOrLoadCached(kAtlasTextureName);
    m_nCapacity = kSpriteCapacity;
    m_pSprite = ne::CreateWorldSpriteBatch(kSpriteCapacity);
    pParent->AttachChild(m_pSprite);
    m_pSprite->SetVisible(true);
    m_pSprite->SetRefCountedMember(m_pTexture);
    m_pSprite->SetSpriteCount(0);
    m_pSprite->SetBlendMode(kAdditiveBlendMode);

    m_bLoaded = true;
}
