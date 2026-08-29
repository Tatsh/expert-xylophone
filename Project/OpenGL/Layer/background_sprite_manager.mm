#include "background_sprite_manager.h"

#include "Share/bg_layer.h"
#include "curve.h"
#include "gamesystem.h"
#include "neRender.h"
#include "neSpriteInstancing.h"
#include "neTexture.h"
#include "s_vector2.h"
#include "sprite_uv_table.h"
#include "vectormath.h"

static BackgroundSpriteManager *g_pBackgroundManager = nullptr; // @ghidraAddress 0x3dcad8

namespace {

// @ghidraAddress 0x3ceaa8
constexpr const char *kTextureName = "00_texture/gm_parts2";

// @ghidraAddress 0x301cc8
constexpr unsigned int kSlotCapacities[] = {3, 11, 11};

constexpr int kAdditiveBlendMode = 1;

constexpr unsigned int kColorMax = 255;

struct ZoomSpriteLayout {
    float flAnchorX;
    float flAnchorY;
    float flSizeX;
    float flSizeY;
    int nUvFrameIndex;
};

// @ghidraAddress 0x301e4c
constexpr ZoomSpriteLayout kZoomSpriteLayout[] = {
    {90.0f, 90.0f, 180.0f, 180.0f, 0},
    {250.0f, 38.0f, 500.0f, 76.0f, 1},
    {21.0f, 28.0f, 42.0f, 56.0f, 2},
    {31.0f, 28.0f, 62.0f, 56.0f, 3},
    {19.0f, 28.0f, 38.0f, 56.0f, 4},
    {18.0f, 28.0f, 36.0f, 56.0f, 5},
    {19.0f, 28.0f, 38.0f, 56.0f, 6},
    {21.0f, 28.0f, 42.0f, 56.0f, 7},
    {23.0f, 28.0f, 46.0f, 56.0f, 8},
};

} // namespace

/** @ghidraAddress 0x10a7d8 */
BackgroundSpriteManager::BackgroundSpriteManager() = default;

/** @ghidraAddress 0x10a81c */
BackgroundSpriteManager *BackgroundSpriteManager::shared() {
    if (g_pBackgroundManager == nullptr) {
        g_pBackgroundManager = new BackgroundSpriteManager();
    }
    return g_pBackgroundManager;
}

/** @ghidraAddress 0x10a86c */
void BackgroundSpriteManager::BuildBackgroundSpriteNodes() {
    if (m_bBuilt) {
        return;
    }

    BgLayer *pBackgroundLayer = BgLayer::GetBackgroundLayer();
    ne::C_RENDER *pParent = pBackgroundLayer->GetBackgroundRenderObject();

    m_pTexture = ne::C_TEXTURE::FindOrLoadCached(kTextureName);

    for (int nSlot = 0; nSlot < kSpriteSlotCount; ++nSlot) {
        ne::C_SPRITE_INSTANCING_2D *pSprite = ne::CreateSpriteInstancer(kSlotCapacities[nSlot]);
        pParent->AttachChild(pSprite);
        pSprite->SetVisible(true);
        pSprite->SetRefCountedMember(m_pTexture);
        pSprite->SetSpriteCount(m_aSpriteCounts[nSlot]);
        if (nSlot != 1) {
            pSprite->SetBlendMode(kAdditiveBlendMode);
        }
        m_apSprites[nSlot] = pSprite;
    }

    m_bBuilt = true;
}

/** @ghidraAddress 0x10b1e0 */
void BackgroundSpriteManager::PushSpriteInstanceSlot(float flScaleX,
                                                     float flScaleY,
                                                     unsigned int nSlotIndex,
                                                     unsigned int nLayoutIndex,
                                                     const S_VECTOR2 *pPosition,
                                                     int nAlpha) {
    ne::C_SPRITE_INSTANCING_2D *pInstancer = m_apSprites[nSlotIndex];
    const int nSlot = pInstancer->GetSpriteCount();
    if (nSlot >= static_cast<int>(pInstancer->GetCapacity())) {
        return;
    }

    const ZoomSpriteLayout &layout = kZoomSpriteLayout[nLayoutIndex];
    const SpriteUvEntry &uv = g_aSpriteUvTable[layout.nUvFrameIndex];

    pInstancer->SetSpritePosition(nSlot, *pPosition);
    pInstancer->SetSpriteAnchor(nSlot, S_VECTOR2{layout.flAnchorX, layout.flAnchorY});
    pInstancer->SetSpriteSize(nSlot, S_VECTOR2{layout.flSizeX, layout.flSizeY});
    pInstancer->SetSpriteUvOrigin(nSlot, S_VECTOR2{uv.flOriginU, uv.flOriginV});
    pInstancer->SetSpriteUvSize(nSlot, S_VECTOR2{uv.flSizeU, uv.flSizeV});
    pInstancer->SetSpriteScale(nSlot, flScaleX, flScaleY);
    pInstancer->SetSpriteColor(
        nSlot, kColorMax, kColorMax, kColorMax, static_cast<unsigned int>(nAlpha));

    pInstancer->SetSpriteCount(nSlot + 1);
}

