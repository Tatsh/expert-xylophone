#include "number_layer.h"

#include "../Share/bg_layer.h"
#include "neRender.h"
#include "neSpriteInstancing.h"
#include "neTexture.h"
#include "s_vector2.h"
#include "sprite_uv_table.h"

// The process-wide number layer, created lazily by shared().
static NumberLayer *g_pNumberLayer = nullptr; // @ghidraAddress 0x3dee50

namespace {

// One score-digit marker layout record: the sprite batch it draws into, its anchor and pixel size,
// and the atlas-frame index. Static read-only data embedded in the binary; the 24-byte stride
// matches the layout. @ghidraAddress 0x30d9f4
struct NumberMarkerLayout {
    int nBatch = {};        // +0x00: the sprite batch index.
    float flAnchorX = {};   // +0x04: the sprite anchor X.
    float flAnchorY = {};   // +0x08: the sprite anchor Y.
    float flSizeX = {};     // +0x0c: the sprite pixel width.
    float flSizeY = {};     // +0x10: the sprite pixel height.
    int nUvFrameIndex = {}; // +0x14: the atlas-frame index (into the shared sprite UV atlas).
};
constexpr NumberMarkerLayout kNumberMarkerLayout[] = {
    {0, 23.0f, 23.5f, 46.0f, 47.0f, 0x67},
    {0, 22.5f, 22.5f, 45.0f, 45.0f, 0x40},
    {0, 19.5f, 22.5f, 39.0f, 45.0f, 0x41},
    {0, 19.5f, 22.5f, 39.0f, 45.0f, 0x42},
    {0, 21.0f, 22.5f, 42.0f, 45.0f, 0x43},
    {0, 20.5f, 22.5f, 41.0f, 45.0f, 0x44},
    {0, 18.5f, 22.5f, 37.0f, 45.0f, 0x45},
    {0, 20.0f, 22.5f, 40.0f, 45.0f, 0x41},
    {0, 19.5f, 22.5f, 39.0f, 45.0f, 0x42},
    {0, 23.0f, 22.5f, 46.0f, 45.0f, 0x40},
    {0, 19.5f, 22.5f, 39.0f, 45.0f, 0x49},
    {0, 20.5f, 22.5f, 41.0f, 45.0f, 0x4a},
    {0, 16.0f, 22.5f, 32.0f, 45.0f, 0x4b},
};

// The marker-index threshold above which the binary draws from the number layer's own effect UV
// atlas (@ghidraAddress 0x2f7908) rather than the shared parts atlas (@c g_aSpriteUvTable). The
// shipped caller (the process step) only emits indices 0 through 12, so that branch is never taken;
// this reconstruction reads the shared atlas for the exercised range.
constexpr unsigned int kEffectAtlasMarkerThreshold = 0xc;

// The X and Y blend offsets applied when centring a marker position (@ghidraAddress 0x2f8568 =
// -384, the field half-width, and 0x301f94 = -680).
constexpr float kCentreBlendX = -384.0f;
constexpr float kCentreBlendY = -680.0f;
constexpr float kCentreBlendHalf = 0.5f;

// The atlases the number layer loads (@ghidraAddress 0x3ceaa8 and 0x3ceaf0).
constexpr const char *kPartsTextureName = "00_texture/gm_parts2";
constexpr const char *kEffectTextureName = "00_texture/ti_parts_eff";

// The per-slot sprite-instancer capacities (@ghidraAddress 0x30d4b0).
constexpr unsigned int kSlotCapacities[] = {13, 28};

// The per-slot texture-field selector (@ghidraAddress 0x30d4b8): 0 binds the parts atlas, 1 binds
// the effect atlas.
constexpr int kSlotTextureField[] = {0, 1};

// The per-slot additive-blend flag (@ghidraAddress 0x30d4c0): a non-zero entry puts the slot into
// additive blend mode.
constexpr bool kSlotAdditiveBlend[] = {false, false};

// The additive blend-mode identifier the flagged slots use.
constexpr int kAdditiveBlendMode = 1;

} // namespace

/** @ghidraAddress 0x17dd98 */
NumberLayer::NumberLayer() = default;

/** @ghidraAddress 0x17dde0 */
NumberLayer *NumberLayer::shared() {
    if (g_pNumberLayer == nullptr) {
        // The binary allocates the raw 0x48-byte object and runs the constructor, which chains the
        // base-layer constructor and zero-clears the layer's state.
        g_pNumberLayer = new NumberLayer();
    }
    return g_pNumberLayer;
}

