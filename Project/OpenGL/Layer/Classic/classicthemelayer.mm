#include "classicthemelayer.h"

#include "ScoreTracker.h"
#include "bg_layer.h"
#include "curve.h"
#include "engineglobals.h"
#include "neRender.h"
#include "neSpriteInstancing.h"
#include "neTexture.h"
#include "sprite_uv_table.h"
#include "vectormath.h"

// The background texture the Classic-theme batches all draw from.
static const char *const g_szGmParts2TextureKey = "00_texture/gm_parts2"; // @ghidraAddress 0x3ceaa8

// The sprite capacities (maximum sprite counts) for the three Classic-theme background batches.
static const int g_anClassicThemeBatchCapacities[] = {1, 7, 30}; // @ghidraAddress 0x301970

// The per-sprite-kind transform table: each kind's anchor, size, and atlas-frame index.
// @ghidraAddress 0x301c60
const ClassicThemeSpriteTransform g_aClassicThemeSpriteTransforms[] = {
    {{384.0f, 512.0f}, {768.0f, 1024.0f}, 0},
    {{145.0f, 53.0f}, {290.0f, 106.0f}, 9},
    {{145.0f, 53.0f}, {290.0f, 106.0f}, 10},
    {{188.0f, 53.0f}, {376.0f, 106.0f}, 11},
    {{14.0f, 14.0f}, {28.0f, 28.0f}, 12},
};

// The process-wide Classic-theme layer, created lazily by shared().
static ClassicThemeLayer *g_pClassicThemeLayer = nullptr; // @ghidraAddress 0x3dca00

namespace {

// The colour index the constructor defaults to.
constexpr int kDefaultColor = 1;

// The value the two score-value slots are seeded to by the constructor.
constexpr int kScoreValueDefault = 4;

// The animation clock's seeded start, well before zero so the intro plays from the beginning
// (@ghidraAddress 0x3018b0).
constexpr float kAnimClockStart = -500.0f;

// The eased-progress channel's fully-shown value.
constexpr float kEaseFullValue = 1.0f;

// The maximum value of an opaque colour channel.
constexpr unsigned int kColorMax = 255;

} // namespace

/** @ghidraAddress 0x109ee0 */
ClassicThemeLayer *ClassicThemeLayer::shared() {
    if (g_pClassicThemeLayer == nullptr) {
        // The binary allocates the raw 0x60-byte object and runs the constructor.
        g_pClassicThemeLayer = new ClassicThemeLayer();
    }
    return g_pClassicThemeLayer;
}

/** @ghidraAddress 0x109e68 */
ClassicThemeLayer::ClassicThemeLayer() {
    // The base constructor and the zero-initialised members clear the texture, batches, counts, and
    // flags; the constructor then applies the two non-zero defaults.
    m_nColor = kDefaultColor;
    for (int &nValue : m_aScoreValues) {
        nValue = kScoreValueDefault;
    }
}

/** @ghidraAddress 0x109f30 */
void ClassicThemeLayer::InitializeBackgroundSceneNodes() {
    if (m_fInitialized) {
        return;
    }

    ne::C_RENDER *pRootNode = BgLayer::GetBackgroundLayer()->GetBackgroundRenderObject();
    m_pTexture = ne::C_TEXTURE::FindOrLoadCached(g_szGmParts2TextureKey);

    for (int nBatchIndex = 0; nBatchIndex < kBackgroundBatchCount; ++nBatchIndex) {
        ne::C_SPRITE_INSTANCING_2D *pBatch =
            ne::CreateWorldSpriteBatch(g_anClassicThemeBatchCapacities[nBatchIndex]);
        pRootNode->AttachChild(pBatch);
        pBatch->SetVisible(true);
        // The first batch is stored without being given the shared texture; only the second and
        // third batches take it, exactly as the binary does.
        if (nBatchIndex != 0) {
            pBatch->SetRefCountedMember(m_pTexture);
        }
        pBatch->SetSpriteCount(m_anSpriteCount[nBatchIndex]);
        // The last batch is additively blended over the others.
        if (nBatchIndex == kBackgroundBatchCount - 1) {
            pBatch->SetBlendMode(1);
        }
        m_apSpriteBatch[nBatchIndex] = pBatch;
    }

    m_fInitialized = true;
}

