#include "tutorial_guide_layer.h"

#import "RBTutorialManager.h"
#include "curve.h"
#include "deviceenvironment.h"
#include "gamesystem.h"
#include "neDebugLog.h"
#include "neRender.h"
#include "neSpriteInstancing.h"
#include "neTexture.h"
#include "result_window_colette_layer.h"
#import "s_vector2.h"
#include "vectormath.h"

static TutorialGuideLayer *g_pTutorialGuideLayer = nullptr; // @ghidraAddress 0x3dcae0

namespace {

// @ghidraAddress 0x3ceb10
constexpr const char *kTextureName = "00_texture/gm_tutorial";

constexpr int kTutorialPhaseGuideActive = 7;

// Update treats a fade state at or above this value as the fade-out path.
constexpr short kFadeStateHidden = 0x100;

// Sprite kinds above this index are the small tap glyphs, halved on the phone (non-pad).
constexpr unsigned int kTapGlyphKindBound = 4;

// The tutorial walkthrough phases the state machine advances through (game-system field +0x130).
enum {
    kTutorialPhaseIntro = 0,
    kTutorialPhaseHint1 = 1,
    kTutorialPhaseHint2 = 2,
    kTutorialPhaseResult = 3,
    kTutorialPhaseDone = 4,
    kTutorialPhaseComplete = 5,
};

// @ghidraAddress 0x2feff0
constexpr float kTutorialPhaseDwellMs = 2000.0f;

// @ghidraAddress 0x2f8568 X, 0x301f94 Y
constexpr float kGaugeBlendOffsetX = -384.0f;
constexpr float kGaugeBlendOffsetY = -680.0f;
constexpr float kGaugeBlendHalf = 0.5f;

// @ghidraAddress 0x3021e0, stride 0x18
struct SpriteKindDescriptor {
    int nInstancer;
    float flAnchorX;
    float flAnchorY;
    float flSizeW;
    float flSizeH;
    int nUvIndex;
};
constexpr SpriteKindDescriptor kSpriteKinds[] = {
    {0, 0.5f, 0.5f, 1.0f, 1.0f, 0},        {0, 0.5f, 0.5f, 1.0f, 1.0f, 0},
    {0, 0.5f, 0.5f, 1.0f, 1.0f, 0},        {0, 0.5f, 0.5f, 1.0f, 1.0f, 0},
    {0, 0.5f, 0.5f, 1.0f, 1.0f, 0},        {0, 8.0f, 8.0f, 16.0f, 16.0f, 3},
    {0, 8.0f, 8.0f, 16.0f, 16.0f, 4},      {0, 8.0f, 8.0f, 16.0f, 16.0f, 5},
    {0, 8.0f, 8.0f, 16.0f, 16.0f, 6},      {0, 68.0f, 144.0f, 136.0f, 144.0f, 1},
    {0, 20.0f, 63.0f, 397.0f, 126.0f, 9},  {0, 20.0f, 63.0f, 397.0f, 126.0f, 10},
    {0, 36.0f, 68.0f, 72.0f, 136.0f, 7},   {0, 36.0f, 68.0f, 72.0f, 136.0f, 8},
    {0, 178.5f, 26.0f, 357.0f, 52.0f, 11}, {0, 178.5f, 40.0f, 357.0f, 80.0f, 12},
    {0, 178.5f, 26.0f, 357.0f, 52.0f, 13}, {0, 178.5f, 12.0f, 357.0f, 24.0f, 14},
    {0, 178.5f, 26.0f, 357.0f, 52.0f, 15}, {0, 178.5f, 26.0f, 357.0f, 52.0f, 16},
    {0, 178.5f, 40.0f, 357.0f, 80.0f, 17}, {0, 178.5f, 26.0f, 357.0f, 52.0f, 18},
    {0, 178.5f, 26.0f, 357.0f, 52.0f, 19}, {0, 178.5f, 26.0f, 357.0f, 52.0f, 20},
    {0, 178.5f, 26.0f, 357.0f, 52.0f, 21}, {0, 178.5f, 26.0f, 357.0f, 52.0f, 22},
    {0, 178.5f, 40.0f, 357.0f, 80.0f, 23}, {0, 178.5f, 12.0f, 357.0f, 24.0f, 24},
};

// @ghidraAddress 0x2f8348, stride 0x10
struct UvRect {
    float flOriginU;
    float flOriginV;
    float flSizeU;
    float flSizeV;
};
constexpr UvRect kUvRects[] = {
    {0.49023438f, 0.076171875f, 0.0009765625f, 0.0009765625f},
    {0.35253906f, 0.001953125f, 0.1328125f, 0.140625f},
    {0.4873047f, 0.001953125f, 0.06640625f, 0.0703125f},
    {0.4873047f, 0.07421875f, 0.015625f, 0.015625f},
    {0.5029297f, 0.07421875f, 0.015625f, 0.015625f},
    {0.4873047f, 0.08984375f, 0.015625f, 0.015625f},
    {0.5029297f, 0.08984375f, 0.015625f, 0.015625f},
    {0.55566406f, 0.001953125f, 0.0703125f, 0.1328125f},
    {0.6279297f, 0.001953125f, 0.0703125f, 0.1328125f},
    {0.35253906f, 0.14453125f, 0.38867188f, 0.13085938f},
    {0.35253906f, 0.27734375f, 0.41992188f, 0.12109375f},
    {0.001953125f, 0.001953125f, 0.3486328f, 0.05078125f},
    {0.001953125f, 0.0546875f, 0.3486328f, 0.078125f},
    {0.001953125f, 0.13476562f, 0.3486328f, 0.05078125f},
    {0.001953125f, 0.1875f, 0.3486328f, 0.0234375f},
    {0.001953125f, 0.21289062f, 0.3486328f, 0.05078125f},
    {0.001953125f, 0.265625f, 0.3486328f, 0.05078125f},
    {0.001953125f, 0.31835938f, 0.3486328f, 0.078125f},
    {0.001953125f, 0.3984375f, 0.3486328f, 0.05078125f},
    {0.001953125f, 0.45117188f, 0.3486328f, 0.05078125f},
    {0.001953125f, 0.50390625f, 0.3486328f, 0.05078125f},
    {0.001953125f, 0.5566406f, 0.3486328f, 0.05078125f},
    {0.001953125f, 0.609375f, 0.3486328f, 0.05078125f},
    {0.001953125f, 0.6621094f, 0.3486328f, 0.078125f},
    {0.001953125f, 0.7421875f, 0.3486328f, 0.0234375f},
};

// @ghidraAddress 0x10b4bc
constexpr TutorialGuideLayer::Keyframe kKeyframes[] = {
    {1683.3334f, 6666.6665f, 0},
    {7016.6665f, 12016.667f, 1},
    {12350.0f, 17350.0f, 2},
    {35666.66796875f, 37666.66796875f, 3},
    {38000.0f, 40000.0f, 4},
    {40333.33203125f, 42666.66796875f, 5},
    {65333.33203125f, 72000.0f, 6},
    {103333.3359375f, 106500.0f, 7},
    {106833.3359375f, 110000.0f, 8},
};

// @ghidraAddress 0x301f00
constexpr int kStepGlyphKinds[] = {14, 15, 16, 17, 18, 19, 20, 21, 22};

// Seeded at +0xd0. @ghidraAddress 0x301f10, 0x301f20
constexpr float kCoords[] = {384.0f, 680.0f, 216.0f, 594.0f, 200.0f, 800.0f, 394.0f, 586.0f};

// @ghidraAddress 0x301f98, stride 0x30
constexpr TutorialGuideLayer::CoordEntry kGridAOffsets[TutorialGuideLayer::kGridRows]
                                                      [TutorialGuideLayer::kGridColumns] = {
                                                          {{0.0f, 0.0f},
                                                           {166.66667f, 1.0f},
                                                           {250.0f, 1.0f},
                                                           {-250.0f, 1.0f},
                                                           {-166.66667f, 1.0f},
                                                           {0.0f, 0.0f}},
                                                          {{0.0f, 0.0f},
                                                           {166.66667f, 1.0f},
                                                           {250.0f, 1.0f},
                                                           {-250.0f, 1.0f},
                                                           {-166.66667f, 1.0f},
                                                           {0.0f, 0.0f}},
                                                          {{0.0f, 0.0f},
                                                           {166.66667f, 1.0f},
                                                           {250.0f, 1.0f},
                                                           {-250.0f, 1.0f},
                                                           {-166.66667f, 1.0f},
                                                           {0.0f, 0.0f}},
                                                          {{0.0f, 0.0f},
                                                           {83.333336f, 0.0f},
                                                           {250.0f, 1.0f},
                                                           {-250.0f, 1.0f},
                                                           {-83.333336f, 0.0f},
                                                           {0.0f, 0.0f}}};

// The binary indexes this by row as well, but all four of its rows are identical.
// @ghidraAddress 0x302058
constexpr TutorialGuideLayer::CoordEntry kGridBOffsets[TutorialGuideLayer::kGridColumns] = {
    {0.0f, 0.0f},
    {233.33333f, 1.0f},
    {250.0f, 1.0f},
    {-250.0f, 1.0f},
    {-233.33333f, 1.0f},
    {0.0f, 0.0f}};

constexpr int kEndColumnThreshold = 3;

} // namespace

