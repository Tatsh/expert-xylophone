//
//  slide_note_layer.mm
//  REFLEC BEAT plus
//
//  The slide-note render layer (SlideNoteLayer). Reconstructed from Ghidra project rb458, program
//  rb458. @ghidraAddress values are relative to the program image base.
//

#include "slide_note_layer.h"

#include <cassert>

#include "bg_layer.h"
#include "gamesystem.h"
#include "neRender.h"
#include "neSpriteInstancing.h"
#include "neTexture.h"
#include "s_vector2.h"
#include "slide_note_sprite_table.h"
#include "sprite_uv_table.h"

// The process-wide slide-note layer, created lazily by shared().
static SlideNoteLayer *g_pSlideNoteLayer = nullptr; // @ghidraAddress 0x3dc658

// The number of active slide-note trails, shared with the trail animator.
int g_nActiveSlideTrailCount = 0; // @ghidraAddress 0x3dc650

// The sprite-UV atlas the slide-note sprite types index (shared with the score-gauge layer).
extern const SpriteUvEntry g_aScoreGaugeUvTable[]; // @ghidraAddress 0x2ef668

// The slide-note sprite-type layout table (declared in slide_note_sprite_table.h): read-only ROM
// data giving each type's batch, anchor, size, and UV-table index.
const SlideNoteSpriteType g_aSlideNoteSpriteTypes[kSlideNoteSpriteTypeCount] = {
    // {batchIndex, anchorX, anchorY, sizeW, sizeH, uvIndex}
    {0, 0.0f, 29.0f, 0.0f, 58.0f, 59},    // 0: head cap.
    {0, 0.0f, 29.0f, 27.0f, 58.0f, 60},   // 1: head body.
    {1, 31.0f, 31.0f, 62.0f, 62.0f, 65},  // 2.
    {1, 31.0f, 31.0f, 62.0f, 62.0f, 66},  // 3.
    {1, 31.0f, 31.0f, 62.0f, 62.0f, 67},  // 4.
    {1, 31.0f, 31.0f, 62.0f, 62.0f, 68},  // 5.
    {1, 31.0f, 31.0f, 62.0f, 62.0f, 69},  // 6.
    {1, 31.0f, 31.0f, 62.0f, 62.0f, 70},  // 7.
    {1, 31.0f, 31.0f, 62.0f, 31.0f, 39},  // 8.
    {1, 31.0f, 31.0f, 62.0f, 31.0f, 40},  // 9.
    {2, 31.0f, 31.0f, 62.0f, 62.0f, 62},  // 10.
    {2, 31.0f, 31.0f, 62.0f, 62.0f, 63},  // 11.
    {2, 31.0f, 31.0f, 62.0f, 62.0f, 64},  // 12.
    {2, 50.0f, 55.0f, 100.0f, 88.0f, 43}, // 13.
    {2, 50.0f, 55.0f, 100.0f, 88.0f, 44}, // 14.
    {0, 40.0f, 0.0f, 80.0f, 18.0f, 61},   // 15: glow.
};

namespace {
// The invalid-clock sentinel the layer starts with (no sample taken yet).
constexpr float kInvalidClock = -1.0f;

// The slide-note trail atlas and each batch's sprite capacity.
constexpr const char *kTrailTextureName = "00_texture/gm_parts1";
constexpr unsigned int kBatchCapacity = 0xf0;

// The additive blend mode, and the two sampler wrap parameters set on the newer hardware.
constexpr int kBlendModeAdditive = 1;
constexpr int kTexParamWrapT = 1;
constexpr int kTexParamWrapS = 0;
constexpr int kTexWrapRepeat = 1;

// The half-turn rotation a trail takes when its note is on the opposite play side, in radians
// (@ghidraAddress 0x2fe894).
constexpr float kMirrorRotation = 3.1415927f;
} // namespace

/** @ghidraAddress 0x95a18 */
SlideNoteLayer::SlideNoteLayer() {
    // The base constructor cached the device flags and theme; every trail record, sprite batch,
    // batch count, and the leading pointer start zero from their member initialisers, matching the
    // binary's field-by-field clears.
    m_bBuilt = false;
    m_flLastClock = kInvalidClock;
    g_nActiveSlideTrailCount = 0;
}

