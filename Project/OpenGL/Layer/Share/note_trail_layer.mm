#include "note_trail_layer.h"

#include <cassert>

#include "bg_layer.h"
#include "gamesystem.h"
#include "neRender.h"
#include "neSpriteInstancing.h"
#include "neTexture.h"
#include "s_vector2.h"
#include "sprite_uv_table.h"

static NoteTrailLayer *g_pNoteTrailLayer = nullptr; // @ghidraAddress 0x3def20

static int g_nNoteTrailCounter = 0; // @ghidraAddress 0x3def18

namespace {

// @ghidraAddress 0x3ceaa0
constexpr const char *kTextureName = "00_texture/gm_parts1";

constexpr int kAdditiveBlendMode = 1;

constexpr int kTexParamSlotHigh = 1;
constexpr int kTexParamSlotLow = 0;
constexpr int kTexParamEnabled = 1;

constexpr float kSpinPhaseAWrap = 3000.0f;                   // @ghidraAddress 0x2fcf80
constexpr float kSpinPhaseAStep = -3000.0f;                  // @ghidraAddress 0x2fcf84
constexpr float kSpinPhaseBWrap = 133.33333f;                // @ghidraAddress 0x2fcf88 (400/3)
constexpr float kSpinPhaseBStep = -133.33333f;               // @ghidraAddress 0x2fcf8c
constexpr double kRotationHalfTurn = 3.14159265358979323846; // @ghidraAddress 0x2f85a0 (pi)
constexpr double kRotationPeriod = 3000.0;                   // @ghidraAddress 0x2fcfa0

constexpr float kResultAnchor = 58.0f; // @ghidraAddress 0x2fcf90
constexpr float kResultSize = 116.0f;  // @ghidraAddress 0x2fcf94

constexpr int kSpinFrameCount = 4;
constexpr int kJudge1SpriteType = 4;
constexpr int kJudge2SpriteType = 5;

// @ghidraAddress 0x30e300
constexpr int kResultUvIndex[NoteTrailLayer::kResultSpriteTypeCount] = {83, 84, 85, 86, 87, 88};

} // namespace

