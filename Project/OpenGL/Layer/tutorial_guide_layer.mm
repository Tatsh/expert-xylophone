#include "tutorial_guide_layer.h"

#import "RBTutorialManager.h"
#include "curve.h"
#include "deviceenvironment.h"
#include "gamesystem.h"
#include "neRender.h"
#include "neSpriteInstancing.h"
#include "neTexture.h"
#include "result_window_colette_layer.h"
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

// The in-play tutorial walkthrough phases the state machine advances through (game-system field
// +0x130). Each transition waits out a dwell time and, from the first hint on, a gating flag on the
// Colette result layer.
enum {
    kTutorialPhaseIntro = 0,    // Waits out the intro dwell, then shows the first hint.
    kTutorialPhaseHint1 = 1,    // First in-play hint; advances on a released tutorial touch.
    kTutorialPhaseHint2 = 2,    // Second in-play hint; advances on a released tutorial touch.
    kTutorialPhaseResult = 3,   // Waits for the result page to be flicked back to page zero.
    kTutorialPhaseDone = 4,     // Final hint; advances on a released tutorial touch.
    kTutorialPhaseComplete = 5, // The walkthrough is finished; the state machine idles.
};

// The dwell time each timed tutorial phase waits before it may advance (@ghidraAddress 0x2feff0).
constexpr float kTutorialPhaseDwellMs = 2000.0f;

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

