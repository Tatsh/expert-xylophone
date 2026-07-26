#include "slide_note_result_layer.h"

#include <cassert>
#include <cmath>

#include "bg_layer.h"
#include "gamesystem.h"
#include "neRender.h"
#include "neSpriteInstancing.h"
#include "neTexture.h"
#import "s_vector2.h"

// The process-wide slide-note result layer, created lazily by shared().
static SlideNoteResultLayer *g_pSlideNoteResultLayer = nullptr; // @ghidraAddress 0x3dc2f0

// The count of result marks queued this frame, shared across Create and Update.
static int g_nSlideResultCount = 0; // @ghidraAddress 0x3dc2e8

namespace {

// The atlas the result marks draw from (@ghidraAddress 0x3ceaa0).
constexpr const char *kTextureName = "00_texture/gm_parts1";

// The sprite-batch capacity (@ghidraAddress 0x66b40).
constexpr unsigned int kBatchCapacity = 40;

// The additive-style blend flag the batch sets.
constexpr int kBlendModeAdditive = 1;

// The first spin phase wraps within (-kSpinPhaseAWrap, kSpinPhaseAWrap] each frame; the second
// wraps within [-kSpinPhaseBWrap, kSpinPhaseBWrap). (@ghidraAddress 0x2fcf80, 0x2fcf88.)
constexpr float kSpinPhaseAWrap = 3000.0f;
constexpr float kSpinPhaseBWrap = 400.0f / 3.0f;

// The result sprite's fixed anchor and size (@ghidraAddress 0x2fcf90, 0x2fcf94).
constexpr float kSpriteAnchor = 58.0f;
constexpr float kSpriteSize = 116.0f;

// The first spin phase drives the sprite rotation as 2 * phase * pi / kSpinRotationScale
// (@ghidraAddress 0x2fcf98, 0x2fcfa0).
constexpr double kSpinRotationScale = 3000.0;

// The judge-0 result mark animates through this many spin-graphic frames (the second phase's
// fraction times this count, truncated).
constexpr int kSpinFrameCount = 4;

// Each sprite type maps to a UV-table entry (@ghidraAddress 0x2fcfa8): types 0-5 select table
// indices 89, 90, 91, 92, 87, and 88.
constexpr int kSpriteTypeUvIndex[] = {89, 90, 91, 92, 87, 88};

// The UV table the sprite types index (@ghidraAddress 0x2ef668, entry = base + index * 0x10): the
// UV origin and UV size. Only the six entries the result sprites use are listed, keyed by index.
struct UvEntry {
    int nIndex;
    float flOriginU;
    float flOriginV;
    float flSizeU;
    float flSizeV;
};
constexpr UvEntry kUvTable[] = {
    {87, 0.154297f, 0.577148f, 0.150391f, 0.150391f},
    {88, 0.306641f, 0.577148f, 0.150391f, 0.150391f},
    {89, 0.650391f, 0.505859f, 0.164062f, 0.164062f},
    {90, 0.816406f, 0.505859f, 0.164062f, 0.164062f},
    {91, 0.650391f, 0.671875f, 0.164062f, 0.164062f},
    {92, 0.816406f, 0.671875f, 0.164062f, 0.164062f},
};

const UvEntry &LookupUv(int nUvIndex) {
    for (const UvEntry &entry : kUvTable) {
        if (entry.nIndex == nUvIndex) {
            return entry;
        }
    }
    return kUvTable[0];
}

} // namespace

/** @ghidraAddress 0x66a60 */
SlideNoteResultLayer::SlideNoteResultLayer() {
    for (ResultMark &mark : m_aResults) {
        mark.bActive = false;
    }
    g_nSlideResultCount = 0;
}

/** @ghidraAddress 0x66ab8 */
SlideNoteResultLayer *SlideNoteResultLayer::shared() {
    if (g_pSlideNoteResultLayer == nullptr) {
        // The binary allocates the raw 0x350-byte object and runs the constructor.
        g_pSlideNoteResultLayer = new SlideNoteResultLayer();
    }
    return g_pSlideNoteResultLayer;
}

/** @ghidraAddress 0x66b08 */
void SlideNoteResultLayer::BuildSpriteBatch() {
    if (m_bBuilt) {
        return;
    }

    // The batch hangs beneath the shared background layer's render object rather than the global
    // scene root.
    BgLayer *pBackgroundLayer = BgLayer::GetBackgroundLayer();
    ne::C_RENDER *pParent = pBackgroundLayer->GetBackgroundRenderObject();

    m_pTexture = ne::C_TEXTURE::FindOrLoadCached(kTextureName);

    m_pBatch = ne::CreateWorldSpriteBatch(kBatchCapacity);
    pParent->AttachChild(m_pBatch);
    m_pBatch->SetVisible(true);
    m_pBatch->SetRefCountedMember(m_pTexture);
    m_pBatch->SetSpriteCount(0);
    m_pBatch->SetBlendMode(kBlendModeAdditive);

    // The newer hardware sets the two texture-environment parameters; the older type 9 skips them.
    if (!IsHardwareType9()) {
        m_pBatch->SetTexParam(1, 1);
        m_pBatch->SetTexParam(0, 1);
    }

    m_bBuilt = true;
    g_nSlideResultCount = 0;
}

