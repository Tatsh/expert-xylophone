#include "chain_connector_layer.h"

#include <cassert>
#include <cmath>

#include "bg_layer.h"
#include "gamesystem.h"
#include "neRender.h"
#include "neSpriteInstancing.h"
#include "neTexture.h"
#include "s_vector2.h"
#include "sprite_uv_table.h"
#include "vectormath.h"

namespace {
constexpr const char *kAtlasTextureName = "00_texture/gm_parts1";

constexpr int kAdditiveBlendMode = 1;
constexpr int kTexParamValue = 1;
} // namespace

int g_nChainConnectorDrawCount = {}; // @ghidraAddress 0x3def48

static ChainConnectorLayer *g_pChainConnectorLayer = nullptr; // @ghidraAddress 0x3def50

// @ghidraAddress 0x2ef668
extern const SpriteUvEntry g_aScoreGaugeUvTable[];

namespace {
constexpr int kPlayerColorMax = 2;

// Play colour 1 makes record colour 1 the play side; any other value swaps the two.
constexpr int kPlayColorSide1 = 1;

constexpr float kAlphaScale = 255.0f;

constexpr float kMinConnectorLength = 1.0f;

constexpr float kLengthToScaleY = 0.0625f;

// A quarter turn, so the connector sprite points along the chain.
constexpr double kRotationBias = M_PI_2;

// Both types draw the same fixed quad; the type only selects the atlas frame.
constexpr int kConnectorTypeCount = 2;
constexpr int kConnectorUvIndex[kConnectorTypeCount] = {71, 72};
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

constexpr int kSpriteBatchCapacity = 256;

/** @ghidraAddress 0x1857e4 */
ChainConnectorLayer::ChainConnectorLayer() {
    g_nChainConnectorDrawCount = 0;
    // Without this the batch has capacity zero; the binary adds 0x100 at 0x185834.
    m_nCapacity = kSpriteBatchCapacity;
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

    if (!IsHardwareType9()) {
        m_pSprite->SetTexParam(1, kTexParamValue);
        m_pSprite->SetTexParam(0, kTexParamValue);
    }

    m_bLoaded = true;
    g_nChainConnectorDrawCount = 0;
}

/** @ghidraAddress 0x185944 */
void ChainConnectorLayer::Create(
    int nColor, float flStartX, float flStartY, float flEndX, float flEndY) {
    assert(nColor >= 0);
    assert(nColor < kPlayerColorMax);

    if (g_nChainConnectorDrawCount >= kChainRecordCount) {
        return;
    }

    for (int nIndex = g_nChainConnectorDrawCount; nIndex < kChainRecordCount; ++nIndex) {
        ChainRecord &record = m_aChains[nIndex];
        if (record.bActive) {
            continue;
        }
        record.nColor = nColor;
        record.bActive = true;
        record.flStartX = flStartX;
        record.flStartY = flStartY;
        record.flEndX = flEndX;
        record.flEndY = flEndY;
        ++g_nChainConnectorDrawCount;
        return;
    }
}

/** @ghidraAddress 0x1859fc */
void ChainConnectorLayer::Update() {
    m_nSpriteCount = 0;

    const GameSystem *pGameSystem = GameSystem::GetGameSystem();
    const int nScaledRivalAlpha = static_cast<int>(pGameSystem->GetRivalAlpha() * kAlphaScale);
    const bool bColor1IsPlaySide = pGameSystem->GetPlayColor() == kPlayColorSide1;
    const unsigned int nAlphaColor0 =
        static_cast<unsigned int>((bColor1IsPlaySide ? nScaledRivalAlpha : -1) & 0xff);
    const unsigned int nAlphaColor1 =
        static_cast<unsigned int>((bColor1IsPlaySide ? -1 : nScaledRivalAlpha) & 0xff);

    for (int nIndex = 0; nIndex < kChainRecordCount; ++nIndex) {
        ChainRecord &record = m_aChains[nIndex];
        // @ghidraAddress 0x185a7c, 0x185ad0
        if (nIndex >= g_nChainConnectorDrawCount) {
            record.bActive = false;
            continue;
        }
        if (!record.bActive) {
            continue;
        }
        record.bActive = false;

        S_VECTOR2 vStart{record.flStartX, record.flStartY};
        S_VECTOR2 vDelta{record.flEndX, record.flEndY};
        SubtractVector2(&vDelta, &vStart);
        const float flLength = Vector2Length(&vDelta);

        float flRotation = 0.0f;
        if (flLength >= kMinConnectorLength) {
            flRotation = static_cast<float>(
                atan2(static_cast<double>(-vDelta.y), static_cast<double>(vDelta.x)) +
                kRotationBias);
        }
        const float flScaleY = flLength * kLengthToScaleY;

        assert(record.nColor == 0 || record.nColor == 1);
        const unsigned int nAlpha = record.nColor == kPlayColorSide1 ? nAlphaColor1 : nAlphaColor0;
        CreateSprite(record.nColor, &vStart, nAlpha, flRotation, flScaleY);
    }

    m_pSprite->SetSpriteCount(m_nSpriteCount);
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
