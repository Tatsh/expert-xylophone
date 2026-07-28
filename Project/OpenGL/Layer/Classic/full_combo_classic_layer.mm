#include "full_combo_classic_layer.h"

#include <cassert>

#include "../Share/bg_layer.h"
#include "../Share/sprite_uv_table.h"
#include "full_combo_classic_sprite_table.h"
#include "neRender.h"
#include "neSpriteInstancing.h"
#include "neTexture.h"
#include "s_vector2.h"

// The process-wide Classic full-combo layer, created lazily by shared().
static FullComboClassicLayer *g_pFullComboClassicLayer = nullptr; // @ghidraAddress 0x3dd078

// The shared sprite-UV atlas the descriptor entries index by uvIndex.
extern const SpriteUvEntry g_aSpriteUvTable[]; // @ghidraAddress 0x2efcc8

// The Classic full-combo sprite-type descriptor table (declared in
// full_combo_classic_sprite_table.h): read-only ROM data transcribed from the binary at 0x302bf8.
const ClassicFullComboSpriteType g_aClassicFullComboSpriteTypes[kClassicFullComboSpriteTypeCount] =
    {
        // {anchorX, anchorY, sizeW, sizeH, uvIndex}
        {15.0f, 24.0f, 30.0f, 48.0f, 13},    // 0
        {19.0f, 24.0f, 38.0f, 48.0f, 14},    // 1
        {15.0f, 24.0f, 30.0f, 48.0f, 15},    // 2
        {27.0f, 24.0f, 54.0f, 48.0f, 16},    // 3
        {29.0f, 24.0f, 58.0f, 48.0f, 17},    // 4
        {28.0f, 24.0f, 56.0f, 48.0f, 18},    // 5
        {18.0f, 24.0f, 36.0f, 48.0f, 19},    // 6
        {4.0f, 24.0f, 8.0f, 48.0f, 20},      // 7
        {234.0f, 39.0f, 468.0f, 78.0f, 21},  // 8
        {62.0f, 200.0f, 124.0f, 200.0f, 22}, // 9
        {62.0f, 200.0f, 124.0f, 200.0f, 23}, // 10
        {22.0f, 22.0f, 44.0f, 44.0f, 24},    // 11
        {22.0f, 22.0f, 44.0f, 44.0f, 25},    // 12
        {32.0f, 106.0f, 64.0f, 106.0f, 26},  // 13
        {32.0f, 106.0f, 64.0f, 106.0f, 27},  // 14
        {14.0f, 14.0f, 28.0f, 28.0f, 12},    // 15
};

namespace {

// The atlas the full-combo sprites draw from (@ghidraAddress 0x3ceaa8).
constexpr const char *kTextureName = "00_texture/gm_parts2";

// The sprite capacity each of the layer's instancers is built with.
constexpr unsigned int kSlotCapacity = 0x40;

// The additive blend-mode identifier the sprites use.
constexpr int kAdditiveBlendMode = 1;

// The two texture-environment parameter slots the builder seeds (to 1 each), and that value.
constexpr int kTexParamSlotHigh = 1;
constexpr int kTexParamSlotLow = 0;
constexpr int kTexParamEnabled = 1;

} // namespace

/** @ghidraAddress 0x10f280 */
FullComboClassicLayer::FullComboClassicLayer() = default;

/** @ghidraAddress 0x10f2dc */
FullComboClassicLayer *FullComboClassicLayer::shared() {
    if (g_pFullComboClassicLayer == nullptr) {
        // The binary allocates the raw 0x50-byte object and runs the constructor, which chains the
        // base-layer constructor and zero-clears the layer's state.
        g_pFullComboClassicLayer = new FullComboClassicLayer();
    }
    return g_pFullComboClassicLayer;
}

