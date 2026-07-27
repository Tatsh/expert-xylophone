//
//  chain_connector_layer.mm
//  REFLEC BEAT plus
//
//  The note chain-connector layer (ChainConnectorLayer). Reconstructed from Ghidra project rb458,
//  program rb458. @ghidraAddress values are relative to the program image base.
//

#include "chain_connector_layer.h"

#include <cassert>

#include "bg_layer.h"
#include "neRender.h"
#include "neSpriteInstancing.h"
#include "neTexture.h"
#include "s_vector2.h"
#include "sprite_uv_table.h"

namespace {
// The atlas the connector sprites draw from.
constexpr const char *kAtlasTextureName = "00_texture_gm_parts1";

// The connector sprite batch draws additively; the non-tutorial build seeds two texture parameters.
constexpr int kAdditiveBlendMode = 1;
constexpr int kTexParamValue = 1;
} // namespace

// The shared connector draw count, reset when the layer is constructed.
int g_nChainConnectorDrawCount = {}; // @ghidraAddress 0x3def48

// The process-wide chain-connector layer, created lazily by shared().
static ChainConnectorLayer *g_pChainConnectorLayer = nullptr; // @ghidraAddress 0x3def50

// The shared sprite-UV atlas the connector sprite types index (@ghidraAddress 0x2ef668).
extern const SpriteUvEntry g_aScoreGaugeUvTable[];

namespace {
// The number of connector sprite types, and the UV-table entry each indexes (both draw the same
// fixed quad; the type only selects the atlas frame).
constexpr int kConnectorTypeCount = 2;
constexpr int kConnectorUvIndex[kConnectorTypeCount] = {71, 72};
// The fixed connector-quad anchor and size every connector sprite uses.
constexpr float kConnectorAnchorX = 7.0f;
constexpr float kConnectorAnchorY = 0.0f;
constexpr float kConnectorSizeW = 14.0f;
constexpr float kConnectorSizeH = 16.0f;
} // namespace

/** @ghidraAddress 0x185844 */
ChainConnectorLayer *ChainConnectorLayer::shared() {
    if (g_pChainConnectorLayer == nullptr) {
        g_pChainConnectorLayer = new ChainConnectorLayer();
    }
    return g_pChainConnectorLayer;
}

/** @ghidraAddress 0x1857e4 */
ChainConnectorLayer::ChainConnectorLayer() {
    // The base constructor and member initialisers clear the sprite header and pooled records; the
    // shared connector draw count resets to zero.
    g_nChainConnectorDrawCount = 0;
}

/** @ghidraAddress 0x185894 */
void ChainConnectorLayer::CreateSprites() {
    if (m_bLoaded) {
        return;
    }

    ne::C_RENDER *pParent = BgLayer::GetBackgroundLayer()->GetBackgroundRenderObject();
    m_pTexture = ne::C_TEXTURE::FindOrLoadCached(kAtlasTextureName);
    m_pSprite = ne::CreateWorldSpriteBatch(static_cast<unsigned int>(m_nCapacity));
    pParent->AttachChild(m_pSprite);
    m_pSprite->SetVisible(true);
    m_pSprite->SetRefCountedMember(m_pTexture);
    m_pSprite->SetSpriteCount(0);
    m_pSprite->SetBlendMode(kAdditiveBlendMode);

    // A non-tutorial build seeds two texture parameters.
    if (!IsHardwareType9()) {
        m_pSprite->SetTexParam(1, kTexParamValue);
        m_pSprite->SetTexParam(0, kTexParamValue);
    }

    m_bLoaded = true;
    g_nChainConnectorDrawCount = 0;
}

/** @ghidraAddress 0x185b94 */
void ChainConnectorLayer::CreateSprite(
    int nType, const S_VECTOR2 *pPosition, unsigned int nAlpha, float flRotation, float flScaleY) {
    assert(nType >= 0);
    assert(nType < kConnectorTypeCount);

    const SpriteUvEntry &uv = g_aScoreGaugeUvTable[kConnectorUvIndex[nType]];
    const int nIndex = m_nSpriteCount;

    m_pSprite->SetSpritePosition(nIndex, *pPosition);
    m_pSprite->SetSpriteAnchor(nIndex, S_VECTOR2{kConnectorAnchorX, kConnectorAnchorY});
    m_pSprite->SetSpriteSize(nIndex, S_VECTOR2{kConnectorSizeW, kConnectorSizeH});
    m_pSprite->SetSpriteUvOrigin(nIndex, S_VECTOR2{uv.flOriginU, uv.flOriginV});
    m_pSprite->SetSpriteUvSize(nIndex, S_VECTOR2{uv.flSizeU, uv.flSizeV});
    m_pSprite->SetSpriteRotation(nIndex, flRotation);
    m_pSprite->SetSpriteScale(nIndex, 1.0f, flScaleY);
    m_pSprite->SetSpriteColor(nIndex, 0xff, 0xff, 0xff, nAlpha);

    ++m_nSpriteCount;
}