/** @ghidraAddress 0x10a0a0 */
void ClassicThemeLayer::SetColor(int nColor) {
    m_nColor = nColor;
}

/** @ghidraAddress 0x10a644 */
void ClassicThemeLayer::ConfigureSpriteSlot(int nBatch,
                                            int nSpriteKind,
                                            const S_VECTOR2 &position,
                                            float flScaleX,
                                            float flScaleY,
                                            float flRotation,
                                            int nAlpha) {
    ne::C_SPRITE_INSTANCING_2D *pBatch = m_apSpriteBatch[nBatch];
    const int nIndex = m_anSpriteCount[nBatch];
    if (nIndex >= g_anClassicThemeBatchCapacities[nBatch]) {
        return;
    }

    const ClassicThemeSpriteTransform &transform = g_aClassicThemeSpriteTransforms[nSpriteKind];
    const SpriteUvEntry &uv = g_aSpriteUvTable[transform.nUvIndex];

    // The slot sits at the given position, offset down by the play-field half-height (rounding
    // toward zero).
    const int nHalfHeight =
        (g_nPlayfieldFullHeightY < 0 ? g_nPlayfieldFullHeightY + 1 : g_nPlayfieldFullHeightY) / 2;
    pBatch->SetSpritePositionXY(nIndex, position.x, position.y + static_cast<float>(nHalfHeight));
    pBatch->SetSpriteAnchor(nIndex, transform.anchor);
    pBatch->SetSpriteSize(nIndex, transform.size);
    pBatch->SetSpriteUvOrigin(nIndex, S_VECTOR2{uv.flOriginU, uv.flOriginV});
    pBatch->SetSpriteUvSize(nIndex, S_VECTOR2{uv.flSizeU, uv.flSizeV});
    pBatch->SetSpriteScale(nIndex, flScaleX, flScaleY);
    pBatch->SetSpriteRotation(nIndex, flRotation);

    // Batch zero is tinted black; the others opaque white.
    const unsigned int nChannel = nBatch == 0 ? 0 : kColorMax;
    pBatch->SetSpriteColor(nIndex, nChannel, nChannel, nChannel, static_cast<unsigned int>(nAlpha));

    ++m_anSpriteCount[nBatch];
}

/** @ghidraAddress 0x10a01c */
void ClassicThemeLayer::InitializeScoreGaugeState() {
    // Seed the animation clock and the eased-progress channel: the clock starts well before zero,
    // the channel starts and ends fully shown over a zero duration (so it reads as shown), and its
    // current value is one. Both animation flags are raised.
    m_flClock = kAnimClockStart;
    m_easeChannel.SetStart(kEaseFullValue);
    m_easeChannel.SetEnd(kEaseFullValue);
    m_easeChannel.SetDuration(0.0f);
    m_easeChannel.SetElapsed(0.0f);
    m_easeChannel.SetCurrent(kEaseFullValue);
    m_bAnimActive = true;
    m_bAnimEnabled = true;
    InitializeScoreValuesFromTracker();
}

/** @ghidraAddress 0x10a044 */
void ClassicThemeLayer::InitializeScoreValuesFromTracker() {
    for (int nSide = 0; nSide < kScoreValueCount; ++nSide) {
        m_aScoreValues[nSide] =
            ScoreTracker::shared()->GetPlayRecordField10(static_cast<unsigned int>(nSide));
    }
}

/** @ghidraAddress 0x10a080 */
void ClassicThemeLayer::StartGaugeValueFade(float flDuration) {
    // Restart the eased-progress channel from its current value down to zero over the given
    // duration.
    m_easeChannel.SetStart(m_easeChannel.GetCurrent());
    m_easeChannel.SetEnd(0.0f);
    m_easeChannel.SetDuration(flDuration);
    m_easeChannel.SetElapsed(0.0f);
    // A non-positive duration takes effect immediately: snap the current value to zero.
    if (flDuration <= 0.0f) {
        m_easeChannel.SetCurrent(0.0f);
    }
}

