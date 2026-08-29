#include "note_layer.h"

#include <cassert>
#include <cmath>

#include "bg_layer.h"
#include "gamesystem.h"
#include "neRender.h"
#include "neSpriteInstancing.h"
#include "neTexture.h"
#include "s_vector2.h"

int g_nParticleActiveIndex = {}; // @ghidraAddress 0x3df228

namespace {

// @ghidraAddress 0x30f754
struct NoteSpriteDescriptor {
    float flAnchorX;
    float flAnchorY;
    float flSizeW;
    float flSizeH;
    int nUvIndex;
};
constexpr NoteSpriteDescriptor kNoteSpriteDescriptors[] = {
    {50.0f, 50.0f, 100.0f, 100.0f, 11},
    {31.0f, 31.0f, 62.0f, 62.0f, 12},
    {31.0f, 31.0f, 62.0f, 62.0f, 13},
    {31.0f, 31.0f, 62.0f, 62.0f, 14},
    {31.0f, 31.0f, 62.0f, 62.0f, 15},
    {31.0f, 31.0f, 62.0f, 62.0f, 16},
    {31.0f, 31.0f, 62.0f, 62.0f, 17},
    {31.0f, 31.0f, 62.0f, 62.0f, 18},
    {31.0f, 31.0f, 62.0f, 62.0f, 19},
    {31.0f, 31.0f, 62.0f, 62.0f, 20},
    {31.0f, 31.0f, 62.0f, 62.0f, 21},
    {31.0f, 31.0f, 62.0f, 62.0f, 22},
};

// @ghidraAddress 0x30f6f4
constexpr int kNoteSpriteBatch[] = {0, 1, 1, 1, 1, 1, 1, 2, 1, 1, 1, 1};

// @ghidraAddress 0x2ef668
struct NoteUvRect {
    float flOriginU;
    float flOriginV;
    float flSizeU;
    float flSizeV;
};
constexpr NoteUvRect kNoteUvRects[] = {
    {0.0f, 0.0f, 0.0f, 0.0f},
    {0.001953125f, 0.31054688f, 0.09765625f, 0.09765625f},
    {0.001953125f, 0.31054688f, 0.09765625f, 0.09765625f},
    {0.20117188f, 0.31054688f, 0.0703125f, 0.06640625f},
    {0.2734375f, 0.31054688f, 0.0703125f, 0.06640625f},
    {0.203125f, 0.37890625f, 0.01953125f, 0.02734375f},
    {0.22851562f, 0.37890625f, 0.01953125f, 0.02734375f},
    {0.1015625f, 0.31054688f, 0.09765625f, 0.09765625f},
    {0.1015625f, 0.31054688f, 0.09765625f, 0.09765625f},
    {0.890625f, 0.099609375f, 0.060546875f, 0.060546875f},
    {0.890625f, 0.099609375f, 0.060546875f, 0.060546875f},
    {0.671875f, 0.001953125f, 0.09765625f, 0.09765625f},
    {0.19335938f, 0.08984375f, 0.09375f, 0.09375f},
    {0.001953125f, 0.08984375f, 0.09375f, 0.09375f},
    {0.38476562f, 0.08984375f, 0.09375f, 0.09375f},
    {0.2890625f, 0.08984375f, 0.09375f, 0.09375f},
    {0.09765625f, 0.08984375f, 0.09375f, 0.09375f},
    {0.38476562f, 0.18554688f, 0.09375f, 0.09375f},
    {0.34570312f, 0.31054688f, 0.09375f, 0.09375f},
    {0.6503906f, 0.41015625f, 0.09375f, 0.09375f},
    {0.45898438f, 0.41015625f, 0.09375f, 0.09375f},
    {0.74609375f, 0.41015625f, 0.09375f, 0.09375f},
    {0.5546875f, 0.41015625f, 0.09375f, 0.09375f},
};

constexpr float kScrollWrapWide = 1000.0f;       // @ghidraAddress 0x2f8540
constexpr float kScrollStepWide = -1000.0f;      // @ghidraAddress 0x2f8544
constexpr float kScrollWrapNarrow = 133.33333f;  // @ghidraAddress 0x2fcf88
constexpr float kScrollStepNarrow = -133.33333f; // @ghidraAddress 0x2fcf8c

constexpr double kPhaseToRadians = 0.006283185307179587; // @ghidraAddress 0x30f6e8

constexpr float kFadeMidpoint = 500.0f;        // @ghidraAddress 0x2feff4
constexpr float kFadeRiseDivisor = -66.66667f; // @ghidraAddress 0x2fee0c
constexpr float kFadeFallOffset = -0.3f;       // @ghidraAddress 0x30f6f0
constexpr float kFadeFallDivisor = 0.3f;       // @ghidraAddress 0x2ee910
constexpr float kFadeHalf = 0.5f;
constexpr float kFadeOne = 1.0f;

constexpr float kAlphaScale = 255.0f; // @ghidraAddress 0x2eed00

constexpr int kPhaseA = 0;
constexpr int kPhaseB = 1;
constexpr int kPhaseC = 2;
constexpr int kPlayColorPrimary = 1;

constexpr unsigned int kOpaque = 0xff;

inline void AdvanceScrollPhase(float &flPhase, float flDelta, float flWrap, float flStep) {
    flPhase += flDelta;
    while (flPhase > flWrap) {
        flPhase += flStep;
    }
}

} // namespace

