#include "bounds_effect_layer.h"

#include <cassert>

#import "RBUserSettingData.h"
#include "bg_layer.h"
#include "neRender.h"
#include "neSpriteInstancing.h"
#include "neTexture.h"
#include "s_vector2.h"

namespace {
constexpr float kInitialEffectSize = 1.0f;

constexpr unsigned char kLaneLightOn = 0xff;

// @ghidraAddress 0x30bf28 anchor, 0x30bf2c size
constexpr float kEffectAnchor = 84.0f;
constexpr float kEffectSize = 168.0f;

// @ghidraAddress 0x30c0c0
constexpr float kEffectUvSizeU = 0.041015625f;
constexpr float kEffectUvSizeV = 0.1640625f;

// @ghidraAddress 0x2fe894
constexpr float kMirrorRotation = 3.1415927f;

constexpr const char *kEffectTextureNames[] = {
    "00_texture/gm_eff", "00_texture/gm_eff_limelight", "00_texture/gm_eff_colette"};
constexpr int kEffectStyleCount = 3;

constexpr int kSpriteCapacity = 0x5c;
constexpr int kAdditiveBlendMode = 1;

// @ghidraAddress 0x2feff4 lifetime, 0x30bf20 frame step
constexpr float kEffectLifetime = 500.0f;
constexpr float kEffectFrameStep = 20.833334f;
constexpr int kEffectFrameCount = 24;

constexpr int kEffectFrameCountByStyle[] = {0x14, 0x17, 0x16};

// @ghidraAddress 0x30c0d0
// The ROM block holds only 46 entries; bank 1's last two slots are zeroed here to keep the flat
// index in range.
constexpr S_VECTOR2 kEffectUvOrigins[BoundsEffectLayer::kBankCount][kEffectFrameCount] = {
    {
        {0.0f, 0.6640625f},        {0.041992188f, 0.6640625f}, {0.083984375f, 0.6640625f},
        {0.12597656f, 0.6640625f}, {0.16796875f, 0.6640625f},  {0.20996094f, 0.6640625f},
        {0.25195312f, 0.6640625f}, {0.2939453f, 0.6640625f},   {0.3359375f, 0.6640625f},
        {0.3779297f, 0.6640625f},  {0.41992188f, 0.6640625f},  {0.46191406f, 0.6640625f},
        {0.50390625f, 0.6640625f}, {0.54589844f, 0.6640625f},  {0.5878906f, 0.6640625f},
        {0.6298828f, 0.6640625f},  {0.671875f, 0.6640625f},    {0.7138672f, 0.6640625f},
        {0.7558594f, 0.6640625f},  {0.79785156f, 0.6640625f},  {0.83984375f, 0.6640625f},
        {0.88183594f, 0.6640625f}, {0.9238281f, 0.6640625f},   {0.0f, 0.8300781f},
    },
    {
        {0.041992188f, 0.8300781f},
        {0.083984375f, 0.8300781f},
        {0.12597656f, 0.8300781f},
        {0.16796875f, 0.8300781f},
        {0.20996094f, 0.8300781f},
        {0.25195312f, 0.8300781f},
        {0.2939453f, 0.8300781f},
        {0.3359375f, 0.8300781f},
        {0.3779297f, 0.8300781f},
        {0.41992188f, 0.8300781f},
        {0.46191406f, 0.8300781f},
        {0.50390625f, 0.8300781f},
        {0.54589844f, 0.8300781f},
        {0.5878906f, 0.8300781f},
        {0.6298828f, 0.8300781f},
        {0.671875f, 0.8300781f},
        {0.7138672f, 0.8300781f},
        {0.7558594f, 0.8300781f},
        {0.79785156f, 0.8300781f},
        {0.83984375f, 0.8300781f},
        {0.88183594f, 0.8300781f},
        {0.9238281f, 0.8300781f},
        {0.0f, 0.0f},
        {0.0f, 0.0f},
    },
};
} // namespace

static BoundsEffectLayer *g_pBoundsEffectLayer = nullptr; // @ghidraAddress 0x3de9b0

/** @ghidraAddress 0x17528c */
BoundsEffectLayer *BoundsEffectLayer::shared() {
    if (g_pBoundsEffectLayer == nullptr) {
        g_pBoundsEffectLayer = new BoundsEffectLayer();
    }
    return g_pBoundsEffectLayer;
}

/** @ghidraAddress 0x175210 */
BoundsEffectLayer::BoundsEffectLayer() {
    m_nLaneLightAlpha0 = kLaneLightOn;
    m_nLaneLightAlpha1 = kLaneLightOn;
    m_flEffectSize = kInitialEffectSize;
}