/** @ghidraAddress 0x10a5fc */
void ClassicThemeLayer::AdvanceEasedProgress(float flDelta) {
    m_easeChannel.Advance(flDelta);
}

namespace {

// The number of play sides the reveal draws.
constexpr int kSideCount = 2;

// The animation clock at which the reveal stops advancing (@ghidraAddress 0x2feff0).
constexpr float kAnimClockEnd = 2000.0f;

// The clock the glow sprite waits for before it is emitted (@ghidraAddress 0x2ec6b0).
constexpr float kGlowStartClock = 100.0f;

// The half-turn rotation a mirrored side's sprites take, in radians (@ghidraAddress 0x2fe894).
constexpr float kMirrorRotation = 3.1415927f;

// The factor a mirrored side's particle offsets are scaled by, flipping them through the anchor.
constexpr float kMirrorScale = -1.0f;

// The scale every sprite but the particles is drawn at.
constexpr float kUnitScale = 1.0f;

// The 0-to-255 alpha channel the eased progress is scaled into (@ghidraAddress 0x2eed00).
constexpr float kAlphaScale = 255.0f;

// The three batches the reveal emits into: the full-screen scrim, the per-side outcome banner, and
// the glow and particle effects.
constexpr int kScrimBatch = 0;
constexpr int kBannerBatch = 1;
constexpr int kEffectBatch = 2;

// The sprite kinds the reveal emits directly: the full-screen scrim, and the small particle glyph.
// The banner and glow instead take the side's outcome plus one as their kind.
constexpr int kScrimSpriteKind = 0;
constexpr int kParticleSpriteKind = 4;

// The play-record outcomes that gate the reveal: the winning side plays the two particle bursts,
// and the losing side draws nothing past its banner.
constexpr int kOutcomeWin = 0;
constexpr int kOutcomeLose = 1;

// Every curve sampled through CalculateCurveInterpolation below has two keyframe pairs.
constexpr int kTwoPointCurve = 2;

// The scrim's alpha over the animation clock (@ghidraAddress 0x30197c).
constexpr float kScrimAlphaPairs[] = {-500.0f, 0.0f, -333.33334f, 0.75f};

// The outcome banner's vertical scale over the animation clock (@ghidraAddress 0x301990).
constexpr float kBannerScalePairs[] = {0.0f, 0.0f, 116.666664f, 1.0f};

// The glow's alpha over the animation clock (@ghidraAddress 0x3019a0).
constexpr float kGlowAlphaPairs[] = {116.666664f, 0.6f, 500.0f, 0.0f};

// Whether each side's sprites are mirrored, indexed by the theme colour and then the side
// (@ghidraAddress 0x30198c).
constexpr unsigned char kSideMirrored[][kSideCount] = {{0, 0}, {1, 0}};

// The number of particles in each of the two bursts, and the keyframe-pair count of each of their
// curves.
constexpr int kBurstAParticleCount = 10;
constexpr int kBurstBParticleCount = 6;
constexpr int kBurstAScalePairCount = 3;
constexpr int kBurstAOffsetPairCount = 2;
constexpr int kBurstBScalePairCount = 4;
constexpr int kBurstBSpinPairCount = 2;

// The first burst's per-particle scale curves (@ghidraAddress 0x3019b0). The curve doubles as the
// particle's gate: a non-positive value skips it for this frame.
constexpr float kBurstAScalePairs[][kBurstAScalePairCount * 2] = {
    {450.0f, 0.0f, 700.0f, 1.0f, 1200.0f, 0.0f},
    {250.0f, 0.0f, 500.0f, 1.0f, 1000.0f, 0.0f},
    {400.0f, 0.0f, 650.0f, 1.0f, 1150.0f, 0.0f},
    {333.33334f, 0.0f, 583.3333f, 1.0f, 1083.3334f, 0.0f},
    {500.0f, 0.0f, 750.0f, 1.0f, 1250.0f, 0.0f},
    {400.0f, 0.0f, 650.0f, 1.0f, 1150.0f, 0.0f},
    {333.33334f, 0.0f, 583.3333f, 1.0f, 1083.3334f, 0.0f},
    {400.0f, 0.0f, 650.0f, 1.0f, 1150.0f, 0.0f},
    {250.0f, 0.0f, 500.0f, 1.0f, 1000.0f, 0.0f},
    {250.0f, 0.0f, 500.0f, 1.0f, 1000.0f, 0.0f},
};

// The first burst's per-particle vertical-drift curves, added to each spawn offset's Y
// (@ghidraAddress 0x301aa0).
constexpr float kBurstAOffsetPairs[][kBurstAOffsetPairCount * 2] = {
    {450.0f, 0.0f, 1200.0f, -100.0f},
    {250.0f, 0.0f, 1000.0f, -110.0f},
    {400.0f, 0.0f, 1150.0f, -170.0f},
    {333.33334f, 0.0f, 1083.3334f, -150.0f},
    {500.0f, 0.0f, 1250.0f, -100.0f},
    {400.0f, 0.0f, 1150.0f, -110.0f},
    {333.33334f, 0.0f, 1083.3334f, -130.0f},
    {400.0f, 0.0f, 1150.0f, -140.0f},
    {250.0f, 0.0f, 1000.0f, -170.0f},
    {250.0f, 0.0f, 1000.0f, -190.0f},
};

// The second burst's per-particle scale curves, gating each particle as above
// (@ghidraAddress 0x301b40).
constexpr float kBurstBScalePairs[][kBurstBScalePairCount * 2] = {
    {1331.6666f, 0.0f, 1333.3334f, 0.5f, 1500.0f, 1.0f, 1833.3334f, 0.0f},
    {1365.0f, 0.0f, 1366.6666f, 0.5f, 1533.3334f, 1.0f, 1866.6666f, 0.0f},
    {1398.3334f, 0.0f, 1400.0f, 0.5f, 1566.6666f, 1.0f, 1900.0f, 0.0f},
    {1431.6666f, 0.0f, 1433.3334f, 0.5f, 1600.0f, 1.0f, 1933.3334f, 0.0f},
    {1465.0f, 0.0f, 1466.6666f, 0.5f, 1633.3334f, 1.0f, 1966.6666f, 0.0f},
    {1498.3334f, 0.0f, 1500.0f, 0.5f, 1666.6666f, 1.0f, 2000.0f, 0.0f},
};

// The second burst's per-particle spin curves, added to the side's base rotation
// (@ghidraAddress 0x301c00).
constexpr float kBurstBSpinPairs[][kBurstBSpinPairCount * 2] = {
    {1333.3334f, 0.0f, 1833.3334f, 1.5707964f},
    {1366.6666f, 0.0f, 1866.6666f, 1.5707964f},
    {1400.0f, 0.0f, 1900.0f, 1.5707964f},
    {1433.3334f, 0.0f, 1933.3334f, 1.5707964f},
    {1466.6666f, 0.0f, 1966.6666f, 1.5707964f},
    {1500.0f, 0.0f, 2000.0f, 1.5707964f},
};

// The four curve arrays the bursts sample, each pairing a keyframe count with one of the pair
// blocks above. @ghidraAddress 0x35cb80, 0x35cc20, 0x35ccc0, and 0x35cd20.
const FloatCurve g_aBurstAScaleCurves[kBurstAParticleCount] = {
    {kBurstAScalePairCount, kBurstAScalePairs[0]},
    {kBurstAScalePairCount, kBurstAScalePairs[1]},
    {kBurstAScalePairCount, kBurstAScalePairs[2]},
    {kBurstAScalePairCount, kBurstAScalePairs[3]},
    {kBurstAScalePairCount, kBurstAScalePairs[4]},
    {kBurstAScalePairCount, kBurstAScalePairs[5]},
    {kBurstAScalePairCount, kBurstAScalePairs[6]},
    {kBurstAScalePairCount, kBurstAScalePairs[7]},
    {kBurstAScalePairCount, kBurstAScalePairs[8]},
    {kBurstAScalePairCount, kBurstAScalePairs[9]},
};
const FloatCurve g_aBurstAOffsetCurves[kBurstAParticleCount] = {
    {kBurstAOffsetPairCount, kBurstAOffsetPairs[0]},
    {kBurstAOffsetPairCount, kBurstAOffsetPairs[1]},
    {kBurstAOffsetPairCount, kBurstAOffsetPairs[2]},
    {kBurstAOffsetPairCount, kBurstAOffsetPairs[3]},
    {kBurstAOffsetPairCount, kBurstAOffsetPairs[4]},
    {kBurstAOffsetPairCount, kBurstAOffsetPairs[5]},
    {kBurstAOffsetPairCount, kBurstAOffsetPairs[6]},
    {kBurstAOffsetPairCount, kBurstAOffsetPairs[7]},
    {kBurstAOffsetPairCount, kBurstAOffsetPairs[8]},
    {kBurstAOffsetPairCount, kBurstAOffsetPairs[9]},
};
const FloatCurve g_aBurstBScaleCurves[kBurstBParticleCount] = {
    {kBurstBScalePairCount, kBurstBScalePairs[0]},
    {kBurstBScalePairCount, kBurstBScalePairs[1]},
    {kBurstBScalePairCount, kBurstBScalePairs[2]},
    {kBurstBScalePairCount, kBurstBScalePairs[3]},
    {kBurstBScalePairCount, kBurstBScalePairs[4]},
    {kBurstBScalePairCount, kBurstBScalePairs[5]},
};
const FloatCurve g_aBurstBSpinCurves[kBurstBParticleCount] = {
    {kBurstBSpinPairCount, kBurstBSpinPairs[0]},
    {kBurstBSpinPairCount, kBurstBSpinPairs[1]},
    {kBurstBSpinPairCount, kBurstBSpinPairs[2]},
    {kBurstBSpinPairCount, kBurstBSpinPairs[3]},
    {kBurstBSpinPairCount, kBurstBSpinPairs[4]},
    {kBurstBSpinPairCount, kBurstBSpinPairs[5]},
};

} // namespace

