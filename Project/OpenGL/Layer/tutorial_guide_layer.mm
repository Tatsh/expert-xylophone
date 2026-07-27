#include "tutorial_guide_layer.h"

#include "deviceenvironment.h"
#include "gamesystem.h"
#include "neRender.h"
#include "neSpriteInstancing.h"
#include "neTexture.h"
#import "s_vector2.h"

// The process-wide tutorial-guide layer, created lazily by shared().
static TutorialGuideLayer *g_pTutorialGuideLayer = nullptr; // @ghidraAddress 0x3dcae0

namespace {

// The atlas the guide draws from (@ghidraAddress 0x3ceb10).
constexpr const char *kTextureName = "00_texture/gm_tutorial";

// The game-system tutorial phase the guide sets while it is showing.
constexpr int kTutorialPhaseGuideActive = 7;

// The fade state that marks the guide hidden/fading out (the Update dispatcher treats a state at or
// above this value as the fade-out path).
constexpr short kFadeStateHidden = 0x100;

// Sprite kinds above this index are the small tap glyphs, halved on the phone (non-pad).
constexpr unsigned int kTapGlyphKindBound = 4;

// The gauge-anchored blend offsets (@ghidraAddress 0x2f8568 X, 0x301f94 Y): the sprite is recentred
// between its position and the cached gauge coordinate.
constexpr float kGaugeBlendOffsetX = -384.0f;
constexpr float kGaugeBlendOffsetY = -680.0f;
constexpr float kGaugeBlendHalf = 0.5f;

// One guide sprite-kind descriptor (@ghidraAddress 0x3021e0, stride 0x18): the target instancer, the
// anchor and size, and the index into the UV table below.
struct SpriteKindDescriptor {
    int nInstancer;
    float flAnchorX;
    float flAnchorY;
    float flSizeW;
    float flSizeH;
    int nUvIndex;
};
constexpr SpriteKindDescriptor kSpriteKinds[] = {
    {0, 0.5f, 0.5f, 1.0f, 1.0f, 0},
    {0, 0.5f, 0.5f, 1.0f, 1.0f, 0},
    {0, 0.5f, 0.5f, 1.0f, 1.0f, 0},
    {0, 0.5f, 0.5f, 1.0f, 1.0f, 0},
    {0, 0.5f, 0.5f, 1.0f, 1.0f, 0},
    {0, 8.0f, 8.0f, 16.0f, 16.0f, 3},
    {0, 8.0f, 8.0f, 16.0f, 16.0f, 4},
    {0, 8.0f, 8.0f, 16.0f, 16.0f, 5},
    {0, 8.0f, 8.0f, 16.0f, 16.0f, 6},
    {0, 68.0f, 144.0f, 136.0f, 144.0f, 1},
    {0, 20.0f, 63.0f, 397.0f, 126.0f, 9},
};

// The UV rectangles the descriptors index (@ghidraAddress 0x2f8348, stride 0x10): UV origin and UV
// size.
struct UvRect {
    float flOriginU;
    float flOriginV;
    float flSizeU;
    float flSizeV;
};
constexpr UvRect kUvRects[] = {
    {0.49023f, 0.07617f, 0.00098f, 0.00098f},
    {0.35254f, 0.00195f, 0.13281f, 0.14062f},
    {0.48730f, 0.00195f, 0.06641f, 0.07031f},
    {0.48730f, 0.07422f, 0.01562f, 0.01562f},
    {0.50293f, 0.07422f, 0.01562f, 0.01562f},
    {0.48730f, 0.08984f, 0.01562f, 0.01562f},
    {0.50293f, 0.08984f, 0.01562f, 0.01562f},
    {0.55566f, 0.00195f, 0.07031f, 0.13281f},
    {0.62793f, 0.00195f, 0.07031f, 0.13281f},
    {0.35254f, 0.14453f, 0.38867f, 0.13086f},
};

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

/** @ghidraAddress 0x10b308 */
TutorialGuideLayer::TutorialGuideLayer() {
    // The base constructor runs first; every member is zero-initialised by its in-class initialiser,
    // matching the binary's explicit zero-clear of the texture, sprite, counts, flags, clock, and
    // coordinate table.
}

/** @ghidraAddress 0x10cda4 */
void TutorialGuideLayer::EmitTutorialSpriteSlot(
    float flSizeX, float flSizeY, unsigned int nSpriteKind, float *pPosition, int nAlpha) {
    const SpriteKindDescriptor &kind = kSpriteKinds[nSpriteKind];
    ne::C_SPRITE_INSTANCING_2D *pInstancer = m_pSprite;
    const int nIndex = pInstancer->GetSpriteCount();
    if (nIndex >= static_cast<int>(pInstancer->GetCapacity())) {
        return;
    }

    const UvRect &uv = kUvRects[kind.nUvIndex];

    // In the gauge-anchored mode (any non-zero fade state low byte) the sprite is recentred between
    // its own position and the cached gauge coordinate; the portrait variant additionally halves the
    // X blend.
    if ((m_nFadeState & 0xff) != 0) {
        float flY;
        if (!IsPad()) {
            pPosition[0] = (pPosition[0] + kGaugeBlendOffsetX) * kGaugeBlendHalf +
                           m_flGaugeX * kGaugeBlendHalf;
            flY = (pPosition[1] + kGaugeBlendOffsetY) * kGaugeBlendHalf;
        } else {
            flY = pPosition[1] + kGaugeBlendOffsetY;
        }
        pPosition[1] = flY + m_flGaugeY * kGaugeBlendHalf;
    }

    pInstancer->SetSpritePosition(nIndex, S_VECTOR2{pPosition[0], pPosition[1]});
    pInstancer->SetSpriteAnchor(nIndex, S_VECTOR2{kind.flAnchorX, kind.flAnchorY});
    pInstancer->SetSpriteSize(nIndex, S_VECTOR2{kind.flSizeW, kind.flSizeH});
    pInstancer->SetSpriteUvOrigin(nIndex, S_VECTOR2{uv.flOriginU, uv.flOriginV});
    pInstancer->SetSpriteUvSize(nIndex, S_VECTOR2{uv.flSizeU, uv.flSizeV});

    // On the phone (non-pad) the small tap glyphs draw at half scale.
    if (!IsPad() && nSpriteKind > kTapGlyphKindBound) {
        flSizeX *= kGaugeBlendHalf;
        flSizeY *= kGaugeBlendHalf;
    }
    pInstancer->SetSpriteScale(nIndex, flSizeX, flSizeY);
    pInstancer->SetSpriteColor(nIndex, 0xff, 0xff, 0xff, static_cast<unsigned int>(nAlpha));
    pInstancer->SetSpriteCount(nIndex + 1);
}

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

/** @ghidraAddress 0x10b734 */
void TutorialGuideLayer::Stop() {
    m_bActive = false;
}

/** @ghidraAddress 0x10b73c */
void TutorialGuideLayer::StartFadeIn() {
    m_nFadeState = 1;
}

/** @ghidraAddress 0x10b70c */
void TutorialGuideLayer::Start() {
    m_bActive = true;
    m_flClock = 0.0f;
    GameSystem::GetGameSystem()->SetTutorialPhase(kTutorialPhaseGuideActive);
}

/** @ghidraAddress 0x10b748 */
void TutorialGuideLayer::Reset() {
    m_nFadeState = kFadeStateHidden;
    GameSystem::GetGameSystem()->SetTutorialPhase(0);
    m_flStateTimer = 0.0f;
}

/** @ghidraAddress 0x10b350 */
void TutorialGuideLayer::Release() {
    if (m_pTexture != nullptr) {
        m_pTexture->Release();
        m_pTexture = nullptr;
    }
    if (m_pSprite != nullptr) {
        // The sprite node is owned by the scene graph; flag it for the scene walker to delete.
        m_pSprite->RequestDelete();
        m_pSprite = nullptr;
    }
    m_bBuilt = false;
}

/** @ghidraAddress 0x10b400 */
void TutorialGuideLayer::destroyShared() {
    if (g_pTutorialGuideLayer != nullptr) {
        g_pTutorialGuideLayer->Release();
        delete g_pTutorialGuideLayer;
        g_pTutorialGuideLayer = nullptr;
    }
}
