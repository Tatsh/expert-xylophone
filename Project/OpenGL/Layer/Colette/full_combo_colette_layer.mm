#include "full_combo_colette_layer.h"

#include <cassert>

#include "../Share/bg_layer.h"
#include "../Share/sprite_uv_table.h"
#include "full_combo_colette_sprite_table.h"
#include "neRender.h"
#include "neSpriteInstancing.h"
#include "neTexture.h"
#include "s_vector2.h"

// The process-wide Colette full-combo layer, created lazily by shared().
static FullComboColetteLayer *g_pFullComboColetteLayer = nullptr; // @ghidraAddress 0x3dc668

// The shared sprite-UV atlas the descriptor entries index by uvIndex.
extern const SpriteUvEntry g_aSpriteUvTable[]; // @ghidraAddress 0x2efcc8

// The Colette full-combo sprite-type descriptor table (declared in
// full_combo_colette_sprite_table.h): read-only ROM data transcribed from the binary at
// 0x3005f0, giving each type its batch group, anchor, size, and UV-table index.
const ColetteFullComboSpriteType g_aColetteFullComboSpriteTypes[kColetteFullComboSpriteTypeCount] =
    {
        {2, 23f, 23.5f, 46f, 47f, 63},  // 0
        {2, 19.5f, 23f, 39f, 46f, 93},  // 1
        {2, 19f, 23f, 38f, 46f, 94},    // 2
        {2, 18.5f, 23f, 37f, 46f, 95},  // 3
        {2, 18.5f, 23f, 37f, 46f, 96},  // 4
        {2, 21f, 23f, 42f, 46f, 97},    // 5
        {2, 21f, 23f, 42f, 46f, 98},    // 6
        {2, 22.5f, 23f, 45f, 46f, 99},  // 7
        {2, 20f, 23f, 40f, 46f, 100},   // 8
        {2, 21f, 23f, 42f, 46f, 101},   // 9
        {2, 7f, 23f, 14f, 46f, 102},    // 10
        {1, 32f, 106f, 64f, 106f, 106}, // 11
        {1, 32f, 106f, 64f, 106f, 106}, // 12
        {1, 32f, 106f, 64f, 106f, 107}, // 13
        {1, 32f, 106f, 64f, 106f, 107}, // 14
        {1, 50f, 50f, 100f, 100f, 92},  // 15
        {1, 50f, 50f, 100f, 100f, 92},  // 16
        {1, 23f, 23.5f, 46f, 47f, 104}, // 17
        {1, 23f, 23.5f, 46f, 47f, 104}, // 18
        {1, 23f, 23.5f, 46f, 47f, 104}, // 19
        {1, 23f, 23.5f, 46f, 47f, 104}, // 20
        {1, 23f, 23.5f, 46f, 47f, 104}, // 21
        {1, 23f, 23.5f, 46f, 47f, 104}, // 22
        {1, 23f, 23.5f, 46f, 47f, 104}, // 23
        {1, 23f, 23.5f, 46f, 47f, 104}, // 24
        {1, 23f, 23.5f, 46f, 47f, 104}, // 25
        {1, 23f, 23.5f, 46f, 47f, 105}, // 26
        {1, 23f, 23.5f, 46f, 47f, 105}, // 27
        {1, 23f, 23.5f, 46f, 47f, 105}, // 28
        {1, 23f, 23.5f, 46f, 47f, 105}, // 29
        {1, 23f, 23.5f, 46f, 47f, 105}, // 30
        {1, 23f, 23.5f, 46f, 47f, 105}, // 31
        {1, 23f, 23.5f, 46f, 47f, 105}, // 32
        {1, 23f, 23.5f, 46f, 47f, 105}, // 33
        {1, 23f, 23.5f, 46f, 47f, 105}, // 34
        {1, 23f, 23.5f, 46f, 47f, 105}, // 35
        {1, 23f, 23.5f, 46f, 47f, 105}, // 36
        {1, 23f, 23.5f, 46f, 47f, 105}, // 37
        {1, 23f, 23.5f, 46f, 47f, 105}, // 38
        {1, 23f, 23.5f, 46f, 47f, 105}, // 39
        {1, 23f, 23.5f, 46f, 47f, 105}, // 40
        {1, 23f, 23.5f, 46f, 47f, 105}, // 41
        {1, 23f, 23.5f, 46f, 47f, 105}, // 42
        {1, 23f, 23.5f, 46f, 47f, 105}, // 43
        {1, 23f, 23.5f, 46f, 47f, 105}, // 44
        {1, 23f, 23.5f, 46f, 47f, 105}, // 45
        {1, 23f, 23.5f, 46f, 47f, 105}, // 46
        {1, 20f, 20f, 40f, 40f, 109},   // 47
        {1, 20f, 20f, 40f, 40f, 109},   // 48
        {1, 20f, 20f, 40f, 40f, 109},   // 49
        {1, 20f, 20f, 40f, 40f, 109},   // 50
        {1, 20f, 20f, 40f, 40f, 109},   // 51
        {1, 20f, 20f, 40f, 40f, 109},   // 52
        {1, 20f, 20f, 40f, 40f, 109},   // 53
        {1, 20f, 20f, 40f, 40f, 109},   // 54
        {1, 23f, 22f, 46f, 44f, 110},   // 55
        {1, 23f, 22f, 46f, 44f, 110},   // 56
        {1, 23f, 22f, 46f, 44f, 110},   // 57
        {1, 23f, 22f, 46f, 44f, 110},   // 58
        {1, 50f, 50f, 100f, 100f, 91},  // 59
        {1, 50f, 50f, 100f, 100f, 91},  // 60
        {1, 23f, 23.5f, 46f, 47f, 104}, // 61
        {1, 23f, 23.5f, 46f, 47f, 104}, // 62
        {1, 23f, 23.5f, 46f, 47f, 104}, // 63
        {1, 23f, 23.5f, 46f, 47f, 104}, // 64
        {1, 23f, 23.5f, 46f, 47f, 104}, // 65
        {1, 23f, 23.5f, 46f, 47f, 104}, // 66
        {1, 23f, 23.5f, 46f, 47f, 104}, // 67
        {1, 23f, 23.5f, 46f, 47f, 104}, // 68
        {1, 23f, 23.5f, 46f, 47f, 104}, // 69
        {1, 23f, 23.5f, 46f, 47f, 105}, // 70
        {1, 23f, 23.5f, 46f, 47f, 105}, // 71
        {1, 23f, 23.5f, 46f, 47f, 105}, // 72
        {1, 23f, 23.5f, 46f, 47f, 105}, // 73
        {1, 23f, 23.5f, 46f, 47f, 105}, // 74
        {1, 23f, 23.5f, 46f, 47f, 105}, // 75
        {1, 23f, 23.5f, 46f, 47f, 105}, // 76
        {1, 23f, 23.5f, 46f, 47f, 105}, // 77
        {1, 23f, 23.5f, 46f, 47f, 105}, // 78
        {1, 23f, 23.5f, 46f, 47f, 105}, // 79
        {1, 23f, 23.5f, 46f, 47f, 105}, // 80
        {1, 23f, 23.5f, 46f, 47f, 105}, // 81
        {1, 23f, 23.5f, 46f, 47f, 105}, // 82
        {1, 23f, 23.5f, 46f, 47f, 105}, // 83
        {1, 23f, 23.5f, 46f, 47f, 105}, // 84
        {1, 23f, 23.5f, 46f, 47f, 105}, // 85
        {1, 23f, 23.5f, 46f, 47f, 105}, // 86
        {1, 23f, 23.5f, 46f, 47f, 105}, // 87
        {1, 23f, 23.5f, 46f, 47f, 105}, // 88
        {1, 23f, 23.5f, 46f, 47f, 105}, // 89
        {1, 23f, 23.5f, 46f, 47f, 105}, // 90
        {1, 20f, 20f, 40f, 40f, 108},   // 91
        {1, 20f, 20f, 40f, 40f, 108},   // 92
        {1, 20f, 20f, 40f, 40f, 108},   // 93
        {1, 20f, 20f, 40f, 40f, 108},   // 94
        {1, 20f, 20f, 40f, 40f, 108},   // 95
        {1, 20f, 20f, 40f, 40f, 108},   // 96
        {1, 20f, 20f, 40f, 40f, 108},   // 97
        {1, 20f, 20f, 40f, 40f, 108},   // 98
        {1, 23f, 22f, 46f, 44f, 110},   // 99
        {1, 23f, 22f, 46f, 44f, 110},   // 100
        {1, 23f, 22f, 46f, 44f, 110},   // 101
        {1, 23f, 22f, 46f, 44f, 110},   // 102
};