/** @ghidraAddress 0x10a0a8 */
void ClassicThemeLayer::Update(float flDelta) {
    for (int &nCount : m_anSpriteCount) {
        nCount = 0;
    }
    AdvanceEasedProgress(flDelta);

    if (m_bAnimEnabled) {
        if (m_bAnimActive) {
            m_flClock += flDelta;
        }
        if (m_flClock >= kAnimClockEnd) {
            m_bAnimActive = false;
        }

        // The eased progress fades the whole reveal in and out; every sprite's alpha is scaled by
        // it.
        const float flProgress = m_easeChannel.GetCurrent();

        // The full-screen scrim darkens the play field behind the reveal.
        S_VECTOR2 anchor{0.0f, 0.0f};
        const float flScrimAlpha =
            CalculateCurveInterpolation(kScrimAlphaPairs, kTwoPointCurve, m_flClock);
        ConfigureSpriteSlot(kScrimBatch,
                            kScrimSpriteKind,
                            anchor,
                            kUnitScale,
                            kUnitScale,
                            0.0f,
                            static_cast<int>(flScrimAlpha * flProgress * kAlphaScale));

        for (int nSide = 0; nSide < kSideCount; ++nSide) {
            // Colour zero draws only the second side.
            if ((m_nColor | nSide) == 0) {
                continue;
            }

            // Each side's banner anchor, by theme colour then side (@ghidraAddress 0x3dca10, seeded
            // once from the read-only block at 0x3018c0).
            static const S_VECTOR2 kSideAnchor[][kSideCount] = {
                {{0.0f, -5000.0f}, {0.0f, 0.0f}},
                {{0.0f, -300.0f}, {0.0f, 300.0f}},
            };

            // The side's outcome selects the banner and glow sprite kind; the mirrored side is
            // rotated a half turn and has its particle offsets flipped.
            const int nOutcome = m_aScoreValues[nSide];
            const int nOutcomeSpriteKind = nOutcome + 1;
            const bool bMirrored = kSideMirrored[m_nColor][nSide] != 0;
            const float flRotation = bMirrored ? kMirrorRotation : 0.0f;
            anchor = kSideAnchor[m_nColor][nSide];

            // The outcome banner grows vertically into place.
            const float flBannerScale =
                CalculateCurveInterpolation(kBannerScalePairs, kTwoPointCurve, m_flClock);
            ConfigureSpriteSlot(kBannerBatch,
                                nOutcomeSpriteKind,
                                anchor,
                                kUnitScale,
                                flBannerScale,
                                flRotation,
                                static_cast<int>(flProgress * kAlphaScale));

            if (nOutcome == kOutcomeLose) {
                continue;
            }

            // The additive glow behind the banner, once the clock has run past its start.
            if (m_flClock > kGlowStartClock) {
                const float flGlowAlpha =
                    CalculateCurveInterpolation(kGlowAlphaPairs, kTwoPointCurve, m_flClock);
                ConfigureSpriteSlot(kEffectBatch,
                                    nOutcomeSpriteKind,
                                    anchor,
                                    kUnitScale,
                                    kUnitScale,
                                    flRotation,
                                    static_cast<int>(flGlowAlpha * flProgress * kAlphaScale));
            }

            if (nOutcome != kOutcomeWin) {
                continue;
            }

            // The winning side's first particle burst: ten particles that drift upward from their
            // spawn offsets (@ghidraAddress 0x3dca40, seeded once from 0x3018e0).
            static const S_VECTOR2 kBurstASpawn[kBurstAParticleCount] = {
                {250.0f, 30.0f},
                {150.0f, 30.0f},
                {130.0f, 50.0f},
                {70.0f, 0.0f},
                {-250.0f, 30.0f},
                {-150.0f, 30.0f},
                {-80.0f, 30.0f},
                {-30.0f, 30.0f},
                {-100.0f, 30.0f},
                {0.0f, 30.0f},
            };
            for (int nParticle = 0; nParticle < kBurstAParticleCount; ++nParticle) {
                const float flScale =
                    CalculateCurveValue(&g_aBurstAScaleCurves[nParticle], m_flClock);
                if (flScale <= 0.0f) {
                    continue;
                }
                S_VECTOR2 offset = kBurstASpawn[nParticle];
                offset.y += CalculateCurveValue(&g_aBurstAOffsetCurves[nParticle], m_flClock);
                if (bMirrored) {
                    ScaleVector2(&offset, kMirrorScale);
                }
                AddVector2(&offset, &anchor);
                ConfigureSpriteSlot(kEffectBatch,
                                    kParticleSpriteKind,
                                    offset,
                                    flScale,
                                    flScale,
                                    flRotation,
                                    static_cast<int>(flProgress * kAlphaScale));
            }

            // The second burst: six particles that spin in place rather than drift
            // (@ghidraAddress 0x3dcaa0, seeded once from 0x301930).
            static const S_VECTOR2 kBurstBSpawn[kBurstBParticleCount] = {
                {-109.0f, -42.0f},
                {-101.0f, 49.0f},
                {-45.0f, 49.0f},
                {-29.0f, -49.0f},
                {0.0f, -49.0f},
                {87.0f, -49.0f},
            };
            for (int nParticle = 0; nParticle < kBurstBParticleCount; ++nParticle) {
                const float flScale =
                    CalculateCurveValue(&g_aBurstBScaleCurves[nParticle], m_flClock);
                if (flScale <= 0.0f) {
                    continue;
                }
                S_VECTOR2 offset = kBurstBSpawn[nParticle];
                const float flSpin =
                    CalculateCurveValue(&g_aBurstBSpinCurves[nParticle], m_flClock);
                if (bMirrored) {
                    ScaleVector2(&offset, kMirrorScale);
                }
                AddVector2(&offset, &anchor);
                ConfigureSpriteSlot(kEffectBatch,
                                    kParticleSpriteKind,
                                    offset,
                                    flScale,
                                    flScale,
                                    flRotation + flSpin,
                                    static_cast<int>(flProgress * kAlphaScale));
            }
        }
    }

    // Publish each batch's live slot count to its render node, whether or not the reveal ran.
    for (int nBatch = 0; nBatch < kBackgroundBatchCount; ++nBatch) {
        m_apSpriteBatch[nBatch]->SetSpriteCount(m_anSpriteCount[nBatch]);
    }
}
