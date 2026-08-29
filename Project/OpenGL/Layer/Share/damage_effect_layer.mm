#include "damage_effect_layer.h"

#include <cassert>

#import "RBUserSettingData.h"
#include "bg_layer.h"
#include "neRender.h"
#include "neSpriteInstancing.h"
#include "neTexture.h"
#include "s_vector2.h"
#include "sprite_uv_table.h"

extern const SpriteUvEntry g_aScoreGaugeUvTable[]; // @ghidraAddress 0x2ef668

namespace {
constexpr const char *kEffectTextureNames[] = {
    "00_texture/gm_eff", "00_texture/gm_eff_limelight", "00_texture/gm_eff_colette"};
constexpr int kEffectStyleCount = 3;

constexpr float kInitialLaneValue = 1.0f;
constexpr float kInitialEffectSize = 1.0f;

constexpr int kAdditiveBlendMode = 1;

constexpr int kSpriteTypeMax = 2;

// @ghidraAddress 0x30bf28
constexpr float kSpriteAnchor = 84.0f;
// @ghidraAddress 0x30bf2c
constexpr float kSpriteSize = 168.0f;
// @ghidraAddress 0x30bf30
constexpr float kSpriteUvSizeU = 0.08203125f;
constexpr float kSpriteUvSizeV = 0.1640625f;
// @ghidraAddress 0x307a3c
constexpr float kColetteOffsetAbove = 42.0f;
// @ghidraAddress 0x30bf24
constexpr float kColetteOffsetBelow = -42.0f;

// @ghidraAddress 0x2fe894
constexpr float kMirrorRotation = 3.1415927f;

// @ghidraAddress 0x2eed00
constexpr float kAlphaByteScale = 255.0f;

constexpr int kThemaColette = 2;

// @ghidraAddress 0x2feff4
constexpr float kEffectLifetime = 500.0f;
// @ghidraAddress 0x30bf20
constexpr float kFrameDivisor = 20.8333f;
constexpr int kAnimFrameCount = 24;
constexpr int kLastAnimFrame = kAnimFrameCount - 1;

// @ghidraAddress 0x30bf40
constexpr S_VECTOR2 kBoundsDamageUv[] = {
    {0.0f, 0.0f},           {0.0830078f, 0.0f},      {0.166016f, 0.0f},      {0.249023f, 0.0f},
    {0.332031f, 0.0f},      {0.415039f, 0.0f},       {0.498047f, 0.0f},      {0.581055f, 0.0f},
    {0.664062f, 0.0f},      {0.74707f, 0.0f},        {0.830078f, 0.0f},      {0.913086f, 0.0f},
    {0.0f, 0.166016f},      {0.0830078f, 0.166016f}, {0.166016f, 0.166016f}, {0.249023f, 0.166016f},
    {0.332031f, 0.166016f}, {0.415039f, 0.166016f},  {0.498047f, 0.166016f}, {0.581055f, 0.166016f},
    {0.664062f, 0.166016f}, {0.74707f, 0.166016f},   {0.830078f, 0.166016f}, {0.913086f, 0.166016f},
    {0.0f, 0.332031f},      {0.0830078f, 0.332031f}, {0.166016f, 0.332031f}, {0.249023f, 0.332031f},
    {0.332031f, 0.332031f}, {0.415039f, 0.332031f},  {0.498047f, 0.332031f}, {0.581055f, 0.332031f},
    {0.664062f, 0.332031f}, {0.74707f, 0.332031f},   {0.830078f, 0.332031f}, {0.913086f, 0.332031f},
    {0.0f, 0.498047f},      {0.0830078f, 0.498047f}, {0.166016f, 0.498047f}, {0.249023f, 0.498047f},
    {0.332031f, 0.498047f}, {0.415039f, 0.498047f},  {0.498047f, 0.498047f}, {0.581055f, 0.498047f},
    {0.664062f, 0.498047f}, {0.74707f, 0.498047f},   {0.830078f, 0.498047f}, {0.913086f, 0.498047f},
};
} // namespace

static DamageEffectLayer *g_pDamageEffectLayer = nullptr; // @ghidraAddress 0x3de810

/** @ghidraAddress 0x173f7c */
DamageEffectLayer *DamageEffectLayer::shared() {
    if (g_pDamageEffectLayer == nullptr) {
        g_pDamageEffectLayer = new DamageEffectLayer();
    }
    return g_pDamageEffectLayer;
}

constexpr int kSpriteBatchCapacity = 128;

/** @ghidraAddress 0x173f10 */
DamageEffectLayer::DamageEffectLayer() {
    for (float &flValue : m_aLaneValue) {
        flValue = kInitialLaneValue;
    }
    m_flEffectSize = kInitialEffectSize;
    // Without this the batch has capacity zero and the first effect trips the sprite-index
    // assertion (the binary adds 0x80 to the freshly zeroed field at 0x173f6c).
    m_nCapacity = kSpriteBatchCapacity;
}

