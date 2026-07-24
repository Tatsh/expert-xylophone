#include "tutorial_guide_layer.h"

#import "neEngineBridge.h"
#include "neRender.h"
#include "neSpriteInstancing.h"
#include "neTexture.h"

// The process-wide tutorial-guide layer, created lazily by shared().
static TutorialGuideLayer *g_pTutorialGuideLayer = nullptr; // @ghidraAddress 0x3dcae0

namespace {

// The atlas the guide draws from (@ghidraAddress 0x3ceb10).
constexpr const char *kTextureName = "00_texture/gm_tutorial";

// The nine keyframe timings (start X, end X, step index) the guide sweep uses (@ghidraAddress
// 0x10b4bc onwards, in the constructor's immediate stores).
constexpr TutorialGuideLayer::Keyframe kKeyframes[] = {
    {1683.3333740234375f, 6666.66650390625f, 0},
    {7016.66650390625f, 12016.6669921875f, 1},
    {12350.0f, 17350.0f, 2},
    {35666.66796875f, 37666.66796875f, 3},
    {38000.0f, 40000.0f, 4},
    {40333.33203125f, 42666.66796875f, 5},
    {65333.33203125f, 72000.0f, 6},
    {103333.3359375f, 106500.0f, 7},
    {106833.3359375f, 110000.0f, 8},
};

// The two trailing step indices stored after the keyframes.
constexpr int kStepHi0 = 14;
constexpr int kStepHi1 = 15;

// The seven sprite frame indices (@ghidraAddress 0x301f00) and the three trailing frame counters.
constexpr int kFrameIndices[] = {16, 17, 18, 19, 20, 21, 22};

// The four screen-coordinate pairs seeded at +0xb4 (@ghidraAddress 0x301f00 floats onwards).
constexpr float kCoords[] = {384.0f, 680.0f, 216.0f, 594.0f, 200.0f, 800.0f, 394.0f, 586.0f};

// The per-column offset table added to each keyframe's end X for grid A (@ghidraAddress 0x302058);
// grid B uses the table at 0x301f98. Each entry is an X offset and a tag (a sprite frame or enable
// flag). Every keyframe row reuses the same four-row block, so only the block is stored here.
constexpr TutorialGuideLayer::CoordEntry kOffsetsA[TutorialGuideLayer::kGridColumns] = {
    {0.0f, 0}, {233.333f, 1}, {250.0f, 1}, {-250.0f, 1}, {-233.333f, 1}, {0.0f, 0}};

// The per-column offset table for grid B; its last row narrows the inner taps and clears their tags.
constexpr TutorialGuideLayer::CoordEntry
    kOffsetsB[TutorialGuideLayer::kGridRows][TutorialGuideLayer::kGridColumns] = {
        {{0.0f, 0}, {166.667f, 1}, {250.0f, 1}, {-250.0f, 1}, {-166.667f, 1}, {0.0f, 0}},
        {{0.0f, 0}, {166.667f, 1}, {250.0f, 1}, {-250.0f, 1}, {-166.667f, 1}, {0.0f, 0}},
        {{0.0f, 0}, {166.667f, 1}, {250.0f, 1}, {-250.0f, 1}, {-166.667f, 1}, {0.0f, 0}},
        {{0.0f, 0}, {83.333f, 0}, {250.0f, 1}, {-250.0f, 1}, {-83.333f, 0}, {0.0f, 0}}};

// The column index at and beyond which a grid row switches from the keyframe's start X to its end X.
constexpr int kEndColumnThreshold = 3;

} // namespace

/** @ghidraAddress 0x10b3b0 */
TutorialGuideLayer *TutorialGuideLayer::shared() {
    if (g_pTutorialGuideLayer == nullptr) {
        // The binary allocates the raw 0xe70-byte object and runs its initialiser.
        g_pTutorialGuideLayer = new TutorialGuideLayer();
    }
    return g_pTutorialGuideLayer;
}

/** @ghidraAddress 0x10b44c */
void TutorialGuideLayer::BuildTutorialGuideSpriteTable() {
    // The transient visibility byte is cleared on every call, before the built-once guard.
    m_aReserved08[0] = 0;
    if (m_bBuilt) {
        return;
    }

    m_pTexture = ne::C_TEXTURE::FindOrLoadCached(kTextureName);
    m_pSprite = ne::CreateSpriteInstancer(kSpriteCapacity);
    m_pSprite->RegisterGlobal();
    m_pSprite->SetVisible(true);
    m_pSprite->SetRefCountedMember(m_pTexture);
    m_pSprite->SetSpriteCount(m_nSpriteCount);
    m_bBuilt = true;

    // Seed the keyframe timings, the trailing step indices, the frame-index table, and the screen
    // coordinates.
    for (int nKeyframe = 0; nKeyframe < kKeyframeCount; ++nKeyframe) {
        m_aKeyframes[nKeyframe] = kKeyframes[nKeyframe];
    }
    m_nStepHi0 = kStepHi0;
    m_nStepHi1 = kStepHi1;
    for (int nFrame = 0; nFrame < static_cast<int>(sizeof(kFrameIndices) / sizeof(*kFrameIndices));
         ++nFrame) {
        m_aFrameIndices[nFrame] = kFrameIndices[nFrame];
    }
    for (int nCoord = 0; nCoord < static_cast<int>(sizeof(kCoords) / sizeof(*kCoords)); ++nCoord) {
        m_aCoords[nCoord] = kCoords[nCoord];
    }

    // Fill the two per-step coordinate grids: for each keyframe, each row, and each column, offset
    // the keyframe's base X (its start X for the first columns, its end X for the rest) by the
    // per-column offset table, carrying the offset's tag alongside.
    for (int nKeyframe = 0; nKeyframe < kKeyframeCount; ++nKeyframe) {
        const Keyframe &keyframe = m_aKeyframes[nKeyframe];
        for (int nRow = 0; nRow < kGridRows; ++nRow) {
            for (int nColumn = 0; nColumn < kGridColumns; ++nColumn) {
                const float flBaseX =
                    nColumn < kEndColumnThreshold ? keyframe.flStartX : keyframe.flEndX;
                m_aGridA[nKeyframe][nRow][nColumn].flX = flBaseX + kOffsetsA[nColumn].flX;
                m_aGridA[nKeyframe][nRow][nColumn].nTag = kOffsetsA[nColumn].nTag;
                m_aGridB[nKeyframe][nRow][nColumn].flX = flBaseX + kOffsetsB[nRow][nColumn].flX;
                m_aGridB[nKeyframe][nRow][nColumn].nTag = kOffsetsB[nRow][nColumn].nTag;
            }
        }
    }
}
