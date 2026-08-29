#include "number_layer.h"

#include "../Share/bg_layer.h"
#include "curve.h"
#include "gamesystem.h"
#include "neRender.h"
#include "neSpriteInstancing.h"
#include "neTexture.h"
#include "s_vector2.h"
#include "sprite_uv_table.h"

static NumberLayer *g_pNumberLayer = nullptr; // @ghidraAddress 0x3dee50

namespace {

// @ghidraAddress 0x30d9f4
struct NumberMarkerLayout {
    int nBatch = {};        // +0x00: the sprite batch index.
    float flAnchorX = {};   // +0x04: the sprite anchor X.
    float flAnchorY = {};   // +0x08: the sprite anchor Y.
    float flSizeX = {};     // +0x0c: the sprite pixel width.
    float flSizeY = {};     // +0x10: the sprite pixel height.
    int nUvFrameIndex = {}; // +0x14: the atlas-frame index (into the shared sprite UV atlas).
};
constexpr NumberMarkerLayout kNumberMarkerLayout[] = {
    {0, 23.0f, 23.5f, 46.0f, 47.0f, 0x67},
    {0, 22.5f, 22.5f, 45.0f, 45.0f, 0x40},
    {0, 19.5f, 22.5f, 39.0f, 45.0f, 0x41},
    {0, 19.5f, 22.5f, 39.0f, 45.0f, 0x42},
    {0, 21.0f, 22.5f, 42.0f, 45.0f, 0x43},
    {0, 20.5f, 22.5f, 41.0f, 45.0f, 0x44},
    {0, 18.5f, 22.5f, 37.0f, 45.0f, 0x45},
    {0, 20.0f, 22.5f, 40.0f, 45.0f, 0x41},
    {0, 19.5f, 22.5f, 39.0f, 45.0f, 0x42},
    {0, 23.0f, 22.5f, 46.0f, 45.0f, 0x40},
    {0, 19.5f, 22.5f, 39.0f, 45.0f, 0x49},
    {0, 20.5f, 22.5f, 41.0f, 45.0f, 0x4a},
    {0, 16.0f, 22.5f, 32.0f, 45.0f, 0x4b},
};

// Above this the binary reads the effect UV atlas; the shipped caller never gets there.
// @ghidraAddress 0x2f7908
constexpr unsigned int kEffectAtlasMarkerThreshold = 0xc;

constexpr float kCentreBlendX = -384.0f; // @ghidraAddress 0x2f8568
constexpr float kCentreBlendY = -680.0f; // @ghidraAddress 0x301f94
constexpr float kCentreBlendHalf = 0.5f;

constexpr const char *kPartsTextureName = "00_texture/gm_parts2";     // @ghidraAddress 0x3ceaa8
constexpr const char *kEffectTextureName = "00_texture/ti_parts_eff"; // @ghidraAddress 0x3ceaf0

constexpr unsigned int kSlotCapacities[] = {13, 28}; // @ghidraAddress 0x30d4b0

// 0 binds the parts atlas, 1 binds the effect atlas.
// @ghidraAddress 0x30d4b8
constexpr int kSlotTextureField[] = {0, 1};

constexpr bool kSlotAdditiveBlend[] = {false, false}; // @ghidraAddress 0x30d4c0

constexpr int kAdditiveBlendMode = 1;

constexpr int kNumberMarkerRun = 12;

// The per-digit alpha-envelope curve (4 {time, value} points per marker). @ghidraAddress 0x30d824
constexpr float kNumberAlphaCurve[kNumberMarkerRun][8] = {
    {400.0f, 0.0f, 650.0f, 1.0f, 1416.6666f, 1.0f, 1583.3334f, 0.00001f},
    {366.66666f, 0.0f, 616.6667f, 1.0f, 1416.6666f, 1.0f, 1583.3334f, 0.00001f},
    {333.33334f, 0.0f, 583.3333f, 1.0f, 1416.6666f, 1.0f, 1583.3334f, 0.00001f},
    {300.0f, 0.0f, 550.0f, 1.0f, 1416.6666f, 1.0f, 1583.3334f, 0.00001f},
    {266.66666f, 0.0f, 516.6667f, 1.0f, 1416.6666f, 1.0f, 1583.3334f, 0.00001f},
    {233.33333f, 0.0f, 483.33334f, 1.0f, 1416.6666f, 1.0f, 1583.3334f, 0.00001f},
    {233.33333f, 0.0f, 483.33334f, 1.0f, 1416.6666f, 1.0f, 1583.3334f, 0.00001f},
    {266.66666f, 0.0f, 516.6667f, 1.0f, 1416.6666f, 1.0f, 1583.3334f, 0.00001f},
    {300.0f, 0.0f, 550.0f, 1.0f, 1416.6666f, 1.0f, 1583.3334f, 0.00001f},
    {333.33334f, 0.0f, 583.3333f, 1.0f, 1416.6666f, 1.0f, 1583.3334f, 0.00001f},
    {366.66666f, 0.0f, 616.6667f, 1.0f, 1416.6666f, 1.0f, 1583.3334f, 0.00001f},
    {400.0f, 0.0f, 650.0f, 1.0f, 1416.6666f, 1.0f, 1583.3334f, 0.00001f},
};

// The per-digit scale curve (9 {time, value} points per marker). @ghidraAddress 0x30d4c4
constexpr float kNumberScaleCurve[kNumberMarkerRun][18] = {
    {400.0f,
     0.0f,
     566.6667f,
     1.1f,
     650.0f,
     1.0f,
     733.3333f,
     1.05f,
     783.3333f,
     1.0f,
     833.3333f,
     1.02f,
     866.6667f,
     1.0f,
     900.0f,
     1.02f,
     933.3333f,
     1.0f},
    {366.66666f,
     0.0f,
     533.3333f,
     1.1f,
     616.6667f,
     1.0f,
     700.0f,
     1.05f,
     750.0f,
     1.0f,
     800.0f,
     1.02f,
     833.3333f,
     1.0f,
     866.6667f,
     1.02f,
     900.0f,
     1.0f},
    {333.33334f,
     0.0f,
     500.0f,
     1.1f,
     583.3333f,
     1.0f,
     666.6667f,
     1.05f,
     716.6667f,
     1.0f,
     766.6667f,
     1.02f,
     800.0f,
     1.0f,
     833.3333f,
     1.02f,
     866.6667f,
     1.0f},
    {300.0f,
     0.0f,
     466.66666f,
     1.1f,
     550.0f,
     1.0f,
     633.3333f,
     1.05f,
     683.3333f,
     1.0f,
     733.3333f,
     1.02f,
     766.6667f,
     1.0f,
     800.0f,
     1.02f,
     833.3333f,
     1.0f},
    {266.66666f,
     0.0f,
     433.33334f,
     1.1f,
     516.6667f,
     1.0f,
     600.0f,
     1.05f,
     650.0f,
     1.0f,
     700.0f,
     1.02f,
     733.3333f,
     1.0f,
     766.6667f,
     1.02f,
     800.0f,
     1.0f},
    {233.33333f,
     0.0f,
     400.0f,
     1.1f,
     483.33334f,
     1.0f,
     566.6667f,
     1.05f,
     616.6667f,
     1.0f,
     666.6667f,
     1.02f,
     700.0f,
     1.0f,
     733.3333f,
     1.02f,
     766.6667f,
     1.0f},
    {233.33333f,
     0.0f,
     400.0f,
     1.1f,
     483.33334f,
     1.0f,
     566.6667f,
     1.05f,
     616.6667f,
     1.0f,
     666.6667f,
     1.02f,
     700.0f,
     1.0f,
     733.3333f,
     1.02f,
     766.6667f,
     1.0f},
    {266.66666f,
     0.0f,
     433.33334f,
     1.1f,
     516.6667f,
     1.0f,
     600.0f,
     1.05f,
     650.0f,
     1.0f,
     700.0f,
     1.02f,
     733.3333f,
     1.0f,
     766.6667f,
     1.02f,
     800.0f,
     1.0f},
    {300.0f,
     0.0f,
     466.66666f,
     1.1f,
     550.0f,
     1.0f,
     633.3333f,
     1.05f,
     683.3333f,
     1.0f,
     733.3333f,
     1.02f,
     766.6667f,
     1.0f,
     800.0f,
     1.02f,
     833.3333f,
     1.0f},
    {333.33334f,
     0.0f,
     500.0f,
     1.1f,
     583.3333f,
     1.0f,
     666.6667f,
     1.05f,
     716.6667f,
     1.0f,
     766.6667f,
     1.02f,
     800.0f,
     1.0f,
     833.3333f,
     1.02f,
     866.6667f,
     1.0f},
    {366.66666f,
     0.0f,
     533.3333f,
     1.1f,
     616.6667f,
     1.0f,
     700.0f,
     1.05f,
     750.0f,
     1.0f,
     800.0f,
     1.02f,
     833.3333f,
     1.0f,
     866.6667f,
     1.02f,
     900.0f,
     1.0f},
    {400.0f,
     0.0f,
     566.6667f,
     1.1f,
     650.0f,
     1.0f,
     733.3333f,
     1.05f,
     783.3333f,
     1.0f,
     833.3333f,
     1.02f,
     866.6667f,
     1.0f,
     900.0f,
     1.02f,
     933.3333f,
     1.0f},
};

// @ghidraAddress 0x30d450
constexpr S_VECTOR2 kNumberDigitBase[kNumberMarkerRun] = {
    {135.0f, 663.0f},
    {180.0f, 663.0f},
    {222.0f, 663.0f},
    {286.0f, 663.0f},
    {325.0f, 663.0f},
    {367.0f, 663.0f},
    {432.0f, 663.0f},
    {474.0f, 663.0f},
    {518.0f, 663.0f},
    {561.0f, 663.0f},
    {600.0f, 663.0f},
    {639.0f, 663.0f},
};

// @ghidraAddress 0x30d9a4
constexpr float kNumberLabelScaleXCurve[] = {
    0.0f, 0.0f, 166.66667f, 1.5f, 250.0f, 1.0f, 500.0f, 5.0f};
// @ghidraAddress 0x30d9c4
constexpr float kNumberLabelScaleYCurve[] = {
    0.0f, 0.0f, 166.66667f, 1.5f, 250.0f, 1.0f, 500.0f, 1.5f};
// @ghidraAddress 0x30d9e4
constexpr float kNumberLabelAlphaCurve[] = {250.0f, 1.0f, 500.0f, 0.0f};
constexpr int kNumberLabelScalePoints = 4;
constexpr int kNumberLabelAlphaPoints = 2;
constexpr int kNumberCurvePoints = 4;
constexpr int kNumberScalePoints = 9;

constexpr S_VECTOR2 kNumberLabelBase = {384.0f, 663.0f};

constexpr float kNumberAnimDuration = 2000.0f; // @ghidraAddress 0x2feff0
constexpr float kNumberPhoneScale = 0.5f;
constexpr float kNumberPadScale = 1.0f;
// The binary widens this multiply to double, so a double reproduces its rounding exactly.
// @ghidraAddress 0x2fede0
constexpr double kNumberLabelScaleFactor = 0.9;

constexpr float kNumberAlphaScale = 255.0f; // @ghidraAddress 0x2eed00

} // namespace

