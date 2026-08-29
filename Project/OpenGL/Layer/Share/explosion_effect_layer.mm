#include "explosion_effect_layer.h"

#include <cassert>

#include "bg_layer.h"
#include "gamesystem.h"
#include "neRender.h"
#include "neSpriteInstancing.h"
#include "neTexture.h"
#include "s_vector2.h"

static ExplosionEffectLayer *g_pExplosionEffectLayer = nullptr; // @ghidraAddress 0x3deb50

namespace {

// @ghidraAddress 0x2eed00
constexpr float kAlphaByteScale = 255.0f;

// @ghidraAddress 0x176e4c, 0x176e58, 0x176e7c, 0x30ca80
constexpr unsigned char kPlayColorAlphaFull = 0xff;
constexpr float kInitialEffectSize = 1.0f;
constexpr int kInitialEffectType = 0x14;

// @ghidraAddress 0x30bf28 anchor, 0x30bf2c size
constexpr float kEffectAnchor = 84.0f;
constexpr float kEffectSize = 168.0f;

// @ghidraAddress 0x30bf30 (the U; the V is an inline constant)
constexpr float kEffectUvSizeU = 0.08203125f;
constexpr float kEffectUvSizeV = 0.1640625f;

// Interleaved red then blue, indexed by (colour + type * 2). @ghidraAddress 0x3ce608
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
        m_aPlayColorAlpha[nBank] = kPlayColorAlphaFull;
        m_aEffectType[nBank] = kInitialEffectType;
        for (int nSlot = 0; nSlot < kSlotsPerBank; ++nSlot) {
            m_aBanks[nBank][nSlot] = EffectEntry{};
        }
    }
    m_flEffectSize = kInitialEffectSize;
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

    for (int nSlot = 0; nSlot < kSlotsPerBank; ++nSlot) {
        EffectEntry &entry = m_aBanks[nColor][nSlot];
        if (!entry.bActive) {
            entry.flTimer = 0.0f;
            entry.nJudge = nJudge;
            entry.bActive = true;
            entry.position.x = flPosX;
            entry.position.y = flPosY;
            return;
        }
    }
}

namespace {
// @ghidraAddress 0x3deb60
constexpr S_VECTOR2 kBurstUvCells[] = {
    {0.0f, 0.6640625f},
    {0.08300781f, 0.6640625f},
    {0.16601562f, 0.6640625f},
    {0.24902344f, 0.6640625f},
    {0.33203125f, 0.6640625f},
    {0.41503906f, 0.6640625f},
    {0.49804688f, 0.6640625f},
    {0.5810547f, 0.6640625f},
    {0.6640625f, 0.6640625f},
    {0.7470703f, 0.6640625f},
    {0.8300781f, 0.6640625f},
    {0.91308594f, 0.6640625f},
    {0.0f, 0.8300781f},
    {0.08300781f, 0.8300781f},
    {0.16601562f, 0.8300781f},
    {0.24902344f, 0.8300781f},
    {0.33203125f, 0.8300781f},
    {0.41503906f, 0.8300781f},
    {0.49804688f, 0.8300781f},
    {0.5810547f, 0.8300781f},
    {0.6640625f, 0.8300781f},
    {0.7470703f, 0.8300781f},
    {0.8300781f, 0.8300781f},
    {0.91308594f, 0.8300781f},
    {0.0f, 0.33203125f},
    {0.08300781f, 0.33203125f},
    {0.16601562f, 0.33203125f},
    {0.24902344f, 0.33203125f},
    {0.33203125f, 0.33203125f},
    {0.41503906f, 0.33203125f},
    {0.49804688f, 0.33203125f},
    {0.5810547f, 0.33203125f},
    {0.6640625f, 0.33203125f},
    {0.7470703f, 0.33203125f},
    {0.8300781f, 0.33203125f},
    {0.91308594f, 0.33203125f},
    {0.0f, 0.49804688f},
    {0.08300781f, 0.49804688f},
    {0.16601562f, 0.49804688f},
    {0.24902344f, 0.49804688f},
    {0.33203125f, 0.49804688f},
    {0.41503906f, 0.49804688f},
    {0.49804688f, 0.49804688f},
    {0.5810547f, 0.49804688f},
    {0.6640625f, 0.49804688f},
    {0.7470703f, 0.49804688f},
    {0.8300781f, 0.49804688f},
    {0.91308594f, 0.49804688f},
    {0.0f, 0.0f},
    {0.08300781f, 0.0f},
    {0.16601562f, 0.0f},
    {0.24902344f, 0.0f},
    {0.33203125f, 0.0f},
    {0.41503906f, 0.0f},
    {0.49804688f, 0.0f},
    {0.5810547f, 0.0f},
    {0.6640625f, 0.0f},
    {0.7470703f, 0.0f},
    {0.8300781f, 0.0f},
    {0.91308594f, 0.0f},
    {0.0f, 0.16601562f},
    {0.08300781f, 0.16601562f},
    {0.16601562f, 0.16601562f},
    {0.24902344f, 0.16601562f},
    {0.33203125f, 0.16601562f},
    {0.41503906f, 0.16601562f},
    {0.49804688f, 0.16601562f},
    {0.5810547f, 0.16601562f},
    {0.6640625f, 0.16601562f},
    {0.7470703f, 0.16601562f},
    {0.8300781f, 0.16601562f},
    {0.91308594f, 0.16601562f},
};
// @ghidraAddress 0x30c9b0
constexpr int kBurstPhaseCount = 24;
constexpr float kBurstFrameTime = 16.66666603f;
// @ghidraAddress 0x302d6c
constexpr float kBurstLifetime = 400.0f;
// @ghidraAddress 0x30ca90
constexpr float kBurstMirrorRotation = 3.1415927f;
constexpr int kEffectTypeOff = kInitialEffectType;
} // namespace