/** @ghidraAddress 0x189104 */
void NoteLayer::CreateSprite(
    int nType, const S_VECTOR2 *pPosition, int nAlpha, float flScale, float flRotation) {
    assert(nType >= 0);
    assert(nType < static_cast<int>(sizeof(kNoteSpriteBatch) / sizeof(*kNoteSpriteBatch)));

    const int nBatch = kNoteSpriteBatch[nType];
    const NoteSpriteDescriptor &desc = kNoteSpriteDescriptors[nType];
    const NoteUvRect &uv = kNoteUvRects[desc.nUvIndex];

    ne::C_SPRITE_INSTANCING_2D *pBatch = m_apSprites[nBatch];
    const int nIndex = m_anBatchCount[nBatch];

    pBatch->SetSpritePosition(nIndex, *pPosition);
    pBatch->SetSpriteAnchor(nIndex, S_VECTOR2{desc.flAnchorX, desc.flAnchorY});
    pBatch->SetSpriteSize(nIndex, S_VECTOR2{desc.flSizeW, desc.flSizeH});
    pBatch->SetSpriteUvOrigin(nIndex, S_VECTOR2{uv.flOriginU, uv.flOriginV});
    pBatch->SetSpriteUvSize(nIndex, S_VECTOR2{uv.flSizeU, uv.flSizeV});
    pBatch->SetSpriteScale(nIndex, flScale, flScale);
    pBatch->SetSpriteRotation(nIndex, flRotation);
    pBatch->SetSpriteColor(nIndex, kOpaque, kOpaque, kOpaque, static_cast<unsigned int>(nAlpha));

    ++m_anBatchCount[nBatch];
}