// The nine per-step glyph sprite kinds, indexed by the current keyframe step (@ghidraAddress
// 0x301f00 onwards): the two intro steps then the seven swept-tap frames.
constexpr int kStepGlyphKinds[] = {14, 15, 16, 17, 18, 19, 20, 21, 22};

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

    // Seed the keyframe timings, the per-step glyph kinds, and the screen coordinates.
    for (int nKeyframe = 0; nKeyframe < kKeyframeCount; ++nKeyframe) {
        m_aKeyframes[nKeyframe] = kKeyframes[nKeyframe];
    }
    for (int nStep = 0; nStep < kKeyframeCount; ++nStep) {
        m_aStepGlyphKinds[nStep] = kStepGlyphKinds[nStep];
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

namespace {
// The finger animator's shared curve control-point offsets, added to the guide's swept keyframe X
// positions to build the per-frame animation curves. @ghidraAddress 0x301f70 onwards.
constexpr float kSweepHalfSpan = 166.66667f;     // 0x301f70
constexpr float kSweepHalfSpanNeg = -166.66667f; // 0x301f74
constexpr float kPulseSpan1 = 200.0f;            // 0x301f78
constexpr float kPulseSpan2 = 233.33333f;        // 0x301f7c
constexpr float kPulseSpan3 = 266.66667f;        // 0x301f80
constexpr float kTriRise = -150.0f;              // 0x301f84 (used with the ripple table)
constexpr float kFullSpan = 250.0f;              // 0x301f88
constexpr float kFullSpanNeg = -250.0f;          // 0x301f8c
constexpr float kPulseSpan0 = 150.0f;            // 0x2eedc8

// The pulse scale keyframes.
constexpr float kScaleOne = 1.0f;
constexpr float kScalePeak = 1.1f;    // 0x3f8ccccd
constexpr float kScaleSettle = 1.05f; // 0x3f866666

// The alpha scales the finger animator applies to its curve outputs.
constexpr float kFingerAlphaScale = 128.0f;
constexpr float kRingAlphaScale = 255.0f; // 0x2eed00

// The number of swept keyframes and the finger-animator curve-table lengths.
constexpr int kSweepKeyframeCount = 9;
constexpr int kRampCurveLen = 0x10;
constexpr int kPulseCurveLen = 0x35;
constexpr int kTriCurveLen = 0x18;
constexpr int kConnCurveLen = 0x24;

// The per-step glyph "no step" sentinel returned by the keyframe-step lookup.
constexpr int kStepNoGlyph = 10;

// The finger animator's sprite kinds.
constexpr unsigned int kFingerSpriteKind = 0;
constexpr unsigned int kRingSpriteKind = 10;
constexpr unsigned int kHighlightSpriteKind = 9;

// A curve control point: a query X and its value.
struct CurvePoint {
    float flX;
    float flValue;
};

// Appends a rising ramp for one keyframe span to the curve: two flat-zero points at the swept start
// and end, bracketed by two unit points half a span in from each side. The finger and ring curves
// are built from four such spans (the guide's four visible tap columns).
inline int AppendRampSpan(CurvePoint *pCurve, int nAt, float flStartX, float flEndX) {
    pCurve[nAt] = CurvePoint{flStartX, 0.0f};
    pCurve[nAt + 1] = CurvePoint{flStartX + kSweepHalfSpan, kScaleOne};
    pCurve[nAt + 2] = CurvePoint{flEndX + kSweepHalfSpanNeg, kScaleOne};
    pCurve[nAt + 3] = CurvePoint{flEndX, 0.0f};
    return nAt + 4;
}

// Appends a five-point scale pulse rising from unit to a peak and settling back, used by the
// highlight curve at each swept tap.
inline int AppendScalePulse(CurvePoint *pCurve, int nAt, float flBaseX) {
    pCurve[nAt] = CurvePoint{flBaseX, kScaleOne};
    pCurve[nAt + 1] = CurvePoint{flBaseX + kPulseSpan0, kScalePeak};
    pCurve[nAt + 2] = CurvePoint{flBaseX + kPulseSpan1, kScaleOne};
    pCurve[nAt + 3] = CurvePoint{flBaseX + kPulseSpan2, kScaleSettle};
    pCurve[nAt + 4] = CurvePoint{flBaseX + kPulseSpan3, kScaleOne};
    return nAt + 5;
}

// Appends a two-point connector holding unit scale across a keyframe's off span.
inline int AppendConnector(CurvePoint *pCurve, int nAt, float flEndX) {
    pCurve[nAt] = CurvePoint{flEndX + kSweepHalfSpanNeg, kScaleOne};
    pCurve[nAt + 1] = CurvePoint{flEndX, kScaleOne};
    return nAt + 2;
}

// Appends a three-point rising triangle (two zeros then a unit) used by the highlight-alpha curve.
inline int AppendRiseTriple(CurvePoint *pCurve, int nAt, float flStartX) {
    pCurve[nAt] = CurvePoint{flStartX, 0.0f};
    pCurve[nAt + 1] = CurvePoint{flStartX + kSweepHalfSpan, 0.0f};
    pCurve[nAt + 2] = CurvePoint{flStartX + kFullSpan, kScaleOne};
    return nAt + 3;
}

// Appends a three-point falling triangle (a unit then two zeros) used by the highlight-alpha curve.
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

    if ((m_nFadeState & 0xff) == 0) {
        return;
    }
    m_flClock += flDeltaTime;

    // The current swept step drives the per-step glyph at the end.
    const int nStep = static_cast<int>(
        KeyframeStepTableLookup(m_flClock, &m_aKeyframes[0].flStartX, kSweepKeyframeCount));

    // The finger, ring, and ripple curves share the same four-span rising ramp built from the
    // keyframes' first, third, sixth (with its own end), and eighth spans.
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

    // The finger sprite sizes to the viewport per the device and orientation, and fades in through
    // the ramp curve at 128-scaled alpha.
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

    // The ring and ripple curves are the same ramp; they scale and fade the ring sprite.
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

    // The highlight sprite's scale pulses at every swept tap (nine pulses joined by four connectors)
    // and its alpha rises and falls in triangles at the outer taps.
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

    // The per-step glyph fades in over its own connector curve (a rise-hold per keyframe), unless the
    // step lookup reported no glyph.
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
        [[RBTutorialManager getInstance]
            updateStatus:static_cast<RBTutorialStatus>(RBTutorialManager.getCurrentStatus + 1)];
        nNextPhase = kTutorialPhaseHint2;
        break;
    case kTutorialPhaseHint2:
        if (m_flStateTimer < kTutorialPhaseDwellMs ||
            !ResultWindowColetteLayer::shared()->IsTutorialTouchEnded()) {
            return;
        }
        [[RBTutorialManager getInstance]
            updateStatus:static_cast<RBTutorialStatus>(RBTutorialManager.getCurrentStatus + 1)];
        nNextPhase = kTutorialPhaseResult;
        break;
    case kTutorialPhaseResult: {
        ResultWindowColetteLayer *pResult = ResultWindowColetteLayer::shared();
        if (!pResult->IsPageDirty() || pResult->GetActivePage() != 0) {
            return;
        }
        [[RBTutorialManager getInstance]
            updateStatus:static_cast<RBTutorialStatus>(RBTutorialManager.getCurrentStatus + 1)];
        nNextPhase = kTutorialPhaseDone;
        break;
    }
    case kTutorialPhaseDone:
        if (m_flStateTimer < kTutorialPhaseDwellMs ||
            !ResultWindowColetteLayer::shared()->IsTutorialTouchEnded()) {
            return;
        }
        [[RBTutorialManager getInstance] updateStatus:RBTutorialStatusMusicSelectSeen];
        nNextPhase = kTutorialPhaseComplete;
        break;
    default:
        return;
    }

    GameSystem::GetGameSystem()->SetTutorialPhase(nNextPhase);
    m_flStateTimer = 0.0f;
}