/** @ghidraAddress 0x17de30 */
void NumberLayer::InitializeNumberLayer() {
    if (m_bBuilt) {
        return;
    }

    // The sprites hang beneath the shared background layer's render object rather than the global
    // scene root.
    BgLayer *pBackgroundLayer = BgLayer::GetBackgroundLayer();
    ne::C_RENDER *pParent = pBackgroundLayer->GetBackgroundRenderObject();

    m_pPartsTexture = ne::C_TEXTURE::FindOrLoadCached(kPartsTextureName);
    m_pEffectTexture = ne::C_TEXTURE::FindOrLoadCached(kEffectTextureName);

    ne::C_TEXTURE *const apTextureFields[] = {m_pPartsTexture, m_pEffectTexture};

    // Build one sprite instancer per slot, attach it under the background render object, make it
    // visible, bind its atlas, seed its sprite count, and flag additive blend where requested.
    for (int nSlot = 0; nSlot < kSpriteSlotCount; ++nSlot) {
        ne::C_SPRITE_INSTANCING_2D *pSprite = ne::CreateSpriteInstancer(kSlotCapacities[nSlot]);
        pParent->AttachChild(pSprite);
        pSprite->SetVisible(true);
        pSprite->SetRefCountedMember(apTextureFields[kSlotTextureField[nSlot]]);
        pSprite->SetSpriteCount(m_aSpriteCounts[nSlot]);
        if (kSlotAdditiveBlend[nSlot]) {
            pSprite->SetBlendMode(kAdditiveBlendMode);
        }
        m_apSprites[nSlot] = pSprite;
    }

    m_bBuilt = true;
}

/** @ghidraAddress 0x17df2c */
void NumberLayer::SetReady() {
    m_bReady = true;
    m_nFrameCounter = 0;
}

/** @ghidraAddress 0x17df3c */
void NumberLayer::ClearReady() {
    m_bReady = false;
}

/** @ghidraAddress 0x17e1b4 */
void NumberLayer::EmitMarkerSprite(
    unsigned int uMarkerIndex, S_VECTOR2 *pPosition, int iAlpha, float flScaleW, float flScaleH) {
    const NumberMarkerLayout &layout = kNumberMarkerLayout[uMarkerIndex];
    // The shared parts atlas covers the exercised marker range; the binary's high-index branch
    // (uMarkerIndex > 12) instead reads the layer's effect atlas, which the shipped caller never hits.
    (void)kEffectAtlasMarkerThreshold;
    const SpriteUvEntry &uv = g_aSpriteUvTable[layout.nUvFrameIndex];

    ne::C_SPRITE_INSTANCING_2D *pBatch = m_apSprites[layout.nBatch];
    const int nSlot = pBatch->GetSpriteCount();
    if (nSlot >= static_cast<int>(pBatch->GetCapacity())) {
        return;
    }

    // Blend the position toward the screen centre: the phone layout averages both axes with the
    // field edge and adds half the cached viewport size; the iPad layout offsets only the Y.
    if (!IsPad()) {
        pPosition->x = (pPosition->x + kCentreBlendX) * kCentreBlendHalf +
                       m_flViewportWidth * kCentreBlendHalf;
        pPosition->y = (pPosition->y + kCentreBlendY) * kCentreBlendHalf +
                       m_flViewportHeight * kCentreBlendHalf;
    } else {
        pPosition->y = pPosition->y + kCentreBlendY + m_flViewportHeight * kCentreBlendHalf;
    }

    pBatch->SetSpritePosition(nSlot, *pPosition);
    pBatch->SetSpriteAnchor(nSlot, S_VECTOR2{layout.flAnchorX, layout.flAnchorY});
    pBatch->SetSpriteSize(nSlot, S_VECTOR2{layout.flSizeX, layout.flSizeY});
    pBatch->SetSpriteUvOrigin(nSlot, S_VECTOR2{uv.flOriginU, uv.flOriginV});
    pBatch->SetSpriteUvSize(nSlot, S_VECTOR2{uv.flSizeU, uv.flSizeV});
    pBatch->SetSpriteScale(nSlot, flScaleW, flScaleH);
    pBatch->SetSpriteColor(nSlot, 0xff, 0xff, 0xff, static_cast<unsigned int>(iAlpha));
    pBatch->SetSpriteCount(nSlot + 1);
}