/** @ghidraAddress 0x1752dc */
void BoundsEffectLayer::InitializeSprites() {
    if (m_bLoaded) {
        return;
    }

    m_nStyle = [RBUserSettingData sharedInstance].boundsEffectStyle;
    ne::C_RENDER *pParent = BgLayer::GetBackgroundLayer()->GetBackgroundRenderObject();
    if (m_nStyle >= 0 && m_nStyle < kEffectStyleCount) {
        m_pTexture = ne::C_TEXTURE::FindOrLoadCached(kEffectTextureNames[m_nStyle]);
    }
    m_nCapacity = kSpriteCapacity;
    m_pSprite = ne::CreateWorldSpriteBatch(kSpriteCapacity);
    pParent->AttachChild(m_pSprite);
    m_pSprite->SetVisible(true);
    m_pSprite->SetRefCountedMember(m_pTexture);
    m_pSprite->SetSpriteCount(0);
    m_pSprite->SetBlendMode(kAdditiveBlendMode);

    m_bLoaded = true;
}

/** @ghidraAddress 0x1753e4 */
void BoundsEffectLayer::SetStyle() {
    RefreshThema();
    m_nStyle = [RBUserSettingData sharedInstance].boundsEffectStyle;
    if (m_nStyle >= 0 && m_nStyle < kEffectStyleCount) {
        m_pTexture = ne::C_TEXTURE::FindOrLoadCached(kEffectTextureNames[m_nStyle]);
    }
    m_pSprite->SetRefCountedMember(m_pTexture);
}

/** @ghidraAddress 0x1754cc */
void BoundsEffectLayer::CreateBoundsEffect(unsigned int nColor, float flPosX, float flPosY) {
    if (!m_bLoaded) {
        InitializeSprites();
    }
    assert(static_cast<int>(nColor) >= 0 && static_cast<int>(nColor) < kBankCount);
    // A full bank silently drops the effect.
    for (EffectRecord &effect : m_aEffects[nColor]) {
        if (!effect.bActive) {
            effect.bActive = true;
            effect.flTimer = 0.0f;
            effect.flPosX = flPosX;
            effect.flPosY = flPosY;
            return;
        }
    }
}

/** @ghidraAddress 0x17559c */
void BoundsEffectLayer::Process(float flDelta) {
    m_nSpriteCount = 0;

    for (int nBank = 0; nBank < kBankCount; ++nBank) {
        const unsigned char nLaneAlpha = nBank == 1 ? m_nLaneLightAlpha0 : m_nLaneLightAlpha1;
        for (EffectRecord &effect : m_aEffects[nBank]) {
            if (!effect.bActive) {
                continue;
            }
            effect.flTimer += flDelta;
            if (effect.flTimer > kEffectLifetime) {
                effect.bActive = false;
                continue;
            }
            if (nLaneAlpha == 0) {
                continue;
            }

            int nFrame = static_cast<int>(effect.flTimer / kEffectFrameStep);
            if (nFrame < 0) {
                nFrame = 0;
            } else if (nFrame >= kEffectFrameCount) {
                nFrame = kEffectFrameCount - 1;
            }

            // An unknown style, which the sprite build never sets, draws nothing.
            if (m_nStyle >= 0 && m_nStyle < kEffectStyleCount &&
                nFrame < kEffectFrameCountByStyle[m_nStyle]) {
                const S_VECTOR2 position{effect.flPosX, effect.flPosY};
                SetBoundsEffectSprite(&position, &kEffectUvOrigins[nBank][nFrame], nLaneAlpha);
            }
        }
    }

    m_pSprite->SetSpriteCount(m_nSpriteCount);
}

/** @ghidraAddress 0x1754c4 */
void BoundsEffectLayer::SetEffectSize(float flSize) {
    m_flEffectSize = flSize;
}

/** @ghidraAddress 0x1754a8 */
void BoundsEffectLayer::SetLaneLightFlag(float flValue, int nLane) {
    // The binary truncates the float to the alpha byte the lane's effects draw at.
    const auto nAlpha = static_cast<unsigned char>(static_cast<int>(flValue));
    if (nLane == 1) {
        m_nLaneLightAlpha0 = nAlpha;
    } else {
        m_nLaneLightAlpha1 = nAlpha;
    }
}

/** @ghidraAddress 0x1758f0 */
void BoundsEffectLayer::SetBoundsEffectSprite(const S_VECTOR2 *pPosition,
                                              const S_VECTOR2 *pUvOrigin,
                                              int nAlpha) {
    const float flScale = m_flEffectSize;
    const int nIndex = m_nSpriteCount;

    m_pSprite->SetSpritePosition(nIndex, *pPosition);
    m_pSprite->SetSpriteAnchor(nIndex, S_VECTOR2{kEffectAnchor, kEffectAnchor});
    // Faithful: the binary reuses the anchor's 84 as the width at 0x175954, so the sprite is half
    // as wide as it is tall.
    m_pSprite->SetSpriteSize(nIndex, S_VECTOR2{kEffectAnchor, kEffectSize});
    m_pSprite->SetSpriteUvOrigin(nIndex, *pUvOrigin);
    m_pSprite->SetSpriteUvSize(nIndex, S_VECTOR2{kEffectUvSizeU, kEffectUvSizeV});
    m_pSprite->SetSpriteScale(nIndex, flScale, flScale);
    m_pSprite->SetSpriteRotation(nIndex, pPosition->x < 0.0f ? kMirrorRotation : 0.0f);
    m_pSprite->SetSpriteColor(nIndex, 0xff, 0xff, 0xff, static_cast<unsigned int>(nAlpha));
    ++m_nSpriteCount;
}