/** @ghidraAddress 0x188cc0 */
void NoteLayer::Update(float flDelta) {
    for (int &nCount : m_anBatchCount) {
        nCount = 0;
    }

    AdvanceScrollPhase(m_aScrollPhase[kPhaseA], flDelta, kScrollWrapWide, kScrollStepWide);
    AdvanceScrollPhase(m_aScrollPhase[kPhaseB], flDelta, kScrollWrapWide, kScrollStepWide);
    AdvanceScrollPhase(m_aScrollPhase[kPhaseC], flDelta, kScrollWrapNarrow, kScrollStepNarrow);

    const float flRotation =
        static_cast<float>(static_cast<double>(m_aScrollPhase[kPhaseA]) * kPhaseToRadians);

    // @ghidraAddress 0x188ddc
    float flFade;
    if (m_aScrollPhase[kPhaseC] < kFadeMidpoint) {
        flFade = m_aScrollPhase[kPhaseC] / kFadeRiseDivisor * kFadeHalf + kFadeOne;
    } else {
        flFade =
            (m_aScrollPhase[kPhaseC] + kFadeFallOffset) / kFadeFallDivisor * kFadeHalf + kFadeHalf;
    }
    flFade += flFade;
    if (flFade < 0.0f) {
        flFade = 0.0f;
    } else if (flFade > kFadeOne) {
        flFade = kFadeOne;
    }
    const float flGlobalAlpha = flFade * kAlphaScale;

    GameSystem *pGameSystem = GameSystem::GetGameSystem();
    const bool bPrimary = pGameSystem->GetPlayColor() == kPlayColorPrimary;
    const float flRivalAlpha = pGameSystem->GetRivalAlpha();
    const float flColorA = bPrimary ? flRivalAlpha : kFadeOne;
    const float flColorB = bPrimary ? kFadeOne : flRivalAlpha;
    const float flColorScale = pGameSystem->GetSheetRadiusScaled();

    for (int nSlot = 0; nSlot < kParticleCount; ++nSlot) {
        Particle &particle = m_aParticles[nSlot];
        // A slot at or past the shared active index is retired rather than left set.
        // @ghidraAddress 0x188e44
        if (nSlot >= g_nParticleActiveIndex) {
            particle.bActive = false;
            continue;
        }
        if (!particle.bActive) {
            continue;
        }
        particle.bActive = false;

        const S_VECTOR2 pos{particle.flX, particle.flY};
        const float flScale = particle.flScaleX * flColorScale;

        switch (particle.nKind) {
        case 0:
            CreateSprite(1,
                         &pos,
                         static_cast<int>(particle.flScaleY * flColorA * kAlphaScale),
                         flScale,
                         particle.flRotation);
            break;
        case 1:
            CreateSprite(4,
                         &pos,
                         static_cast<int>(particle.flScaleY * flColorB * kAlphaScale),
                         flScale,
                         particle.flRotation);
            break;
        case 2:
            CreateSprite(2,
                         &pos,
                         static_cast<int>(particle.flScaleY * flColorA * kAlphaScale),
                         flScale,
                         particle.flRotation);
            break;
        case 3:
            CreateSprite(5,
                         &pos,
                         static_cast<int>(particle.flScaleY * flColorB * kAlphaScale),
                         flScale,
                         particle.flRotation);
            break;
        case 4:
            CreateSprite(3,
                         &pos,
                         static_cast<int>(particle.flScaleY * flColorA * kAlphaScale),
                         flScale,
                         particle.flRotation);
            CreateSprite(7,
                         &pos,
                         static_cast<int>(particle.flScaleY * flColorA * kAlphaScale),
                         particle.flScaleX * flColorScale,
                         flRotation);
            break;
        case 5:
            CreateSprite(6,
                         &pos,
                         static_cast<int>(particle.flScaleY * flColorB * kAlphaScale),
                         flScale,
                         particle.flRotation);
            CreateSprite(7,
                         &pos,
                         static_cast<int>(particle.flScaleY * flColorB * kAlphaScale),
                         particle.flScaleX * flColorScale,
                         flRotation);
            break;
        case 6:
            CreateSprite(0,
                         &pos,
                         static_cast<int>(particle.flScaleY * flColorA * flGlobalAlpha),
                         flScale,
                         particle.flRotation);
            break;
        case 7:
            CreateSprite(0,
                         &pos,
                         static_cast<int>(particle.flScaleY * flColorB * flGlobalAlpha),
                         flScale,
                         particle.flRotation);
            break;
        case 8:
            CreateSprite(8,
                         &pos,
                         static_cast<int>(particle.flScaleY * flColorA * kAlphaScale),
                         flScale,
                         particle.flRotation);
            break;
        case 9:
            CreateSprite(9,
                         &pos,
                         static_cast<int>(particle.flScaleY * flColorA * kAlphaScale),
                         flScale,
                         particle.flRotation);
            break;
        case 10:
            CreateSprite(10,
                         &pos,
                         static_cast<int>(particle.flScaleY * flColorB * kAlphaScale),
                         flScale,
                         particle.flRotation);
            break;
        case 11:
            CreateSprite(11,
                         &pos,
                         static_cast<int>(particle.flScaleY * flColorB * kAlphaScale),
                         flScale,
                         particle.flRotation);
            break;
        default:
            assert(0);
        }
    }

    for (int nBatch = 0; nBatch < kBatchCount; ++nBatch) {
        m_apSprites[nBatch]->SetSpriteCount(m_anBatchCount[nBatch]);
    }
    g_nParticleActiveIndex = 0;
}

namespace {
constexpr int kParticleKindDefault = 6;
constexpr int kParticleKindAlt = 7;
constexpr int kParticleTypeAlt = 1;

// @ghidraAddress 0x30f6f4
constexpr int kBatchSeedIndex[] = {0, 1, 1, 1, 1, 1, 1, 2, 1, 1, 1, 1};
// @ghidraAddress 0x30f724
constexpr int kBatchSeedCount[] = {512, 256, 256, 256, 256, 256, 256, 512, 256, 256, 256, 256};
constexpr int kBatchSeedEntryCount = 12;

constexpr const char *kAtlasTextureName = "00_texture/gm_parts1";

constexpr int kAdditiveBlendMode = 1;
constexpr int kTexParamValue = 1;
} // namespace

static NoteLayer *g_pNoteLayer = nullptr; // @ghidraAddress 0x3df230

/** @ghidraAddress 0x188904 */
NoteLayer *NoteLayer::shared() {
    if (g_pNoteLayer == nullptr) {
        g_pNoteLayer = new NoteLayer();
    }
    return g_pNoteLayer;
}

/** @ghidraAddress 0x188850 */
NoteLayer::NoteLayer() {
    g_nParticleActiveIndex = 0;
    for (int i = 0; i < kBatchSeedEntryCount; ++i) {
        m_anBatchCapacity[kBatchSeedIndex[i]] += kBatchSeedCount[i];
    }
}

