#include "note_trail_layer.h"

#include <cassert>

#include "bg_layer.h"
#include "gamesystem.h"
#include "neRender.h"
#include "neSpriteInstancing.h"
#include "neTexture.h"
#include "s_vector2.h"
#include "sprite_uv_table.h"

// The process-wide note-trail layer, created lazily by shared().
static NoteTrailLayer *g_pNoteTrailLayer = nullptr; // @ghidraAddress 0x3def20

// A shared note-trail counter the constructor resets.
static int g_nNoteTrailCounter = 0; // @ghidraAddress 0x3def18

namespace {

// The atlas the note trails draw from (@ghidraAddress 0x3ceaa0).
constexpr const char *kTextureName = "00_texture/gm_parts1";

// The additive blend-mode identifier the trail batch uses.
constexpr int kAdditiveBlendMode = 1;

// The two texture-environment parameter slots the builder seeds (to 1 each), and that value.
constexpr int kTexParamSlotHigh = 1;
constexpr int kTexParamSlotLow = 0;
constexpr int kTexParamEnabled = 1;

// The result-queue spin/rotation constants. Phase A wraps to (0, 3000] and drives the sprite
// rotation (phaseA*2 * pi / 3000); phase B wraps to [0, 400/3) and selects the spin frame.
constexpr float kSpinPhaseAWrap = 3000.0f;                   // @ghidraAddress 0x2fcf80
constexpr float kSpinPhaseAStep = -3000.0f;                  // @ghidraAddress 0x2fcf84
constexpr float kSpinPhaseBWrap = 133.33333f;                // @ghidraAddress 0x2fcf88 (400/3)
constexpr float kSpinPhaseBStep = -133.33333f;               // @ghidraAddress 0x2fcf8c
constexpr double kRotationHalfTurn = 3.14159265358979323846; // @ghidraAddress 0x2f85a0 (pi)
constexpr double kRotationPeriod = 3000.0;                   // @ghidraAddress 0x2fcfa0

// The fixed result-mark anchor and size every result sprite uses.
constexpr float kResultAnchor = 58.0f; // @ghidraAddress 0x2fcf90
constexpr float kResultSize = 116.0f;  // @ghidraAddress 0x2fcf94

// The number of spin frames (sprite types 0..3) judge-0 marks cycle through, and the fixed sprite
// types the other two judges emit.
constexpr int kSpinFrameCount = 4;
constexpr int kJudge1SpriteType = 4;
constexpr int kJudge2SpriteType = 5;

// The UV-table index each of the six result sprite types samples (@ghidraAddress 0x30e300).
constexpr int kResultUvIndex[NoteTrailLayer::kResultSpriteTypeCount] = {83, 84, 85, 86, 87, 88};

} // namespace

// The shared sprite-UV atlas the result sprite types index (@ghidraAddress 0x2ef668).
extern const SpriteUvEntry g_aScoreGaugeUvTable[];

/** @ghidraAddress 0x1846b0 */
NoteTrailLayer::NoteTrailLayer() {
    g_nNoteTrailCounter = 0;
}

/** @ghidraAddress 0x184708 */
NoteTrailLayer *NoteTrailLayer::shared() {
    if (g_pNoteTrailLayer == nullptr) {
        // The binary allocates the raw 0x2b0-byte object and runs the constructor.
        g_pNoteTrailLayer = new NoteTrailLayer();
    }
    return g_pNoteTrailLayer;
}

/** @ghidraAddress 0x184758 */
void NoteTrailLayer::LoadNoteTrailSprites() {
    if (m_bBuilt) {
        return;
    }

    // The sprite hangs beneath the shared background layer's render object rather than the global
    // scene root.
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

    // Claim the first free queue slot; drop the mark when the queue is full.
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

    // Advance the rotation spin phase, wrapping it down into (0, 3000].
    m_flSpinPhaseA += flDeltaSeconds;
    while (m_flSpinPhaseA > kSpinPhaseAWrap) {
        m_flSpinPhaseA += kSpinPhaseAStep;
    }
    const float flRotation = static_cast<float>(static_cast<double>(m_flSpinPhaseA * 2.0f) *
                                                kRotationHalfTurn / kRotationPeriod);

    // Advance the frame-select spin phase, wrapping it down into [0, 400/3), and derive the spin
    // frame (0 through 3).
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

    // Every result sprite is scaled by the game system's scaled sheet radius.
    const float flScale = GameSystem::GetGameSystem()->GetSheetRadiusScaled();

    // Emit each queued mark's sprite, then clear the queue.
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

        // Judge 0 shows the current spin frame; judges 1 and 2 show their fixed graphics.
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

    // Publish the frame's sprite count to the batch and reset the queue.
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