namespace {
// The element anchor ids the overlay highlights per tutorial phase: the music-info block during
// phases 2 through 4, the centre panel at phase 5, and the score block at phase 1. These match
// ResultWindowColetteLayer's element anchor ids.
constexpr int kAnchorMusicInfo = 0x46;
constexpr int kAnchorCentre = 1;
constexpr int kAnchorScore = 5;

// The half factor used throughout the overlay's midpoint maths.
constexpr float kHalf = 0.5f;

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

// The phrase-anchor vertical offsets: the drop below the element when it is in the upper half, and
// the rise above the element (phone versus iPad) when it is in the lower half. @ghidraAddress
// 0x2eedd0, 0x2fcfec, 0x301f90.
constexpr float kPhraseBelowOffset = 50.0f;     // 0x2eedd0
constexpr float kHandOffsetLandscape = -100.0f; // 0x2fcfec
constexpr float kHandOffsetPad = -240.0f;       // 0x301f90

// The lazily-initialised per-device phrase-glyph offset tables (@ghidraAddress 0x3dd020 phone,
// 0x3dd050 iPad), each four {x, y} pairs seeded from the shipped vector constants at 0x301f30 and
// 0x301f50. Modelled as file-scope constants rather than the binary's guarded runtime copies. Only
// entries 1 through 3 are read (the hand, the primary phrase, and the finish phrase).
struct HandGlyphOffset {
    float flX;
    float flY;
};
constexpr HandGlyphOffset kHandOffsetsPhone[] = {
    {0.0f, 0.0f}, {-68.0f, 0.0f}, {-90.0f, 106.0f}, {20.0f, -4.0f}}; // 0x301f30
constexpr HandGlyphOffset kHandOffsetsPad[] = {
    {0.0f, 0.0f}, {-180.0f, 40.0f}, {-180.0f, 240.0f}, {0.0f, 32.0f}}; // 0x301f50

// The phrase-glyph offset-table entries: the pointer hand, the primary phrase, and the finish phrase.
constexpr int kOffsetHand = 1;
constexpr int kOffsetPrimary = 2;
constexpr int kOffsetFinish = 3;

// The overlay animation curves (@ghidraAddress 0x302118/128/138/160/188/1a0/1c0).
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

// The alpha scale applied to the curve outputs (@ghidraAddress 0x2eed00 = 255).
constexpr float kAlphaScale = 255.0f;

// The half-opaque and fully-opaque sprite alphas.
constexpr int kHalfAlpha = 0x80;
constexpr int kFullAlpha = 0xff;

// The phase bit masks that gate the animated phrase glyphs.
constexpr int kPhaseMaskAnimatedHand = 0x26; // Phases 1, 2, and 5.
constexpr int kPhaseMaskStaticHand = 0x18;   // Phases 3 and 4.

// The phase-5 blink period, in milliseconds, and its half point (glyph swaps at the half period).
constexpr int kBlinkPeriodMs = 1000;
constexpr int kBlinkHalfMs = 500;

// The sprite kinds the overlay emits.
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

