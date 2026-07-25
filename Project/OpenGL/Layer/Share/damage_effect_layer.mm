//
//  damage_effect_layer.mm
//  REFLEC BEAT plus
//
//  The bounds-damage effect layer (DamageEffectLayer). Reconstructed from Ghidra project rb458,
//  program rb458. @ghidraAddress values are relative to the program image base.
//

#include "damage_effect_layer.h"

#import "RBUserSettingData.h"
#include "neSpriteInstancing.h"
#include "neTexture.h"

namespace {
// The effect atlas for each bounds-effect style (default, limelight, colette).
constexpr const char *kEffectTextureNames[] = {
    "00_texture/gm_eff", "00_texture/gm_eff_limelight", "00_texture/gm_eff_colette"};
} // namespace

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