/** @ghidraAddress 0x10a938 */
void BackgroundSpriteManager::SetActiveAndResetCounter() {
    m_bActive = true;
    m_flTimer = 0.0f;
}

/** @ghidraAddress 0x10a948 */
void BackgroundSpriteManager::SetInactive(float flDuration) {
    (void)flDuration; // The binary takes a duration in s0 and never reads it.
    m_bActive = false;
}

namespace {

// @ghidraAddress 0x301cc4
constexpr float kEffectDuration = 1600.0f;

// @ghidraAddress 0x2ec6b0
constexpr float kEffectStartTime = 100.0f;

constexpr float kHalfScale = 0.5f;
constexpr float kFullScale = 1.0f;

// @ghidraAddress 0x2f8568
constexpr float kRowOriginX = -384.0f;

// @ghidraAddress 0x2eed00
constexpr float kAlphaByteScale = 255.0f;

constexpr unsigned int kSlotBurst = 0;
constexpr unsigned int kSlotRow = 1;
constexpr unsigned int kSlotGhostRow = 2;

constexpr unsigned int kLayoutBurst = 0;
constexpr unsigned int kLayoutHalo = 1;

constexpr int kRowSpriteCount = 11;
constexpr unsigned int kRowLayout[kRowSpriteCount] = {2, 3, 4, 4, 5, 6, 7, 4, 3, 8, 4};

constexpr int kTwoPointCurve = 2;
constexpr int kThreePointCurve = 3;
constexpr int kFourPointCurve = 4;
constexpr int kSixPointCurve = 6;

// @ghidraAddress 0x301cd4
constexpr float kBurstAAlphaCurve[] = {100.0f, 1.0f, 366.66666f, 0.0f};
// @ghidraAddress 0x301ce4
constexpr float kBurstAScaleCurve[] = {100.0f, 0.47f, 266.66666f, 1.17f, 1416.6666f, 1.69f};

// @ghidraAddress 0x301cfc
constexpr float kBurstBAlphaCurve[] = {
    100.0f, 0.0f, 166.66667f, 1.0f, 533.3333f, 1.0f, 1416.6666f, 0.0f};
// @ghidraAddress 0x301d1c
constexpr float kBurstBScaleCurve[] = {100.0f, 0.47f, 266.66666f, 1.17f, 1416.6666f, 1.69f};

// @ghidraAddress 0x301d34
constexpr float kHaloAlphaCurve[] = {100.0f,
                                     0.0f,
                                     166.66667f,
                                     0.75f,
                                     533.3333f,
                                     0.4f,
                                     1000.0f,
                                     0.4f,
                                     1333.3334f,
                                     0.4f,
                                     1500.0f,
                                     0.0f};

// @ghidraAddress 0x301d64
constexpr float kRowOffsetCurves[kRowSpriteCount][kTwoPointCurve * 2] = {
    {1333.3334f, 163.0f, 1583.3334f, 133.0f},
    {1333.3334f, 213.0f, 1583.3334f, 188.0f},
    {1333.3334f, 253.0f, 1583.3334f, 233.0f},
    {1333.3334f, 292.0f, 1583.3334f, 277.0f},
    {1333.3334f, 331.0f, 1583.3334f, 321.0f},
    {1333.3334f, 369.0f, 1583.3334f, 364.0f},
    {1333.3334f, 435.0f, 1583.3334f, 440.0f},
    {1333.3334f, 472.0f, 1583.3334f, 482.0f},
    {1333.3334f, 513.0f, 1583.3334f, 527.0f},
    {1333.3334f, 569.0f, 1583.3334f, 588.0f},
    {1333.3334f, 608.0f, 1583.3334f, 632.0f},
};

// @ghidraAddress 0x301e14
constexpr float kRowAlphaCurve[] = {1333.3334f, 1.0f, 1500.0f, 0.0f};
// @ghidraAddress 0x301e24
constexpr float kRowScaleYCurve[] = {0.0f, 0.0f, 133.33333f, 1.0f};
// @ghidraAddress 0x301e34
constexpr float kGhostAlphaCurve[] = {133.33333f, 0.6f, 333.33334f, 0.5f, 833.3333f, 0.0f};

} // namespace