/** @ghidraAddress 0x17dd98 */
NumberLayer::NumberLayer() = default;

/** @ghidraAddress 0x17dde0 */
NumberLayer *NumberLayer::shared() {
    if (g_pNumberLayer == nullptr) {
        g_pNumberLayer = new NumberLayer();
    }
    return g_pNumberLayer;
}

/** @ghidraAddress 0x17de30 */
void NumberLayer::InitializeNumberLayer() {
    if (m_bBuilt) {
        return;
    }

    BgLayer *pBackgroundLayer = BgLayer::GetBackgroundLayer();
    ne::C_RENDER *pParent = pBackgroundLayer->GetBackgroundRenderObject();

    m_pPartsTexture = ne::C_TEXTURE::FindOrLoadCached(kPartsTextureName);
    m_pEffectTexture = ne::C_TEXTURE::FindOrLoadCached(kEffectTextureName);

    ne::C_TEXTURE *const apTextureFields[] = {m_pPartsTexture, m_pEffectTexture};

    for (int nSlot = 0; nSlot < kSpriteSlotCount; ++nSlot) {
        ne::C_SPRITE_INSTANCING_2D *pSprite = ne::CreateSpriteInstancer(kSlotCapacities[nSlot]);
        pParent->AttachChild(pSprite);
        pSprite->SetVisible(true);
        pSprite->SetRefCountedMember(apTextureFields[kSlotTextureField[nSlot]]);
        pSprite->SetSpriteCount(m_aSpriteCounts[nSlot]);
        if (kSlotAdditiveBlend[nSlot]) {
            pSprite->SetBlendMode(kAdditiveBlendMode);
        }
        m_apSprites[nSlot] = pSprite;
    }

    m_bBuilt = true;
}