// @ghidraAddress 0x2ef668
extern const SpriteUvEntry g_aScoreGaugeUvTable[];
const SpriteUvEntry g_aScoreGaugeUvTable[] = {
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
    {0.001953125f, 0.028320312f, 0.056640625f, -0.026367188f},
    {0.001953125f, 0.057617188f, 0.056640625f, -0.026367188f},
    {0.001953125f, 0.08691406f, 0.056640625f, -0.026367188f},
    {0.001953125f, 0.08691406f, 0.056640625f, -0.026367188f},
    {0.001953125f, 0.001953125f, 0.056640625f, 0.026367188f},
    {0.001953125f, 0.03125f, 0.056640625f, 0.026367188f},
    {0.001953125f, 0.060546875f, 0.056640625f, 0.026367188f},
    {0.001953125f, 0.060546875f, 0.056640625f, 0.026367188f},
    {0.060546875f, 0.06542969f, 0.078125f, 0.017578125f},
    {0.140625f, 0.06542969f, 0.078125f, 0.017578125f},
    {0.22070312f, 0.06542969f, 0.078125f, 0.017578125f},
    {0.22070312f, 0.06542969f, 0.078125f, 0.017578125f},
    {0.001953125f, 0.234375f, 0.09375f, 0.07421875f},
    {0.09765625f, 0.234375f, 0.09375f, 0.07421875f},
    {0.19335938f, 0.234375f, 0.09375f, 0.07421875f},
    {0.2890625f, 0.234375f, 0.09375f, 0.07421875f},
    {0.001953125f, 0.18554688f, 0.09375f, 0.046875f},
    {0.09765625f, 0.18554688f, 0.09375f, 0.046875f},
    {0.19335938f, 0.18554688f, 0.09375f, 0.046875f},
    {0.2890625f, 0.18554688f, 0.09375f, 0.046875f},
    {0.31054688f, 0.001953125f, 0.09765625f, 0.0859375f},
    {0.41015625f, 0.001953125f, 0.09765625f, 0.0859375f},
    {0.31054688f, 0.001953125f, 0.09765625f, 0.0859375f},
    {0.41015625f, 0.001953125f, 0.09765625f, 0.0859375f},
    {0.001953125f, 0.028320312f, 0.056640625f, -0.026367188f},
    {0.001953125f, 0.057617188f, 0.056640625f, -0.026367188f},
    {0.001953125f, 0.001953125f, 0.056640625f, 0.026367188f},
    {0.001953125f, 0.03125f, 0.056640625f, 0.026367188f},
    {0.060546875f, 0.06542969f, 0.078125f, 0.017578125f},
    {0.140625f, 0.06542969f, 0.078125f, 0.017578125f},
    {0.45898438f, 0.5546875f, 0.09375f, 0.07421875f},
    {0.5546875f, 0.5546875f, 0.09375f, 0.07421875f},
    {0.001953125f, 0.18554688f, 0.09375f, 0.046875f},
    {0.09765625f, 0.18554688f, 0.09375f, 0.046875f},
    {0.31054688f, 0.001953125f, 0.09765625f, 0.0859375f},
    {0.41015625f, 0.001953125f, 0.09765625f, 0.0859375f},
    {0.5214844f, 0.08984375f, 0.056640625f, -0.026367188f},
    {0.5214844f, 0.08984375f, 0.056640625f, 0.026367188f},
    {0.5214844f, 0.12011719f, 0.078125f, 0.017578125f},
    {0.45898438f, 0.31445312f, 0.09375f, 0.09375f},
    {0.5546875f, 0.31445312f, 0.09375f, 0.09375f},
    {0.6503906f, 0.31445312f, 0.09375f, 0.09375f},
    {0.001953125f, 0.734375f, 0.09375f, 0.09375f},
    {0.2890625f, 0.734375f, 0.09375f, 0.09375f},
    {0.09765625f, 0.734375f, 0.09375f, 0.09375f},
    {0.38476562f, 0.734375f, 0.09375f, 0.09375f},
    {0.19335938f, 0.734375f, 0.09375f, 0.09375f},
    {0.48046875f, 0.734375f, 0.09375f, 0.09375f},
    {0.640625f, 0.08203125f, 0.013671875f, 0.015625f},
    {0.65625f, 0.08203125f, 0.013671875f, 0.015625f},
    {0.18554688f, 0.001953125f, 0.060546875f, 0.060546875f},
    {0.24804688f, 0.001953125f, 0.060546875f, 0.060546875f},
    {0.7714844f, 0.001953125f, 0.1171875f, 0.11328125f},
    {0.7714844f, 0.1171875f, 0.1171875f, 0.11328125f},
    {0.890625f, 0.001953125f, 0.03125f, 0.03125f},
    {0.890625f, 0.03515625f, 0.03125f, 0.03125f},
    {0.890625f, 0.068359375f, 0.029296875f, 0.029296875f},
    {0.9238281f, 0.001953125f, 0.03125f, 0.03125f},
    {0.9238281f, 0.03515625f, 0.03125f, 0.03125f},
    {0.9238281f, 0.068359375f, 0.029296875f, 0.029296875f},
    {0.001953125f, 0.41503906f, 0.15039062f, 0.15039062f},
    {0.15429688f, 0.41503906f, 0.15039062f, 0.15039062f},
    {0.30664062f, 0.41503906f, 0.15039062f, 0.15039062f},
    {0.001953125f, 0.57714844f, 0.15039062f, 0.15039062f},
    {0.15429688f, 0.57714844f, 0.15039062f, 0.15039062f},
    {0.30664062f, 0.57714844f, 0.15039062f, 0.15039062f},
    {0.6503906f, 0.5058594f, 0.1640625f, 0.1640625f},
    {0.81640625f, 0.5058594f, 0.1640625f, 0.1640625f},
    {0.6503906f, 0.671875f, 0.1640625f, 0.1640625f},
    {0.81640625f, 0.671875f, 0.1640625f, 0.1640625f},
    {0.49902344f, 0.08984375f, 0.0009765625f, 0.09765625f},
    {0.5048828f, 0.08984375f, 0.0009765625f, 0.09765625f},
    {0.5107422f, 0.15820312f, 0.0009765625f, 0.01953125f},
    {0.51660156f, 0.15820312f, 0.0009765625f, 0.01953125f},
    {0.5107422f, 0.08984375f, 0.0009765625f, 0.06640625f},
    {0.51660156f, 0.08984375f, 0.0009765625f, 0.06640625f},
    {0.001953125f, 0.8769531f, 0.484375f, 0.12109375f},
    {0.48828125f, 0.8769531f, 0.484375f, 0.12109375f},
    {0.7128906f, 0.1015625f, 0.056640625f, 0.048828125f},
};

/** @ghidraAddress 0x1846b0 */
NoteTrailLayer::NoteTrailLayer() {
    g_nNoteTrailCounter = 0;
}

/** @ghidraAddress 0x184708 */
NoteTrailLayer *NoteTrailLayer::shared() {
    if (g_pNoteTrailLayer == nullptr) {
        g_pNoteTrailLayer = new NoteTrailLayer();
    }
    return g_pNoteTrailLayer;
}

