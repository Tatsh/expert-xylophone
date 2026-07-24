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

// The process-wide explosion effect layer, created lazily by shared().
static ExplosionEffectLayer *g_pExplosionEffectLayer = nullptr; // @ghidraAddress 0x3deb50

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
        ne::C_SPRITE_INSTANCING *pSprite = ne::CreateWorldSpriteBatch(kSpriteCapacity);
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
