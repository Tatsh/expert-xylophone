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

// The process-wide just-reflec effect layer, created lazily by shared().
static JustReflecEffectLayer *g_pJustReflecEffectLayer = nullptr; // @ghidraAddress 0x3deef8

namespace {

// The atlas the charge notes draw from (@ghidraAddress 0x3ceaa0).
constexpr const char *kTextureName = "00_texture/gm_parts1";

// The per-group sprite capacities the constructor sums into the instancer capacity (@ghidraAddress
// 0x30dee0).
constexpr int kGroupCapacities[] = {32, 32, 256, 256, 256, 256, 256, 256};

// The additive blend-mode identifier the charge batch uses.
constexpr int kAdditiveBlendMode = 1;

// The two texture-environment parameter slots the builder seeds (to 1 each), and that value.
constexpr int kTexParamSlotHigh = 1;
constexpr int kTexParamSlotLow = 0;
constexpr int kTexParamEnabled = 1;

// The two spin-phase wrap thresholds and their wrap steps, and the particle-retire age.
constexpr float kSpinPhaseAWrap = 133.33333f;    // @ghidraAddress 0x2fcf88
constexpr float kSpinPhaseAStep = -133.33333f;   // @ghidraAddress 0x2fcf8c
constexpr float kSpinPhaseBWrap = 16.666666f;    // @ghidraAddress 0x30c9b0
constexpr float kSpinPhaseBStep = -16.666666f;   // @ghidraAddress 0x30ded4
constexpr float kParticleRetireAge = 444.44443f; // @ghidraAddress 0x30ded8
// The alpha scale applied to the 0..1 fade into the 0..255 sprite alpha.
constexpr float kAlphaScale = 255.0f; // @ghidraAddress 0x2eed00
// The particle fade curve maps age 0..retire to alpha 0.8..0 (fade = age*-0.8/retire + 0.8).
constexpr float kFadeSlope = -0.8f; // @ghidraAddress 0x30dedc
constexpr float kFadeBase = 0.8f;   // @ghidraAddress 0x2f856c

// The particle spawn jitter: rand() is normalised by 1/2^31, scaled by the 64-unit margin, and
// offset by -32, giving a random value in [-32, 32) per axis.
constexpr float kRandNormalise = 4.6566129e-10f; // @ghidraAddress 0x3014d0 (1/2^31)
constexpr float kJitterMargin = 64.0f;           // @ghidraAddress 0x2ef184
constexpr float kJitterOffset = -32.0f;          // @ghidraAddress 0x30ded0

// The randomised particle lifetimes: a 0..3-scaled random base plus a per-colour minimum (5 for
// colour 1, else 2).
constexpr float kLifeRandScale = 3.0f;
constexpr float kLifeMinColor1 = 5.0f;
constexpr float kLifeMinColor0 = 2.0f;

// One record spawns this many burst particles per phase-B overflow this frame.
// (Derived at run time from the phase-B wrap count.)

// One charge sprite descriptor: anchor, size, and UV-table index. A 20-byte read-only ROM record.
struct ChargeSpriteType {
    float flAnchorX = {};
    float flAnchorY = {};
    float flSizeW = {};
    float flSizeH = {};
    unsigned int nUvIndex = {};
};

// The charge sprite-type table (@ghidraAddress 0x30df00): read-only ROM data.
constexpr ChargeSpriteType kChargeSpriteTypes[JustReflecEffectLayer::kSpriteTypeCount] = {
    {60.0f, 58.0f, 120.0f, 116.0f, 75}, // 0
    {60.0f, 58.0f, 120.0f, 116.0f, 76}, // 1
    {16.0f, 16.0f, 32.0f, 32.0f, 77},   // 2
    {16.0f, 16.0f, 32.0f, 32.0f, 78},   // 3
    {15.0f, 15.0f, 30.0f, 30.0f, 79},   // 4
    {16.0f, 16.0f, 32.0f, 32.0f, 80},   // 5
    {16.0f, 16.0f, 32.0f, 32.0f, 81},   // 6
    {15.0f, 15.0f, 30.0f, 30.0f, 82},   // 7
};

} // namespace