/** @ghidraAddress 0x17df2c */
void NumberLayer::SetReady() {
    m_bReady = true;
    m_flAnimTime = 0.0f;
}

/** @ghidraAddress 0x17df3c */
void NumberLayer::ClearReady(float flDuration) {
    (void)flDuration; // The binary takes a duration in s0 and never reads it.
    m_bReady = false;
}

/** @ghidraAddress 0x17df44 */
void NumberLayer::Process(float flDelta) {
    if (!m_bReady) {
        return;
    }

    m_flAnimTime += flDelta;
    if (m_flAnimTime >= kNumberAnimDuration) {
        m_bReady = false;
        return;
    }

    GameSystem *pGameSystem = GameSystem::GetGameSystem();
    m_flViewportWidth = pGameSystem->GetViewportWidth();
    m_flViewportHeight = pGameSystem->GetViewportHeight();
    for (ne::C_SPRITE_INSTANCING_2D *pSprite : m_apSprites) {
        pSprite->SetSpriteCount(0);
    }
    // The binary computes a half-viewport stack local here that nothing reads; it is elided.

    const float flScale = IsPad() ? kNumberPadScale : kNumberPhoneScale;

    for (int nDigit = 0; nDigit < kNumberMarkerRun; ++nDigit) {
        S_VECTOR2 position = kNumberDigitBase[nDigit];
        const float flAlpha = CalculateCurveInterpolation(
            kNumberAlphaCurve[nDigit], kNumberCurvePoints, m_flAnimTime);
        const float flCurveScale = CalculateCurveInterpolation(
            kNumberScaleCurve[nDigit], kNumberScalePoints, m_flAnimTime);
        EmitMarkerSprite(static_cast<unsigned int>(nDigit + 1),
                         &position,
                         static_cast<int>(flAlpha * kNumberAlphaScale),
                         flScale * flCurveScale,
                         flScale * flCurveScale);
    }

    S_VECTOR2 labelPos = kNumberLabelBase;
    const float flLabelScaleX =
        CalculateCurveInterpolation(kNumberLabelScaleXCurve, kNumberLabelScalePoints, m_flAnimTime);
    const float flLabelScaleY =
        CalculateCurveInterpolation(kNumberLabelScaleYCurve, kNumberLabelScalePoints, m_flAnimTime);
    const float flLabelAlpha =
        CalculateCurveInterpolation(kNumberLabelAlphaCurve, kNumberLabelAlphaPoints, m_flAnimTime);
    EmitMarkerSprite(
        0,
        &labelPos,
        static_cast<int>(flLabelAlpha * kNumberAlphaScale),
        static_cast<float>(static_cast<double>(flScale * flLabelScaleX) * kNumberLabelScaleFactor),
        static_cast<float>(static_cast<double>(flScale * flLabelScaleY) * kNumberLabelScaleFactor));
}

