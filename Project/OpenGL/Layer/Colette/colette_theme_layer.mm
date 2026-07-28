#include "colette_theme_layer.h"

#include "../Share/bg_layer.h"
#include "ScoreTracker.h"
#include "engineglobals.h"
#include "neRender.h"
#include "neSpriteInstancing.h"
#include "neTexture.h"
#include "s_vector2.h"
#include "sprite_uv_table.h"

// The process-wide Colette-theme layer, created lazily by shared().
static ColetteThemeLayer *g_pColetteThemeLayer = nullptr; // @ghidraAddress 0x3def58

namespace {

// The full-combo atlases the layer loads (@ghidraAddress 0x3ceaa8 and 0x3ceaf0). The first and last
// texture fields share the gm_parts2 atlas.
constexpr const char *kPartsTextureName = "00_texture/gm_parts2";
constexpr const char *kEffectTextureName = "00_texture/ti_parts_eff";

// The per-slot sprite-instancer capacities (@ghidraAddress 0x30e84c).
constexpr unsigned int kSlotCapacities[] = {1, 100, 100, 2};

// The per-slot texture-field selector (@ghidraAddress 0x30e85c): the index into the layer's three
// texture fields for each textured slot. Slot 0 binds no texture, so its entry is unused.
constexpr int kSlotTextureField[] = {-1, 0, 1, 2};

// The slot that receives additive blend mode, and that mode's identifier.
constexpr int kAdditiveBlendSlot = 3;
constexpr int kAdditiveBlendMode = 1;

// The layer's layout size the constructor seeds.
constexpr float kLayoutWidth = 384.0f;
constexpr float kLayoutHeight = 680.0f;

// The grade-display defaults: single-side, both best-rank flags four.
constexpr int kDefaultSideCount = 1;
constexpr int kGradeValueDefault = 4;

// The grade reveal-channel value that holds the display fully shown, the clock's off-screen start,
// and the two reveal-duration thresholds.
constexpr float kGradeChannelFull = 1.0f;
constexpr float kGradeClockStart = -500.0f;
constexpr float kGradeRevealDurationDual = 3000.0f;
constexpr float kGradeRevealDurationSingle = 5000.0f;

// The maximum value of an opaque colour channel.
constexpr unsigned int kColorMax = 255;

// One full-combo sprite-slot descriptor: the batch-kind selector, the sprite anchor and pixel size,
// and the shared UV atlas frame. The 24-byte stride matches the binary.
struct FcSpriteDescriptor {
    int nBatchKind;    // +0x00: the batch-kind selector (indexes the batch-index table).
    float flAnchorX;   // +0x04: the sprite's anchor X.
    float flAnchorY;   // +0x08: the sprite's anchor Y.
    float flSizeX;     // +0x0c: the sprite's pixel width.
    float flSizeY;     // +0x10: the sprite's pixel height.
    int nUvFrameIndex; // +0x14: the frame into the shared sprite UV atlas.
};

// The full-combo sprite-slot descriptor table, indexed by the sprite slot the caller passes.
// Read-only ROM data embedded in the binary. @ghidraAddress 0x30f494
constexpr FcSpriteDescriptor kFcSpriteDescriptors[] = {
    {4, 384.0f, 512.0f, 768.0f, 1024.0f, 0x0}, {0, 23.0f, 23.5f, 46.0f, 47.0f, 0x67},
    {0, 34.5f, 40.5f, 69.0f, 81.0f, 0x4c},     {0, 31.0f, 40.5f, 62.0f, 81.0f, 0x4d},
    {0, 33.0f, 40.5f, 66.0f, 81.0f, 0x4e},     {0, 39.0f, 40.5f, 78.0f, 81.0f, 0x4f},
    {0, 33.5f, 40.5f, 67.0f, 81.0f, 0x50},     {0, 25.5f, 40.5f, 51.0f, 81.0f, 0x51},
    {0, 32.0f, 37.5f, 64.0f, 75.0f, 0x52},     {0, 38.5f, 37.5f, 77.0f, 75.0f, 0x53},
    {0, 7.5f, 37.5f, 15.0f, 75.0f, 0x54},      {0, 31.0f, 37.5f, 62.0f, 75.0f, 0x55},
    {0, 32.5f, 37.5f, 65.0f, 75.0f, 0x56},     {0, 33.5f, 37.5f, 67.0f, 75.0f, 0x57},
    {0, 11.5f, 12.5f, 23.0f, 25.0f, 0x58},     {0, 11.5f, 12.5f, 23.0f, 25.0f, 0x58},
    {0, 11.5f, 12.5f, 23.0f, 25.0f, 0x58},     {0, 41.0f, 41.0f, 82.0f, 82.0f, 0x59},
    {2, 50.0f, 50.0f, 100.0f, 100.0f, 0x5b},   {2, 50.0f, 50.0f, 100.0f, 100.0f, 0x5c},
    {0, 53.0f, 53.0f, 106.0f, 106.0f, 0x5a},   {0, 38.0f, 38.0f, 76.0f, 76.0f, 0x68},
    {0, 38.0f, 38.0f, 76.0f, 76.0f, 0x68},     {0, 38.0f, 38.0f, 76.0f, 76.0f, 0x68},
};

// The batch-kind to sprite-instancer-index table: maps a descriptor's batch kind to the batch slot
// it draws into. @ghidraAddress 0x30f6d4
constexpr unsigned int kFcBatchIndex[] = {1, 2, 3, 4, 0};

// The sprite slot whose glyph draws black (the drop-shadow copy); every other slot draws white.
constexpr unsigned int kFcShadowSlot = 0;

} // namespace

