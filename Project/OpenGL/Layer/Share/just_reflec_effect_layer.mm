#include "just_reflec_effect_layer.h"

#include <cassert>
#include <cstdlib>

#include "bg_layer.h"
#import "deviceenvironment.h"
#include "gamesystem.h"
#include "neRender.h"
#include "neSpriteInstancing.h"
#include "neTexture.h"
#include "s_vector2.h"
#include "sprite_uv_table.h"

static JustReflecEffectLayer *g_pJustReflecEffectLayer = nullptr; // @ghidraAddress 0x3deef8

namespace {

// @ghidraAddress 0x3ceaa0
constexpr const char *kTextureName = "00_texture/gm_parts1";

// @ghidraAddress 0x30dee0
constexpr int kGroupCapacities[] = {32, 32, 256, 256, 256, 256, 256, 256};

constexpr int kAdditiveBlendMode = 1;

constexpr int kTexParamSlotHigh = 1;
constexpr int kTexParamSlotLow = 0;
constexpr int kTexParamEnabled = 1;

constexpr float kSpinPhaseAWrap = 133.33333f;    // @ghidraAddress 0x2fcf88
constexpr float kSpinPhaseAStep = -133.33333f;   // @ghidraAddress 0x2fcf8c
constexpr float kSpinPhaseBWrap = 16.666666f;    // @ghidraAddress 0x30c9b0
constexpr float kSpinPhaseBStep = -16.666666f;   // @ghidraAddress 0x30ded4
constexpr float kParticleRetireAge = 444.44443f; // @ghidraAddress 0x30ded8
constexpr float kAlphaScale = 255.0f;            // @ghidraAddress 0x2eed00
constexpr float kFadeSlope = -0.8f;              // @ghidraAddress 0x30dedc
constexpr float kFadeBase = 0.8f;                // @ghidraAddress 0x2f856c

// Together these give a random value in [-32, 32) per axis.
constexpr float kRandNormalise = 4.6566129e-10f; // @ghidraAddress 0x3014d0 (1/2^31)
constexpr float kJitterMargin = 64.0f;           // @ghidraAddress 0x2ef184
constexpr float kJitterOffset = -32.0f;          // @ghidraAddress 0x30ded0

constexpr float kLifeRandScale = 3.0f;
constexpr float kLifeMinColor1 = 5.0f;
constexpr float kLifeMinColor0 = 2.0f;

struct ChargeSpriteType {
    float flAnchorX = {};
    float flAnchorY = {};
    float flSizeW = {};
    float flSizeH = {};
    unsigned int nUvIndex = {};
};

// @ghidraAddress 0x30df00
constexpr ChargeSpriteType kChargeSpriteTypes[JustReflecEffectLayer::kSpriteTypeCount] = {
    {60.0f, 58.0f, 120.0f, 116.0f, 75},
    {60.0f, 58.0f, 120.0f, 116.0f, 76},
    {16.0f, 16.0f, 32.0f, 32.0f, 77},
    {16.0f, 16.0f, 32.0f, 32.0f, 78},
    {15.0f, 15.0f, 30.0f, 30.0f, 79},
    {16.0f, 16.0f, 32.0f, 32.0f, 80},
    {16.0f, 16.0f, 32.0f, 32.0f, 81},
    {15.0f, 15.0f, 30.0f, 30.0f, 82},
};

} // namespace

// @ghidraAddress 0x2ef668
extern const SpriteUvEntry g_aScoreGaugeUvTable[];

/** @ghidraAddress 0x180b54 */
JustReflecEffectLayer::JustReflecEffectLayer() {
    for (int nGroup = 0;
         nGroup < static_cast<int>(sizeof(kGroupCapacities) / sizeof(*kGroupCapacities));
         ++nGroup) {
        m_nSpriteCapacity += kGroupCapacities[nGroup];
    }
}

/** @ghidraAddress 0x180bf8 */
JustReflecEffectLayer *JustReflecEffectLayer::shared() {
    if (g_pJustReflecEffectLayer == nullptr) {
        g_pJustReflecEffectLayer = new JustReflecEffectLayer();
    }
    return g_pJustReflecEffectLayer;
}

/** @ghidraAddress 0x180c48 */
void JustReflecEffectLayer::LoadNoteChargeSprites() {
    if (m_bBuilt) {
        return;
    }

    BgLayer *pBackgroundLayer = BgLayer::GetBackgroundLayer();
    ne::C_RENDER *pParent = pBackgroundLayer->GetBackgroundRenderObject();

    m_pTexture = ne::C_TEXTURE::FindOrLoadCached(kTextureName);

    m_pSprite = ne::CreateWorldSpriteBatch(static_cast<unsigned int>(m_nSpriteCapacity));
    pParent->AttachChild(m_pSprite);
    m_pSprite->SetVisible(true);
    m_pSprite->SetRefCountedMember(m_pTexture);
    m_pSprite->SetSpriteCount(0);
    m_pSprite->SetBlendMode(kAdditiveBlendMode);
    if (!GetIsHardwareType9Flag()) {
        m_pSprite->SetTexParam(kTexParamSlotHigh, kTexParamEnabled);
        m_pSprite->SetTexParam(kTexParamSlotLow, kTexParamEnabled);
    }

    m_bBuilt = true;
}