/** @ghidraAddress 0x184758 */
void NoteTrailLayer::LoadNoteTrailSprites() {
    if (m_bBuilt) {
        return;
    }

    // The sprite hangs beneath the background layer's render object, not the global scene root.
    BgLayer *pBackgroundLayer = BgLayer::GetBackgroundLayer();
    ne::C_RENDER *pParent = pBackgroundLayer->GetBackgroundRenderObject();

    m_pTexture = ne::C_TEXTURE::FindOrLoadCached(kTextureName);

    m_pSprite = ne::CreateWorldSpriteBatch(kSpriteCapacity);
    pParent->AttachChild(m_pSprite);
    m_pSprite->SetVisible(true);
    m_pSprite->SetRefCountedMember(m_pTexture);
    m_pSprite->SetSpriteCount(0);
    m_pSprite->SetBlendMode(kAdditiveBlendMode);
    if (!IsHardwareType9()) {
        m_pSprite->SetTexParam(kTexParamSlotHigh, kTexParamEnabled);
        m_pSprite->SetTexParam(kTexParamSlotLow, kTexParamEnabled);
    }

    m_bBuilt = true;
}

/** @ghidraAddress 0x184800 */
void NoteTrailLayer::Create(int nJudge, float flX, float flY) {
    assert(nJudge >= 0);
    assert(nJudge < kJudgeMax);

    for (int nSlot = g_nNoteTrailCounter; nSlot < kMaxResults; ++nSlot) {
        ResultMark &mark = m_aResults[nSlot];
        if (!mark.bActive) {
            mark.nJudge = nJudge;
            mark.bActive = true;
            mark.position.x = flX;
            mark.position.y = flY;
            ++g_nNoteTrailCounter;
            return;
        }
    }
}

/** @ghidraAddress 0x1848b0 */
void NoteTrailLayer::Update(float flDeltaSeconds) {
    m_nSpriteCount = 0;

    m_flSpinPhaseA += flDeltaSeconds;
    while (m_flSpinPhaseA > kSpinPhaseAWrap) {
        m_flSpinPhaseA += kSpinPhaseAStep;
    }
    const float flRotation = static_cast<float>(static_cast<double>(m_flSpinPhaseA * 2.0f) *
                                                kRotationHalfTurn / kRotationPeriod);

    m_flSpinPhaseB += flDeltaSeconds;
    while (m_flSpinPhaseB >= kSpinPhaseBWrap) {
        m_flSpinPhaseB += kSpinPhaseBStep;
    }
    int nSpinFrame = static_cast<int>(m_flSpinPhaseB / kSpinPhaseBWrap * kSpinFrameCount);
    if (nSpinFrame < 0) {
        nSpinFrame = 0;
    } else if (nSpinFrame >= kSpinFrameCount) {
        nSpinFrame = kSpinFrameCount - 1;
    }

    const float flScale = GameSystem::GetGameSystem()->GetSheetRadiusScaled();

    for (int nSlot = 0; nSlot < kMaxResults; ++nSlot) {
        ResultMark &mark = m_aResults[nSlot];
        if (nSlot >= g_nNoteTrailCounter) {
            mark.bActive = false;
            continue;
        }
        if (!mark.bActive) {
            continue;
        }
        mark.bActive = false;

        unsigned int nSpriteType;
        if (mark.nJudge == 0) {
            nSpriteType = static_cast<unsigned int>(nSpinFrame);
        } else if (mark.nJudge == 2) {
            nSpriteType = kJudge2SpriteType;
        } else {
            assert(mark.nJudge == 1);
            nSpriteType = kJudge1SpriteType;
        }
        CreateSprite(nSpriteType, &mark.position, 0xff, flRotation, flScale, flScale);
    }

    m_pSprite->SetSpriteCount(m_nSpriteCount);
    g_nNoteTrailCounter = 0;
}

/** @ghidraAddress 0x184a48 */
void NoteTrailLayer::CreateSprite(unsigned int nSpriteType,
                                  const S_VECTOR2 *pPosition,
                                  unsigned int nAlpha,
                                  float flRotation,
                                  float flScaleX,
                                  float flScaleY) {
    assert(static_cast<int>(nSpriteType) >= 0);
    assert(static_cast<int>(nSpriteType) < kResultSpriteTypeCount);

    const SpriteUvEntry &uv = g_aScoreGaugeUvTable[kResultUvIndex[nSpriteType]];
    const int nIndex = m_nSpriteCount;

    m_pSprite->SetSpritePosition(nIndex, *pPosition);
    m_pSprite->SetSpriteAnchor(nIndex, S_VECTOR2{kResultAnchor, kResultAnchor});
    m_pSprite->SetSpriteSize(nIndex, S_VECTOR2{kResultSize, kResultSize});
    m_pSprite->SetSpriteUvOrigin(nIndex, S_VECTOR2{uv.flOriginU, uv.flOriginV});
    m_pSprite->SetSpriteUvSize(nIndex, S_VECTOR2{uv.flSizeU, uv.flSizeV});
    m_pSprite->SetSpriteRotation(nIndex, flRotation);
    m_pSprite->SetSpriteScale(nIndex, flScaleX, flScaleY);
    m_pSprite->SetSpriteColor(nIndex, 0xff, 0xff, 0xff, nAlpha);

    ++m_nSpriteCount;
}
