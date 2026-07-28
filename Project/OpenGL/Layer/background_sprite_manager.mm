#include "background_sprite_manager.h"

#include "Share/bg_layer.h"
#include "neRender.h"
#include "neSpriteInstancing.h"
#include "neTexture.h"
#include "s_vector2.h"
#include "sprite_uv_table.h"

// The process-wide background sprite manager, created lazily by shared().
static BackgroundSpriteManager *g_pBackgroundManager = nullptr; // @ghidraAddress 0x3dcad8

namespace {

// The atlas the background sprites draw from (@ghidraAddress 0x3ceaa8).
constexpr const char *kTextureName = "00_texture/gm_parts2";

// The per-slot sprite-instancer capacities (@ghidraAddress 0x301cc8).
constexpr unsigned int kSlotCapacities[] = {3, 11, 11};

// The additive blend-mode identifier the outer two slots use.
constexpr int kAdditiveBlendMode = 1;

// The maximum value of an opaque colour channel.
constexpr unsigned int kColorMax = 255;

// One zoom-effect sprite-layout record: the instance's sprite anchor and pixel size, and the shared
// UV atlas frame it draws from. The 20-byte stride matches the binary.
struct ZoomSpriteLayout {
    float flAnchorX;   // +0x00: the sprite's anchor X.
    float flAnchorY;   // +0x04: the sprite's anchor Y.
    float flSizeX;     // +0x08: the sprite's pixel width.
    float flSizeY;     // +0x0c: the sprite's pixel height.
    int nUvFrameIndex; // +0x10: the frame into the shared sprite UV atlas.
};

// The zoom-effect sprite-layout table: the border quad, the edge quads, and the segment row the
// intro zoom animation draws. Read-only ROM data embedded in the binary. @ghidraAddress 0x301e4c
constexpr ZoomSpriteLayout kZoomSpriteLayout[] = {
    {90.0f, 90.0f, 180.0f, 180.0f, 0},
    {250.0f, 38.0f, 500.0f, 76.0f, 1},
    {21.0f, 28.0f, 42.0f, 56.0f, 2},
    {31.0f, 28.0f, 62.0f, 56.0f, 3},
    {19.0f, 28.0f, 38.0f, 56.0f, 4},
    {18.0f, 28.0f, 36.0f, 56.0f, 5},
    {19.0f, 28.0f, 38.0f, 56.0f, 6},
    {21.0f, 28.0f, 42.0f, 56.0f, 7},
    {23.0f, 28.0f, 46.0f, 56.0f, 8},
};

} // namespace

/** @ghidraAddress 0x10a7d8 */
BackgroundSpriteManager::BackgroundSpriteManager() = default;

/** @ghidraAddress 0x10a81c */
BackgroundSpriteManager *BackgroundSpriteManager::shared() {
    if (g_pBackgroundManager == nullptr) {
        // The binary allocates the raw 0x40-byte object and runs the constructor, which chains the
        // base-layer constructor and zero-clears the manager's state.
        g_pBackgroundManager = new BackgroundSpriteManager();
    }
    return g_pBackgroundManager;
}

/** @ghidraAddress 0x10a86c */
void BackgroundSpriteManager::BuildBackgroundSpriteNodes() {
    if (m_bBuilt) {
        return;
    }

    // The sprites hang beneath the shared background layer's render object rather than the global
    // scene root.
    BgLayer *pBackgroundLayer = BgLayer::GetBackgroundLayer();
    ne::C_RENDER *pParent = pBackgroundLayer->GetBackgroundRenderObject();

    m_pTexture = ne::C_TEXTURE::FindOrLoadCached(kTextureName);

    // Build one sprite instancer per slot, attach it under the background render object, make it
    // visible, bind the atlas, seed its sprite count, and flag additive blend on the outer two slots
    // (every slot but the middle one).
    for (int nSlot = 0; nSlot < kSpriteSlotCount; ++nSlot) {
        ne::C_SPRITE_INSTANCING_2D *pSprite = ne::CreateSpriteInstancer(kSlotCapacities[nSlot]);
        pParent->AttachChild(pSprite);
        pSprite->SetVisible(true);
        pSprite->SetRefCountedMember(m_pTexture);
        pSprite->SetSpriteCount(m_aSpriteCounts[nSlot]);
        if (nSlot != 1) {
            pSprite->SetBlendMode(kAdditiveBlendMode);
        }
        m_apSprites[nSlot] = pSprite;
    }

    m_bBuilt = true;
}

/** @ghidraAddress 0x10b1e0 */
void BackgroundSpriteManager::PushSpriteInstanceSlot(float flScaleX,
                                                     float flScaleY,
                                                     unsigned int nSlotIndex,
                                                     unsigned int nLayoutIndex,
                                                     const S_VECTOR2 *pPosition,
                                                     int nAlpha) {
    ne::C_SPRITE_INSTANCING_2D *pInstancer = m_apSprites[nSlotIndex];
    const int nSlot = pInstancer->GetSpriteCount();
    if (nSlot >= static_cast<int>(pInstancer->GetCapacity())) {
        return;
    }

    const ZoomSpriteLayout &layout = kZoomSpriteLayout[nLayoutIndex];
    const SpriteUvEntry &uv = g_aSpriteUvTable[layout.nUvFrameIndex];

    pInstancer->SetSpritePosition(nSlot, *pPosition);
    pInstancer->SetSpriteAnchor(nSlot, S_VECTOR2{layout.flAnchorX, layout.flAnchorY});
    pInstancer->SetSpriteSize(nSlot, S_VECTOR2{layout.flSizeX, layout.flSizeY});
    pInstancer->SetSpriteUvOrigin(nSlot, S_VECTOR2{uv.flOriginU, uv.flOriginV});
    pInstancer->SetSpriteUvSize(nSlot, S_VECTOR2{uv.flSizeU, uv.flSizeV});
    pInstancer->SetSpriteScale(nSlot, flScaleX, flScaleY);
    pInstancer->SetSpriteColor(
        nSlot, kColorMax, kColorMax, kColorMax, static_cast<unsigned int>(nAlpha));

    pInstancer->SetSpriteCount(nSlot + 1);
}

/** @ghidraAddress 0x10a938 */
void BackgroundSpriteManager::SetActiveAndResetCounter() {
    m_bActive = true;
    m_nFrameCounter = 0;
}

/** @ghidraAddress 0x10a948 */
void BackgroundSpriteManager::SetInactive() {
    m_bActive = false;
}