/** @ghidraAddress 0x188954 */
void NoteLayer::CreateSpriteBatches() {
    if (m_bBuilt) {
        return;
    }

    ne::C_RENDER *pParent = BgLayer::GetBackgroundLayer()->GetBackgroundRenderObject();
    m_pTexture = ne::C_TEXTURE::FindOrLoadCached(kAtlasTextureName);
    for (int i = 0; i < kBatchCount; ++i) {
        ne::C_SPRITE_INSTANCING_2D *pSprite =
            ne::CreateWorldSpriteBatch(static_cast<unsigned int>(m_anBatchCapacity[i]));
        m_apSprites[i] = pSprite;
        pParent->AttachChild(pSprite);
        pSprite->SetVisible(true);
        pSprite->SetRefCountedMember(m_pTexture);
        pSprite->SetSpriteCount(0);
        if (i != 1) {
            pSprite->SetBlendMode(kAdditiveBlendMode);
        }
        if (i == 1 && !IsHardwareType9()) {
            pSprite->SetTexParam(1, kTexParamValue);
            pSprite->SetTexParam(0, kTexParamValue);
        }
    }

    m_bBuilt = true;
    g_nParticleActiveIndex = 0;
}

/** @ghidraAddress 0x188c50 */
void NoteLayer::SpawnParticle(float flX, float flY, float flScaleX, float flScaleY, int nType) {
    const int nKind = nType == kParticleTypeAlt ? kParticleKindAlt : kParticleKindDefault;
    // A full pool drops the particle.
    for (int nSlot = g_nParticleActiveIndex; nSlot < kParticleCount; ++nSlot) {
        Particle &particle = m_aParticles[nSlot];
        if (!particle.bActive) {
            particle.nKind = nKind;
            particle.bActive = true;
            particle.flX = flX;
            particle.flY = flY;
            particle.flRotation = 0.0f;
            particle.flScaleX = flScaleX;
            particle.flScaleY = flScaleY;
            ++g_nParticleActiveIndex;
            return;
        }
    }
}

namespace {
constexpr int kEndTypeHead = 0;
constexpr int kEndTypeTail = 1;
constexpr int kPlayerColorMax = 2;
constexpr double kTailAngleBias = 1.5707963267948966; // @ghidraAddress 0x2fedd8
constexpr float kHeadMirrorRotation = 3.1415927f;     // @ghidraAddress 0x2fe894
constexpr int kTailKindColor0 = 4;
constexpr int kTailKindColor1 = 5;
} // namespace

/** @ghidraAddress 0x188a48 */
void NoteLayer::Create(int nColor,
                       int nEndType,
                       int nShapeFlagA,
                       int nShapeFlagB,
                       int bSpawnTrail,
                       float flX,
                       float flY,
                       float flDirX,
                       float flDirY,
                       float flScaleX,
                       float flScaleY) {
    assert(nColor >= 0 && nColor < kPlayerColorMax);
    assert(nEndType >= 0 && nEndType < kPlayerColorMax);

    int nKind;
    float flRotation;
    if (nEndType != kEndTypeHead) {
        nKind = nColor == 1 ? kTailKindColor1 : kTailKindColor0;
        flRotation = static_cast<float>(
            std::atan2(static_cast<double>(-flDirY), static_cast<double>(flDirX)) + kTailAngleBias);
    } else {
        if (nColor == 1) {
            nKind = nShapeFlagA != 0 ? (nShapeFlagB != 0 ? 0xb : 0xa) : (nShapeFlagB != 0 ? 3 : 1);
        } else {
            nKind = nShapeFlagA != 0 ? (nShapeFlagB != 0 ? 9 : 8) : (nShapeFlagB != 0 ? 2 : 0);
        }
        flRotation =
            GameSystem::GetGameSystem()->GetPlayColor() == nColor ? 0.0f : kHeadMirrorRotation;
    }

    for (int nSlot = g_nParticleActiveIndex; nSlot < kParticleCount; ++nSlot) {
        Particle &particle = m_aParticles[nSlot];
        if (!particle.bActive) {
            particle.nKind = nKind;
            particle.bActive = true;
            particle.flX = flX;
            particle.flY = flY;
            particle.flRotation = flRotation;
            particle.flScaleX = flScaleX;
            particle.flScaleY = flScaleY;
            ++g_nParticleActiveIndex;
            if (bSpawnTrail != 0) {
                SpawnParticle(flX, flY, flScaleX, flScaleY, nColor);
            }
            return;
        }
    }
}