/** @ghidraAddress 0x180cf4 */
void JustReflecEffectLayer::Create(int nColor, float flX, float flY, float flA, float flB) {
    assert(nColor >= 0);
    assert(nColor < kPlayerColorMax);

    for (ChargeRecord &charge : m_aCharges) {
        if (!charge.bActive) {
            charge.nColor = nColor;
            charge.bActive = true;
            charge.position.x = flX;
            charge.position.y = flY;
            charge.flA = flA;
            charge.flB = flB;
            return;
        }
    }
}

/** @ghidraAddress 0x180d8c */
void JustReflecEffectLayer::CreateParticle(int nColor, const S_VECTOR2 *pPosition) {
    assert(nColor >= 0);
    assert(nColor < kPlayerColorMax);

    for (BurstParticle &particle : m_aParticles) {
        if (particle.bActive) {
            continue;
        }
        particle.bActive = true;
        particle.nColor = nColor;
        particle.flAge = 0.0f;
        particle.position.x = pPosition->x +
                              static_cast<float>(rand()) * kRandNormalise * kJitterMargin +
                              kJitterOffset;
        particle.position.y = pPosition->y +
                              static_cast<float>(rand()) * kRandNormalise * kJitterMargin +
                              kJitterOffset;
        const float flTypeMin = nColor == 1 ? kLifeMinColor1 : kLifeMinColor0;
        particle.nSpriteType = static_cast<int>(
            static_cast<float>(rand()) * kRandNormalise * kLifeRandScale + flTypeMin);
        return;
    }
}

/** @ghidraAddress 0x180ed4 */
void JustReflecEffectLayer::Update(float flDeltaSeconds) {
    m_nSpriteCount = 0;

    m_flSpinPhaseA += flDeltaSeconds;
    while (m_flSpinPhaseA > kSpinPhaseAWrap) {
        m_flSpinPhaseA += kSpinPhaseAStep;
    }

    // Each overflow spawns one burst particle per active charge.
    int nParticleBursts = 0;
    m_flSpinPhaseB += flDeltaSeconds;
    while (m_flSpinPhaseB > kSpinPhaseBWrap) {
        m_flSpinPhaseB += kSpinPhaseBStep;
        ++nParticleBursts;
    }

    GameSystem *pGameSystem = GameSystem::GetGameSystem();
    const bool bColor1Active = pGameSystem->GetPlayColor() == 1;
    const float flRivalAlpha = pGameSystem->GetRivalAlpha();
    const float flColor0Weight = bColor1Active ? flRivalAlpha : 1.0f;
    const float flColor1Weight = bColor1Active ? 1.0f : flRivalAlpha;

    const float flScale = GameSystem::GetGameSystem()->GetSheetRadiusScaled();

    for (ChargeRecord &charge : m_aCharges) {
        if (!charge.bActive) {
            continue;
        }
        charge.bActive = false;

        float flWeight;
        if (charge.nColor == 0) {
            flWeight = flColor0Weight;
        } else {
            assert(charge.nColor == 1);
            flWeight = flColor1Weight;
        }
        const unsigned int nAlpha = static_cast<unsigned int>(flWeight * charge.flB * kAlphaScale);
        CreateSprite(charge.nColor, &charge.position, nAlpha, charge.flA, flScale);

        for (int nBurst = nParticleBursts; nBurst > 0; --nBurst) {
            CreateParticle(charge.nColor, &charge.position);
        }
    }

    for (BurstParticle &particle : m_aParticles) {
        if (!particle.bActive) {
            continue;
        }
        particle.flAge += flDeltaSeconds;
        if (particle.flAge >= kParticleRetireAge) {
            particle.bActive = false;
            continue;
        }

        float flWeight;
        if (particle.nColor == 0) {
            flWeight = flColor0Weight;
        } else {
            assert(particle.nColor == 1);
            flWeight = flColor1Weight;
        }
        const float flFade = particle.flAge * kFadeSlope / kParticleRetireAge + kFadeBase;
        const unsigned int nAlpha = static_cast<unsigned int>(flFade * flWeight * kAlphaScale);
        CreateSprite(particle.nSpriteType, &particle.position, nAlpha, 0.0f, flScale);
    }

    m_pSprite->SetSpriteCount(m_nSpriteCount);
}

/** @ghidraAddress 0x181140 */
void JustReflecEffectLayer::CreateSprite(
    int nType, const S_VECTOR2 *pPosition, unsigned int nAlpha, float flRotation, float flScale) {
    assert(nType >= 0);
    assert(nType < kSpriteTypeCount);

    const ChargeSpriteType &spriteType = kChargeSpriteTypes[nType];
    const SpriteUvEntry &uv = g_aScoreGaugeUvTable[spriteType.nUvIndex];
    const int nIndex = m_nSpriteCount;

    m_pSprite->SetSpritePosition(nIndex, *pPosition);
    m_pSprite->SetSpriteAnchor(nIndex, S_VECTOR2{spriteType.flAnchorX, spriteType.flAnchorY});
    m_pSprite->SetSpriteSize(nIndex, S_VECTOR2{spriteType.flSizeW, spriteType.flSizeH});
    m_pSprite->SetSpriteUvOrigin(nIndex, S_VECTOR2{uv.flOriginU, uv.flOriginV});
    m_pSprite->SetSpriteUvSize(nIndex, S_VECTOR2{uv.flSizeU, uv.flSizeV});
    m_pSprite->SetSpriteRotation(nIndex, flRotation);
    m_pSprite->SetSpriteScale(nIndex, flScale, flScale);
    m_pSprite->SetSpriteColor(nIndex, 0xff, 0xff, 0xff, nAlpha);

    ++m_nSpriteCount;
}