/** @ghidraAddress 0x173fcc */
void DamageEffectLayer::InitializeSprites() {
    if (m_bLoaded) {
        return;
    }

    m_nStyle = [RBUserSettingData sharedInstance].boundsEffectStyle;
    ne::C_RENDER *pParent = BgLayer::GetBackgroundLayer()->GetBackgroundRenderObject();
    if (m_nStyle >= 0 && m_nStyle < kEffectStyleCount) {
        m_pTexture = ne::C_TEXTURE::FindOrLoadCached(kEffectTextureNames[m_nStyle]);
    }
    m_pSprite = ne::CreateWorldSpriteBatch(static_cast<unsigned int>(m_nCapacity));
    pParent->AttachChild(m_pSprite);
    m_pSprite->SetVisible(true);
    m_pSprite->SetRefCountedMember(m_pTexture);
    m_pSprite->SetSpriteCount(0);
    m_pSprite->SetBlendMode(kAdditiveBlendMode);

    m_bLoaded = true;
}

/** @ghidraAddress 0x1740cc */
void DamageEffectLayer::SetBoundsDamageStyle() {
    RefreshThema();
    m_nStyle = [RBUserSettingData sharedInstance].boundsEffectStyle;
    if (m_nStyle >= 0 &&
        m_nStyle < static_cast<int>(sizeof(kEffectTextureNames) / sizeof(kEffectTextureNames[0]))) {
        m_pTexture = ne::C_TEXTURE::FindOrLoadCached(kEffectTextureNames[m_nStyle]);
    }
    m_pSprite->SetRefCountedMember(m_pTexture);
}

/** @ghidraAddress 0x174190 */
void DamageEffectLayer::CreateBoundsDamage(int nColor, float flPosX, float flPosY) {
    assert(nColor >= 0 && nColor < kLaneCount);
    // A full pool silently drops the effect.
    for (EffectRecord &effect : m_aEffects) {
        if (!effect.bActive) {
            effect.nColor = nColor;
            effect.bActive = true;
            effect.flPosX = flPosX;
            effect.flPosY = flPosY;
            effect.flTimer = 0.0f;
            return;
        }
    }
}

/** @ghidraAddress 0x174224 */
void DamageEffectLayer::SetLaneValue(int nLane, float flValue) {
    m_aLaneValue[nLane != 0 ? 1 : 0] = flValue;
}

/** @ghidraAddress 0x174238 */
void DamageEffectLayer::SetEffectSize(float flSize) {
    m_flEffectSize = flSize;
}

/** @ghidraAddress 0x174538 */
void DamageEffectLayer::EmitSprite(int nColor, const S_VECTOR2 *pUv, const S_VECTOR2 *pPosition) {
    assert(nColor >= 0 && nColor < kSpriteTypeMax);

    const float flScale = m_flEffectSize;
    ne::C_SPRITE_INSTANCING_2D *pBatch = m_pSprite;
    const int nIndex = m_nSpriteCount;

    if ([RBUserSettingData sharedInstance].thema == kThemaColette) {
        const float flOffsetY = pPosition->y < 0.0f ? kColetteOffsetBelow : kColetteOffsetAbove;
        pBatch->SetSpritePositionXY(nIndex, pPosition->x, pPosition->y + flOffsetY);
    } else {
        pBatch->SetSpritePosition(nIndex, *pPosition);
    }

    pBatch->SetSpriteAnchor(nIndex, S_VECTOR2{kSpriteAnchor, kSpriteAnchor});
    pBatch->SetSpriteSize(nIndex, S_VECTOR2{kSpriteSize, kSpriteSize});
    pBatch->SetSpriteUvOrigin(nIndex, *pUv);
    pBatch->SetSpriteUvSize(nIndex, S_VECTOR2{kSpriteUvSizeU, kSpriteUvSizeV});
    pBatch->SetSpriteScale(nIndex, flScale, flScale);

    float flAlphaScale;
    if (pPosition->y < 0.0f) {
        pBatch->SetSpriteRotation(nIndex, kMirrorRotation);
        flAlphaScale = m_aLaneValue[1];
    } else {
        pBatch->SetSpriteRotation(nIndex, 0.0f);
        flAlphaScale = m_aLaneValue[0];
    }
    pBatch->SetSpriteColor(
        nIndex, 0xff, 0xff, 0xff, static_cast<unsigned int>(flAlphaScale * kAlphaByteScale));
    ++m_nSpriteCount;
}

/** @ghidraAddress 0x174240 */
void DamageEffectLayer::Process(float flDelta) {
    m_nSpriteCount = 0;
    for (EffectRecord &effect : m_aEffects) {
        if (!effect.bActive) {
            continue;
        }
        effect.flTimer += flDelta;
        if (effect.flTimer >= kEffectLifetime) {
            effect.bActive = false;
            continue;
        }
        int nFrame = static_cast<int>(effect.flTimer / kFrameDivisor);
        if (nFrame > kLastAnimFrame) {
            nFrame = kLastAnimFrame;
        }
        const S_VECTOR2 &uv = kBoundsDamageUv[effect.nColor * kAnimFrameCount + nFrame];
        const S_VECTOR2 position{effect.flPosX, effect.flPosY};
        EmitSprite(effect.nColor, &uv, &position);
    }
    m_pSprite->SetSpriteCount(m_nSpriteCount);
}
