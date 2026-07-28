#include "full_combo_limelight_layer.h"

#include <cassert>

#include "../Share/bg_layer.h"
#include "neRender.h"
#include "neSpriteInstancing.h"
#include "neTexture.h"
#include "s_vector2.h"
#include "sprite_uv_table.h"

// The process-wide Limelight full-combo layer, created lazily by shared().
static FullComboLimelightLayer *g_pFullComboLimelightLayer = nullptr; // @ghidraAddress 0x3ddc40

// The Limelight full-combo title-part UV atlas, indexed by a batch-0 descriptor's atlas frame
// (@ghidraAddress 0x2f7908, defined in titlecolettescene_data.mm).
extern const SpriteUvEntry g_aTitlePartUvDefault[];

namespace {

// The layout size the constructor seeds.
constexpr float kLayoutWidth = 384.0f;
constexpr float kLayoutHeight = 1098.0f;

// The full-combo atlases the layer loads (@ghidraAddress 0x3ceaf0 and 0x3ceaa8). The last two slots
// share the gm_parts2 atlas.
constexpr const char *kEffectTextureName = "00_texture/ti_parts_eff";
constexpr const char *kPartsTextureName = "00_texture/gm_parts2";

// The per-slot sprite-instancer capacities (@ghidraAddress 0x306260).
constexpr unsigned int kSlotCapacities[] = {256, 32, 32};

// The per-slot texture-field selector (@ghidraAddress 0x30626c): the index into the layer's three
// texture fields for each slot.
constexpr int kSlotTextureField[] = {0, 1, 2};

// The slot that receives additive blend mode, and that mode's identifier.
constexpr int kAdditiveBlendSlot = 1;
constexpr int kAdditiveBlendMode = 1;

// The two texture-environment parameter slots the builder seeds (to 1 each), and that value.
constexpr int kTexParamSlotHigh = 1;
constexpr int kTexParamSlotLow = 0;
constexpr int kTexParamEnabled = 1;

// The maximum value of an opaque colour channel.
constexpr unsigned int kColorMax = 255;

// The sprite-type bound the emitter asserts on (SPRITE_TYPE_LIMELIGHT_MAX).
constexpr int kSpriteTypeCount = 0x4a;

// The batch selector whose descriptors draw from the Limelight title-part atlas; every other
// selector draws from the shared sprite atlas.
constexpr int kTitlePartBatch = 0;

// One full-combo sprite-type descriptor: the batch selector (also the atlas selector), the sprite
// anchor and pixel size, and the atlas frame. The 24-byte stride matches the binary.
struct LimelightSpriteDescriptor {
    int nBatch;        // +0x00: the sprite batch (and atlas) selector.
    float flAnchorX;   // +0x04: the sprite's anchor X.
    float flAnchorY;   // +0x08: the sprite's anchor Y.
    float flSizeX;     // +0x0c: the sprite's pixel width.
    float flSizeY;     // +0x10: the sprite's pixel height.
    int nUvFrameIndex; // +0x14: the atlas frame index.
};

// The full-combo sprite-type descriptor table, indexed by the sprite type. Read-only ROM data
// embedded in the binary. @ghidraAddress 0x307348
constexpr LimelightSpriteDescriptor kLimelightSpriteDescriptors[] = {
    {2, 19.0f, 32.0f, 38.0f, 64.0f, 0x33},   {2, 23.0f, 32.0f, 46.0f, 64.0f, 0x34},
    {2, 19.0f, 32.0f, 38.0f, 64.0f, 0x35},   {2, 19.0f, 32.0f, 38.0f, 64.0f, 0x36},
    {2, 31.0f, 32.0f, 62.0f, 64.0f, 0x37},   {2, 33.0f, 32.0f, 66.0f, 64.0f, 0x38},
    {2, 32.0f, 32.0f, 64.0f, 64.0f, 0x39},   {2, 22.0f, 32.0f, 44.0f, 64.0f, 0x3a},
    {2, 33.0f, 32.0f, 66.0f, 64.0f, 0x3b},   {2, 16.0f, 32.0f, 32.0f, 64.0f, 0x3c},
    {0, 23.0f, 22.0f, 46.0f, 44.0f, 0x7},    {0, 23.0f, 22.0f, 46.0f, 44.0f, 0x6},
    {0, 23.0f, 22.0f, 46.0f, 44.0f, 0x5},    {0, 23.0f, 22.0f, 46.0f, 44.0f, 0x4},
    {0, 27.0f, 27.0f, 54.0f, 54.0f, 0xa},    {0, 9.5f, 9.5f, 19.0f, 19.0f, 0xb},
    {0, 27.0f, 27.0f, 54.0f, 54.0f, 0x18},   {0, 9.5f, 9.5f, 16.0f, 16.0f, 0x19},
    {0, 27.0f, 27.0f, 54.0f, 54.0f, 0xa},    {0, 9.5f, 9.5f, 19.0f, 19.0f, 0xb},
    {0, 27.0f, 27.0f, 54.0f, 54.0f, 0x18},   {0, 9.5f, 9.5f, 16.0f, 16.0f, 0x19},
    {0, 27.0f, 27.0f, 54.0f, 54.0f, 0x18},   {0, 9.5f, 9.5f, 16.0f, 16.0f, 0x19},
    {0, 69.0f, 69.0f, 138.0f, 138.0f, 0x16}, {0, 55.5f, 55.5f, 110.0f, 110.0f, 0x17},
    {0, 69.0f, 69.0f, 138.0f, 138.0f, 0x16}, {0, 55.5f, 55.5f, 110.0f, 110.0f, 0x17},
    {0, 61.5f, 61.5f, 123.0f, 123.0f, 0x20}, {0, 69.0f, 69.0f, 138.0f, 138.0f, 0x1d},
    {0, 69.0f, 69.0f, 138.0f, 138.0f, 0x1c}, {0, 55.5f, 55.5f, 110.0f, 110.0f, 0x13},
    {0, 69.0f, 69.0f, 138.0f, 138.0f, 0x1c}, {0, 55.5f, 55.5f, 110.0f, 110.0f, 0x13},
    {0, 69.0f, 69.0f, 138.0f, 138.0f, 0x1c}, {0, 55.5f, 55.5f, 110.0f, 110.0f, 0x13},
    {0, 61.5f, 61.5f, 123.0f, 123.0f, 0x1e}, {0, 55.5f, 55.5f, 110.0f, 110.0f, 0x17},
    {0, 69.0f, 69.0f, 138.0f, 138.0f, 0x12}, {0, 55.5f, 55.5f, 110.0f, 110.0f, 0x13},
    {1, 32.0f, 106.0f, 64.0f, 106.0f, 0x3d}, {1, 32.0f, 106.0f, 64.0f, 106.0f, 0x3d},
    {0, 23.0f, 22.0f, 46.0f, 44.0f, 0x3},    {0, 23.0f, 22.0f, 46.0f, 44.0f, 0x2},
    {0, 23.0f, 22.0f, 46.0f, 44.0f, 0x1},    {0, 23.0f, 22.0f, 46.0f, 44.0f, 0x0},
    {0, 27.0f, 27.0f, 54.0f, 54.0f, 0xa},    {0, 9.5f, 9.5f, 19.0f, 19.0f, 0xb},
    {0, 27.0f, 27.0f, 54.0f, 54.0f, 0x8},    {0, 9.5f, 9.5f, 16.0f, 16.0f, 0x9},
    {0, 27.0f, 27.0f, 54.0f, 54.0f, 0xa},    {0, 9.5f, 9.5f, 19.0f, 19.0f, 0xb},
    {0, 27.0f, 27.0f, 54.0f, 54.0f, 0x8},    {0, 9.5f, 9.5f, 16.0f, 16.0f, 0x9},
    {0, 27.0f, 27.0f, 54.0f, 54.0f, 0x8},    {0, 9.5f, 9.5f, 16.0f, 16.0f, 0x9},
    {0, 69.0f, 69.0f, 138.0f, 138.0f, 0x16}, {0, 55.5f, 55.5f, 110.0f, 110.0f, 0x17},
    {0, 69.0f, 69.0f, 138.0f, 138.0f, 0x16}, {0, 55.5f, 55.5f, 110.0f, 110.0f, 0x17},
    {0, 61.5f, 61.5f, 123.0f, 123.0f, 0x20}, {0, 69.0f, 69.0f, 138.0f, 138.0f, 0x1d},
    {0, 69.0f, 69.0f, 138.0f, 138.0f, 0x1c}, {0, 55.5f, 55.5f, 110.0f, 110.0f, 0x13},
    {0, 69.0f, 69.0f, 138.0f, 138.0f, 0x1c}, {0, 55.5f, 55.5f, 110.0f, 110.0f, 0x13},
    {0, 69.0f, 69.0f, 138.0f, 138.0f, 0x1c}, {0, 55.5f, 55.5f, 110.0f, 110.0f, 0x13},
    {0, 61.5f, 61.5f, 123.0f, 123.0f, 0x1e}, {0, 55.5f, 55.5f, 110.0f, 110.0f, 0x17},
    {0, 69.0f, 69.0f, 138.0f, 138.0f, 0x12}, {0, 55.5f, 55.5f, 110.0f, 110.0f, 0x13},
    {1, 32.0f, 106.0f, 64.0f, 106.0f, 0x3e}, {1, 32.0f, 106.0f, 64.0f, 106.0f, 0x3e},
}; // @ghidraAddress 0x307348

} // namespace

