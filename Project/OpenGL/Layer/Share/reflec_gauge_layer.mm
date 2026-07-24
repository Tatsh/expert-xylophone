#include "reflec_gauge_layer.h"

#include <cassert>
#include <cmath>

#include "bg_layer.h"
#include "gamesystem.h"
#include "neRender.h"
#include "neSpriteInstancing.h"
#include "neTexture.h"

// The process-wide Reflec gauge layer, created lazily by shared().
static ReflecGaugeLayer *g_pReflecGaugeLayer = nullptr; // @ghidraAddress 0x3df2c8

namespace {

// The atlas the gauge/combo sprites draw from (@ghidraAddress 0x3ceaa8).
constexpr const char *kTextureName = "00_texture/gm_parts2";

// Which batch each part group's capacity accumulates into (@ghidraAddress 0x30fc58).
constexpr int kGroupBatch[] = {0, 1, 2, 1, 2, 3};

// How many sprites each part group contributes to its batch (@ghidraAddress 0x30fc70).
constexpr int kGroupPartCount[] = {2, 5, 5, 5, 5, 2};

// The batch that receives the vertex flag, and that flag value.
constexpr int kVertexFlagBatch = 2;
constexpr int kVertexFlagMode = 1;

// The gauge value is quantised to steps of one hundredth (@ghidraAddress 0x2ec6b0) and clamped to
// the range zero through five.
constexpr float kGaugeQuantizeScale = 100.0f;
constexpr float kGaugeMax = 5.0f;

} // namespace

/** @ghidraAddress 0x18a7d0 */
ReflecGaugeLayer::ReflecGaugeLayer() {
    m_aScales[0] = 1.0f;
    m_aScales[1] = 1.0f;

    // Accumulate each part group's sprite count into its batch's capacity, recording each group's
    // base index within that batch.
    for (int i = 0; i < kPartGroupCount; ++i) {
        const int nBatch = kGroupBatch[i];
        m_aPartBaseIndex[i] = m_aBatchCapacity[nBatch];
        m_aBatchCapacity[nBatch] += kGroupPartCount[i];
    }
}

/** @ghidraAddress 0x18a88c */
ReflecGaugeLayer *ReflecGaugeLayer::shared() {
    if (g_pReflecGaugeLayer == nullptr) {
        // The binary allocates the raw 0xa0-byte object and runs the constructor.
        g_pReflecGaugeLayer = new ReflecGaugeLayer();
    }
    return g_pReflecGaugeLayer;
}

/** @ghidraAddress 0x18a8dc */
void ReflecGaugeLayer::CreateGaugeSliderSprites() {
    if (m_bBuilt) {
        return;
    }

    m_pTexture = ne::C_TEXTURE::FindOrLoadCached(kTextureName);

    // Build the four batches, each sized to its accumulated capacity, attach each under the
    // background layer's render object, make it visible, bind the atlas, and clear its frame index;
    // the third batch also sets its vertex flag.
    for (int i = 0; i < kBatchCount; ++i) {
        ne::C_SPRITE_INSTANCING *pSprite =
            ne::CreateWorldSpriteBatch(static_cast<unsigned int>(m_aBatchCapacity[i]));
        m_apSprites[i] = pSprite;
        BgLayer *pBackgroundLayer = BgLayer::GetBackgroundLayer();
        ne::C_RENDER *pParent = pBackgroundLayer->GetBackgroundRenderObject();
        pParent->AttachChild(pSprite);
        pSprite->SetVisible(true);
        pSprite->SetRefCountedMember(m_pTexture);
        pSprite->SetSpriteCount(0);
        if (i == kVertexFlagBatch) {
            pSprite->SetBlendMode(kVertexFlagMode);
        }
    }

    m_bBuilt = true;
}

/** @ghidraAddress 0x18ab98 */
float ReflecGaugeLayer::GetValueBySide(unsigned int nSide) const {
    assert(static_cast<int>(nSide) >= 0 && nSide < kSideCount);
    return m_aSides[nSide].flValue;
}

/** @ghidraAddress 0x18aa68 */
void ReflecGaugeLayer::SetValueBySide(float flValue, unsigned int nSide) {
    assert(static_cast<int>(nSide) >= 0 && nSide < kSideCount);
    // Quantise to hundredths, floor at zero, then cap at the maximum unless every reflec was a
    // full-just.
    float flQuantized = std::round(flValue * kGaugeQuantizeScale) / kGaugeQuantizeScale;
    if (flQuantized <= 0.0f) {
        flQuantized = 0.0f;
    }
    if (flQuantized > kGaugeMax && !GameSystem::GetGameSystem()->GetFullJustReflec()) {
        flQuantized = kGaugeMax;
    }
    m_aSides[nSide].flValue = flQuantized;
}

/** @ghidraAddress 0x18ab18 */
float ReflecGaugeLayer::GetValue(int nColor) const {
    assert(nColor >= 0 && nColor < kSideCount);
    // The colour selects the side by whether it matches the current play side.
    const unsigned int nSide = GameSystem::GetGameSystem()->GetPlayColor() == nColor ? 1 : 0;
    return GetValueBySide(nSide);
}

/** @ghidraAddress 0x18a9d8 */
void ReflecGaugeLayer::SetValue(float flValue, int nColor) {
    assert(nColor >= 0 && nColor < kSideCount);
    const unsigned int nSide = GameSystem::GetGameSystem()->GetPlayColor() == nColor ? 1 : 0;
    SetValueBySide(flValue, nSide);
}

/** @ghidraAddress 0x18abfc */
void AddReflecGaugeValue(float flDelta, ReflecGaugeLayer *pGauge, int nColor) {
    pGauge->SetValue(pGauge->GetValue(nColor) + flDelta, nColor);
}

/** @ghidraAddress 0x18acb8 */
void SubReflecGaugeValue(float flDelta, ReflecGaugeLayer *pGauge, int nPlayer) {
    // The gauge side is the player's opposite-of-match against the current play side.
    const unsigned int nSide = GameSystem::GetGameSystem()->GetPlayColor() != nPlayer ? 1 : 0;
    pGauge->SetValueBySide(pGauge->GetValueBySide(nSide) - flDelta, nSide);
}
