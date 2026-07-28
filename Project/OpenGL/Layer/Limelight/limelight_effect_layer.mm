#include "limelight_effect_layer.h"

#include "bg_layer.h"
#include "neRender.h"
#include "neSpriteInstancing.h"
#include "neTexture.h"
#include "s_vector2.h"
#include "sprite_uv_table.h"

// The title-part UV atlas (a distinct atlas from the shared sprite UV table); the lower effect
// glyph kinds take their UV from it.
extern const SpriteUvEntry g_aTitlePartUvDefault[]; // @ghidraAddress 0x2f7908

// The process-wide Limelight effect layer, created lazily by shared().
static LimelightEffectLayer *g_pLimelightEffectLayer = nullptr; // @ghidraAddress 0x3dd300

namespace {

// The background-effect atlases the layer loads (@ghidraAddress 0x3ceaa8 and 0x3ceaf0).
constexpr const char *kBackgroundTextureName = "00_texture/gm_parts2";
constexpr const char *kEffectTextureName = "00_texture/ti_parts_eff";

// The per-slot sprite-instancer capacities (@ghidraAddress 0x304210).
constexpr unsigned int kSlotCapacities[] = {12, 28};

// The per-slot texture-field selector (@ghidraAddress 0x304218): 0 binds the background atlas, 1
// binds the effect atlas.
constexpr int kSlotTextureField[] = {0, 1};

// The per-slot additive-blend flag (@ghidraAddress 0x304220): a non-zero entry puts the slot into
// additive blend mode.
constexpr bool kSlotAdditiveBlend[] = {false, false};

// The additive blend-mode identifier the flagged slots use.
constexpr int kAdditiveBlendMode = 1;

// One record of the effect sprite-layout table: the target sprite group, the fixed anchor and quad
// size, and the atlas-frame index for an effect glyph kind.
struct EffectSpriteLayout {
    int nGroup = {};      // +0x00: the sprite group, used directly as the instancer slot.
    float flAnchorX = {}; // +0x04: the anchor's X offset.
    float flAnchorY = {}; // +0x08: the anchor's Y offset.
    float flSizeX = {};   // +0x0c: the quad's width.
    float flSizeY = {};   // +0x10: the quad's height.
    int nAtlasFrame = {}; // +0x14: the atlas-frame index into the UV table.
};

// The per-kind effect sprite layout (@ghidraAddress 0x304d64): kinds 0..11 are the base glyphs
// (group 0), kinds 12..39 the curve-animated glyphs (group 1).
constexpr EffectSpriteLayout kEffectSpriteLayout[] = {
    {0, 30.0f, 28.0f, 60.0f, 56.0f, 28},   {0, 23.0f, 28.0f, 46.0f, 56.0f, 29},
    {0, 20.0f, 28.0f, 40.0f, 56.0f, 30},   {0, 20.0f, 28.0f, 50.0f, 56.0f, 31},
    {0, 33.0f, 28.0f, 66.0f, 56.0f, 32},   {0, 23.0f, 28.0f, 46.0f, 56.0f, 33},
    {0, 23.0f, 28.0f, 46.0f, 56.0f, 29},   {0, 20.0f, 28.0f, 40.0f, 56.0f, 30},
    {0, 30.0f, 28.0f, 60.0f, 56.0f, 28},   {0, 27.0f, 28.0f, 54.0f, 56.0f, 34},
    {0, 26.0f, 28.0f, 52.0f, 56.0f, 35},   {0, 22.0f, 28.0f, 44.0f, 56.0f, 36},
    {1, 69.0f, 69.0f, 138.0f, 138.0f, 20}, {1, 55.5f, 55.5f, 110.0f, 110.0f, 21},
    {1, 27.0f, 27.0f, 54.0f, 54.0f, 24},   {1, 9.5f, 9.5f, 16.0f, 16.0f, 25},
    {1, 27.0f, 27.0f, 54.0f, 54.0f, 8},    {1, 9.5f, 9.5f, 19.0f, 19.0f, 9},
    {1, 69.0f, 69.0f, 138.0f, 138.0f, 22}, {1, 55.5f, 55.5f, 110.0f, 110.0f, 23},
    {1, 9.5f, 9.5f, 16.0f, 16.0f, 25},     {1, 27.0f, 27.0f, 54.0f, 54.0f, 24},
    {1, 69.0f, 69.0f, 138.0f, 138.0f, 20}, {1, 55.5f, 55.5f, 110.0f, 110.0f, 21},
    {1, 69.0f, 69.0f, 138.0f, 138.0f, 18}, {1, 55.5f, 55.5f, 110.0f, 110.0f, 19},
    {1, 27.0f, 27.0f, 54.0f, 54.0f, 8},    {1, 9.5f, 9.5f, 19.0f, 19.0f, 9},
    {1, 27.0f, 27.0f, 54.0f, 54.0f, 8},    {1, 9.5f, 9.5f, 19.0f, 19.0f, 9},
    {1, 69.0f, 69.0f, 138.0f, 138.0f, 22}, {1, 55.5f, 55.5f, 110.0f, 110.0f, 23},
    {1, 69.0f, 69.0f, 138.0f, 138.0f, 22}, {1, 55.5f, 55.5f, 110.0f, 110.0f, 23},
    {1, 69.0f, 69.0f, 138.0f, 138.0f, 18}, {1, 55.5f, 55.5f, 110.0f, 110.0f, 19},
    {1, 70.0f, 70.0f, 140.0f, 140.0f, 14}, {1, 70.0f, 70.0f, 140.0f, 140.0f, 15},
    {1, 69.0f, 69.0f, 138.0f, 138.0f, 20}, {1, 55.5f, 55.5f, 110.0f, 110.0f, 21},
};

// The highest effect glyph kind whose UV comes from the shared atlas table rather than the
// title-part table (@c kind @c > @c 11 selects the shared atlas).
constexpr unsigned int kMaxTitlePartKind = 11;

// The layout offsets the phone and iPad use to place a glyph relative to the cached viewport size
// (@ghidraAddress 0x2f8568 = -384 half-width bias, 0x301f94 = -680 height bias). The phone halves
// the biased position and adds half the cached viewport; the iPad keeps full size and only shifts
// vertically.
constexpr float kPhoneHalfWidthBias = -384.0f;
constexpr float kHeightBias = -680.0f;
constexpr float kViewportHalfScale = 0.5f;

// The opaque white channel value each effect glyph is tinted with.
constexpr unsigned int kChannelWhite = 0xff;

} // namespace