/** @ghidraAddress 0x95bc0 */
void SlideNoteLayer::Create(int nColor,
                            unsigned char nFlagA,
                            int nKind,
                            float flEndX,
                            float flEndY,
                            float flTargetX,
                            float flTargetY,
                            float flAlphaScale,
                            unsigned char nFlagB,
                            unsigned char nFlagC,
                            unsigned char nFlagD,
                            unsigned char nFlagE) {
    assert(nColor >= 0 && nColor < kPlayerColorMax);

    // A trail whose note is on the opposite play side is drawn mirrored a half-turn.
    const float flRotation =
        GameSystem::GetGameSystem()->GetPlayColor() != nColor ? kMirrorRotation : 0.0f;

    // Claim the first inactive pooled trail, scanning from the shared active-trail cursor; a full
    // pool drops the trail.
    for (int nSlot = g_nActiveSlideTrailCount; nSlot < kTrailCount; ++nSlot) {
        SlideNoteTrail &trail = m_aTrails[nSlot];
        if (!trail.bActive) {
            trail.nKind = nKind;
            trail.nColor = nColor;
            trail.bActive = true;
            trail.nFlagA = nFlagA;
            trail.flEndX = flEndX;
            trail.flEndY = flEndY;
            trail.flTargetX = flTargetX;
            trail.flTargetY = flTargetY;
            trail.nFlagB = nFlagB;
            trail.nFlagC = nFlagC;
            trail.flAlphaScale = flAlphaScale;
            trail.flRotation = flRotation;
            trail.nFlagD = nFlagD;
            trail.nFlagE = nFlagE;
            ++g_nActiveSlideTrailCount;
            return;
        }
    }
}

/** @ghidraAddress 0x95ae0 */
void SlideNoteLayer::BuildSprites() {
    if (m_bBuilt) {
        return;
    }
    // The trails hang beneath the shared background layer's render object.
    ne::C_RENDER *pParent = BgLayer::GetBackgroundLayer()->GetBackgroundRenderObject();
    m_pTexture = ne::C_TEXTURE::FindOrLoadCached(kTrailTextureName);
    for (int nBatch = 0; nBatch < kBatchCount; ++nBatch) {
        ne::C_SPRITE_INSTANCING_2D *pBatch = ne::CreateWorldSpriteBatch(kBatchCapacity);
        m_apBatches[nBatch] = pBatch;
        pParent->AttachChild(pBatch);
        pBatch->SetVisible(true);
        pBatch->SetRefCountedMember(m_pTexture);
        pBatch->SetSpriteCount(0);
        // Batches 0 and 2 draw with additive blending.
        if ((nBatch & ~2) == 0) {
            pBatch->SetBlendMode(kBlendModeAdditive);
        }
        // The newer hardware needs the trail atlas's wrap sampler parameters set explicitly.
        if (!IsHardwareType9()) {
            pBatch->SetTexParam(kTexParamWrapT, kTexWrapRepeat);
            pBatch->SetTexParam(kTexParamWrapS, kTexWrapRepeat);
        }
    }
    m_bBuilt = true;
    g_nActiveSlideTrailCount = 0;
}

/** @ghidraAddress 0x95a90 */
SlideNoteLayer *SlideNoteLayer::shared() {
    if (g_pSlideNoteLayer == nullptr) {
        // The binary allocates the raw 0xe08-byte object and runs the constructor.
        g_pSlideNoteLayer = new SlideNoteLayer();
    }
    return g_pSlideNoteLayer;
}

/** @ghidraAddress 0x96164 */
void SlideNoteLayer::CreateSprite(int nType,
                                  const S_VECTOR2 *pPosition,
                                  unsigned int nAlpha,
                                  float flLength,
                                  float flRotation,
                                  float flScale) {
    assert(nType >= 0);
    assert(nType < kSlideNoteSpriteTypeCount);

    const SlideNoteSpriteType &spriteType = g_aSlideNoteSpriteTypes[nType];
    const SpriteUvEntry &uv = g_aScoreGaugeUvTable[spriteType.nUvIndex];

    // Claim the next free sprite in the type's batch.
    ne::C_SPRITE_INSTANCING_2D *pBatch = m_apBatches[spriteType.nBatchIndex];
    const int nIndex = m_anBatchCount[spriteType.nBatchIndex];

    pBatch->SetSpritePosition(nIndex, *pPosition);
    pBatch->SetSpriteAnchor(nIndex, S_VECTOR2{spriteType.flAnchorX, spriteType.flAnchorY});
    pBatch->SetSpriteUvOrigin(nIndex, S_VECTOR2{uv.flOriginU, uv.flOriginV});
    pBatch->SetSpriteUvSize(nIndex, S_VECTOR2{uv.flSizeU, uv.flSizeV});
    pBatch->SetSpriteRotation(nIndex, flRotation);
    pBatch->SetSpriteColor(nIndex, 0xff, 0xff, 0xff, nAlpha);

    // The head/tail types size to the layout height and scale both axes; the glow types (0xf and up)
    // take their height from the length argument and draw at unit y-scale.
    float flScaleY;
    if (nType < kSlideNoteGlowTypeBase) {
        pBatch->SetSpriteSize(nIndex, S_VECTOR2{spriteType.flSizeW, spriteType.flSizeH});
        flScaleY = flScale;
    } else {
        pBatch->SetSpriteSize(nIndex, S_VECTOR2{spriteType.flSizeW, flLength});
        flScaleY = 1.0f;
    }
    pBatch->SetSpriteScale(nIndex, flScale, flScaleY);

    ++m_anBatchCount[spriteType.nBatchIndex];
}
