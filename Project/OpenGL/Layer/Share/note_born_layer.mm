#include "note_born_layer.h"

#include <cassert>

#include "bg_layer.h"
#include "curve.h"
#include "neRender.h"
#include "neSpriteInstancing.h"
#include "neTexture.h"
#include "sprite_uv_table.h"

extern const SpriteUvEntry g_aScoreGaugeUvTable[]; // @ghidraAddress 0x2ef668

namespace {
constexpr const char *kAtlasTextureName = "00_texture/gm_parts1";

constexpr float kInitialScale = 1.0f;

constexpr int kAdditiveBlendMode = 1;

constexpr int kTexParamOne = 1;
constexpr int kTexParamValue = 1;

// The anchor is half the sprite size. @ghidraAddress 0x30e780
constexpr float kBurstAnchor = 31.0f;
constexpr float kBurstSize = 62.0f;

constexpr int kSpriteBatchCapacity = 256;

constexpr unsigned int kColorMax = 255;

// @ghidraAddress 0x30e7b0
constexpr int kBurstUvRow[] = {0x49, 0x4a};

constexpr int kSecondPlayerColor = 1;

// @ghidraAddress 0x2eed00
constexpr float kAlphaByteScale = 255.0f;

// {time, scale} pairs. @ghidraAddress 0x30e788
constexpr float kBurstScaleCurve[] = {0.0f, 1.0f, 666.66669f, 1.4f};
constexpr int kBurstScaleCurvePairs = 2;

// {time, alpha} pairs; the burst deactivates when the alpha reaches zero.
// @ghidraAddress 0x30e798
constexpr float kBurstAlphaCurve[] = {0.0f, 1.0f, 133.33333f, 1.0f, 666.66669f, 0.0f};
constexpr int kBurstAlphaCurvePairs = 3;
} // namespace

static NoteBornLayer *g_pNoteBornLayer = nullptr; // @ghidraAddress 0x3def40

/** @ghidraAddress 0x18546c */
NoteBornLayer *NoteBornLayer::shared() {
    if (g_pNoteBornLayer == nullptr) {
        g_pNoteBornLayer = new NoteBornLayer();
    }
    return g_pNoteBornLayer;
}

/** @ghidraAddress 0x185408 */
NoteBornLayer::NoteBornLayer() {
    m_aScale[0] = kInitialScale;
    m_aScale[1] = kInitialScale;
    // Without this the batch is created empty and the first burst trips SetSpritePosition.
    m_nCapacity = kSpriteBatchCapacity;
}

/** @ghidraAddress 0x185564 */
void NoteBornLayer::Create(int nColor, float flX, float flY) {
    assert(nColor >= 0 && nColor < kPlayerColorMax);

    // A full pool silently drops the effect.
    for (EffectRecord &record : m_aEffects) {
        if (!record.bActive) {
            record.nColorRow = nColor == kSecondPlayerColor;
            record.bActive = true;
            record.position = S_VECTOR2{flX, flY};
            record.flTimer = 0.0f;
            return;
        }
    }
}

/** @ghidraAddress 0x1856e0 */
void NoteBornLayer::EmitBurstSprite(unsigned int nColorRow,
                                    float flScale,
                                    const S_VECTOR2 &position,
                                    int nAlpha) {
    const SpriteUvEntry &uv = g_aScoreGaugeUvTable[kBurstUvRow[nColorRow]];

    m_pSprite->SetSpritePosition(m_nSlotCount, position);
    m_pSprite->SetSpriteAnchor(m_nSlotCount, S_VECTOR2{kBurstAnchor, kBurstAnchor});
    m_pSprite->SetSpriteSize(m_nSlotCount, S_VECTOR2{kBurstSize, kBurstSize});
    m_pSprite->SetSpriteUvOrigin(m_nSlotCount, S_VECTOR2{uv.flOriginU, uv.flOriginV});
    m_pSprite->SetSpriteUvSize(m_nSlotCount, S_VECTOR2{uv.flSizeU, uv.flSizeV});
    m_pSprite->SetSpriteScale(m_nSlotCount, flScale, flScale);
    m_pSprite->SetSpriteColor(
        m_nSlotCount, kColorMax, kColorMax, kColorMax, static_cast<unsigned int>(nAlpha));

    ++m_nSlotCount;
}

/** @ghidraAddress 0x1854bc */
void NoteBornLayer::LoadSprites() {
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
        m_pSprite->SetTexParam(kTexParamOne, kTexParamValue);
        m_pSprite->SetTexParam(0, kTexParamValue);
    }

    m_bLoaded = true;
}

/** @ghidraAddress 0x185600 */
void NoteBornLayer::RenderScoreGaugeEffects(float flDelta) {
    m_nSlotCount = 0;
    for (auto &record : m_aEffects) {
        if (!record.bActive) {
            continue;
        }
        record.flTimer += flDelta;
        const float flScale =
            CalculateCurveInterpolation(kBurstScaleCurve, kBurstScaleCurvePairs, record.flTimer);
        const float flAlpha =
            CalculateCurveInterpolation(kBurstAlphaCurve, kBurstAlphaCurvePairs, record.flTimer);
        if (flAlpha <= 0.0f) {
            record.bActive = false;
            continue;
        }
        EmitBurstSprite(record.nColorRow,
                        flScale,
                        record.position,
                        static_cast<int>(flAlpha * kAlphaByteScale));
    }
    m_pSprite->SetSpriteCount(m_nSlotCount);
}