// The shared sprite-UV atlas the charge sprite types index (@ghidraAddress 0x2ef668).
extern const SpriteUvEntry g_aScoreGaugeUvTable[];

/** @ghidraAddress 0x180b54 */
JustReflecEffectLayer::JustReflecEffectLayer() {
    // The instancer capacity is the sum of the per-group capacity table.
    for (int nGroup = 0;
         nGroup < static_cast<int>(sizeof(kGroupCapacities) / sizeof(*kGroupCapacities));
         ++nGroup) {
        m_nSpriteCapacity += kGroupCapacities[nGroup];
    }
}

/** @ghidraAddress 0x180bf8 */
JustReflecEffectLayer *JustReflecEffectLayer::shared() {
    if (g_pJustReflecEffectLayer == nullptr) {
        // The binary allocates the raw 0x1b38-byte object and runs the constructor.
        g_pJustReflecEffectLayer = new JustReflecEffectLayer();
    }
    return g_pJustReflecEffectLayer;
}

/** @ghidraAddress 0x180c48 */
void JustReflecEffectLayer::LoadNoteChargeSprites() {
    if (m_bBuilt) {
        return;
    }

    // The sprite hangs beneath the shared background layer's render object rather than the global
    // scene root.
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
        // Jitter each axis by a random value in [-32, 32).
        particle.position.x = pPosition->x +
                              static_cast<float>(rand()) * kRandNormalise * kJitterMargin +
                              kJitterOffset;
        particle.position.y = pPosition->y +
                              static_cast<float>(rand()) * kRandNormalise * kJitterMargin +
                              kJitterOffset;
        // Seed a randomised sprite type (its lifetime slot), higher for colour 1.
        const float flTypeMin = nColor == 1 ? kLifeMinColor1 : kLifeMinColor0;
        particle.nSpriteType = static_cast<int>(
            static_cast<float>(rand()) * kRandNormalise * kLifeRandScale + flTypeMin);
        return;
    }
}

/** @ghidraAddress 0x180ed4 */
void JustReflecEffectLayer::Update(float flDeltaSeconds) {
    m_nSpriteCount = 0;

    // Advance the first spin phase, wrapping it down into range.
    m_flSpinPhaseA += flDeltaSeconds;
    while (m_flSpinPhaseA > kSpinPhaseAWrap) {
        m_flSpinPhaseA += kSpinPhaseAStep;
    }

    // Advance the second spin phase, counting how many times it overflowed this frame; each
    // overflow spawns one burst particle per active charge.
    int nParticleBursts = 0;
    m_flSpinPhaseB += flDeltaSeconds;
    while (m_flSpinPhaseB > kSpinPhaseBWrap) {
        m_flSpinPhaseB += kSpinPhaseBStep;
        ++nParticleBursts;
    }

    // The per-colour alpha weights: the active play colour draws at full weight, the other at the
    // rival alpha.
    GameSystem *pGameSystem = GameSystem::GetGameSystem();
    const bool bColor1Active = pGameSystem->GetPlayColor() == 1;
    const float flRivalAlpha = pGameSystem->GetRivalAlpha();
    const float flColor0Weight = bColor1Active ? flRivalAlpha : 1.0f;
    const float flColor1Weight = bColor1Active ? 1.0f : flRivalAlpha;

    // Every sprite is scaled by the game system's scaled sheet radius.
    const float flScale = GameSystem::GetGameSystem()->GetSheetRadiusScaled();

    // Emit each active charge's sprite, and spawn its burst particles.
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
        // The charge's sprite type is its colour, and its rotation is the flA geometry field.
        CreateSprite(charge.nColor, &charge.position, nAlpha, charge.flA, flScale);

        for (int nBurst = nParticleBursts; nBurst > 0; --nBurst) {
            CreateParticle(charge.nColor, &charge.position);
        }
    }

    // Age each active particle, retiring the spent ones and emitting a fading sprite for the rest.
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
        // The particle draws its stored sprite type, without rotation.
        CreateSprite(particle.nSpriteType, &particle.position, nAlpha, 0.0f, flScale);
    }

    // Publish the frame's sprite count to the batch.
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
