#include "classicthemelayer.h"

#include "ScoreTracker.h"
#include "bg_layer.h"
#include "engineglobals.h"
#include "neRender.h"
#include "neSpriteInstancing.h"
#include "neTexture.h"
#include "sprite_uv_table.h"

// The background texture the Classic-theme batches all draw from.
static const char *const g_szGmParts2TextureKey = "00_texture/gm_parts2"; // @ghidraAddress 0x3ceaa8

// The sprite capacities (maximum sprite counts) for the three Classic-theme background batches.
static const int g_anClassicThemeBatchCapacities[] = {1, 7, 30}; // @ghidraAddress 0x301970

// The per-sprite-kind transform table: each kind's anchor, size, and atlas-frame index.
// @ghidraAddress 0x301c60
const ClassicThemeSpriteTransform g_aClassicThemeSpriteTransforms[] = {
    {{384.0f, 512.0f}, {768.0f, 1024.0f}, 0},
    {{145.0f, 53.0f}, {290.0f, 106.0f}, 9},
    {{145.0f, 53.0f}, {290.0f, 106.0f}, 10},
    {{188.0f, 53.0f}, {376.0f, 106.0f}, 11},
    {{14.0f, 14.0f}, {28.0f, 28.0f}, 12},
};

// The process-wide Classic-theme layer, created lazily by shared().
static ClassicThemeLayer *g_pClassicThemeLayer = nullptr; // @ghidraAddress 0x3de7b8

namespace {

// The colour index the constructor defaults to.
constexpr int kDefaultColor = 1;

// The value the two score-value slots are seeded to by the constructor.
constexpr int kScoreValueDefault = 4;

// The animation clock's seeded start, well before zero so the intro plays from the beginning
// (@ghidraAddress 0x3018b0).
constexpr float kAnimClockStart = -500.0f;

// The eased-progress channel's fully-shown value.
constexpr float kEaseFullValue = 1.0f;

// The maximum value of an opaque colour channel.
constexpr unsigned int kColorMax = 255;

} // namespace

/** @ghidraAddress 0x109ee0 */
ClassicThemeLayer *ClassicThemeLayer::shared() {
    if (g_pClassicThemeLayer == nullptr) {
        // The binary allocates the raw 0x60-byte object and runs the constructor.
        g_pClassicThemeLayer = new ClassicThemeLayer();
    }
    return g_pClassicThemeLayer;
}

/** @ghidraAddress 0x109e68 */
ClassicThemeLayer::ClassicThemeLayer() {
    // The base constructor and the zero-initialised members clear the texture, batches, counts, and
    // flags; the constructor then applies the two non-zero defaults.
    m_nColor = kDefaultColor;
    for (int &nValue : m_aScoreValues) {
        nValue = kScoreValueDefault;
    }
}

/** @ghidraAddress 0x109f30 */
void ClassicThemeLayer::InitializeBackgroundSceneNodes() {
    if (m_fInitialized) {
        return;
    }

    ne::C_RENDER *pRootNode = BgLayer::GetBackgroundLayer()->GetBackgroundRenderObject();
    m_pTexture = ne::C_TEXTURE::FindOrLoadCached(g_szGmParts2TextureKey);

    for (int nBatchIndex = 0; nBatchIndex < kBackgroundBatchCount; ++nBatchIndex) {
        ne::C_SPRITE_INSTANCING_2D *pBatch =
            ne::CreateWorldSpriteBatch(g_anClassicThemeBatchCapacities[nBatchIndex]);
        pRootNode->AttachChild(pBatch);
        pBatch->SetVisible(true);
        // The first batch is stored without being given the shared texture; only the second and
        // third batches take it, exactly as the binary does.
        if (nBatchIndex != 0) {
            pBatch->SetRefCountedMember(m_pTexture);
        }
        pBatch->SetSpriteCount(m_anSpriteCount[nBatchIndex]);
        // The last batch is additively blended over the others.
        if (nBatchIndex == kBackgroundBatchCount - 1) {
            pBatch->SetBlendMode(1);
        }
        m_apSpriteBatch[nBatchIndex] = pBatch;
    }

    m_fInitialized = true;
}

