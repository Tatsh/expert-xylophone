//
//  damage_effect_layer.mm
//  REFLEC BEAT plus
//
//  The bounds-damage effect layer (DamageEffectLayer). Reconstructed from Ghidra project rb458,
//  program rb458. @ghidraAddress values are relative to the program image base.
//

#include "damage_effect_layer.h"

#include <cassert>

#import "RBUserSettingData.h"
#include "bg_layer.h"
#include "neRender.h"
#include "neSpriteInstancing.h"
#include "neTexture.h"
#include "s_vector2.h"
#include "sprite_uv_table.h"

// The score-gauge burst atlas UV table (a distinct atlas from the shared sprite UV table); the
// damage sprites take their UV size from it.
extern const SpriteUvEntry g_aScoreGaugeUvTable[]; // @ghidraAddress 0x2ef668

namespace {
// The effect atlas for each bounds-effect style (default, limelight, colette).
constexpr const char *kEffectTextureNames[] = {
    "00_texture/gm_eff", "00_texture/gm_eff_limelight", "00_texture/gm_eff_colette"};
constexpr int kEffectStyleCount = 3;

// The lane display value and effect size the constructor seeds.
constexpr float kInitialLaneValue = 1.0f;
constexpr float kInitialEffectSize = 1.0f;

// The additive blend mode the effect batch draws with.
constexpr int kAdditiveBlendMode = 1;

// The number of sprite colours/types a damage sprite may take.
constexpr int kSpriteTypeMax = 2;

// The fixed anchor and quad size, in points, every damage sprite draws with (@ghidraAddress
// 0x30bf28 anchor, 0x30bf2c size), the atlas cell UV size (0x30bf30 U; V is an inline constant), and
// the Colette-theme vertical nudge (0x307a3c above, 0x30bf24 below).
constexpr float kSpriteAnchor = 84.0f;
constexpr float kSpriteSize = 168.0f;
constexpr float kSpriteUvSizeU = 0.08203125f;
constexpr float kSpriteUvSizeV = 0.1640625f;
constexpr float kColetteOffsetAbove = 42.0f;
constexpr float kColetteOffsetBelow = -42.0f;

// The half-turn rotation a mirrored (negative-y) sprite takes, in radians (@ghidraAddress 0x2fe894).
constexpr float kMirrorRotation = 3.1415927f;

// Scales a lane's unit-interval alpha to the byte range (@ghidraAddress 0x2eed00).
constexpr float kAlphaByteScale = 255.0f;

// The Colette theme id.
constexpr int kThemaColette = 2;
} // namespace

// The process-wide damage-effect layer, created lazily by shared().
static DamageEffectLayer *g_pDamageEffectLayer = nullptr; // @ghidraAddress 0x3de810

/** @ghidraAddress 0x173f7c */
DamageEffectLayer *DamageEffectLayer::shared() {
    if (g_pDamageEffectLayer == nullptr) {
        g_pDamageEffectLayer = new DamageEffectLayer();
    }
    return g_pDamageEffectLayer;
}

/** @ghidraAddress 0x173f10 */
DamageEffectLayer::DamageEffectLayer() {
    // The base constructor and the member initialisers clear the header and pooled records; the
    // lane values and effect size seed to one.
    for (float &flValue : m_aLaneValue) {
        flValue = kInitialLaneValue;
    }
    m_flEffectSize = kInitialEffectSize;
}

/** @ghidraAddress 0x173fcc */
void DamageEffectLayer::InitializeSprites() {
    if (m_bLoaded) {
        return;
    }

    m_nStyle = [RBUserSettingData sharedInstance].boundsEffectStyle;
    ne::C_RENDER *pParent = BgLayer::GetBackgroundLayer()->GetBackgroundRenderObject();
    // Styles 0..2 pick a themed atlas; any other style keeps the current texture.
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
    // Styles 0..2 pick a themed atlas; any other style keeps the current texture.
    if (m_nStyle >= 0 &&
        m_nStyle < static_cast<int>(sizeof(kEffectTextureNames) / sizeof(kEffectTextureNames[0]))) {
        m_pTexture = ne::C_TEXTURE::FindOrLoadCached(kEffectTextureNames[m_nStyle]);
    }
    m_pSprite->SetRefCountedMember(m_pTexture);
}

/** @ghidraAddress 0x174190 */
void DamageEffectLayer::CreateBoundsDamage(int nColor, float flPosX, float flPosY) {
    assert(nColor >= 0 && nColor < kLaneCount);
    // Claim the first inactive pooled record; a full pool drops the effect.
    for (EffectRecord &effect : m_aEffects) {
        if (!effect.bActive) {
            effect.nColor = nColor;
            effect.bActive = true;
            effect.flPosX = flPosX;
            effect.flPosY = flPosY;
            effect.nTimer = 0;
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

    // The Colette theme nudges the sprite vertically (down normally, up when already below); every
    // other theme uses the plain position.
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

    // A sprite below the field (negative y) is mirrored a half-turn and uses the second lane's alpha.
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