/** @ghidraAddress 0x10f32c */
void FullComboClassicLayer::InitializeBackgroundSprites() {
    if (m_bBuilt) {
        return;
    }

    // The sprites hang beneath the shared background layer's render object rather than the global
    // scene root.
    BgLayer *pBackgroundLayer = BgLayer::GetBackgroundLayer();
    ne::C_RENDER *pParent = pBackgroundLayer->GetBackgroundRenderObject();

    m_pTexture = ne::C_TEXTURE::FindOrLoadCached(kTextureName);

    // Build one sprite instancer per slot, attach it under the background render object, make it
    // visible, bind the atlas, clear its sprite count, put it in additive blend, and enable its two
    // texture-environment parameters.
    for (int nSlot = 0; nSlot < kSpriteSlotCount; ++nSlot) {
        ne::C_SPRITE_INSTANCING_2D *pSprite = ne::CreateWorldSpriteBatch(kSlotCapacity);
        m_apSprites[nSlot] = pSprite;
        pParent->AttachChild(pSprite);
        pSprite->SetVisible(true);
        pSprite->SetRefCountedMember(m_pTexture);
        pSprite->SetSpriteCount(0);
        pSprite->SetBlendMode(kAdditiveBlendMode);
        pSprite->SetTexParam(kTexParamSlotHigh, kTexParamEnabled);
        pSprite->SetTexParam(kTexParamSlotLow, kTexParamEnabled);
    }

    m_bBuilt = true;
}

/** @ghidraAddress 0x10f3f4 */
void FullComboClassicLayer::CreateFullComboClassic(unsigned int nColor) {
    assert(static_cast<int>(nColor) >= 0 && nColor < kColorCount);
    EffectRecord &effect = m_aEffects[nColor];
    effect.m_bActive = true;
    effect.m_nTimer = 0;
    effect.m_bFlag2 = false;
}

/** @ghidraAddress 0x10fe88 */
void FullComboClassicLayer::CreateSprite(int nObjType,
                                         int nType,
                                         const S_VECTOR2 *pPosition,
                                         unsigned int nAlpha,
                                         float flScaleX,
                                         float flScaleY,
                                         float flRotation) {
    assert(nObjType >= 0);
    assert(nObjType < kClassicFullComboObjectTypeCount);
    assert(nType >= 0);
    assert(nType < kClassicFullComboSpriteTypeCount);

    // Skip the sprite when the object type's batch is already full.
    const int nIndex = m_aSpriteCounts[nObjType];
    if (nIndex >= static_cast<int>(kSlotCapacity)) {
        return;
    }

    const ClassicFullComboSpriteType &spriteType = g_aClassicFullComboSpriteTypes[nType];
    const SpriteUvEntry &uv = g_aSpriteUvTable[spriteType.nUvIndex];
    ne::C_SPRITE_INSTANCING_2D *pBatch = m_apSprites[nObjType];

    pBatch->SetSpritePosition(nIndex, *pPosition);
    pBatch->SetSpriteAnchor(nIndex, S_VECTOR2{spriteType.flAnchorX, spriteType.flAnchorY});
    pBatch->SetSpriteSize(nIndex, S_VECTOR2{spriteType.flSizeW, spriteType.flSizeH});
    pBatch->SetSpriteUvOrigin(nIndex, S_VECTOR2{uv.flOriginU, uv.flOriginV});
    pBatch->SetSpriteUvSize(nIndex, S_VECTOR2{uv.flSizeU, uv.flSizeV});
    pBatch->SetSpriteScale(nIndex, flScaleX, flScaleY);
    pBatch->SetSpriteRotation(nIndex, flRotation);
    pBatch->SetSpriteColor(nIndex, 0xff, 0xff, 0xff, nAlpha);

    ++m_aSpriteCounts[nObjType];
}

/** @ghidraAddress 0x10f46c */
void FullComboClassicLayer::ClearEffectFlags() {
    for (EffectRecord &effect : m_aEffects) {
        effect.m_bActive = false;
    }
}

/** @ghidraAddress 0x10f488 */
bool FullComboClassicLayer::IsAnyEffectActive() const {
    for (const EffectRecord &effect : m_aEffects) {
        if (effect.m_bActive) {
            return true;
        }
    }
    return false;
}