/** @ghidraAddress 0x17e1b4 */
void NumberLayer::EmitMarkerSprite(
    unsigned int uMarkerIndex, S_VECTOR2 *pPosition, int iAlpha, float flScaleW, float flScaleH) {
    const NumberMarkerLayout &layout = kNumberMarkerLayout[uMarkerIndex];
    (void)kEffectAtlasMarkerThreshold; // The binary's high-index branch is never taken.
    const SpriteUvEntry &uv = g_aSpriteUvTable[layout.nUvFrameIndex];

    ne::C_SPRITE_INSTANCING_2D *pBatch = m_apSprites[layout.nBatch];
    const int nSlot = pBatch->GetSpriteCount();
    if (nSlot >= static_cast<int>(pBatch->GetCapacity())) {
        return;
    }

    if (!IsPad()) {
        pPosition->x = (pPosition->x + kCentreBlendX) * kCentreBlendHalf +
                       m_flViewportWidth * kCentreBlendHalf;
        pPosition->y = (pPosition->y + kCentreBlendY) * kCentreBlendHalf +
                       m_flViewportHeight * kCentreBlendHalf;
    } else {
        pPosition->y = pPosition->y + kCentreBlendY + m_flViewportHeight * kCentreBlendHalf;
    }

    pBatch->SetSpritePosition(nSlot, *pPosition);
    pBatch->SetSpriteAnchor(nSlot, S_VECTOR2{layout.flAnchorX, layout.flAnchorY});
    pBatch->SetSpriteSize(nSlot, S_VECTOR2{layout.flSizeX, layout.flSizeY});
    pBatch->SetSpriteUvOrigin(nSlot, S_VECTOR2{uv.flOriginU, uv.flOriginV});
    pBatch->SetSpriteUvSize(nSlot, S_VECTOR2{uv.flSizeU, uv.flSizeV});
    pBatch->SetSpriteScale(nSlot, flScaleW, flScaleH);
    pBatch->SetSpriteColor(nSlot, 0xff, 0xff, 0xff, static_cast<unsigned int>(iAlpha));
    pBatch->SetSpriteCount(nSlot + 1);
}
