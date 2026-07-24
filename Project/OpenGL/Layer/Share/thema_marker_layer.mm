#include "thema_marker_layer.h"

#import "RBUserSettingData.h"
#include "bg_layer.h"
#include "neRender.h"
#include "neSpriteInstancing.h"
#include "neTexture.h"
#import "s_vector2.h"

// The process-wide theme-marker layer, created lazily by shared().
static ThemaMarkerLayer *g_pThemaMarkerLayer = nullptr; // @ghidraAddress 0x3deed0

namespace {

// The atlas the markers draw from (@ghidraAddress 0x3ceaa0).
constexpr const char *kTextureName = "00_texture/gm_parts1";

// Which of the two batches each marker group draws into (@ghidraAddress 0x30de28).
constexpr int kMarkerBatch[] = {0, 0, 1, 1, 1, 1};

// How many sprites each marker group emits (@ghidraAddress 0x30de40).
constexpr int kMarkerSpriteCount[] = {1, 1, 1, 1, 4, 4};

// Per-marker layout (@ghidraAddress 0x30de58): the anchor (half the size), the size, and the index
// into the UV table below.
struct MarkerLayout {
    float flAnchorX;
    float flAnchorY;
    float flSizeW;
    float flSizeH;
    int nUvIndex;
};
constexpr MarkerLayout kMarkerLayout[] = {
    {318.0f, 10.0f, 636.0f, 20.0f, 95},
    {318.0f, 10.0f, 636.0f, 20.0f, 96},
    {318.0f, 34.0f, 636.0f, 68.0f, 97},
    {318.0f, 34.0f, 636.0f, 68.0f, 98},
    {248.0f, 34.0f, 496.0f, 124.0f, 99},
    {248.0f, 34.0f, 496.0f, 124.0f, 100},
};

// The UV table (@ghidraAddress 0x2ef668, entry = base + nUvIndex * 0x10): the UV origin and UV size
// mapped to each marker. Only the six entries the markers use (indices 95 through 100) are listed,
// keyed by their table index.
struct UvEntry {
    int nIndex;
    float flOriginU;
    float flOriginV;
    float flSizeU;
    float flSizeV;
};
constexpr UvEntry kUvTable[] = {
    {95, 0.51074f, 0.1582f, 0.00098f, 0.01953f},
    {96, 0.5166f, 0.1582f, 0.00098f, 0.01953f},
    {97, 0.51074f, 0.08984f, 0.00098f, 0.06641f},
    {98, 0.5166f, 0.08984f, 0.00098f, 0.06641f},
    {99, 0.00195f, 0.87695f, 0.48438f, 0.12109f},
    {100, 0.48828f, 0.87695f, 0.48438f, 0.12109f},
};

// The marker count for the Classic theme versus the others.
constexpr int kClassicMarkerCount = 6;
constexpr int kOtherMarkerCount = 4;
constexpr int kClassicThema = 0;

// The batch that draws in 3D (its vertex flag is set), and the additive-style vertex flag value.
constexpr int k3dBatch = 1;

const UvEntry &LookupUv(int nUvIndex) {
    for (const UvEntry &entry : kUvTable) {
        if (entry.nIndex == nUvIndex) {
            return entry;
        }
    }
    return kUvTable[0];
}

} // namespace

/** @ghidraAddress 0x17fc00 */
ThemaMarkerLayer::ThemaMarkerLayer() {
    m_flScaleX = 1.0f;
    m_flScaleY = 1.0f;
    m_flReserved8c = 1.0f;

    // Assign each marker group a non-overlapping index range within its batch, accumulating each
    // batch's total sprite capacity as it goes.
    for (int nMarker = 0; nMarker < kMarkerLayoutCount; ++nMarker) {
        const int nBatch = kMarkerBatch[nMarker];
        m_aMarkerBaseIndex[nMarker] = m_aBatchCapacity[nBatch];
        m_aBatchCapacity[nBatch] += kMarkerSpriteCount[nMarker];
    }
}

/** @ghidraAddress 0x17fccc */
ThemaMarkerLayer *ThemaMarkerLayer::shared() {
    if (g_pThemaMarkerLayer == nullptr) {
        // The binary allocates the raw 0x98-byte object and runs the constructor.
        g_pThemaMarkerLayer = new ThemaMarkerLayer();
    }
    return g_pThemaMarkerLayer;
}

/** @ghidraAddress 0x17ff50 */
void ThemaMarkerLayer::LoadThemaMarkerSprites() {
    if (m_bBuilt) {
        return;
    }

    // The Classic theme shows six marker groups; the others show four.
    const int nThema = [RBUserSettingData.sharedInstance thema];
    m_nMarkerCount = nThema == kClassicThema ? kClassicMarkerCount : kOtherMarkerCount;

    // The markers hang beneath the shared background layer's render object rather than the global
    // scene root.
    BgLayer *pBackgroundLayer = BgLayer::GetBackgroundLayer();
    ne::C_RENDER *pParent = pBackgroundLayer->GetBackgroundRenderObject();

    m_pTexture = ne::C_TEXTURE::FindOrLoadCached(kTextureName);

    // Build the two sprite batches, each sized to hold all the marker groups routed to it; mark the
    // 3D batch's vertex flag.
    for (int nBatch = 0; nBatch < kBatchCount; ++nBatch) {
        ne::C_SPRITE_INSTANCING *pSprite =
            ne::CreateWorldSpriteBatch(static_cast<unsigned int>(m_aBatchCapacity[nBatch]));
        m_apSprites[nBatch] = pSprite;
        pParent->AttachChild(pSprite);
        pSprite->SetVisible(true);
        pSprite->SetRefCountedMember(m_pTexture);
        pSprite->SetSpriteCount(m_aBatchCapacity[nBatch]);
        if (nBatch == k3dBatch) {
            pSprite->SetBlendMode(1);
            break;
        }
    }

    // Emit each marker group's sprites into its batch: the anchor and size come from the layout
    // table, the UV origin and size from the UV table, all at white with zero alpha.
    for (int nMarker = 0; nMarker < m_nMarkerCount; ++nMarker) {
        const MarkerLayout &layout = kMarkerLayout[nMarker];
        const UvEntry &uv = LookupUv(layout.nUvIndex);
        ne::C_SPRITE_INSTANCING *pSprite = m_apSprites[kMarkerBatch[nMarker]];
        const int nBaseIndex = m_aMarkerBaseIndex[nMarker];
        for (int nSprite = 0; nSprite < kMarkerSpriteCount[nMarker]; ++nSprite) {
            const int nIndex = nBaseIndex + nSprite;
            pSprite->SetSpritePosition(nIndex, S_VECTOR2{0.0f, 0.0f});
            pSprite->SetSpriteAnchor(nIndex, S_VECTOR2{layout.flAnchorX, layout.flAnchorY});
            pSprite->SetSpriteSize(nIndex, S_VECTOR2{layout.flSizeW, layout.flSizeH});
            pSprite->SetSpriteUvOrigin(nIndex, S_VECTOR2{uv.flOriginU, uv.flOriginV});
            pSprite->SetSpriteUvSize(nIndex, S_VECTOR2{uv.flSizeU, uv.flSizeV});
            pSprite->SetSpriteColor(nIndex, 0xff, 0xff, 0xff, 0);
        }
    }

    m_bBuilt = true;
}