/** @ghidraAddress 0x11ff84 */
LimelightEffectLayer::LimelightEffectLayer() = default;

/** @ghidraAddress 0x11ffcc */
LimelightEffectLayer *LimelightEffectLayer::shared() {
    if (g_pLimelightEffectLayer == nullptr) {
        // The binary allocates the raw 0x48-byte object and runs the constructor, which chains the
        // base-layer constructor and zero-clears the layer's state.
        g_pLimelightEffectLayer = new LimelightEffectLayer();
    }
    return g_pLimelightEffectLayer;
}

/** @ghidraAddress 0x12001c */
void LimelightEffectLayer::InitializeBackgroundSprites() {
    if (m_bSpritesBuilt) {
        return;
    }

    // The sprites hang beneath the shared background layer's render object rather than the global
    // scene root.
    BgLayer *pBackgroundLayer = BgLayer::GetBackgroundLayer();
    ne::C_RENDER *pParent = pBackgroundLayer->GetBackgroundRenderObject();

    m_pBackgroundTexture = ne::C_TEXTURE::FindOrLoadCached(kBackgroundTextureName);
    m_pEffectTexture = ne::C_TEXTURE::FindOrLoadCached(kEffectTextureName);

    ne::C_TEXTURE *const apTextureFields[] = {m_pBackgroundTexture, m_pEffectTexture};

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

    m_bSpritesBuilt = true;
}

/** @ghidraAddress 0x120118 */
void LimelightEffectLayer::SetActiveAndResetCounter() {
    m_bActive = true;
    m_flClock = 0.0f;
}

/** @ghidraAddress 0x120128 */
void LimelightEffectLayer::SetInactive() {
    m_bActive = false;
}

/** @ghidraAddress 0x120434 */
void LimelightEffectLayer::EmitSpriteSlot(unsigned int nSpriteKind,
                                          S_VECTOR2 *pPosition,
                                          unsigned int nAlpha,
                                          float flScaleX,
                                          float flScaleY) {
    const EffectSpriteLayout &layout = kEffectSpriteLayout[nSpriteKind];
    // The higher kinds index the shared atlas; the lower kinds index the title-part atlas.
    const SpriteUvEntry &uv = nSpriteKind > kMaxTitlePartKind ?
                                  g_aSpriteUvTable[layout.nAtlasFrame] :
                                  g_aTitlePartUvDefault[layout.nAtlasFrame];

    ne::C_SPRITE_INSTANCING_2D *pBatch = m_apSprites[layout.nGroup];
    const int nIndex = pBatch->GetSpriteCount();
    // Drop the sprite when the target batch is full.
    if (nIndex >= static_cast<int>(pBatch->GetCapacity())) {
        return;
    }

    // The iPad keeps the base position and only shifts it vertically by the cached viewport height;
    // the phone halves the horizontally-biased position and re-centres it on the cached viewport.
    if (IsPad()) {
        pPosition->y = pPosition->y + kHeightBias + m_flCachedViewportHeight * kViewportHalfScale;
    } else {
        pPosition->x = (pPosition->x + kPhoneHalfWidthBias) * kViewportHalfScale +
                       m_flCachedViewportWidth * kViewportHalfScale;
        pPosition->y = (pPosition->y + kHeightBias) * kViewportHalfScale +
                       m_flCachedViewportHeight * kViewportHalfScale;
    }

    pBatch->SetSpritePosition(nIndex, *pPosition);
    pBatch->SetSpriteAnchor(nIndex, S_VECTOR2{layout.flAnchorX, layout.flAnchorY});
    pBatch->SetSpriteSize(nIndex, S_VECTOR2{layout.flSizeX, layout.flSizeY});
    pBatch->SetSpriteUvOrigin(nIndex, S_VECTOR2{uv.flOriginU, uv.flOriginV});
    pBatch->SetSpriteUvSize(nIndex, S_VECTOR2{uv.flSizeU, uv.flSizeV});
    pBatch->SetSpriteScale(nIndex, flScaleX, flScaleY);
    pBatch->SetSpriteColor(nIndex, kChannelWhite, kChannelWhite, kChannelWhite, nAlpha);
    pBatch->SetSpriteCount(nIndex + 1);
}