namespace {

// The layout size the constructor seeds.
constexpr float kLayoutWidth = 384.0f;
constexpr float kLayoutHeight = 1098.0f;

// The atlas the layer loads into all three of its texture fields (@ghidraAddress 0x3ceaa8).
constexpr const char *kTextureName = "00_texture/gm_parts2";

// The per-slot sprite-instancer capacities (@ghidraAddress 0x2ff050).
constexpr unsigned int kSlotCapacities[] = {32, 256, 32};

// The per-slot texture-field selector (@ghidraAddress 0x2ff05c): the index into the layer's three
// texture fields for each slot.
constexpr int kSlotTextureField[] = {0, 1, 2};

// The slot that receives additive blend mode, and that mode's identifier.
constexpr int kAdditiveBlendSlot = 1;
constexpr int kAdditiveBlendMode = 1;

// The two texture-environment parameter slots the builder seeds (to 1 each), and that value.
constexpr int kTexParamSlotHigh = 1;
constexpr int kTexParamSlotLow = 0;
constexpr int kTexParamEnabled = 1;

} // namespace

/** @ghidraAddress 0x9b118 */
FullComboColetteLayer::FullComboColetteLayer() {
    // The base constructor runs first; the remaining state is already zero-cleared by the member
    // initialisers, so only the layout size is seeded here.
    m_flWidth = kLayoutWidth;
    m_flHeight = kLayoutHeight;
}