/** @ghidraAddress 0x10b308 */
TutorialGuideLayer::TutorialGuideLayer() {
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

    // A non-zero fade-state low byte is the gauge-anchored mode: the sprite is recentred between
    // its own position and the cached gauge coordinate.
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
        g_pTutorialGuideLayer = new TutorialGuideLayer();
    }
    return g_pTutorialGuideLayer;
}

/** @ghidraAddress 0x10b44c */
void TutorialGuideLayer::BuildTutorialGuideSpriteTable() {
    // Cleared on every call, before the built-once guard.
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

    for (int nKeyframe = 0; nKeyframe < kKeyframeCount; ++nKeyframe) {
        m_aKeyframes[nKeyframe] = kKeyframes[nKeyframe];
    }
    for (int nStep = 0; nStep < kKeyframeCount; ++nStep) {
        m_aStepGlyphKinds[nStep] = kStepGlyphKinds[nStep];
    }
    for (int nCoord = 0; nCoord < static_cast<int>(sizeof(kCoords) / sizeof(*kCoords)); ++nCoord) {
        m_aCoords[nCoord] = kCoords[nCoord];
    }

    for (int nKeyframe = 0; nKeyframe < kKeyframeCount; ++nKeyframe) {
        const Keyframe &keyframe = m_aKeyframes[nKeyframe];
        for (int nRow = 0; nRow < kGridRows; ++nRow) {
            for (int nColumn = 0; nColumn < kGridColumns; ++nColumn) {
                const float flBaseX =
                    nColumn < kEndColumnThreshold ? keyframe.flStartX : keyframe.flEndX;
                m_aGridA[nKeyframe][nRow][nColumn].flX = flBaseX + kGridAOffsets[nRow][nColumn].flX;
                m_aGridA[nKeyframe][nRow][nColumn].flWeight = kGridAOffsets[nRow][nColumn].flWeight;
                m_aGridB[nKeyframe][nRow][nColumn].flX = flBaseX + kGridBOffsets[nColumn].flX;
                m_aGridB[nKeyframe][nRow][nColumn].flWeight = kGridBOffsets[nColumn].flWeight;
            }
        }
    }
}