    // Nothing to draw while the overlay is disabled.
    if ((m_nFadeState & 0xff) == 0) {
        return;
    }
    m_flClock += flDeltaTime;

    // The overlay only runs while a tutorial phase is active.
    if (pGameSystem->GetTutorialPhase() == 0) {
        return;
    }

    const float flViewportWidth = pGameSystem->GetViewportWidth();
    const float flViewportHeight = pGameSystem->GetViewportHeight();

    // Resolve the highlighted element's bounds by phase.
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
        // The score block is nudged in per orientation.
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

    // The four bounding arrows point at the element's edge midpoints, and the four corner boxes sit
    // just inside its corners.
    S_VECTOR2 arrowTop{(elemMax.x + elemMin.x) * kHalf, elemMin.y * kHalf};
    S_VECTOR2 arrowBottom{(elemMax.x + elemMin.x) * kHalf, (flViewportHeight + elemMax.y) * kHalf};
    S_VECTOR2 arrowLeft{elemMin.x * kHalf, flViewportHeight * kHalf + kArrowVerticalNudge};
    S_VECTOR2 arrowRight{(flViewportWidth + elemMax.x) * kHalf,
                         flViewportHeight * kHalf + kArrowVerticalNudge};
    S_VECTOR2 boxTopLeft{elemMin.x + kBoxInset, elemMin.y + kBoxInset};
    S_VECTOR2 boxTopRight{elemMax.x - kBoxInset, elemMin.y + kBoxInset};
    S_VECTOR2 boxBottomRight{elemMax.x - kBoxInset, elemMax.y - kBoxInset};
    S_VECTOR2 boxBottomLeft{elemMin.x + kBoxInset, elemMax.y - kBoxInset};

    // The phrase glyphs anchor above the element when it sits in the screen's upper half, and below
    // it (with a larger drop on an iPad) when it sits in the lower half.
    float flPhraseHandBaseY;
    if ((elemMax.y + elemMin.y) * kHalf < flViewportHeight * kHalf) {
        flPhraseHandBaseY = elemMax.y + kPhraseBelowOffset;
    } else {
        flPhraseHandBaseY = elemMin.y + (IsPad() ? kHandOffsetPad : kHandOffsetLandscape);
    }
    const float flPhraseHandBaseX = flViewportWidth * kHalf;

    // The three phrase-glyph positions read from the per-device offset table.
    const HandGlyphOffset *pOffsets = IsPad() ? kHandOffsetsPad : kHandOffsetsPhone;
    S_VECTOR2 phraseHand{flPhraseHandBaseX + pOffsets[kOffsetHand].flX,
                         flPhraseHandBaseY + pOffsets[kOffsetHand].flY};
    S_VECTOR2 phrasePrimary{flPhraseHandBaseX + pOffsets[kOffsetPrimary].flX,
                            flPhraseHandBaseY + pOffsets[kOffsetPrimary].flY};
    S_VECTOR2 phraseFinish{flPhraseHandBaseX + pOffsets[kOffsetFinish].flX,
                           flPhraseHandBaseY + pOffsets[kOffsetFinish].flY};

    // Emit the four arrows and four corner boxes at half alpha.
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

    // The animated phrase and its pointer hand: phases 1, 2, and 5 fade and scale the hand in;
    // phases 3 and 4 draw it steady; the primary phrase scales along its own curve.
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

    // The finish phrase fades in over phases 1 through 5.
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

    // A hand sweeps horizontally across the element along the sweep curve; at phase 3 an extra
    // finish hand fades in at the sweep position.
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

    // A blinking glyph in the final phase, nudged in on the phone portrait layout, alternating
    // between two frames each half of the blink period.
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