/** @ghidraAddress 0x66bb8 */
void SlideNoteResultLayer::Create(int nJudge, const S_VECTOR2 &position) {
    assert(nJudge >= 0);             // The binary asserts "judge>=0".
    assert(nJudge < kSlideJudgeMax); // The binary asserts "judge<JUDGE_TYPE_MAX".

    if (g_nSlideResultCount >= kMaxResults) {
        return;
    }
    for (int nSlot = g_nSlideResultCount; nSlot < kMaxResults; ++nSlot) {
        ResultMark &mark = m_aResults[nSlot];
        if (!mark.bActive) {
            mark.nJudge = nJudge;
            mark.bActive = true;
            mark.position = position;
            ++g_nSlideResultCount;
            return;
        }
    }
}

/** @ghidraAddress 0x66c6c */
void SlideNoteResultLayer::Update(float flDeltaSeconds) {
    m_nWriteIndex = 0;

    // Advance the first spin phase and wrap it back down into range.
    m_flSpinPhaseA += flDeltaSeconds;
    while (m_flSpinPhaseA > kSpinPhaseAWrap) {
        m_flSpinPhaseA -= kSpinPhaseAWrap;
    }
    // The sprite rotation follows from the first phase.
    const float flRotation =
        static_cast<float>(2.0 * static_cast<double>(m_flSpinPhaseA) * -M_PI / kSpinRotationScale);

    // Advance the second spin phase and wrap it likewise.
    m_flSpinPhaseB += flDeltaSeconds;
    while (m_flSpinPhaseB >= kSpinPhaseBWrap) {
        m_flSpinPhaseB -= kSpinPhaseBWrap;
    }
    // The second phase over its range gives a four-frame graphic index (the phase fraction times
    // four, truncated), clamped to [0, 3]. It is the graphic drawn for a judge-0 result mark.
    int nFrameIndex = static_cast<int>(m_flSpinPhaseB / kSpinPhaseBWrap * kSpinFrameCount);
    if (nFrameIndex < 0) {
        nFrameIndex = 0;
    }
    if (nFrameIndex >= kSpinFrameCount - 1) {
        nFrameIndex = kSpinFrameCount - 1;
    }

    const float flScale = GameSystem::GetGameSystem()->GetSheetRadiusScaled();

    for (int nSlot = 0; nSlot < kMaxResults; ++nSlot) {
        ResultMark &mark = m_aResults[nSlot];
        if (nSlot >= g_nSlideResultCount) {
            mark.bActive = false;
            continue;
        }
        if (!mark.bActive) {
            continue;
        }
        mark.bActive = false;

        // The judge grade selects the sprite graphic: grade 0 draws the current spin-animation
        // frame, grade 1 draws type 4, and grade 2 draws type 5. (The binary asserts the grade is
        // one of 0, 1, or 2.)
        int nSpriteType = nFrameIndex;
        if (mark.nJudge == kSlideJudge1) {
            nSpriteType = kSlideSpriteType4;
        } else if (mark.nJudge == kSlideJudge2) {
            nSpriteType = kSlideSpriteType5;
        } else {
            assert(mark.nJudge == kSlideJudge0); // The binary asserts "0" for any other grade.
        }
        CreateSprite(static_cast<unsigned int>(nSpriteType),
                     &mark.position,
                     0xff,
                     flRotation,
                     flScale,
                     flScale);
    }

    // Publish the frame's sprite count and reset the queue.
    m_pBatch->SetSpriteCount(m_nWriteIndex);
    g_nSlideResultCount = 0;
}

/** @ghidraAddress 0x66e04 */
void SlideNoteResultLayer::CreateSprite(unsigned int nSpriteType,
                                        const S_VECTOR2 *pPosition,
                                        int nAlpha,
                                        float flRotation,
                                        float flScaleX,
                                        float flScaleY) {
    assert(static_cast<int>(nSpriteType) >= 0); // The binary asserts "type>=0".
    assert(nSpriteType < static_cast<unsigned int>(kSlideSpriteTypeMax)); // "type<SPRITE_TYPE_MAX".

    const UvEntry &uv = LookupUv(kSpriteTypeUvIndex[nSpriteType]);
    m_pBatch->SetSpritePosition(m_nWriteIndex, *pPosition);
    m_pBatch->SetSpriteAnchor(m_nWriteIndex, S_VECTOR2{kSpriteAnchor, kSpriteAnchor});
    m_pBatch->SetSpriteSize(m_nWriteIndex, S_VECTOR2{kSpriteSize, kSpriteSize});
    m_pBatch->SetSpriteUvOrigin(m_nWriteIndex, S_VECTOR2{uv.flOriginU, uv.flOriginV});
    m_pBatch->SetSpriteUvSize(m_nWriteIndex, S_VECTOR2{uv.flSizeU, uv.flSizeV});
    m_pBatch->SetSpriteRotation(m_nWriteIndex, flRotation);
    m_pBatch->SetSpriteScale(m_nWriteIndex, flScaleX, flScaleY);
    m_pBatch->SetSpriteColor(m_nWriteIndex, 0xff, 0xff, 0xff, static_cast<unsigned int>(nAlpha));
    ++m_nWriteIndex;
}
