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
#include "gamesystem.h"
#include "neRender.h"
#include "neSpriteInstancing.h"
#include "neTexture.h"
#include "s_vector2.h"

// The process-wide explosion effect layer, created lazily by shared().
static ExplosionEffectLayer *g_pExplosionEffectLayer = nullptr; // @ghidraAddress 0x3deb50

namespace {

// The scale converting a unit-interval alpha to the byte range (@ghidraAddress 0x2eed00).
constexpr float kAlphaByteScale = 255.0f;

// The constructor's seeds: both play-colour alpha bytes opaque, the burst size at unit scale, and
// both banks' effect type set to the disabled value (@ghidraAddress 0x176e4c, 0x176e58, and the
// eight-byte _memset_pattern16 from 0x30ca80 at 0x176e7c).
constexpr unsigned char kPlayColorAlphaFull = 0xff;
constexpr float kInitialEffectSize = 1.0f;
constexpr int kInitialEffectType = 0x14;

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
        // Process reads this as every burst's sprite alpha, so leaving it zero makes each burst
        // fully transparent and no explosion is ever seen.
        m_aPlayColorAlpha[nBank] = kPlayColorAlphaFull;
        m_aEffectType[nBank] = kInitialEffectType;
        for (int nSlot = 0; nSlot < kSlotsPerBank; ++nSlot) {
            m_aBanks[nBank][nSlot] = EffectEntry{};
        }
    }
    // The sprite scale until the user setting arrives; zero would draw every burst at no size.
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
// The burst animation UV table (@ghidraAddress 0x3deb60, built once by a compile-generated one-shot
// from scattered source constants): 72 atlas-cell UV origins, indexed by the burst's judgement type
// times twenty-four plus its clamped animation phase. Each row of twelve shares a V; the U ramps
// across the atlas in twelfths.
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
// The animation phase count and the frame time per phase (@ghidraAddress 0x30c9b0 = 16.667).
constexpr int kBurstPhaseCount = 24;
constexpr float kBurstFrameTime = 16.66666603f;
// The burst lifetime past which a slot is deactivated (@ghidraAddress 0x302d6c = 400).
constexpr float kBurstLifetime = 400.0f;
// The mirror rotation applied to a bank that does not match the current play colour (pi), and none
// for the matching bank (@ghidraAddress 0x30ca90 = {pi, 0}).
constexpr float kBurstMirrorRotation = 3.1415927f;
// The effect type value that disables a bank (the same value the constructor seeds).
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

        // A bank matching the current play colour draws upright at its own alpha; the other bank is
        // mirrored a half turn.
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
            // At exactly the lifetime the binary skips this frame's emission without deactivating:
            // the fcmp is followed by both a b.le (only > deactivates) and a b.pl (>= skips emit),
            // so only flTimer strictly below the lifetime draws. @ghidraAddress 0x177480
            if (entry.flTimer >= kBurstLifetime) {
                continue;
            }
            // The bank's alpha gates emission; a zeroed alpha skips the burst this frame.
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

    // Publish each bank's live sprite count to its instancer.
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
    // Rebind the bank's instancer texture once the sprites exist.
    if (m_bBuilt) {
        m_apSprites[nColor]->SetRefCountedMember(
            ne::C_TEXTURE::FindOrLoadCached(kEffectTextureNames[nColor + nType * 2]));
    }
    // Clear every effect slot in both banks so no stale burst keeps the old texture.
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