/** @ghidraAddress 0x122870 */
FullComboLimelightLayer::FullComboLimelightLayer() {
    // The base constructor runs first; the remaining state is already zero-cleared by the member
    // initialisers, so only the layout size is seeded here.
    m_flWidth = kLayoutWidth;
    m_flHeight = kLayoutHeight;
}

/** @ghidraAddress 0x1228e4 */
FullComboLimelightLayer *FullComboLimelightLayer::shared() {
    if (g_pFullComboLimelightLayer == nullptr) {
        // The binary allocates the raw 0x68-byte object and runs its initialiser, which chains the
        // base-layer constructor and seeds the layer's state.
        g_pFullComboLimelightLayer = new FullComboLimelightLayer();
    }
    return g_pFullComboLimelightLayer;
}

/** @ghidraAddress 0x122934 */
void FullComboLimelightLayer::LoadTexturesAndBatchesForLimelightLayer() {
    if (m_bBuilt) {
        return;
    }

    // The sprites hang beneath the shared background layer's render object rather than the global
    // scene root.
    BgLayer *pBackgroundLayer = BgLayer::GetBackgroundLayer();
    ne::C_RENDER *pParent = pBackgroundLayer->GetBackgroundRenderObject();

    m_pEffectTexture = ne::C_TEXTURE::FindOrLoadCached(kEffectTextureName);
    m_pPartsTexture = ne::C_TEXTURE::FindOrLoadCached(kPartsTextureName);
    m_pPartsTexture2 = ne::C_TEXTURE::FindOrLoadCached(kPartsTextureName);

    ne::C_TEXTURE *const apTextureFields[] = {m_pEffectTexture, m_pPartsTexture, m_pPartsTexture2};

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

/** @ghidraAddress 0x122a44 */
void FullComboLimelightLayer::CreateFullComboLimelight(unsigned int nColor) {
    assert(static_cast<int>(nColor) >= 0 && nColor < kColorCount);
    EffectRecord &effect = m_aEffects[nColor];
    effect.m_bActive = true;
    effect.m_nTimer = 0;
    effect.m_bFlag2 = false;
}

/** @ghidraAddress 0x122abc */
void FullComboLimelightLayer::ClearEffectFlags() {
    for (EffectRecord &effect : m_aEffects) {
        effect.m_bActive = false;
    }
}

/** @ghidraAddress 0x122ad8 */
bool FullComboLimelightLayer::IsAnyEffectActive() const {
    for (const EffectRecord &effect : m_aEffects) {
        if (effect.m_bActive) {
            return true;
        }
    }
    return false;
}

/** @ghidraAddress 0x123658 */
void FullComboLimelightLayer::CreateSprite(int nType,
                                           const S_VECTOR2 *pPosition,
                                           int nAlpha,
                                           float flScaleX,
                                           float flScaleY,
                                           float flRotation) {
    assert(nType >= 0 && nType < kSpriteTypeCount);

    const LimelightSpriteDescriptor &descriptor = kLimelightSpriteDescriptors[nType];
    const int nBatch = descriptor.nBatch;

    // The write cursor is the layer's own per-batch count, not the instancer's; a full batch drops
    // the quad.
    const int nIndex = m_aSpriteCounts[nBatch];
    if (nIndex >= static_cast<int>(kSlotCapacities[nBatch])) {
        return;
    }

    // Batch 0 draws from the Limelight title-part atlas; every other batch from the shared atlas.
    const SpriteUvEntry &uv = nBatch == kTitlePartBatch ?
                                  g_aTitlePartUvDefault[descriptor.nUvFrameIndex] :
                                  g_aSpriteUvTable[descriptor.nUvFrameIndex];

    ne::C_SPRITE_INSTANCING_2D *pBatch = m_apSprites[nBatch];
    pBatch->SetSpritePosition(nIndex, *pPosition);
    pBatch->SetSpriteAnchor(nIndex, S_VECTOR2{descriptor.flAnchorX, descriptor.flAnchorY});
    pBatch->SetSpriteSize(nIndex, S_VECTOR2{descriptor.flSizeX, descriptor.flSizeY});
    pBatch->SetSpriteUvOrigin(nIndex, S_VECTOR2{uv.flOriginU, uv.flOriginV});
    pBatch->SetSpriteUvSize(nIndex, S_VECTOR2{uv.flSizeU, uv.flSizeV});
    pBatch->SetSpriteScale(nIndex, flScaleX, flScaleY);
    pBatch->SetSpriteRotation(nIndex, flRotation);
    pBatch->SetSpriteColor(
        nIndex, kColorMax, kColorMax, kColorMax, static_cast<unsigned int>(nAlpha));

    m_aSpriteCounts[nBatch] = nIndex + 1;
}