/** @ghidraAddress 0x9b18c */
FullComboColetteLayer *FullComboColetteLayer::shared() {
    if (g_pFullComboColetteLayer == nullptr) {
        // The binary allocates the raw 0x68-byte object and runs its initialiser, which chains the
        // base-layer constructor and seeds the layer's state.
        g_pFullComboColetteLayer = new FullComboColetteLayer();
    }
    return g_pFullComboColetteLayer;
}

/** @ghidraAddress 0x9b1dc */
void FullComboColetteLayer::InitializeBackgroundSpriteLayers() {
    if (m_bBuilt) {
        return;
    }

    // The sprites hang beneath the shared background layer's render object rather than the global
    // scene root.
    BgLayer *pBackgroundLayer = BgLayer::GetBackgroundLayer();
    ne::C_RENDER *pParent = pBackgroundLayer->GetBackgroundRenderObject();

    m_pTexture0 = ne::C_TEXTURE::FindOrLoadCached(kTextureName);
    m_pTexture1 = ne::C_TEXTURE::FindOrLoadCached(kTextureName);
    m_pTexture2 = ne::C_TEXTURE::FindOrLoadCached(kTextureName);

    ne::C_TEXTURE *const apTextureFields[] = {m_pTexture0, m_pTexture1, m_pTexture2};

    // Build one sprite instancer per slot, attach it under the background render object, make it
    // visible, bind its mapped atlas, clear its sprite count, put the middle slot in additive blend,
    // and enable each slot's two texture-environment parameters.
    for (int nSlot = 0; nSlot < kSpriteSlotCount; ++nSlot) {
        ne::C_SPRITE_INSTANCING_2D *pSprite = ne::CreateWorldSpriteBatch(kSlotCapacities[nSlot]);
        m_apSprites[nSlot] = pSprite;
        pParent->AttachChild(pSprite);
        pSprite->SetVisible(true);
        pSprite->SetRefCountedMember(apTextureFields[kSlotTextureField[nSlot]]);
        pSprite->SetSpriteCount(0);
        if (nSlot == kAdditiveBlendSlot) {
            pSprite->SetBlendMode(kAdditiveBlendMode);
        }
        pSprite->SetTexParam(kTexParamSlotHigh, kTexParamEnabled);
        pSprite->SetTexParam(kTexParamSlotLow, kTexParamEnabled);
    }

    m_bBuilt = true;
}

/** @ghidraAddress 0x9b2e4 */
void FullComboColetteLayer::CreateFullComboColette(unsigned int nColor) {
    assert(static_cast<int>(nColor) >= 0 && nColor < kColorCount);
    EffectRecord &effect = m_aEffects[nColor];
    effect.m_bActive = true;
    effect.m_nTimer = 0;
    effect.m_bFlag2 = false;
}

/** @ghidraAddress 0x9c264 */
void FullComboColetteLayer::CreateColetteSprite(int nType,
                                                const S_VECTOR2 *pPosition,
                                                unsigned int nAlpha,
                                                float flScaleX,
                                                float flScaleY,
                                                float flRotation) {
    assert(nType >= 0);
    assert(nType < kColetteFullComboSpriteTypeCount);

    const ColetteFullComboSpriteType &spriteType = g_aColetteFullComboSpriteTypes[nType];
    const unsigned int nGroup = spriteType.nGroup;

    // Skip the sprite when the group's batch is already full.
    const int nIndex = m_aSpriteCounts[nGroup];
    if (nIndex >= static_cast<int>(kSlotCapacities[nGroup])) {
        return;
    }

    const SpriteUvEntry &uv = g_aSpriteUvTable[spriteType.nUvIndex];
    ne::C_SPRITE_INSTANCING_2D *pBatch = m_apSprites[nGroup];

    pBatch->SetSpritePosition(nIndex, *pPosition);
    pBatch->SetSpriteAnchor(nIndex, S_VECTOR2{spriteType.flAnchorX, spriteType.flAnchorY});
    pBatch->SetSpriteSize(nIndex, S_VECTOR2{spriteType.flSizeW, spriteType.flSizeH});
    pBatch->SetSpriteUvOrigin(nIndex, S_VECTOR2{uv.flOriginU, uv.flOriginV});
    pBatch->SetSpriteUvSize(nIndex, S_VECTOR2{uv.flSizeU, uv.flSizeV});
    pBatch->SetSpriteScale(nIndex, flScaleX, flScaleY);
    pBatch->SetSpriteRotation(nIndex, flRotation);
    pBatch->SetSpriteColor(nIndex, 0xff, 0xff, 0xff, nAlpha);

    ++m_aSpriteCounts[nGroup];
}

/** @ghidraAddress 0x9b35c */
void FullComboColetteLayer::ClearEffectFlags() {
    for (EffectRecord &effect : m_aEffects) {
        effect.m_bActive = false;
    }
}

/** @ghidraAddress 0x9b378 */
bool FullComboColetteLayer::IsAnyEffectActive() const {
    for (const EffectRecord &effect : m_aEffects) {
        if (effect.m_bActive) {
            return true;
        }
    }
    return false;
}
