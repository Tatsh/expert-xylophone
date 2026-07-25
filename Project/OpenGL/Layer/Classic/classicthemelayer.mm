#include "classicthemelayer.h"

#include "ScoreTracker.h"
#include "bg_layer.h"
#include "neRender.h"
#include "neSpriteInstancing.h"
#include "neTexture.h"

// The background texture the Classic-theme batches all draw from.
static const char *const g_szGmParts2TextureKey = "00_texture/gm_parts2"; // @ghidraAddress 0x3ceaa8

// The sprite capacities (maximum sprite counts) for the three Classic-theme background batches.
static const int g_anClassicThemeBatchCapacities[] = {1, 7, 30}; // @ghidraAddress 0x301970

// The process-wide Classic-theme layer, created lazily by shared().
static ClassicThemeLayer *g_pClassicThemeLayer = nullptr; // @ghidraAddress 0x3de7b8

namespace {

// The colour index the constructor defaults to.
constexpr int kDefaultColor = 1;

// The value the two score-value slots are seeded to by the constructor.
constexpr int kScoreValueDefault = 4;

// The score-gauge display block's initial state: an off-screen start Y and two unit scales
// (@ghidraAddress 0x3018b0).
constexpr float kScoreGaugeInitial[] = {-500.0f, 1.0f, 1.0f, 0.0f};

// The score gauge's full target value.
constexpr float kScoreGaugeFullTarget = 1.0f;

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
        ne::C_SPRITE_INSTANCING *pBatch =
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

/** @ghidraAddress 0x10a01c */
void ClassicThemeLayer::InitializeScoreGaugeState() {
    m_nScoreGaugeState = 0;
    m_flScoreGaugeTarget = kScoreGaugeFullTarget;
    for (int i = 0; i < kScoreGaugeBlockCount; ++i) {
        m_aScoreGaugeBlock[i] = kScoreGaugeInitial[i];
    }
    m_bFlag3c = true;
    m_bFlag3d = true;
    InitializeScoreValuesFromTracker();
}

/** @ghidraAddress 0x10a044 */
void ClassicThemeLayer::InitializeScoreValuesFromTracker() {
    for (int nSide = 0; nSide < kScoreValueCount; ++nSide) {
        m_aScoreValues[nSide] =
            ScoreTracker::shared()->GetPlayRecordField10(static_cast<unsigned int>(nSide));
    }
}