/** @ghidraAddress 0x10a0a0 */
void ClassicThemeLayer::SetColor(int nColor) {
    m_nColor = nColor;
}

/** @ghidraAddress 0x10a644 */
void ClassicThemeLayer::ConfigureSpriteSlot(int nBatch,
                                            int nSpriteKind,
                                            const S_VECTOR2 &position,
                                            float flScaleX,
                                            float flScaleY,
                                            float flRotation,
                                            int nAlpha) {
    ne::C_SPRITE_INSTANCING_2D *pBatch = m_apSpriteBatch[nBatch];
    const int nIndex = m_anSpriteCount[nBatch];
    if (nIndex >= g_anClassicThemeBatchCapacities[nBatch]) {
        return;
    }

    const ClassicThemeSpriteTransform &transform = g_aClassicThemeSpriteTransforms[nSpriteKind];
    const SpriteUvEntry &uv = g_aSpriteUvTable[transform.nUvIndex];

    // The slot sits at the given position, offset down by the play-field half-height (rounding
    // toward zero).
    const int nHalfHeight =
        (g_nPlayfieldFullHeightY < 0 ? g_nPlayfieldFullHeightY + 1 : g_nPlayfieldFullHeightY) / 2;
    pBatch->SetSpritePositionXY(nIndex, position.x, position.y + static_cast<float>(nHalfHeight));
    pBatch->SetSpriteAnchor(nIndex, transform.anchor);
    pBatch->SetSpriteSize(nIndex, transform.size);
    pBatch->SetSpriteUvOrigin(nIndex, S_VECTOR2{uv.flOriginU, uv.flOriginV});
    pBatch->SetSpriteUvSize(nIndex, S_VECTOR2{uv.flSizeU, uv.flSizeV});
    pBatch->SetSpriteScale(nIndex, flScaleX, flScaleY);
    pBatch->SetSpriteRotation(nIndex, flRotation);

    // Batch zero is tinted black; the others opaque white.
    const unsigned int nChannel = nBatch == 0 ? 0 : kColorMax;
    pBatch->SetSpriteColor(nIndex, nChannel, nChannel, nChannel, static_cast<unsigned int>(nAlpha));

    ++m_anSpriteCount[nBatch];
}

/** @ghidraAddress 0x10a01c */
void ClassicThemeLayer::InitializeScoreGaugeState() {
    // Seed the animation clock and the eased-progress channel: the clock starts well before zero, the
    // channel starts and ends fully shown over a zero duration (so it reads as shown), and its current
    // value is one. Both animation flags are raised.
    m_flClock = kAnimClockStart;
    m_easeChannel.SetStart(kEaseFullValue);
    m_easeChannel.SetEnd(kEaseFullValue);
    m_easeChannel.SetDuration(0.0f);
    m_easeChannel.SetElapsed(0.0f);
    m_easeChannel.SetCurrent(kEaseFullValue);
    m_bAnimActive = true;
    m_bAnimEnabled = true;
    InitializeScoreValuesFromTracker();
}

/** @ghidraAddress 0x10a044 */
void ClassicThemeLayer::InitializeScoreValuesFromTracker() {
    for (int nSide = 0; nSide < kScoreValueCount; ++nSide) {
        m_aScoreValues[nSide] =
            ScoreTracker::shared()->GetPlayRecordField10(static_cast<unsigned int>(nSide));
    }
}

/** @ghidraAddress 0x10a080 */
void ClassicThemeLayer::StartGaugeValueFade(float flDuration) {
    // Restart the eased-progress channel from its current value down to zero over the given duration.
    m_easeChannel.SetStart(m_easeChannel.GetCurrent());
    m_easeChannel.SetEnd(0.0f);
    m_easeChannel.SetDuration(flDuration);
    m_easeChannel.SetElapsed(0.0f);
    // A non-positive duration takes effect immediately: snap the current value to zero.
    if (flDuration <= 0.0f) {
        m_easeChannel.SetCurrent(0.0f);
    }
}

/** @ghidraAddress 0x10a5fc */
void ClassicThemeLayer::AdvanceEasedProgress(float flDelta) {
    m_easeChannel.Advance(flDelta);
}