/** @ghidraAddress 0x187484 */
ColetteThemeLayer::ColetteThemeLayer() {
    // The base constructor and the zero-initialised members clear the layer; the constructor then
    // seeds the layout size, the single-side default, and the two best-rank flag slots.
    m_flWidth = kLayoutWidth;
    m_flHeight = kLayoutHeight;
    m_nSideCount = kDefaultSideCount;
    for (int &nValue : m_aGradeValues) {
        nValue = kGradeValueDefault;
    }
}

/** @ghidraAddress 0x18751c */
ColetteThemeLayer *ColetteThemeLayer::shared() {
    if (g_pColetteThemeLayer == nullptr) {
        // The binary allocates the raw 0x98-byte object and runs the constructor, which chains the
        // base-layer constructor and seeds the layer's state.
        g_pColetteThemeLayer = new ColetteThemeLayer();
    }
    return g_pColetteThemeLayer;
}

/** @ghidraAddress 0x18756c */
void ColetteThemeLayer::CreateFcEffectSprites() {
    if (m_bBuilt) {
        return;
    }

    // The sprites hang beneath the shared background layer's render object rather than the global
    // scene root.
    BgLayer *pBackgroundLayer = BgLayer::GetBackgroundLayer();
    ne::C_RENDER *pParent = pBackgroundLayer->GetBackgroundRenderObject();

    m_pPartsTexture = ne::C_TEXTURE::FindOrLoadCached(kPartsTextureName);
    m_pEffectTexture = ne::C_TEXTURE::FindOrLoadCached(kEffectTextureName);
    m_pPartsTexture2 = ne::C_TEXTURE::FindOrLoadCached(kPartsTextureName);

    ne::C_TEXTURE *const apTextureFields[] = {m_pPartsTexture, m_pEffectTexture, m_pPartsTexture2};

    // Build one sprite instancer per slot, attach it under the background render object, and make it
    // visible. The first slot binds no texture; the rest bind their mapped atlas. Seed each slot's
    // sprite count and flag additive blend on the last slot.
    for (int nSlot = 0; nSlot < kSpriteSlotCount; ++nSlot) {
        ne::C_SPRITE_INSTANCING_2D *pSprite = ne::CreateWorldSpriteBatch(kSlotCapacities[nSlot]);
        pParent->AttachChild(pSprite);
        pSprite->SetVisible(true);
        if (nSlot != 0) {
            pSprite->SetRefCountedMember(apTextureFields[kSlotTextureField[nSlot]]);
        }
        pSprite->SetSpriteCount(m_aSpriteCounts[nSlot]);
        if (nSlot == kAdditiveBlendSlot) {
            pSprite->SetBlendMode(kAdditiveBlendMode);
        }
        m_apSprites[nSlot] = pSprite;
    }

    m_bBuilt = true;
}

