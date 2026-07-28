//
//  explosion_effect_layer.mm
//  REFLEC BEAT plus
//
//  The note-burst explosion effect layer (ExplosionEffectLayer). Reconstructed from Ghidra project
//  rb458, program rb458. @ghidraAddress values are relative to the program image base.
//

#include "explosion_effect_layer.h"

#include <cassert>

#include "bg_layer.h"
#include "neRender.h"
#include "neSpriteInstancing.h"
#include "neTexture.h"
#include "s_vector2.h"

// The process-wide explosion effect layer, created lazily by shared().
static ExplosionEffectLayer *g_pExplosionEffectLayer = nullptr; // @ghidraAddress 0x3deb50

namespace {

// The scale converting a unit-interval alpha to the byte range (@ghidraAddress 0x2eed00).
constexpr float kAlphaByteScale = 255.0f;

// The fixed anchor and size, in points, every explosion sprite draws with (@ghidraAddress 0x30bf28
// anchor, 0x30bf2c size).
constexpr float kEffectAnchor = 84.0f;
constexpr float kEffectSize = 168.0f;

// The explosion atlas cell's UV size (@ghidraAddress 0x30bf30 U; the V is an inline constant).
constexpr float kEffectUvSizeU = 0.08203125f;
constexpr float kEffectUvSizeV = 0.1640625f;

// The per-type burst texture names, interleaved red then blue, indexed by (colour + type * 2)
// (@ghidraAddress 0x3ce608).
constexpr const char *kEffectTextureNames[] = {
    "00_texture/gm_red_classic",    "00_texture/gm_blue_classic",   "00_texture/gm_red_limelight",
    "00_texture/gm_blue_limelight", "00_texture/gm_red_flame",      "00_texture/gm_blue_flame",
    "00_texture/gm_red_ice",        "00_texture/gm_blue_ice",       "00_texture/gm_red_plasma",
    "00_texture/gm_blue_plasma",    "00_texture/gm_red_tornado",    "00_texture/gm_blue_tornado",
    "00_texture/gm_red_fireworks",  "00_texture/gm_blue_fireworks", "00_texture/gm_red_star",
    "00_texture/gm_blue_star",      "00_texture/gm_red_quavre",     "00_texture/gm_blue_quavre",
    "00_texture/gm_red_heart",      "00_texture/gm_blue_heart",     "00_texture/gm_red_rose",
    "00_texture/gm_blue_rose",      "00_texture/gm_red_copious",    "00_texture/gm_blue_copious",
    "00_texture/gm_red_colette",    "00_texture/gm_blue_colette",   "00_texture/gm_red_snow",
    "00_texture/gm_blue_snow",      "00_texture/gm_red_tentei",     "00_texture/gm_blue_tentei",
    "00_texture/gm_red_flower",     "00_texture/gm_blue_flower",    "00_texture/gm_red_maple",
    "00_texture/gm_blue_maple",     "00_texture/gm_red_iidx",       "00_texture/gm_blue_iidx",
    "00_texture/gm_red_popn",       "00_texture/gm_blue_popn"};

} // namespace

/** @ghidraAddress 0x176e18 */
ExplosionEffectLayer::ExplosionEffectLayer() {
    m_bBuilt = false;
    for (int nBank = 0; nBank < kBankCount; ++nBank) {
        m_apSprites[nBank] = nullptr;
        m_aSpriteCapacity[nBank] = 0;
        for (int nSlot = 0; nSlot < kSlotsPerBank; ++nSlot) {
            m_aBanks[nBank][nSlot] = EffectEntry{};
        }
    }
}

/** @ghidraAddress 0x176ed0 */
ExplosionEffectLayer *ExplosionEffectLayer::shared() {
    if (g_pExplosionEffectLayer == nullptr) {
        g_pExplosionEffectLayer = new ExplosionEffectLayer();
    }
    return g_pExplosionEffectLayer;
}

/** @ghidraAddress 0x176f20 */
void ExplosionEffectLayer::InitializeSprites() {
    if (m_bBuilt) {
        return;
    }

    // The burst sprites hang beneath the shared background layer's render object.
    BgLayer *pBackgroundLayer = BgLayer::GetBackgroundLayer();
    ne::C_RENDER *pParent = pBackgroundLayer->GetBackgroundRenderObject();

    for (int nBank = 0; nBank < kBankCount; ++nBank) {
        m_aSpriteCapacity[nBank] = kSpriteCapacity;
        ne::C_SPRITE_INSTANCING_2D *pSprite = ne::CreateWorldSpriteBatch(kSpriteCapacity);
        m_apSprites[nBank] = pSprite;
        pParent->AttachChild(pSprite);
        pSprite->SetVisible(true);
        pSprite->SetSpriteCount(0);
        pSprite->SetBlendMode(1);
    }

    m_bBuilt = true;
}

