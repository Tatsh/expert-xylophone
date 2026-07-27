//
//  bounds_effect_layer.mm
//  REFLEC BEAT plus
//
//  The play-field bounds effect layer (BoundsEffectLayer). Reconstructed from Ghidra project rb458,
//  program rb458. @ghidraAddress values are relative to the program image base.
//

#include "bounds_effect_layer.h"

#include <cassert>

#import "RBUserSettingData.h"
#include "bg_layer.h"
#include "neRender.h"
#include "neSpriteInstancing.h"
#include "neTexture.h"

namespace {
// The effect size the constructor seeds.
constexpr float kInitialEffectSize = 1.0f;

// The effect atlas for each bounds-effect style (default, limelight, colette).
constexpr const char *kEffectTextureNames[] = {
    "00_texture/gm_eff", "00_texture/gm_eff_limelight", "00_texture/gm_eff_colette"};
constexpr int kEffectStyleCount = 3;

// The sprite-batch capacity and its additive blend mode.
constexpr int kSpriteCapacity = 0x5c;
constexpr int kAdditiveBlendMode = 1;
} // namespace

// The process-wide bounds-effect layer, created lazily by shared().
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
    // The base constructor and member initialisers clear the layer; both lane-light flags start on
    // and the effect size seeds to one.
    m_bLaneLight0 = true;
    m_bLaneLight1 = true;
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
    // Styles 0..2 pick a themed atlas; any other style keeps the current texture.
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
    // Claim the first inactive record in the colour's bank; a full bank drops the effect.
    for (EffectRecord &effect : m_aEffects[nColor]) {
        if (!effect.bActive) {
            effect.bActive = true;
            effect.nTimer = 0;
            effect.flPosX = flPosX;
            effect.flPosY = flPosY;
            return;
        }
    }
}

/** @ghidraAddress 0x1754c4 */
void BoundsEffectLayer::SetEffectSize(float flSize) {
    m_flEffectSize = flSize;
}

/** @ghidraAddress 0x1754a8 */
void BoundsEffectLayer::SetLaneLightFlag(float flValue, int nLane) {
    // The binary truncates the float to an integer byte; the callers only ever pass 0.0 or 1.0.
    const bool bFlag = static_cast<int>(flValue) != 0;
    if (nLane == 1) {
        m_bLaneLight0 = bFlag;
    } else {
        m_bLaneLight1 = bFlag;
    }
}