/** @ghidraAddress 0x10a950 */
void BackgroundSpriteManager::Update(float flDelta) {
    for (ne::C_SPRITE_INSTANCING_2D *pInstancer : m_apSprites) {
        pInstancer->SetSpriteCount(0);
    }
    if (!m_bActive) {
        return;
    }

    m_flTimer += flDelta;
    if (m_flTimer >= kEffectDuration) {
        m_bActive = false;
        return;
    }

    GameSystem *pGameSystem = GameSystem::GetGameSystem();
    S_VECTOR2 center{pGameSystem->GetViewportWidth(), pGameSystem->GetViewportHeight()};
    ScaleVector2(&center, kHalfScale);
    const float flScale = IsPad() ? kFullScale : kHalfScale;

    if (m_flTimer > kEffectStartTime) {
        S_VECTOR2 position = center;
        const float flAlpha =
            CalculateCurveInterpolation(kBurstAAlphaCurve, kTwoPointCurve, m_flTimer);
        const float flBurstScale =
            flScale * CalculateCurveInterpolation(kBurstAScaleCurve, kThreePointCurve, m_flTimer);
        PushSpriteInstanceSlot(flBurstScale,
                               flBurstScale,
                               kSlotBurst,
                               kLayoutBurst,
                               &position,
                               static_cast<int>(flAlpha * kAlphaByteScale));
    }
    if (m_flTimer > kEffectStartTime) {
        S_VECTOR2 position = center;
        const float flAlpha =
            CalculateCurveInterpolation(kBurstBAlphaCurve, kFourPointCurve, m_flTimer);
        const float flBurstScale =
            flScale * CalculateCurveInterpolation(kBurstBScaleCurve, kThreePointCurve, m_flTimer);
        PushSpriteInstanceSlot(flBurstScale,
                               flBurstScale,
                               kSlotBurst,
                               kLayoutBurst,
                               &position,
                               static_cast<int>(flAlpha * kAlphaByteScale));
    }

    S_VECTOR2 haloPosition = center;
    const float flHaloAlpha =
        CalculateCurveInterpolation(kHaloAlphaCurve, kSixPointCurve, m_flTimer);
    PushSpriteInstanceSlot(flScale,
                           flScale,
                           kSlotBurst,
                           kLayoutHalo,
                           &haloPosition,
                           static_cast<int>(flHaloAlpha * kAlphaByteScale));

    const float flRowAlpha = CalculateCurveInterpolation(kRowAlphaCurve, kTwoPointCurve, m_flTimer);
    const float flRowScaleY =
        flScale * CalculateCurveInterpolation(kRowScaleYCurve, kTwoPointCurve, m_flTimer);
    const int nRowAlpha = static_cast<int>(flRowAlpha * kAlphaByteScale);
    for (int nSprite = 0; nSprite < kRowSpriteCount; ++nSprite) {
        const float flOffset =
            CalculateCurveInterpolation(kRowOffsetCurves[nSprite], kTwoPointCurve, m_flTimer);
        S_VECTOR2 position{center.x + flScale * (flOffset + kRowOriginX), center.y};
        PushSpriteInstanceSlot(
            flScale, flRowScaleY, kSlotRow, kRowLayout[nSprite], &position, nRowAlpha);
    }

    if (m_flTimer > kEffectStartTime) {
        const float flGhostAlpha =
            CalculateCurveInterpolation(kGhostAlphaCurve, kThreePointCurve, m_flTimer);
        const int nGhostAlpha = static_cast<int>(flGhostAlpha * kAlphaByteScale);
        for (int nSprite = 0; nSprite < kRowSpriteCount; ++nSprite) {
            const float flOffset =
                CalculateCurveInterpolation(kRowOffsetCurves[nSprite], kTwoPointCurve, 0.0f);
            S_VECTOR2 position{center.x + flScale * (flOffset + kRowOriginX), center.y};
            PushSpriteInstanceSlot(
                flScale, flScale, kSlotGhostRow, kRowLayout[nSprite], &position, nGhostAlpha);
        }
    }
}