/** @ghidraAddress 0x177138 */
void ExplosionEffectLayer::CreateExplosionEffect(unsigned int nColor,
                                                 int nJudge,
                                                 float flPosX,
                                                 float flPosY) {
    if (!m_bBuilt) {
        InitializeSprites();
    }
    assert(static_cast<int>(nColor) >= 0 && nColor < kBankCount);
    assert(nJudge >= 0 && nJudge < 3);

    // Fill the first inactive slot in the colour bank.
    for (int nSlot = 0; nSlot < kSlotsPerBank; ++nSlot) {
        EffectEntry &entry = m_aBanks[nColor][nSlot];
        if (!entry.bActive) {
            entry.nTimer = 0;
            entry.nJudge = nJudge;
            entry.bActive = true;
            entry.flPosX = flPosX;
            entry.flPosY = flPosY;
            return;
        }
    }
}

/** @ghidraAddress 0x176fb8 */
void ExplosionEffectLayer::SetEffectType(unsigned int nColor, int nType) {
    assert(nType >= 0 && nType < kEffectTypeCount);
    assert(static_cast<int>(nColor) >= 0 && nColor < kBankCount);

    if (m_aEffectType[nColor] == nType) {
        return;
    }
    m_aEffectType[nColor] = nType;
    // Rebind the bank's instancer texture once the sprites exist.
    if (m_bBuilt) {
        m_apSprites[nColor]->SetRefCountedMember(
            ne::C_TEXTURE::FindOrLoadCached(kEffectTextureNames[nColor + nType * 2]));
    }
    // Clear every effect slot in both banks so no stale burst keeps the old texture.
    for (int nBank = 0; nBank < kBankCount; ++nBank) {
        for (int nSlot = 0; nSlot < kSlotsPerBank; ++nSlot) {
            m_aBanks[nBank][nSlot].bActive = false;
            m_aBanks[nBank][nSlot].nTimer = 0;
        }
    }
}

/** @ghidraAddress 0x177130 */
void ExplosionEffectLayer::SetEffectSize(float flSize) {
    m_flEffectSize = flSize;
}

/** @ghidraAddress 0x17710c */
void ExplosionEffectLayer::SetPlayColorAlpha(float flAlpha, int nLane) {
    // Lane zero stores the first bank's alpha byte, any other lane the second.
    const int nBank = nLane != 0 ? 1 : 0;
    m_aPlayColorAlpha[nBank] = static_cast<unsigned char>(flAlpha * kAlphaByteScale);
}

/** @ghidraAddress 0x1776ac */
void ExplosionEffectLayer::SetExplosionEffectSprite(unsigned int nLane,
                                                    const S_VECTOR2 *pPosition,
                                                    const S_VECTOR2 *pUvOrigin,
                                                    int nAlpha,
                                                    float flRotation) {
    const int nIndex = m_aSpriteCount[nLane];
    if (nIndex >= m_aSpriteCapacity[nLane]) {
        return;
    }

    const float flScale = m_flEffectSize;
    ne::C_SPRITE_INSTANCING_2D *pBatch = m_apSprites[nLane];
    pBatch->SetSpritePosition(nIndex, *pPosition);
    pBatch->SetSpriteAnchor(nIndex, S_VECTOR2{kEffectAnchor, kEffectAnchor});
    pBatch->SetSpriteSize(nIndex, S_VECTOR2{kEffectSize, kEffectSize});
    pBatch->SetSpriteUvOrigin(nIndex, *pUvOrigin);
    pBatch->SetSpriteUvSize(nIndex, S_VECTOR2{kEffectUvSizeU, kEffectUvSizeV});
    pBatch->SetSpriteScale(nIndex, flScale, flScale);
    pBatch->SetSpriteRotation(nIndex, flRotation);
    pBatch->SetSpriteColor(nIndex, 0xff, 0xff, 0xff, static_cast<unsigned int>(nAlpha));
    ++m_aSpriteCount[nLane];
}
