#include "full_combo_limelight_layer.h"

#include <cassert>

#include "../Share/bg_layer.h"
#import "AudioManager.h"
#include "curve.h"
#include "engineglobals.h"
#include "gamesystem.h"
#include "neRender.h"
#include "neSpriteInstancing.h"
#include "neTexture.h"
#include "s_vector2.h"
#include "soundeffectmanager.h"
#include "sprite_uv_table.h"
#include "vectormath.h"

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
    // visible, bind its mapped atlas, clear its sprite count, put the middle slot in additive
    // blend, and enable each slot's two texture-environment parameters.
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
    effect.m_flTimer = 0.0f;
    effect.m_bVoiceFired = false;
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

namespace {

// The number of play sides the effect can run on, one per player colour.
constexpr int kSideCount = 2;

// The animation clock past which an effect record retires (@ghidraAddress 0x2feff0), and the clock
// at which it fires its themed voice cue exactly once (@ghidraAddress 0x2feff4).
constexpr float kEffectDuration = 2000.0f;
constexpr float kVoiceCueClock = 500.0f;

// The bias the letters sample their curves at (@ghidraAddress 0x2feff8): they run half a second
// behind the column groups.
constexpr float kLetterClockBias = -500.0f;

// The themed voice cue the effect announces itself with.
constexpr int kFullComboVoiceId = 9;

// The game types that leave the rival's side silent. The binary's bitwise test,
// (gameType | 2) == 2, admits exactly game types 0 and 2 — the single-player modes, which have no
// rival to announce a full combo to.
constexpr int kSinglePlayerGameTypeMask = 2;

// The game type whose letters mirror onto the other side.
constexpr int kVersusGameType = 1;

// The half-turn rotation a mirrored side's letters take, in radians (@ghidraAddress 0x2fe894).
constexpr float kMirrorRotation = 3.1415927f;

// The unit-interval-to-byte alpha scale (@ghidraAddress 0x2eed00).
constexpr float kAlphaScale = 255.0f;

// The rotation each side's column sprites take, indexed by whether the side is the local player's
// (@ghidraAddress 0x306278): the rival's side is drawn upside down.
constexpr float kSideRotation[kSideCount] = {3.1415927f, 0.0f};

// The thirteen screen X positions the column sprites stand on (@ghidraAddress 0x305330, 0x305334,
// 0x305338, 0x306240, 0x306244, 0x305348, 0x30534c, 0x3053fc, 0x305358, 0x30535c, 0x3052a8,
// 0x305364, and 0x2f8550). The layer converts each to a layout-relative offset by subtracting its
// own width.
constexpr float kColumnScreenX[] = {
    74.0f,
    194.0f,
    454.0f,
    414.0f,
    684.0f,
    564.0f,
    234.0f,
    524.0f,
    334.0f,
    134.0f,
    644.0f,
    424.0f,
    384.0f,
};

// The centred flare pair's screen position (@ghidraAddress 0x2f8550 and 0x2fefFC), converted the
// same way. The X constant is the layer's own layout width, so the pair lands on the centre line.
constexpr float kFlareScreenX = 384.0f;
constexpr float kFlareScreenY = 1105.0f;

// The number of sprites in each group, and the number of keyframe pairs in their curves.
constexpr int kColumnBurstCount = 26;
constexpr int kColumnEmberCount = 23;
constexpr int kLetterCount = 10;
constexpr int kColumnPairCount = 3;
constexpr int kFlareBackPairCount = 3;
constexpr int kFlareFrontAlphaPairCount = 2;
constexpr int kFlareFrontScalePairCount = 4;
constexpr int kLetterPairCount = 4;

// Each group's first sprite kind, indexed by side. The burst group's kind advances by one per
// sprite; the ember group instead picks one of four kinds per frame (see below).
constexpr int kColumnBurstKindBase[kSideCount] = {46, 14};
constexpr int kColumnEmberKindBase[kSideCount] = {42, 10};
constexpr int kFlareBackKind[kSideCount] = {72, 40};
constexpr int kFlareFrontKind[kSideCount] = {73, 41};

// The fixed alpha the back flare draws at; it never fades.
constexpr int kFlareBackAlpha = 0x7f;

// The column each burst sprite stands on. The bursts pair up — a wide glow and a narrow spark on
// every column — so the index is simply the sprite index halved.
constexpr int kBurstsPerColumn = 2;

// The column each ember sprite stands on. Unlike the bursts these do not pair up evenly: three
// columns carry a single ember and the rest carry two.
constexpr int kEmberColumnIndex[kColumnEmberCount] = {
    0, 0, 1, 1, 2, 2, 3, 3, 4, 4, 5, 5, 6, 6, 7, 8, 9, 9, 10, 11, 11, 12, 12,
};

// Whether each ember draws the first of its two variants. Together with the clock parity below
// this picks one of four consecutive sprite kinds, which the descriptor table maps to four frames
// of the same 46x44 sprite. The binary encodes this table as the bit mask 0x3fff01b0 tested by the
// sprite index; the offset it adds is 0 for a set bit and 2 for a clear one.
constexpr bool kEmberUsesFirstVariant[kColumnEmberCount] = {
    false, false, false, false, true, true, false, true, true, false, false, false,
    false, false, false, false, true, true, true,  true, true, true,  true,
};

// The variant offset a clear mask bit adds to the ember's kind.
constexpr int kEmberSecondVariantOffset = 2;

// The ten letters' offsets from the centre banner. The first eight are shared verbatim with the
// Classic theme's letter table (@ghidraAddress 0x302510); the last two are Limelight's own
// (@ghidraAddress 0x306250).
constexpr S_VECTOR2 kLetterOffsets[kLetterCount] = {
    {-204.0f, 0.0f},
    {-166.0f, 0.0f},
    {-128.0f, 0.0f},
    {-95.0f, 0.0f},
    {-39.0f, 0.0f},
    {19.0f, 0.0f},
    {78.0f, 0.0f},
    {128.0f, 0.0f},
    {179.0f, 0.0f},
    {221.0f, 0.0f},
};

// How far the letters' centre line is inset from each near lane row.
constexpr int kLetterRowInset = 232;

constexpr float kColumnBurstPosYPairs[][3 * 2] = {
    {333.33334f, 1024.0f, 500.0f, 1016.5f, 1000.0f, 994.0f},
    {333.33334f, 1024.0f, 500.0f, 1016.5f, 1000.0f, 994.0f},
    {333.33334f, 1054.0f, 500.0f, 1046.5f, 1000.0f, 1024.0f},
    {333.33334f, 1054.0f, 500.0f, 1046.5f, 1000.0f, 1024.0f},
    {166.66667f, 924.0f, 333.33334f, 916.5f, 833.3333f, 894.0f},
    {166.66667f, 924.0f, 333.33334f, 916.5f, 833.3333f, 894.0f},
    {316.66666f, 894.0f, 333.33334f, 894.0f, 1000.0f, 864.0f},
    {316.66666f, 894.0f, 333.33334f, 894.0f, 1000.0f, 864.0f},
    {316.66666f, 994.0f, 333.33334f, 994.0f, 1000.0f, 964.0f},
    {316.66666f, 994.0f, 333.33334f, 994.0f, 1000.0f, 964.0f},
    {166.66667f, 1050.0f, 333.33334f, 1025.0f, 833.3333f, 1010.0f},
    {166.66667f, 1050.0f, 333.33334f, 1025.0f, 833.3333f, 1010.0f},
    {0.0f, 1080.0f, 166.66667f, 1030.0f, 666.6667f, 1010.0f},
    {0.0f, 1080.0f, 166.66667f, 1030.0f, 666.6667f, 1010.0f},
    {0.0f, 1060.0f, 166.66667f, 1010.0f, 666.6667f, 990.0f},
    {0.0f, 1060.0f, 166.66667f, 1010.0f, 666.6667f, 990.0f},
    {0.0f, 990.0f, 166.66667f, 960.0f, 666.6667f, 940.0f},
    {0.0f, 990.0f, 166.66667f, 960.0f, 666.6667f, 940.0f},
    {333.33334f, 990.0f, 500.0f, 960.0f, 1000.0f, 930.0f},
    {333.33334f, 990.0f, 500.0f, 960.0f, 1000.0f, 930.0f},
    {250.0f, 990.0f, 416.66666f, 960.0f, 916.6667f, 930.0f},
    {250.0f, 990.0f, 416.66666f, 960.0f, 916.6667f, 930.0f},
    {83.333336f, 880.0f, 250.0f, 850.0f, 750.0f, 830.0f},
    {83.333336f, 880.0f, 250.0f, 850.0f, 750.0f, 830.0f},
    {166.66667f, 860.0f, 333.33334f, 810.0f, 833.3333f, 780.0f},
    {166.66667f, 860.0f, 333.33334f, 810.0f, 833.3333f, 780.0f},
};

constexpr float kColumnBurstAlphaPairs[][3 * 2] = {
    {483.33334f, 0.0f, 500.0f, 1.0f, 1000.0f, 0.0f},
    {466.66666f, 0.0f, 483.33334f, 1.0f, 650.0f, 0.0f},
    {483.33334f, 0.0f, 500.0f, 1.0f, 1000.0f, 0.0f},
    {466.66666f, 0.0f, 483.33334f, 1.0f, 650.0f, 0.0f},
    {316.66666f, 0.0f, 333.33334f, 1.0f, 833.3333f, 0.0f},
    {300.0f, 0.0f, 316.66666f, 1.0f, 483.33334f, 0.0f},
    {483.33334f, 0.0f, 500.0f, 1.0f, 1000.0f, 0.0f},
    {466.66666f, 0.0f, 483.33334f, 1.0f, 650.0f, 0.0f},
    {483.33334f, 0.0f, 500.0f, 1.0f, 1000.0f, 0.0f},
    {466.66666f, 0.0f, 483.33334f, 1.0f, 650.0f, 0.0f},
    {483.33334f, 0.0f, 500.0f, 1.0f, 1000.0f, 0.0f},
    {466.66666f, 0.0f, 483.33334f, 1.0f, 650.0f, 0.0f},
    {316.66666f, 0.0f, 333.33334f, 1.0f, 833.3333f, 0.0f},
    {466.66666f, 0.0f, 483.33334f, 1.0f, 650.0f, 0.0f},
    {150.0f, 0.0f, 166.66667f, 1.0f, 666.6667f, 0.0f},
    {133.33333f, 0.0f, 150.0f, 1.0f, 483.33334f, 0.0f},
    {150.0f, 0.0f, 166.66667f, 1.0f, 666.6667f, 0.0f},
    {133.33333f, 0.0f, 150.0f, 1.0f, 483.33334f, 0.0f},
    {150.0f, 0.0f, 166.66667f, 1.0f, 666.6667f, 0.0f},
    {133.33333f, 0.0f, 150.0f, 1.0f, 483.33334f, 0.0f},
    {150.0f, 0.0f, 166.66667f, 1.0f, 666.6667f, 0.0f},
    {133.33333f, 0.0f, 150.0f, 1.0f, 483.33334f, 0.0f},
    {150.0f, 0.0f, 166.66667f, 1.0f, 666.6667f, 0.0f},
    {133.33333f, 0.0f, 150.0f, 1.0f, 483.33334f, 0.0f},
    {150.0f, 0.0f, 166.66667f, 1.0f, 666.6667f, 0.0f},
    {133.33333f, 0.0f, 150.0f, 1.0f, 483.33334f, 0.0f},
};

constexpr float kColumnBurstScalePairs[][3 * 2] = {
    {333.33334f, 0.0f, 1000.0f, 0.5f, 1016.6667f, 0.5f},
    {333.33334f, 0.0f, 1000.0f, 0.5f, 1016.6667f, 0.5f},
    {333.33334f, 0.0f, 1000.0f, 0.5f, 1016.6667f, 0.5f},
    {333.33334f, 0.0f, 1000.0f, 0.5f, 1016.6667f, 0.5f},
    {166.66667f, 0.0f, 833.3333f, 0.5f, 850.0f, 0.5f},
    {166.66667f, 0.0f, 833.3333f, 0.5f, 850.0f, 0.5f},
    {333.33334f, 0.0f, 1000.0f, 0.5f, 1016.6667f, 0.5f},
    {333.33334f, 0.0f, 1000.0f, 0.5f, 1016.6667f, 0.5f},
    {333.33334f, 0.0f, 1000.0f, 0.5f, 1016.6667f, 0.5f},
    {333.33334f, 0.0f, 1000.0f, 0.5f, 1016.6667f, 0.5f},
    {333.33334f, 0.0f, 1000.0f, 0.5f, 1016.6667f, 0.5f},
    {333.33334f, 0.0f, 1000.0f, 0.5f, 1016.6667f, 0.5f},
    {166.66667f, 0.0f, 333.33334f, 0.6f, 833.3333f, 0.8f},
    {166.66667f, 0.0f, 333.33334f, 0.6f, 833.3333f, 0.8f},
    {0.0f, 0.0f, 166.66667f, 0.4f, 666.6667f, 0.7f},
    {0.0f, 0.0f, 166.66667f, 0.4f, 666.6667f, 0.7f},
    {0.0f, 0.0f, 166.66667f, 0.5f, 666.6667f, 1.0f},
    {0.0f, 0.0f, 166.66667f, 0.5f, 666.6667f, 1.0f},
    {0.0f, 0.0f, 166.66667f, 0.8f, 666.6667f, 1.0f},
    {0.0f, 0.0f, 166.66667f, 0.8f, 666.6667f, 1.0f},
    {0.0f, 0.0f, 166.66667f, 0.4f, 666.6667f, 1.0f},
    {0.0f, 0.0f, 166.66667f, 0.4f, 666.6667f, 1.0f},
    {0.0f, 0.0f, 166.66667f, 0.4f, 666.6667f, 1.0f},
    {0.0f, 0.0f, 166.66667f, 0.4f, 666.6667f, 1.0f},
    {0.0f, 0.0f, 166.66667f, 0.8f, 666.6667f, 1.0f},
    {0.0f, 0.0f, 166.66667f, 0.8f, 666.6667f, 1.0f},
};

constexpr float kColumnEmberPosYPairs[][3 * 2] = {
    {333.33334f, 1030.0f, 500.0f, 1022.5f, 1000.0f, 1000.0f},
    {333.33334f, 1030.0f, 500.0f, 1022.5f, 1000.0f, 1000.0f},
    {333.33334f, 1060.0f, 500.0f, 1052.5f, 1000.0f, 1030.0f},
    {333.33334f, 1060.0f, 500.0f, 1052.5f, 1000.0f, 1030.0f},
    {166.66667f, 930.0f, 333.33334f, 922.5f, 833.3333f, 900.0f},
    {166.66667f, 930.0f, 333.33334f, 922.5f, 833.3333f, 900.0f},
    {316.66666f, 900.0f, 333.33334f, 900.0f, 1000.0f, 870.0f},
    {316.66666f, 900.0f, 333.33334f, 900.0f, 1000.0f, 870.0f},
    {316.66666f, 1000.0f, 333.33334f, 1000.0f, 1000.0f, 970.0f},
    {316.66666f, 1000.0f, 333.33334f, 1000.0f, 1000.0f, 970.0f},
    {166.66667f, 1056.0f, 333.33334f, 1031.0f, 833.3333f, 1016.0f},
    {166.66667f, 1056.0f, 333.33334f, 1031.0f, 833.3333f, 1016.0f},
    {0.0f, 1086.0f, 166.66667f, 1036.0f, 666.6667f, 1016.0f},
    {0.0f, 1086.0f, 166.66667f, 1036.0f, 666.6667f, 1016.0f},
    {0.0f, 1066.0f, 166.66667f, 1016.0f, 666.6667f, 996.0f},
    {0.0f, 996.0f, 166.66667f, 966.0f, 666.6667f, 946.0f},
    {0.0f, 996.0f, 166.66667f, 966.0f, 666.6667f, 936.0f},
    {0.0f, 996.0f, 166.66667f, 966.0f, 666.6667f, 936.0f},
    {333.33334f, 996.0f, 500.0f, 966.0f, 1000.0f, 936.0f},
    {83.333336f, 886.0f, 250.0f, 856.0f, 750.0f, 836.0f},
    {83.333336f, 886.0f, 250.0f, 856.0f, 750.0f, 836.0f},
    {166.66667f, 866.0f, 333.33334f, 816.0f, 833.3333f, 786.0f},
    {166.66667f, 866.0f, 333.33334f, 816.0f, 833.3333f, 786.0f},
};

constexpr float kColumnEmberAlphaPairs[][3 * 2] = {
    {483.33334f, 0.0f, 500.0f, 1.0f, 1000.0f, 0.0f},
    {466.66666f, 0.0f, 483.33334f, 1.0f, 650.0f, 0.0f},
    {483.33334f, 0.0f, 500.0f, 1.0f, 1000.0f, 0.0f},
    {466.66666f, 0.0f, 483.33334f, 1.0f, 650.0f, 0.0f},
    {316.66666f, 0.0f, 333.33334f, 1.0f, 833.3333f, 0.0f},
    {300.0f, 0.0f, 316.66666f, 1.0f, 483.33334f, 0.0f},
    {483.33334f, 0.0f, 500.0f, 1.0f, 1000.0f, 0.0f},
    {466.66666f, 0.0f, 483.33334f, 1.0f, 650.0f, 0.0f},
    {483.33334f, 0.0f, 500.0f, 1.0f, 1000.0f, 0.0f},
    {466.66666f, 0.0f, 483.33334f, 1.0f, 650.0f, 0.0f},
    {316.66666f, 0.0f, 333.33334f, 1.0f, 833.3333f, 0.0f},
    {300.0f, 0.0f, 316.66666f, 1.0f, 650.0f, 0.0f},
    {150.0f, 0.0f, 166.66667f, 1.0f, 666.6667f, 0.0f},
    {133.33333f, 0.0f, 150.0f, 1.0f, 483.33334f, 0.0f},
    {150.0f, 0.0f, 166.66667f, 1.0f, 666.6667f, 0.0f},
    {150.0f, 0.0f, 166.66667f, 1.0f, 666.6667f, 0.0f},
    {483.33334f, 0.0f, 500.0f, 1.0f, 1000.0f, 0.0f},
    {466.66666f, 0.0f, 483.33334f, 1.0f, 650.0f, 0.0f},
    {400.0f, 0.0f, 416.66666f, 1.0f, 916.6667f, 0.0f},
    {233.33333f, 0.0f, 250.0f, 1.0f, 750.0f, 0.0f},
    {216.66667f, 0.0f, 233.33333f, 1.0f, 400.0f, 0.0f},
    {316.66666f, 0.0f, 333.33334f, 1.0f, 833.3333f, 0.0f},
    {300.0f, 0.0f, 316.66666f, 1.0f, 566.6667f, 0.0f},
};

constexpr float kColumnEmberScalePairs[][3 * 2] = {
    {333.33334f, 0.0f, 1000.0f, 0.5f, 1016.6667f, 0.5f},
    {333.33334f, 0.0f, 1000.0f, 0.5f, 1016.6667f, 0.5f},
    {333.33334f, 0.0f, 1000.0f, 0.5f, 1016.6667f, 0.5f},
    {333.33334f, 0.0f, 1000.0f, 0.5f, 1016.6667f, 0.5f},
    {166.66667f, 0.0f, 833.3333f, 0.5f, 850.0f, 0.5f},
    {166.66667f, 0.0f, 833.3333f, 0.5f, 850.0f, 0.5f},
    {333.33334f, 0.0f, 1000.0f, 0.5f, 1016.6667f, 0.5f},
    {333.33334f, 0.0f, 1000.0f, 0.5f, 1016.6667f, 0.5f},
    {333.33334f, 0.0f, 1000.0f, 0.5f, 1016.6667f, 0.5f},
    {333.33334f, 0.0f, 1000.0f, 0.5f, 1016.6667f, 0.5f},
    {166.66667f, 0.0f, 333.33334f, 0.6f, 833.3333f, 0.8f},
    {166.66667f, 0.0f, 333.33334f, 0.6f, 833.3333f, 0.8f},
    {0.0f, 0.0f, 166.66667f, 0.4f, 666.6667f, 0.7f},
    {0.0f, 0.0f, 166.66667f, 0.4f, 666.6667f, 0.7f},
    {0.0f, 0.0f, 166.66667f, 0.5f, 666.6667f, 1.0f},
    {0.0f, 0.0f, 166.66667f, 0.5f, 666.6667f, 1.0f},
    {333.33334f, 0.0f, 500.0f, 0.4f, 1000.0f, 0.5f},
    {333.33334f, 0.0f, 500.0f, 0.4f, 1000.0f, 0.5f},
    {333.33334f, 0.0f, 1000.0f, 0.5f, 1016.6667f, 0.5f},
    {83.333336f, 0.0f, 250.0f, 0.8f, 750.0f, 1.0f},
    {83.333336f, 0.0f, 250.0f, 0.8f, 750.0f, 1.0f},
    {166.66667f, 0.0f, 333.33334f, 0.6f, 833.3333f, 1.0f},
    {166.66667f, 0.0f, 333.33334f, 0.6f, 833.3333f, 1.0f},
};

constexpr float kLetterScalePairs[][4 * 2] = {
    {166.66667f, 0.6f, 333.33334f, 1.1f, 383.33334f, 0.95f, 433.33334f, 1.0f},
    {200.0f, 0.6f, 366.66666f, 1.1f, 416.66666f, 0.95f, 466.66666f, 1.0f},
    {233.33333f, 0.6f, 400.0f, 1.1f, 450.0f, 0.95f, 500.0f, 1.0f},
    {266.66666f, 0.6f, 433.33334f, 1.1f, 483.33334f, 0.95f, 533.3333f, 1.0f},
    {300.0f, 0.6f, 466.66666f, 1.1f, 516.6667f, 0.95f, 566.6667f, 1.0f},
    {333.33334f, 0.6f, 500.0f, 1.1f, 550.0f, 0.95f, 600.0f, 1.0f},
    {366.66666f, 0.6f, 533.3333f, 1.1f, 583.3333f, 0.95f, 633.3333f, 1.0f},
    {400.0f, 0.6f, 566.6667f, 1.1f, 616.6667f, 0.95f, 666.6667f, 1.0f},
    {433.33334f, 0.6f, 600.0f, 1.1f, 650.0f, 0.95f, 700.0f, 1.0f},
    {466.66666f, 0.6f, 633.3333f, 1.1f, 683.3333f, 0.95f, 733.3333f, 1.0f},
};

constexpr float kLetterAlphaPairs[][4 * 2] = {
    {166.66667f, 0.0f, 300.0f, 1.0f, 1333.3334f, 1.0f, 1483.3334f, 0.0f},
    {200.0f, 0.0f, 333.33334f, 1.0f, 1333.3334f, 1.0f, 1483.3334f, 0.0f},
    {233.33333f, 0.0f, 366.66666f, 1.0f, 1333.3334f, 1.0f, 1483.3334f, 0.0f},
    {266.66666f, 0.0f, 400.0f, 1.0f, 1333.3334f, 1.0f, 1483.3334f, 0.0f},
    {266.66666f, 0.0f, 433.33334f, 1.0f, 1333.3334f, 1.0f, 1483.3334f, 0.0f},
    {300.0f, 0.0f, 466.66666f, 1.0f, 1333.3334f, 1.0f, 1483.3334f, 0.0f},
    {333.33334f, 0.0f, 500.0f, 1.0f, 1333.3334f, 1.0f, 1483.3334f, 0.0f},
    {366.66666f, 0.0f, 533.3333f, 1.0f, 1333.3334f, 1.0f, 1483.3334f, 0.0f},
    {400.0f, 0.0f, 566.6667f, 1.0f, 1333.3334f, 1.0f, 1483.3334f, 0.0f},
    {433.33334f, 0.0f, 600.0f, 1.0f, 1333.3334f, 1.0f, 1483.3334f, 0.0f},
};

constexpr float kFlareBackScaleXPairs[] = {0.0f, 5.0f, 133.33333f, 5.0f, 1250.0f, 0.0f};
constexpr float kFlareBackScaleYPairs[] = {0.0f, 0.0f, 133.33333f, 3.0f, 1250.0f, 7.0f};
constexpr float kFlareFrontAlphaPairs[] = {500.0f, 1.0f, 1250.0f, 0.0f};
constexpr float kFlareFrontScaleXPairs[] = {
    0.0f,
    15.0f,
    133.33333f,
    15.0f,
    500.0f,
    15.0f,
    1250.0f,
    12.0f,
};
constexpr float kFlareFrontScaleYPairs[] = {
    0.0f,
    0.0f,
    133.33333f,
    3.0f,
    500.0f,
    3.0f,
    1250.0f,
    0.0f,
};

// The truncation the binary applies before handing a curve value to CreateSprite.
inline int ScaleToAlpha(float flValue) {
    return static_cast<int>(flValue * kAlphaScale);
}

} // namespace