/** @ghidraAddress 0x10b734 */
void TutorialGuideLayer::Stop(float flDuration) {
    (void)flDuration; // The binary takes a duration in s0 and never reads it.
    // RBPDBG: the tutorial cannot be completed, so every engine-side phase transition is logged.
    if (NE_DBG_FIRST(40)) {
        neDebugLog("tutorialGuide Stop active=%d fade=%d phase=%d",
                   m_bActive ? 1 : 0,
                   m_nFadeState,
                   GameSystem::GetGameSystem()->GetTutorialPhase());
    }
    m_bActive = false;
}

/** @ghidraAddress 0x10b73c */
void TutorialGuideLayer::StartFadeIn() {
    m_nFadeState = 1;
}

/** @ghidraAddress 0x10b70c */
void TutorialGuideLayer::Start() {
    if (NE_DBG_FIRST(40)) {
        neDebugLog("tutorialGuide Start active=%d fade=%d phase=%d",
                   m_bActive ? 1 : 0,
                   m_nFadeState,
                   GameSystem::GetGameSystem()->GetTutorialPhase());
    }
    m_bActive = true;
    m_flClock = 0.0f;
    GameSystem::GetGameSystem()->SetTutorialPhase(kTutorialPhaseGuideActive);
}

/** @ghidraAddress 0x10b748 */
void TutorialGuideLayer::Reset() {
    if (NE_DBG_FIRST(40)) {
        neDebugLog("tutorialGuide Reset active=%d fade=%d phase=%d",
                   m_bActive ? 1 : 0,
                   m_nFadeState,
                   GameSystem::GetGameSystem()->GetTutorialPhase());
    }
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

namespace {
// @ghidraAddress 0x301f70 onwards.
constexpr float kSweepHalfSpan = 166.66667f;     // 0x301f70
constexpr float kSweepHalfSpanNeg = -166.66667f; // 0x301f74
constexpr float kPulseSpan1 = 200.0f;            // 0x301f78
constexpr float kPulseSpan2 = 233.33333f;        // 0x301f7c
constexpr float kPulseSpan3 = 266.66667f;        // 0x301f80
constexpr float kConnectorOffset = -150.0f;      // 0x301f84
constexpr float kFullSpan = 250.0f;              // 0x301f88
constexpr float kFullSpanNeg = -250.0f;          // 0x301f8c
constexpr float kPulseSpan0 = 150.0f;            // 0x2eedc8

constexpr float kScaleOne = 1.0f;
constexpr float kScalePeak = 1.1f;    // 0x3f8ccccd
constexpr float kScaleSettle = 1.05f; // 0x3f866666

constexpr float kFingerAlphaScale = 128.0f;
constexpr float kRingAlphaScale = 255.0f; // 0x2eed00

constexpr int kSweepKeyframeCount = 9;
constexpr int kRampCurveLen = 0x10;
constexpr int kPulseCurveLen = 0x35;
constexpr int kTriCurveLen = 0x18;
constexpr int kConnCurveLen = 0x24;

constexpr int kStepNoGlyph = 10;

constexpr float kHalf = 0.5f;

constexpr unsigned int kFingerSpriteKind = 0;
constexpr unsigned int kRingSpriteKind = 10;
constexpr unsigned int kHighlightSpriteKind = 9;

struct CurvePoint {
    float flX;
    float flValue;
};

inline int AppendRampSpan(CurvePoint *pCurve, int nAt, float flStartX, float flEndX) {
    pCurve[nAt] = CurvePoint{flStartX, 0.0f};
    pCurve[nAt + 1] = CurvePoint{flStartX + kSweepHalfSpan, kScaleOne};
    pCurve[nAt + 2] = CurvePoint{flEndX + kSweepHalfSpanNeg, kScaleOne};
    pCurve[nAt + 3] = CurvePoint{flEndX, 0.0f};
    return nAt + 4;
}

inline int AppendScalePulse(CurvePoint *pCurve, int nAt, float flBaseX) {
    pCurve[nAt] = CurvePoint{flBaseX, kScaleOne};
    pCurve[nAt + 1] = CurvePoint{flBaseX + kPulseSpan0, kScalePeak};
    pCurve[nAt + 2] = CurvePoint{flBaseX + kPulseSpan1, kScaleOne};
    pCurve[nAt + 3] = CurvePoint{flBaseX + kPulseSpan2, kScaleSettle};
    pCurve[nAt + 4] = CurvePoint{flBaseX + kPulseSpan3, kScaleOne};
    return nAt + 5;
}

inline int AppendConnector(CurvePoint *pCurve, int nAt, float flEndX) {
    pCurve[nAt] = CurvePoint{flEndX + kConnectorOffset, kScaleOne};
    pCurve[nAt + 1] = CurvePoint{flEndX, kScaleOne};
    return nAt + 2;
}

inline int AppendRiseTriple(CurvePoint *pCurve, int nAt, float flStartX) {
    pCurve[nAt] = CurvePoint{flStartX, 0.0f};
    pCurve[nAt + 1] = CurvePoint{flStartX + kSweepHalfSpan, 0.0f};
    pCurve[nAt + 2] = CurvePoint{flStartX + kFullSpan, kScaleOne};
    return nAt + 3;
}

inline int AppendFallTriple(CurvePoint *pCurve, int nAt, float flEndX) {
    pCurve[nAt] = CurvePoint{flEndX + kFullSpanNeg, kScaleOne};
    pCurve[nAt + 1] = CurvePoint{flEndX + kSweepHalfSpanNeg, 0.0f};
    pCurve[nAt + 2] = CurvePoint{flEndX, 0.0f};
    return nAt + 3;
}
} // namespace

/** @ghidraAddress 0x10b828 */
void TutorialGuideLayer::AnimateFingerSprites(float flDeltaTime) {
    GameSystem *pGameSystem = GameSystem::GetGameSystem();
    m_flGaugeX = pGameSystem->GetViewportWidth();
    m_flGaugeY = pGameSystem->GetViewportHeight();
    m_pSprite->SetSpriteCount(0);

    // The gate is the active flag, not the fade state.
    if (!m_bActive) {
        return;
    }
    m_flClock += flDeltaTime;

    S_VECTOR2 viewportHalf{pGameSystem->GetViewportWidth(), pGameSystem->GetViewportHeight()};
    ScaleVector2(&viewportHalf, kHalf); // Yes, the binary computes this and discards it.

    const int nStep = static_cast<int>(
        KeyframeStepTableLookup(m_flClock, &m_aKeyframes[0].flStartX, kSweepKeyframeCount));

    static bool bRampBuilt = false;
    static CurvePoint aFingerCurve[kRampCurveLen];
    if (!bRampBuilt) {
        int n = 0;
        n = AppendRampSpan(aFingerCurve, n, m_aKeyframes[0].flStartX, m_aKeyframes[2].flEndX);
        n = AppendRampSpan(aFingerCurve, n, m_aKeyframes[3].flStartX, m_aKeyframes[5].flEndX);
        n = AppendRampSpan(aFingerCurve, n, m_aKeyframes[6].flStartX, m_aKeyframes[6].flEndX);
        AppendRampSpan(aFingerCurve, n, m_aKeyframes[7].flStartX, m_aKeyframes[8].flEndX);
        bRampBuilt = true;
    }

    float flFingerSizeX;
    float flFingerSizeY;
    if (IsPad()) {
        flFingerSizeX = pGameSystem->GetViewportWidth();
        flFingerSizeY = pGameSystem->GetViewportHeight();
    } else if (m_bPortrait) {
        flFingerSizeX = pGameSystem->GetViewportHeight();
        flFingerSizeY = pGameSystem->GetViewportHeight();
    } else {
        flFingerSizeX = pGameSystem->GetViewportWidth();
        flFingerSizeY = pGameSystem->GetViewportWidth();
    }
    S_VECTOR2 fingerPos{m_aCoords[0], m_aCoords[1]};
    const float flFingerAlpha =
        CalculateCurveInterpolation(&aFingerCurve[0].flX, kRampCurveLen, m_flClock);
    EmitTutorialSpriteSlot(flFingerSizeX,
                           flFingerSizeY,
                           kFingerSpriteKind,
                           &fingerPos.x,
                           static_cast<int>(flFingerAlpha * kFingerAlphaScale));

    static bool bRingBuilt = false;
    static CurvePoint aRingCurve[kRampCurveLen];
    static CurvePoint aRippleCurve[kRampCurveLen];
    if (!bRingBuilt) {
        int n = 0;
        n = AppendRampSpan(aRingCurve, n, m_aKeyframes[0].flStartX, m_aKeyframes[2].flEndX);
        n = AppendRampSpan(aRingCurve, n, m_aKeyframes[3].flStartX, m_aKeyframes[5].flEndX);
        n = AppendRampSpan(aRingCurve, n, m_aKeyframes[6].flStartX, m_aKeyframes[6].flEndX);
        AppendRampSpan(aRingCurve, n, m_aKeyframes[7].flStartX, m_aKeyframes[8].flEndX);
        bRingBuilt = true;
    }
    static bool bRippleBuilt = false;
    if (!bRippleBuilt) {
        int n = 0;
        n = AppendRampSpan(aRippleCurve, n, m_aKeyframes[0].flStartX, m_aKeyframes[2].flEndX);
        n = AppendRampSpan(aRippleCurve, n, m_aKeyframes[3].flStartX, m_aKeyframes[5].flEndX);
        n = AppendRampSpan(aRippleCurve, n, m_aKeyframes[6].flStartX, m_aKeyframes[6].flEndX);
        AppendRampSpan(aRippleCurve, n, m_aKeyframes[7].flStartX, m_aKeyframes[8].flEndX);
        bRippleBuilt = true;
    }
    S_VECTOR2 ringPos{m_aCoords[2], m_aCoords[3]};
    const float flRingScaleX =
        CalculateCurveInterpolation(&aRingCurve[0].flX, kRampCurveLen, m_flClock);
    const float flRingScaleY =
        CalculateCurveInterpolation(&aRingCurve[0].flX, kRampCurveLen, m_flClock);
    const float flRingAlpha =
        CalculateCurveInterpolation(&aRippleCurve[0].flX, kRampCurveLen, m_flClock);
    EmitTutorialSpriteSlot(flRingScaleX,
                           flRingScaleY,
                           kRingSpriteKind,
                           &ringPos.x,
                           static_cast<int>(flRingAlpha * kRingAlphaScale));

    static bool bPulseBuilt = false;
    static CurvePoint aPulseCurve[kPulseCurveLen];
    if (!bPulseBuilt) {
        int n = 0;
        n = AppendScalePulse(aPulseCurve, n, m_aKeyframes[0].flStartX);
        n = AppendScalePulse(aPulseCurve, n, m_aKeyframes[1].flStartX);
        n = AppendScalePulse(aPulseCurve, n, m_aKeyframes[2].flStartX);
        n = AppendConnector(aPulseCurve, n, m_aKeyframes[2].flEndX);
        n = AppendScalePulse(aPulseCurve, n, m_aKeyframes[3].flStartX);
        n = AppendScalePulse(aPulseCurve, n, m_aKeyframes[4].flStartX);
        n = AppendScalePulse(aPulseCurve, n, m_aKeyframes[5].flStartX);
        n = AppendConnector(aPulseCurve, n, m_aKeyframes[5].flEndX);
        n = AppendScalePulse(aPulseCurve, n, m_aKeyframes[6].flStartX);
        n = AppendConnector(aPulseCurve, n, m_aKeyframes[6].flEndX);
        n = AppendScalePulse(aPulseCurve, n, m_aKeyframes[7].flStartX);
        n = AppendScalePulse(aPulseCurve, n, m_aKeyframes[8].flStartX);
        AppendConnector(aPulseCurve, n, m_aKeyframes[8].flEndX);
        bPulseBuilt = true;
    }
    static bool bTriBuilt = false;
    static CurvePoint aTriCurve[kTriCurveLen];
    if (!bTriBuilt) {
        int n = 0;
        n = AppendRiseTriple(aTriCurve, n, m_aKeyframes[0].flStartX);
        n = AppendFallTriple(aTriCurve, n, m_aKeyframes[2].flEndX);
        n = AppendRiseTriple(aTriCurve, n, m_aKeyframes[3].flStartX);
        n = AppendFallTriple(aTriCurve, n, m_aKeyframes[5].flEndX);
        n = AppendRiseTriple(aTriCurve, n, m_aKeyframes[6].flStartX);
        n = AppendFallTriple(aTriCurve, n, m_aKeyframes[6].flEndX);
        n = AppendRiseTriple(aTriCurve, n, m_aKeyframes[7].flStartX);
        AppendFallTriple(aTriCurve, n, m_aKeyframes[8].flEndX);
        bTriBuilt = true;
    }
    S_VECTOR2 highlightPos{m_aCoords[4], m_aCoords[5]};
    const float flHighlightScaleX =
        CalculateCurveInterpolation(&aPulseCurve[0].flX, kPulseCurveLen, m_flClock);
    const float flHighlightScaleY =
        CalculateCurveInterpolation(&aPulseCurve[0].flX, kPulseCurveLen, m_flClock);
    const float flHighlightAlpha =
        CalculateCurveInterpolation(&aTriCurve[0].flX, kTriCurveLen, m_flClock);
    EmitTutorialSpriteSlot(flHighlightScaleX,
                           flHighlightScaleY,
                           kHighlightSpriteKind,
                           &highlightPos.x,
                           static_cast<int>(flHighlightAlpha * kRingAlphaScale));

    static bool bConnBuilt = false;
    static CurvePoint aConnCurve[kConnCurveLen];
    if (!bConnBuilt) {
        int n = 0;
        for (int nKf = 0; nKf < kSweepKeyframeCount; ++nKf) {
            aConnCurve[n] = CurvePoint{m_aKeyframes[nKf].flStartX, 0.0f};
            aConnCurve[n + 1] = CurvePoint{m_aKeyframes[nKf].flStartX + kSweepHalfSpan, kScaleOne};
            aConnCurve[n + 2] = CurvePoint{m_aKeyframes[nKf].flEndX + kSweepHalfSpanNeg, kScaleOne};
            aConnCurve[n + 3] = CurvePoint{m_aKeyframes[nKf].flEndX, 0.0f};
            n += 4;
        }
        bConnBuilt = true;
    }
    S_VECTOR2 glyphPos{m_aCoords[6], m_aCoords[7]};
    if (nStep != kStepNoGlyph) {
        const unsigned int nGlyphKind = static_cast<unsigned int>(m_aStepGlyphKinds[nStep]);
        const float flGlyphAlpha =
            CalculateCurveInterpolation(&aConnCurve[0].flX, kConnCurveLen, m_flClock);
        EmitTutorialSpriteSlot(
            1.0f, 1.0f, nGlyphKind, &glyphPos.x, static_cast<int>(flGlyphAlpha * kRingAlphaScale));
    }
}

/** @ghidraAddress 0x10b778 */
void TutorialGuideLayer::Update(float flDeltaTime) {
    if (!IsPad()) {
        const bool bPortrait = GameSystem::GetGameSystem()->GetViewportWidth() <=
                               GameSystem::GetGameSystem()->GetViewportHeight();
        if (bPortrait != m_bPortrait) {
            m_bPortrait = bPortrait;
        }
    }
    if ((m_nFadeState & 0xff) != 0) {
        AnimateFingerSprites(flDeltaTime);
        return;
    }
    if (static_cast<unsigned short>(m_nFadeState) < kFadeStateHidden) {
        return;
    }
    AdvanceStateMachine(flDeltaTime);
    RenderResultOverlay(flDeltaTime);
}

/** @ghidraAddress 0x10c430 */
void TutorialGuideLayer::AdvanceStateMachine(float flDeltaTime) {
    m_flStateTimer += flDeltaTime;

    int nNextPhase;
    switch (GameSystem::GetGameSystem()->GetTutorialPhase()) {
    case kTutorialPhaseIntro:
        if (m_flStateTimer < kTutorialPhaseDwellMs) {
            return;
        }
        nNextPhase = kTutorialPhaseHint1;
        break;
    case kTutorialPhaseHint1:
        if (m_flStateTimer < kTutorialPhaseDwellMs ||
            !ResultWindowColetteLayer::shared()->IsTutorialTouchEnded()) {
            return;
        }
        [RBTutorialManager
            updateStatus:static_cast<RBTutorialStatus>(RBTutorialManager.getCurrentStatus + 1)];
        nNextPhase = kTutorialPhaseHint2;
        break;
    case kTutorialPhaseHint2:
        if (m_flStateTimer < kTutorialPhaseDwellMs ||
            !ResultWindowColetteLayer::shared()->IsTutorialTouchEnded()) {
            return;
        }
        [RBTutorialManager
            updateStatus:static_cast<RBTutorialStatus>(RBTutorialManager.getCurrentStatus + 1)];
        nNextPhase = kTutorialPhaseResult;
        break;
    case kTutorialPhaseResult: {
        ResultWindowColetteLayer *pResult = ResultWindowColetteLayer::shared();
        if (!pResult->IsPageDirty() || pResult->GetActivePage() != 0) {
            return;
        }
        [RBTutorialManager
            updateStatus:static_cast<RBTutorialStatus>(RBTutorialManager.getCurrentStatus + 1)];
        nNextPhase = kTutorialPhaseDone;
        break;
    }
    case kTutorialPhaseDone:
        if (m_flStateTimer < kTutorialPhaseDwellMs ||
            !ResultWindowColetteLayer::shared()->IsTutorialTouchEnded()) {
            return;
        }
        [RBTutorialManager updateStatus:RBTutorialStatusMusicSelectSeen];
        nNextPhase = kTutorialPhaseComplete;
        break;
    default:
        return;
    }

    GameSystem::GetGameSystem()->SetTutorialPhase(nNextPhase);
    m_flStateTimer = 0.0f;
}

namespace {
// Element anchor ids shared with ResultWindowColetteLayer.
constexpr int kAnchorMusicInfo = 0x46;
constexpr int kAnchorCentre = 1;
constexpr int kAnchorScore = 5;

// The per-orientation phase-1 element nudges, in pixels.
constexpr float kPhase1NudgePortraitBottom = -4.0f;
constexpr float kPhase1NudgePhoneLeft = -10.0f;
constexpr float kPhase1NudgePhoneRight = 10.0f;
constexpr float kPhase1NudgePadLeft = -20.0f;
constexpr float kPhase1NudgePadRight = 20.0f;

// The arrow/box quad offsets, in pixels.
constexpr float kArrowVerticalNudge = -10.0f;
constexpr float kArrowTailOffset = 20.0f;
constexpr float kBoxInset = 4.0f;

constexpr float kPhraseBelowOffset = 50.0f;     // 0x2eedd0
constexpr float kHandOffsetLandscape = -100.0f; // 0x2fcfec
constexpr float kHandOffsetPad = -240.0f;       // 0x301f90

// Modelled as file-scope constants rather than the binary's guarded runtime copies.
// @ghidraAddress 0x3dd020 phone, 0x3dd050 iPad
struct HandGlyphOffset {
    float flX;
    float flY;
};
constexpr HandGlyphOffset kHandOffsetsPhone[] = {
    {0.0f, 0.0f}, {-68.0f, 0.0f}, {-90.0f, 106.0f}, {20.0f, -4.0f}}; // 0x301f30
constexpr HandGlyphOffset kHandOffsetsPad[] = {
    {0.0f, 0.0f}, {-180.0f, 40.0f}, {-180.0f, 240.0f}, {0.0f, 32.0f}}; // 0x301f50

constexpr int kOffsetHand = 1;
constexpr int kOffsetPrimary = 2;
constexpr int kOffsetFinish = 3;

constexpr float kHandScaleInCurve[] = {0.0f, 0.0f, 166.66667f, 1.0f}; // 0x302128 (n=2)
constexpr float kHandAlphaInCurve[] = {0.0f, 0.0f, 166.66667f, 1.0f}; // 0x302118 (n=2)
constexpr float kPhraseScaleCurve[] = {                               // 0x302138 (n=5)
    0.0f,
    0.0f,
    150.0f,
    1.1f,
    200.0f,
    1.0f,
    233.33333f,
    1.05f,
    266.66667f,
    1.0f};
constexpr float kPhraseScaleHeldCurve[] = { // 0x302160 (n=5)
    0.0f,
    1.0f,
    150.0f,
    1.1f,
    200.0f,
    1.0f,
    233.33333f,
    1.05f,
    266.66667f,
    1.0f};
constexpr float kFinishAlphaCurve[] = {
    0.0f, 0.0f, 166.66667f, 0.0f, 250.0f, 1.0f}; // 0x302188 (n=3)
constexpr float kHandSweepCurve[] = {            // 0x3021a0 (n=4)
    0.0f,
    0.8f,
    166.66667f,
    0.8f,
    1500.0f,
    0.2f,
    1666.6667f,
    0.2f};
constexpr float kFinishSweepCurve[] = { // 0x3021c0 (n=4)
    0.0f,
    0.0f,
    166.66667f,
    1.0f,
    1500.0f,
    1.0f,
    1666.6667f,
    0.0f};

// @ghidraAddress 0x2eed00
constexpr float kAlphaScale = 255.0f;

constexpr int kHalfAlpha = 0x80;
constexpr int kFullAlpha = 0xff;

constexpr int kPhaseMaskAnimatedHand = 0x26; // Phases 1, 2, and 5.
constexpr int kPhaseMaskStaticHand = 0x18;   // Phases 3 and 4.

constexpr int kBlinkPeriodMs = 1000;
constexpr int kBlinkHalfMs = 500;

constexpr unsigned int kSpriteKindArrowTop = 1;
constexpr unsigned int kSpriteKindArrowRight = 2;
constexpr unsigned int kSpriteKindArrowBottom = 3;
constexpr unsigned int kSpriteKindArrowLeft = 4;
constexpr unsigned int kSpriteKindBoxTopLeft = 5;
constexpr unsigned int kSpriteKindBoxTopRight = 6;
constexpr unsigned int kSpriteKindBoxBottomLeft = 7;
constexpr unsigned int kSpriteKindBoxBottomRight = 8;
constexpr unsigned int kSpriteKindPhrasePrimary = 9;
constexpr unsigned int kSpriteKindPhraseHand = 10;
constexpr unsigned int kSpriteKindFinishPhraseBase = 0x16;
constexpr unsigned int kSpriteKindFinishHand = 0xd;
constexpr unsigned int kSpriteKindBlinkGlyphA = 0xc;
constexpr unsigned int kSpriteKindBlinkGlyphB = 0xd;
} // namespace

/** @ghidraAddress 0x10c5f8 */
void TutorialGuideLayer::RenderResultOverlay(float flDeltaTime) {
    GameSystem *pGameSystem = GameSystem::GetGameSystem();
    m_flGaugeX = pGameSystem->GetViewportWidth();
    m_flGaugeY = pGameSystem->GetViewportHeight();
    m_pSprite->SetSpriteCount(0);

    // The gate is the active flag, not the fade state.
    if (!m_bActive) {
        return;
    }
    m_flClock += flDeltaTime;

    S_VECTOR2 viewportHalf{pGameSystem->GetViewportWidth(), pGameSystem->GetViewportHeight()};
    ScaleVector2(&viewportHalf, kHalf); // Yes, the binary computes this and discards it.

    if (pGameSystem->GetTutorialPhase() == 0) {
        return;
    }

    const float flViewportWidth = pGameSystem->GetViewportWidth();
    const float flViewportHeight = pGameSystem->GetViewportHeight();

    S_VECTOR2 elemMin{0.0f, 0.0f};
    S_VECTOR2 elemMax{0.0f, 0.0f};
    const int nPhase = pGameSystem->GetTutorialPhase();
    ResultWindowColetteLayer *pResult = ResultWindowColetteLayer::shared();
    if (nPhase - 2U < 3) {
        pResult->ComputeElementBounds(kAnchorMusicInfo, &elemMin, &elemMax);
    } else if (nPhase == kTutorialPhaseComplete) {
        pResult->ComputeElementBounds(kAnchorCentre, &elemMin, &elemMax);
    } else if (nPhase == kTutorialPhaseHint1) {
        pResult->ComputeElementBounds(kAnchorScore, &elemMin, &elemMax);
        if (!IsPad()) {
            if (flViewportWidth < flViewportHeight) {
                elemMax.y += kPhase1NudgePortraitBottom;
            } else {
                elemMin.x += kPhase1NudgePhoneLeft;
                elemMax.x += kPhase1NudgePhoneRight;
            }
        } else {
            elemMin.x += kPhase1NudgePadLeft;
            elemMax.x += kPhase1NudgePadRight;
        }
    }

    S_VECTOR2 arrowTop{(elemMax.x + elemMin.x) * kHalf, elemMin.y * kHalf};
    S_VECTOR2 arrowBottom{(elemMax.x + elemMin.x) * kHalf, (flViewportHeight + elemMax.y) * kHalf};
    S_VECTOR2 arrowLeft{elemMin.x * kHalf, flViewportHeight * kHalf + kArrowVerticalNudge};
    S_VECTOR2 arrowRight{(flViewportWidth + elemMax.x) * kHalf,
                         flViewportHeight * kHalf + kArrowVerticalNudge};
    S_VECTOR2 boxTopLeft{elemMin.x + kBoxInset, elemMin.y + kBoxInset};
    S_VECTOR2 boxTopRight{elemMax.x - kBoxInset, elemMin.y + kBoxInset};
    S_VECTOR2 boxBottomRight{elemMax.x - kBoxInset, elemMax.y - kBoxInset};
    S_VECTOR2 boxBottomLeft{elemMin.x + kBoxInset, elemMax.y - kBoxInset};

    float flPhraseHandBaseY;
    if ((elemMax.y + elemMin.y) * kHalf < flViewportHeight * kHalf) {
        flPhraseHandBaseY = elemMax.y + kPhraseBelowOffset;
    } else {
        flPhraseHandBaseY = elemMin.y + (IsPad() ? kHandOffsetPad : kHandOffsetLandscape);
    }
    const float flPhraseHandBaseX = flViewportWidth * kHalf;

    const HandGlyphOffset *pOffsets = IsPad() ? kHandOffsetsPad : kHandOffsetsPhone;
    S_VECTOR2 phraseHand{flPhraseHandBaseX + pOffsets[kOffsetHand].flX,
                         flPhraseHandBaseY + pOffsets[kOffsetHand].flY};
    S_VECTOR2 phrasePrimary{flPhraseHandBaseX + pOffsets[kOffsetPrimary].flX,
                            flPhraseHandBaseY + pOffsets[kOffsetPrimary].flY};
    S_VECTOR2 phraseFinish{flPhraseHandBaseX + pOffsets[kOffsetFinish].flX,
                           flPhraseHandBaseY + pOffsets[kOffsetFinish].flY};

    EmitTutorialSpriteSlot(
        elemMax.x - elemMin.x, elemMin.y, kSpriteKindArrowTop, &arrowTop.x, kHalfAlpha);
    EmitTutorialSpriteSlot(elemMax.x - elemMin.x,
                           flViewportHeight - elemMax.y,
                           kSpriteKindArrowBottom,
                           &arrowBottom.x,
                           kHalfAlpha);
    EmitTutorialSpriteSlot(elemMin.x,
                           flViewportHeight + kArrowTailOffset,
                           kSpriteKindArrowLeft,
                           &arrowLeft.x,
                           kHalfAlpha);
    EmitTutorialSpriteSlot(flViewportWidth - elemMax.x,
                           flViewportHeight + kArrowTailOffset,
                           kSpriteKindArrowRight,
                           &arrowRight.x,
                           kHalfAlpha);
    EmitTutorialSpriteSlot(1.0f, 1.0f, kSpriteKindBoxTopLeft, &boxTopLeft.x, kHalfAlpha);
    EmitTutorialSpriteSlot(1.0f, 1.0f, kSpriteKindBoxTopRight, &boxTopRight.x, kHalfAlpha);
    EmitTutorialSpriteSlot(1.0f, 1.0f, kSpriteKindBoxBottomLeft, &boxBottomLeft.x, kHalfAlpha);
    EmitTutorialSpriteSlot(1.0f, 1.0f, kSpriteKindBoxBottomRight, &boxBottomRight.x, kHalfAlpha);

    const int nPhaseNow = pGameSystem->GetTutorialPhase();
    if (nPhaseNow < 6) {
        if ((1 << nPhaseNow) & kPhaseMaskAnimatedHand) {
            const float flHandScale =
                CalculateCurveInterpolation(kHandScaleInCurve, 2, m_flStateTimer);
            const float flHandScaleY =
                CalculateCurveInterpolation(kHandScaleInCurve, 2, m_flStateTimer);
            const float flHandAlpha =
                CalculateCurveInterpolation(kHandAlphaInCurve, 2, m_flStateTimer);
            EmitTutorialSpriteSlot(flHandScale,
                                   flHandScaleY,
                                   kSpriteKindPhraseHand,
                                   &phraseHand.x,
                                   static_cast<int>(flHandAlpha * kAlphaScale));
            const float flPhraseScale =
                CalculateCurveInterpolation(kPhraseScaleCurve, 5, m_flStateTimer);
            const float flPhraseScaleY =
                CalculateCurveInterpolation(kPhraseScaleCurve, 5, m_flStateTimer);
            EmitTutorialSpriteSlot(flPhraseScale,
                                   flPhraseScaleY,
                                   kSpriteKindPhrasePrimary,
                                   &phrasePrimary.x,
                                   kFullAlpha);
        } else if ((1 << nPhaseNow) & kPhaseMaskStaticHand) {
            EmitTutorialSpriteSlot(1.0f, 1.0f, kSpriteKindPhraseHand, &phraseHand.x, kFullAlpha);
            const float flPhraseScale =
                CalculateCurveInterpolation(kPhraseScaleHeldCurve, 5, m_flStateTimer);
            const float flPhraseScaleY =
                CalculateCurveInterpolation(kPhraseScaleHeldCurve, 5, m_flStateTimer);
            EmitTutorialSpriteSlot(flPhraseScale,
                                   flPhraseScaleY,
                                   kSpriteKindPhrasePrimary,
                                   &phrasePrimary.x,
                                   kFullAlpha);
        }
    }

    const int nPhaseFinish = pGameSystem->GetTutorialPhase();
    if (nPhaseFinish - 1U < 5) {
        const float flFinishAlpha =
            CalculateCurveInterpolation(kFinishAlphaCurve, 3, m_flStateTimer);
        EmitTutorialSpriteSlot(1.0f,
                               1.0f,
                               static_cast<unsigned int>(nPhaseFinish) +
                                   kSpriteKindFinishPhraseBase,
                               &phraseFinish.x,
                               static_cast<int>(flFinishAlpha * kAlphaScale));
    }

    const float flSweep = CalculateCurveInterpolation(kHandSweepCurve, 4, m_flStateTimer);
    S_VECTOR2 sweepHand{elemMin.x + (elemMax.x - elemMin.x) * flSweep,
                        (elemMax.y + elemMin.y) * kHalf};
    if (pGameSystem->GetTutorialPhase() == kTutorialPhaseResult) {
        const float flFinishSweepAlpha =
            CalculateCurveInterpolation(kFinishSweepCurve, 4, m_flStateTimer);
        EmitTutorialSpriteSlot(1.0f,
                               1.0f,
                               kSpriteKindFinishHand,
                               &sweepHand.x,
                               static_cast<int>(flFinishSweepAlpha * kAlphaScale));
    }

    S_VECTOR2 blinkGlyph;
    if (flViewportHeight <= flViewportWidth) {
        blinkGlyph = S_VECTOR2{elemMax.x, (elemMax.y + elemMin.y) * kHalf};
    } else {
        blinkGlyph = S_VECTOR2{elemMax.x - 9.0f, (elemMax.y + elemMin.y) * kHalf + 17.0f};
    }
    if (pGameSystem->GetTutorialPhase() == kTutorialPhaseComplete) {
        const unsigned int nBlinkKind =
            static_cast<int>(m_flStateTimer) % kBlinkPeriodMs < kBlinkHalfMs ?
                kSpriteKindBlinkGlyphA :
                kSpriteKindBlinkGlyphB;
        EmitTutorialSpriteSlot(1.0f, 1.0f, nBlinkKind, &blinkGlyph.x, kFullAlpha);
    }
}

/** @ghidraAddress 0x10b400 */
void TutorialGuideLayer::destroyShared() {
    if (g_pTutorialGuideLayer != nullptr) {
        g_pTutorialGuideLayer->Release();
        delete g_pTutorialGuideLayer;
        g_pTutorialGuideLayer = nullptr;
    }
}