/** @ghidraAddress 0x177260 */
void ExplosionEffectLayer::Process(float flDeltaTime) {
    m_aSpriteCount[0] = 0;
    m_aSpriteCount[1] = 0;

    GameSystem *pGameSystem = GameSystem::GetGameSystem();
    for (int nBank = 0; nBank < kBankCount; ++nBank) {
        if (m_aEffectType[nBank] == kEffectTypeOff) {
            continue;
        }

        const bool bColorMatch = pGameSystem->GetPlayColor() == nBank;
        const unsigned int nAlpha = m_aPlayColorAlpha[bColorMatch ? 1 : 0];
        const float flRotation = bColorMatch ? 0.0f : kBurstMirrorRotation;

        for (int nSlot = 0; nSlot < kSlotsPerBank; ++nSlot) {
            EffectEntry &entry = m_aBanks[nBank][nSlot];
            if (!entry.bActive) {
                continue;
            }
            entry.flTimer += flDeltaTime;
            if (entry.flTimer > kBurstLifetime) {
                entry.bActive = false;
                continue;
            }
            // At exactly the lifetime the binary skips emission without deactivating.
            // @ghidraAddress 0x177480
            if (entry.flTimer >= kBurstLifetime) {
                continue;
            }
            if (nAlpha == 0) {
                continue;
            }

            int nPhase = static_cast<int>(entry.flTimer / kBurstFrameTime);
            if (nPhase < 0) {
                nPhase = 0;
            } else if (nPhase > kBurstPhaseCount - 1) {
                nPhase = kBurstPhaseCount - 1;
            }
            const S_VECTOR2 &uvOrigin = kBurstUvCells[entry.nJudge * kBurstPhaseCount + nPhase];
            SetExplosionEffectSprite(static_cast<unsigned int>(nBank),
                                     &entry.position,
                                     &uvOrigin,
                                     static_cast<int>(nAlpha),
                                     flRotation);
        }
    }

    for (int nBank = 0; nBank < kBankCount; ++nBank) {
        m_apSprites[nBank]->SetSpriteCount(m_aSpriteCount[nBank]);
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
    if (m_bBuilt) {
        m_apSprites[nColor]->SetRefCountedMember(
            ne::C_TEXTURE::FindOrLoadCached(kEffectTextureNames[nColor + nType * 2]));
    }
    // Both banks are cleared, not only this one, so no stale burst keeps the old texture.
    for (int nBank = 0; nBank < kBankCount; ++nBank) {
        for (int nSlot = 0; nSlot < kSlotsPerBank; ++nSlot) {
            m_aBanks[nBank][nSlot].bActive = false;
            m_aBanks[nBank][nSlot].flTimer = 0.0f;
        }
    }
}

/** @ghidraAddress 0x177130 */
void ExplosionEffectLayer::SetEffectSize(float flSize) {
    m_flEffectSize = flSize;
}

/** @ghidraAddress 0x17710c */
void ExplosionEffectLayer::SetPlayColorAlpha(float flAlpha, int nLane) {
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