/** @ghidraAddress 0x187690 */
void ColetteThemeLayer::ResetGradeDisplayState() {
    // Seed the reveal channel to hold a full value, park the clock off-screen, arm the display, and
    // load the per-side best-rank flags.
    m_gradeChannel.SetStart(kGradeChannelFull);
    m_gradeChannel.SetEnd(kGradeChannelFull);
    m_gradeChannel.SetDuration(0.0f);
    m_gradeChannel.SetElapsed(0.0f);
    m_gradeChannel.SetCurrent(kGradeChannelFull);
    m_flGradeRevealClock = kGradeClockStart;
    m_bGradeVisible = true;
    m_bGradeClockActive = true;
    m_bGradeArmed = true;
    LoadBestRankFlags();

    // The reveal runs longer for a single-side display or when the second side has no records.
    m_flGradeRevealDuration = kGradeRevealDurationDual;
    if (m_nSideCount == 1 || m_aGradeValues[1] == 0) {
        m_flGradeRevealDuration = kGradeRevealDurationSingle;
    }
}

/** @ghidraAddress 0x187710 */
void ColetteThemeLayer::LoadBestRankFlags() {
    for (int nSide = 0; nSide < kSideCount; ++nSide) {
        m_aGradeValues[nSide] =
            ScoreTracker::shared()->GetPlayRecordField10(static_cast<unsigned int>(nSide));
    }
}

/** @ghidraAddress 0x18774c */
void ColetteThemeLayer::StartFadeOut(float flDuration) {
    m_gradeChannel.SetStart(m_gradeChannel.GetCurrent());
    m_gradeChannel.SetEnd(0.0f);
    m_gradeChannel.SetDuration(flDuration);
    m_gradeChannel.SetElapsed(0.0f);
    if (flDuration <= 0.0f) {
        m_gradeChannel.SetCurrent(0.0f);
    }
}

/** @ghidraAddress 0x1879a4 */
void ColetteThemeLayer::EmitFcSprite(float flScaleX,
                                     float flScaleY,
                                     float flRotation,
                                     unsigned int nSpriteSlot,
                                     const S_VECTOR2 *pPosition,
                                     int nAlpha) {
    const FcSpriteDescriptor &descriptor = kFcSpriteDescriptors[nSpriteSlot];
    const unsigned int nBatch = kFcBatchIndex[descriptor.nBatchKind];

    ne::C_SPRITE_INSTANCING_2D *pBatch = m_apSprites[nBatch];
    const int nIndex = m_aSpriteCounts[nBatch];
    if (nIndex >= static_cast<int>(kSlotCapacities[nBatch])) {
        return;
    }

    const SpriteUvEntry &uv = g_aSpriteUvTable[descriptor.nUvFrameIndex];

    // The play-field half-height (rounded toward zero) offsets the quad's base Y.
    const int nHalfHeight =
        (g_nPlayfieldFullHeightY < 0 ? g_nPlayfieldFullHeightY + 1 : g_nPlayfieldFullHeightY) / 2;

    pBatch->SetSpritePositionXY(
        nIndex, pPosition->x, pPosition->y + static_cast<float>(nHalfHeight));
    pBatch->SetSpriteAnchor(nIndex, S_VECTOR2{descriptor.flAnchorX, descriptor.flAnchorY});
    pBatch->SetSpriteSize(nIndex, S_VECTOR2{descriptor.flSizeX, descriptor.flSizeY});
    pBatch->SetSpriteUvOrigin(nIndex, S_VECTOR2{uv.flOriginU, uv.flOriginV});
    pBatch->SetSpriteUvSize(nIndex, S_VECTOR2{uv.flSizeU, uv.flSizeV});
    pBatch->SetSpriteScale(nIndex, flScaleX, flScaleY);
    pBatch->SetSpriteRotation(nIndex, flRotation);

    // The drop-shadow slot draws black; every other slot draws white.
    const unsigned int nChannel = nSpriteSlot == kFcShadowSlot ? 0 : kColorMax;
    pBatch->SetSpriteColor(nIndex, nChannel, nChannel, nChannel, static_cast<unsigned int>(nAlpha));

    m_aSpriteCounts[nBatch] = nIndex + 1;
}