/** @ghidraAddress 0x122b08 */
void FullComboLimelightLayer::Update(float flDelta) {
    for (int &nCount : m_aSpriteCounts) {
        nCount = 0;
    }

    GameSystem *pGameSystem = GameSystem::GetGameSystem();

    for (int nSide = 0; nSide < kSideCount; ++nSide) {
        EffectRecord &effect = m_aEffects[nSide];
        if (!effect.m_bActive) {
            continue;
        }

        effect.m_flTimer += flDelta;
        const float flClock = effect.m_flTimer;
        if (flClock > kEffectDuration) {
            // The record retires here but still draws in full on the frame that retires it.
            effect.m_bActive = false;
        }

        // Announce the full combo once, half a second in. The rival's side stays silent in the
        // single-player modes, where there is no rival to announce it to. Unlike the Classic
        // theme's layer this one does not first check whether a voice is already playing.
        if (!effect.m_bVoiceFired && flClock > kVoiceCueClock) {
            effect.m_bVoiceFired = true;
            const int nRivalSide = (pGameSystem->GetPlayColor() == 0) ? 1 : 0;
            const bool bSilent =
                nSide == nRivalSide && (pGameSystem->GetGameType() | kSinglePlayerGameTypeMask) ==
                                           kSinglePlayerGameTypeMask;
            if (!bSilent) {
                AudioManager *pAudio = AudioManager.sharedManager;
                [pAudio releaseVoice];
                SoundEffectManager::GetInstance()->LoadAndSetThemedVoice(kFullComboVoiceId);
            }
        }

        const int nPlayColor = pGameSystem->GetPlayColor();

        // Each lane row sits on the near lane's slope, scaled by the sheet's half inset. The binary
        // re-reads the game system on every iteration of this two-element loop.
        const float aRowSlope[kSideCount] = {g_flPlayfieldNearLaneSlope,
                                             g_flPlayfieldNearLaneSlopeNeg};
        float aRowBaseY[kSideCount] = {};
        for (int nRow = 0; nRow < kSideCount; ++nRow) {
            aRowBaseY[nRow] = aRowSlope[nRow] * GameSystem::GetGameSystem()->GetSheetInsetHalfY();
        }
        const int nGameType = GameSystem::GetGameSystem()->GetGameType();

        const bool bOwnSide = nPlayColor == nSide;
        const float flRowBaseY = aRowBaseY[bOwnSide ? 1 : 0];
        const float flColumnRotation = kSideRotation[bOwnSide ? 1 : 0];

        // The bursts' and embers' X positions are layout-relative, so the binary caches them in two
        // guarded one-shots seeded from the first frame's layout width (@ghidraAddress 0x3ddc48 and
        // 0x3ddcb8). The function-local statics reproduce that one-time initialisation.
        static float aBurstX[kColumnBurstCount];
        static bool bBurstXBuilt = false;
        if (!bBurstXBuilt) {
            for (int nBurst = 0; nBurst < kColumnBurstCount; ++nBurst) {
                aBurstX[nBurst] = kColumnScreenX[nBurst / kBurstsPerColumn] - m_flWidth;
            }
            bBurstXBuilt = true;
        }
        static float aEmberX[kColumnEmberCount];
        static bool bEmberXBuilt = false;
        if (!bEmberXBuilt) {
            for (int nEmber = 0; nEmber < kColumnEmberCount; ++nEmber) {
                aEmberX[nEmber] = kColumnScreenX[kEmberColumnIndex[nEmber]] - m_flWidth;
            }
            bEmberXBuilt = true;
        }

        // The falling column bursts: a wide glow and a narrow spark on each of the thirteen
        // columns, sharing a descent path and a scale but flashing on their own alpha curves.
        for (int nBurst = 0; nBurst < kColumnBurstCount; ++nBurst) {
            const float flScreenY = CalculateCurveInterpolation(
                kColumnBurstPosYPairs[nBurst], kColumnPairCount, flClock);
            const float flAlpha = CalculateCurveInterpolation(
                kColumnBurstAlphaPairs[nBurst], kColumnPairCount, flClock);
            const float flScale = CalculateCurveInterpolation(
                kColumnBurstScalePairs[nBurst], kColumnPairCount, flClock);
            const float flOffsetY = flScreenY - m_flHeight;
            const S_VECTOR2 position{aBurstX[nBurst],
                                     flRowBaseY + (bOwnSide ? flOffsetY : -flOffsetY)};
            CreateSprite(kColumnBurstKindBase[nSide] + nBurst,
                         &position,
                         ScaleToAlpha(flAlpha),
                         flScale,
                         flScale,
                         flColumnRotation);
        }

        // The column embers, which flicker between a wide glow and a narrow spark on the clock's
        // parity, and pick one of two visual variants per column.
        const int nEmberParity = static_cast<int>(flClock) & 1;
        for (int nEmber = 0; nEmber < kColumnEmberCount; ++nEmber) {
            const float flScreenY = CalculateCurveInterpolation(
                kColumnEmberPosYPairs[nEmber], kColumnPairCount, flClock);
            const float flAlpha = CalculateCurveInterpolation(
                kColumnEmberAlphaPairs[nEmber], kColumnPairCount, flClock);
            const float flScale = CalculateCurveInterpolation(
                kColumnEmberScalePairs[nEmber], kColumnPairCount, flClock);
            const float flOffsetY = flScreenY - m_flHeight;
            const S_VECTOR2 position{aEmberX[nEmber],
                                     flRowBaseY + (bOwnSide ? flOffsetY : -flOffsetY)};
            // Both terms are even, so the binary's bitwise or is an add.
            const int nVariant = kEmberUsesFirstVariant[nEmber] ? 0 : kEmberSecondVariantOffset;
            const int nKind = (kColumnEmberKindBase[nSide] + nVariant) | nEmberParity;
            CreateSprite(
                nKind, &position, ScaleToAlpha(flAlpha), flScale, flScale, flColumnRotation);
        }

        // The centred flare pair. The back flare holds a fixed half alpha and only animates its
        // scale; the front flare fades out on its own curve.
        const float flFlareOffsetY = kFlareScreenY - m_flHeight;
        const S_VECTOR2 flarePosition{kFlareScreenX - m_flWidth,
                                      flRowBaseY + (bOwnSide ? flFlareOffsetY : -flFlareOffsetY)};
        const float flFlareBackScaleX =
            CalculateCurveInterpolation(kFlareBackScaleXPairs, kFlareBackPairCount, flClock);
        const float flFlareBackScaleY =
            CalculateCurveInterpolation(kFlareBackScaleYPairs, kFlareBackPairCount, flClock);
        CreateSprite(kFlareBackKind[nSide],
                     &flarePosition,
                     kFlareBackAlpha,
                     flFlareBackScaleX,
                     flFlareBackScaleY,
                     flColumnRotation);

        const float flFlareFrontAlpha =
            CalculateCurveInterpolation(kFlareFrontAlphaPairs, kFlareFrontAlphaPairCount, flClock);
        const float flFlareFrontScaleX =
            CalculateCurveInterpolation(kFlareFrontScaleXPairs, kFlareFrontScalePairCount, flClock);
        const float flFlareFrontScaleY =
            CalculateCurveInterpolation(kFlareFrontScaleYPairs, kFlareFrontScalePairCount, flClock);
        CreateSprite(kFlareFrontKind[nSide],
                     &flarePosition,
                     ScaleToAlpha(flFlareFrontAlpha),
                     flFlareFrontScaleX,
                     flFlareFrontScaleY,
                     flColumnRotation);

        // The letters' centre line spans both near lane rows, inset from each and shifted by the
        // field's centre split. The binary caches it in a third guarded one-shot
        // (@ghidraAddress 0x3ddd78).
        static S_VECTOR2 aLetterBase[kSideCount];
        static bool bLetterBaseBuilt = false;
        if (!bLetterBaseBuilt) {
            aLetterBase[0] =
                S_VECTOR2{0.0f,
                          static_cast<float>((g_nPlayfieldNearRowTop + kLetterRowInset) -
                                             g_nPlayfieldCentreSplit)};
            aLetterBase[1] =
                S_VECTOR2{0.0f,
                          static_cast<float>((g_nPlayfieldNearRowBottom - kLetterRowInset) -
                                             g_nPlayfieldCentreSplit)};
            bLetterBaseBuilt = true;
        }

        // Unlike the column groups, the letters mirror only in the versus game type.
        const float flLetterClock = flClock + kLetterClockBias;
        const bool bLetterMirrored = nGameType == kVersusGameType && !bOwnSide;
        const float flLetterRotation = bLetterMirrored ? kMirrorRotation : 0.0f;
        const S_VECTOR2 letterBase = aLetterBase[bOwnSide ? 1 : 0];

        // The FULLCOMBO! letters, each swelling in on its own stagger.
        for (int nLetter = 0; nLetter < kLetterCount; ++nLetter) {
            const float flScale = CalculateCurveInterpolation(
                kLetterScalePairs[nLetter], kLetterPairCount, flLetterClock);
            const float flAlpha = CalculateCurveInterpolation(
                kLetterAlphaPairs[nLetter], kLetterPairCount, flLetterClock);
            S_VECTOR2 position = letterBase;
            S_VECTOR2 offset = kLetterOffsets[nLetter];
            if (bLetterMirrored) {
                SubtractVector2(&position, &offset);
            } else {
                AddVector2(&position, &offset);
            }
            CreateSprite(
                nLetter, &position, ScaleToAlpha(flAlpha), flScale, flScale, flLetterRotation);
        }
    }

    for (int nSlot = 0; nSlot < kSpriteSlotCount; ++nSlot) {
        m_apSprites[nSlot]->SetSpriteCount(m_aSpriteCounts[nSlot]);
    }
}
