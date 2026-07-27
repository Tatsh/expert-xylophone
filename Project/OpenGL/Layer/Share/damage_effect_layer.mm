//
//  damage_effect_layer.mm
//  REFLEC BEAT plus
//
//  The bounds-damage effect layer (DamageEffectLayer). Reconstructed from Ghidra project rb458,
//  program rb458. @ghidraAddress values are relative to the program image base.
//

#include "damage_effect_layer.h"

#import "RBUserSettingData.h"
#include "bg_layer.h"
#include "neRender.h"
#include "neSpriteInstancing.h"
#include "neTexture.h"

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

/** @ghidraAddress 0x174224 */
void DamageEffectLayer::SetLaneValue(int nLane, float flValue) {
    m_aLaneValue[nLane != 0 ? 1 : 0] = flValue;
}

/** @ghidraAddress 0x174238 */
void DamageEffectLayer::SetEffectSize(float flSize) {
    m_flEffectSize = flSize;
}
