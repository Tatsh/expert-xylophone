#include "main_frame_layer.h"

#include "RBMacros.h"
#include "RBUserSettingData.h"
#include "frame_texture_table.h"
#include "gamesystem.h"
#include "neDrawPolygon2D.h"
#include "neDrawPolygon3D.h"
#include "neSpriteInstancing.h"
#include "neTexture.h"
#include "s_vector2.h"
#include "s_vector3.h"
#include "sprite_uv_table.h"

static MainFrameLayer *g_pMainFrameLayer = nullptr; // @ghidraAddress 0x3dedb0

static const char *const g_szGmParts2TextureKey = "00_texture/gm_parts2"; // @ghidraAddress 0x3ceaa8

namespace {

constexpr int kDefaultFrameType = 0x20;
constexpr int kDefaultMarker = 5;

constexpr float kFrameAlphaOpaque = 255.0f;
constexpr float kFrameAlphaTransparent = 0.0f;

constexpr int kFrameMeshSlot = 0;

constexpr int kFrameMesh3dVertexCount = 16;
constexpr int kFrameMesh2dVertexCount = 24;

constexpr float kAlphaInvisibleEpsilon = 0.001f; // @ghidraAddress 0x30c244

constexpr float kUvHalf = 0.5f;

constexpr unsigned int kOverlayChannelMax = 255;

struct MainFrameOverlayLayout {
    S_VECTOR2 anchor;
    S_VECTOR2 size; // In pixels.
    int nUvFrameIndex;
};

// The final entry is unused padding.
// @ghidraAddress 0x30ce98
const MainFrameOverlayLayout g_aMainFrameOverlayLayout[] = {
    {{17.0f, 2.0f}, {34.0f, 5.0f}, 0x179},  {{17.0f, 2.0f}, {34.0f, 5.0f}, 0x17a},
    {{15.0f, 5.0f}, {29.0f, 10.0f}, 0x17b}, {{15.0f, 5.0f}, {29.0f, 10.0f}, 0x17c},
    {{15.0f, 5.0f}, {29.0f, 10.0f}, 0x17d}, {{15.0f, 5.0f}, {29.0f, 10.0f}, 0x17e},
    {{6.0f, 5.0f}, {16.0f, 10.0f}, 0x17f},  {{6.0f, 5.0f}, {16.0f, 10.0f}, 0x180},
    {{6.0f, 5.0f}, {16.0f, 10.0f}, 0x181},  {{6.0f, 5.0f}, {16.0f, 10.0f}, 0x182},
    {{6.0f, 5.0f}, {16.0f, 10.0f}, 0x183},  {{6.0f, 5.0f}, {16.0f, 10.0f}, 0x184},
    {{6.0f, 5.0f}, {16.0f, 10.0f}, 0x185},  {{6.0f, 5.0f}, {16.0f, 10.0f}, 0x186},
    {{6.0f, 5.0f}, {16.0f, 10.0f}, 0x187},  {{6.0f, 5.0f}, {16.0f, 10.0f}, 0x188},
    {{6.0f, 5.0f}, {16.0f, 10.0f}, 0x189},  {{6.0f, 5.0f}, {16.0f, 10.0f}, 0x18a},
    {{6.0f, 5.0f}, {16.0f, 10.0f}, 0x18b},  {{6.0f, 5.0f}, {16.0f, 10.0f}, 0x18c},
    {{6.0f, 5.0f}, {16.0f, 10.0f}, 0x18d},  {{6.0f, 5.0f}, {16.0f, 10.0f}, 0x18e},
    {{6.0f, 5.0f}, {16.0f, 10.0f}, 0x18f},  {{6.0f, 5.0f}, {16.0f, 10.0f}, 0x190},
    {{6.0f, 5.0f}, {16.0f, 10.0f}, 0x191},  {{6.0f, 5.0f}, {16.0f, 10.0f}, 0x192},
    {{6.0f, 5.0f}, {16.0f, 10.0f}, 0x193},  {{6.0f, 5.0f}, {16.0f, 10.0f}, 0x194},
    {{6.0f, 5.0f}, {16.0f, 10.0f}, 0x195},  {{6.0f, 5.0f}, {16.0f, 10.0f}, 0x196},
    {{6.0f, 5.0f}, {16.0f, 10.0f}, 0x197},  {{6.0f, 5.0f}, {16.0f, 10.0f}, 0x198},
    {{6.0f, 5.0f}, {16.0f, 10.0f}, 0x199},  {{6.0f, 5.0f}, {16.0f, 10.0f}, 0x19a},
    {{6.0f, 5.0f}, {16.0f, 10.0f}, 0x19b},  {{6.0f, 5.0f}, {16.0f, 10.0f}, 0x19c},
    {{6.0f, 5.0f}, {16.0f, 10.0f}, 0x19d},  {{6.0f, 5.0f}, {16.0f, 10.0f}, 0x19e},
    {{6.0f, 5.0f}, {16.0f, 10.0f}, 0x19f},  {{6.0f, 5.0f}, {16.0f, 10.0f}, 0x1a0},
    {{6.0f, 5.0f}, {16.0f, 10.0f}, 0x1a1},  {{6.0f, 5.0f}, {16.0f, 10.0f}, 0x1a2},
    {{6.0f, 5.0f}, {16.0f, 10.0f}, 0x1a3},  {{6.0f, 5.0f}, {16.0f, 10.0f}, 0x1a4},
    {{6.0f, 5.0f}, {16.0f, 10.0f}, 0x1a5},  {{6.0f, 5.0f}, {16.0f, 10.0f}, 0x1a6},
    {{6.0f, 5.0f}, {16.0f, 10.0f}, 0x1a7},  {{6.0f, 5.0f}, {16.0f, 10.0f}, 0x1a8},
    {{6.0f, 5.0f}, {16.0f, 10.0f}, 0x1a9},  {{6.0f, 5.0f}, {16.0f, 10.0f}, 0x1aa},
    {{6.0f, 5.0f}, {16.0f, 10.0f}, 0x1ab},  {{6.0f, 5.0f}, {16.0f, 10.0f}, 0x1ac},
    {{6.0f, 5.0f}, {16.0f, 10.0f}, 0x1ad},  {{6.0f, 5.0f}, {16.0f, 10.0f}, 0x1ae},
    {{6.0f, 5.0f}, {16.0f, 10.0f}, 0x1af},  {{6.0f, 5.0f}, {16.0f, 10.0f}, 0x1b0},
    {{6.0f, 5.0f}, {16.0f, 10.0f}, 0x1b1},  {{6.0f, 5.0f}, {16.0f, 10.0f}, 0x1b2},
    {{6.0f, 5.0f}, {16.0f, 10.0f}, 0x1b3},  {{6.0f, 5.0f}, {16.0f, 10.0f}, 0x1b4},
    {{6.0f, 5.0f}, {16.0f, 10.0f}, 0x1b5},  {{6.0f, 5.0f}, {16.0f, 10.0f}, 0x1b6},
    {{6.0f, 5.0f}, {16.0f, 10.0f}, 0x1b7},  {{6.0f, 5.0f}, {16.0f, 10.0f}, 0x1b8},
    {{6.0f, 5.0f}, {16.0f, 10.0f}, 0x1b9},  {{6.0f, 5.0f}, {16.0f, 10.0f}, 0x1ba},
    {{17.0f, 2.0f}, {34.0f, 5.0f}, 0x1bd},  {{17.0f, 2.0f}, {34.0f, 5.0f}, 0x1be},
    {{15.0f, 4.0f}, {29.0f, 9.0f}, 0x1bf},  {{15.0f, 4.0f}, {29.0f, 9.0f}, 0x1c0},
    {{15.0f, 4.0f}, {29.0f, 9.0f}, 0x1c1},  {{15.0f, 4.0f}, {29.0f, 9.0f}, 0x1c2},
    {{0.0f, 0.0f}, {0.0f, 0.0f}, 0},
};

constexpr unsigned int kMainFrameSpriteKindBound = 0x49;

constexpr float kFrameInnerEdgeOffset = -123.5f; // @ghidraAddress 0x30ce1c
constexpr float kFrameInnerEdgeSpan = 247.0f;    // @ghidraAddress 0x30ce20
constexpr float kFrameTabTopY = 0.0f;
constexpr float kFrameStripTopY = 7.0f;
constexpr float kFrameBandBottomY = 21.0f;
constexpr float kFrameColumnInset = 11.0f;
constexpr float kFrameColumnMargin = 2.0f;

constexpr float kFrameLabelTopY = 2.0f;
constexpr float kFrameLabelMidY = 14.0f;
constexpr float kFrameMarkerY = 10.0f;
constexpr float kFrameCentreFactor = 0.5f;

constexpr unsigned int kFrameLabelSpriteLeft = 0;
constexpr unsigned int kFrameLabelSpriteRight = 1;
constexpr unsigned int kFrameMarkerSpriteOffset = 2;
constexpr unsigned int kColetteLabelSpriteLeft = 0x42;
constexpr unsigned int kColetteLabelSpriteRight = 0x43;
constexpr unsigned int kColetteMarkerSpriteOffset = 0x44;
constexpr unsigned int kFrameMeshMarkerSprite = 0x48;

// @ghidraAddress 0x30ce88
constexpr int kFrameDifficultyMarkerBase[] = {6, 21, 36, 51};

// The band width is the hardcoded design width rather than the measured far width.
constexpr float kFrameBorderBandWidth = 640.0f; // @ghidraAddress 0x30531c
constexpr float kFrameBorderBandHeight = 33.0f; // @ghidraAddress 0x302d50, negated at 0x30ce24.
constexpr float kFrameBorderStripWidth = 24.0f;

// At 1000x the ring's outer edge is far off screen, so it covers everything outside the sheet.
constexpr float kMarkerRingOuterScale = 1000.0f; // @ghidraAddress 0x2f8540

} // namespace

MainFrameLayer::MainFrameLayer() {
    m_nFrameType = kDefaultFrameType;
    m_nMarker = kDefaultMarker;
}

/** @ghidraAddress 0x17b5d4 */
MainFrameLayer *MainFrameLayer::shared() {
    if (g_pMainFrameLayer == nullptr) {
        g_pMainFrameLayer = new MainFrameLayer();
    }
    return g_pMainFrameLayer;
}

/** @ghidraAddress 0x17c670 */
void MainFrameLayer::StartFadeIn(float flDuration) {
    m_fadeChannel.SetStart(m_fadeChannel.GetCurrent());
    m_fadeChannel.SetEnd(kFrameAlphaOpaque);
    m_fadeChannel.SetDuration(flDuration);
    m_fadeChannel.SetElapsed(0.0f);
    if (flDuration <= 0.0f) {
        m_fadeChannel.SetCurrent(kFrameAlphaOpaque);
        m_bFadeDone = true;
    }
}

/** @ghidraAddress 0x17c6a0 */
void MainFrameLayer::StartFadeOut(float flDuration) {
    m_fadeChannel.SetStart(m_fadeChannel.GetCurrent());
    m_fadeChannel.SetEnd(kFrameAlphaTransparent);
    m_fadeChannel.SetDuration(flDuration);
    m_fadeChannel.SetElapsed(0.0f);
    if (flDuration <= 0.0f) {
        m_fadeChannel.SetCurrent(kFrameAlphaTransparent);
        m_bFadeDone = true;
    }
}

/** @ghidraAddress 0x17c9a8 */
void MainFrameLayer::SetMainFrameEnabled(bool bEnabled) {
    if (m_pFrameMesh2d != nullptr) {
        m_pFrameMesh2d->SetVisible(bEnabled);
    }
}

/** @ghidraAddress 0x17c4c0 */
void MainFrameLayer::SetFrameType(int nType) {
    if (m_nFrameType == nType) {
        return;
    }
    m_nFrameType = nType;
    m_bReady = false;
    BuildSprites();
}

/** @ghidraAddress 0x17c864 */
void MainFrameLayer::BuildGeometry() {
    SetOverlayLayout();
    Build3dVertices();
}

/** @ghidraAddress 0x17c6c8 */
void MainFrameLayer::Process(float flDelta) {
    GameSystem *pGameSystem = GameSystem::GetGameSystem();
    if (m_flLayoutWidth != pGameSystem->GetViewportWidth() ||
        m_flLayoutHeight != pGameSystem->GetViewportHeight()) {
        m_flLayoutWidth = pGameSystem->GetViewportWidth();
        m_flLayoutHeight = pGameSystem->GetViewportHeight();
        SetOverlayLayout();
        Build3dVertices();
    }

    const float flDuration = m_fadeChannel.GetDuration();
    if (flDuration > m_fadeChannel.GetElapsed()) {
        float flElapsed = m_fadeChannel.GetElapsed() + flDelta;
        if (flElapsed > flDuration) {
            flElapsed = flDuration;
        }
        m_fadeChannel.SetElapsed(flElapsed);
        const float flFraction = flDuration == 0.0f ? 1.0f : flElapsed / flDuration;
        m_fadeChannel.SetCurrent(m_fadeChannel.GetStart() +
                                 flFraction * (m_fadeChannel.GetEnd() - m_fadeChannel.GetStart()));
        m_bFadeDone = true; // Raised here and cleared again below; the apply path is shared.
    } else if (!m_bFadeDone) {
        return;
    }
    m_bFadeDone = false;

    const auto nAlpha = static_cast<unsigned char>(static_cast<int>(m_fadeChannel.GetCurrent()));
    for (int nVertex = 0; nVertex < kFrameMesh3dVertexCount; ++nVertex) {
        m_pFrameMesh3d->SetAlpha(nVertex, nAlpha);
    }
    for (int nVertex = 0; nVertex < kFrameMesh2dVertexCount; ++nVertex) {
        m_pFrameMesh2d->SetVertexAlpha(nVertex, nAlpha);
    }
    for (size_t nInstancer = 0; nInstancer < ARRAY_SIZE(m_apInstancers); ++nInstancer) {
        ne::C_SPRITE_INSTANCING_2D *pInstancer = m_apInstancers[nInstancer];
        for (int nSlot = 0; nSlot < pInstancer->GetSpriteCount(); ++nSlot) {
            pInstancer->SetColorAlpha(nSlot, nAlpha);
        }
    }

    m_pMarkerMesh3d->SetVisible(m_fadeChannel.GetCurrent() > kAlphaInvisibleEpsilon);
}

/** @ghidraAddress 0x17c55c */
void MainFrameLayer::SetMainFrameTexture(ne::C_TEXTURE *pTexture) {
    ne::C_SPRITE_INSTANCING_2D *pFrameMesh = m_apInstancers[MainFrameInstancerFrame];
    if (pFrameMesh == nullptr) {
        return;
    }
    pFrameMesh->SetRefCountedMember(pTexture);
    if (pTexture == nullptr) {
        return;
    }

    const float flPointWidth = static_cast<float>(pTexture->GetImageWidth()) / pTexture->GetScale();
    const float flPointHeight =
        static_cast<float>(pTexture->GetImageHeight()) / pTexture->GetScale();

    pFrameMesh->SetSpriteAnchor(
        kFrameMeshSlot,
        S_VECTOR2{static_cast<float>(static_cast<int>(flPointWidth * kUvHalf)),
                  static_cast<float>(static_cast<int>(flPointHeight * kUvHalf))});
    pFrameMesh->SetSpriteSize(kFrameMeshSlot, S_VECTOR2{flPointWidth, flPointHeight});
    pFrameMesh->SetSpriteUvOrigin(kFrameMeshSlot, S_VECTOR2{0.0f, 0.0f});
    pFrameMesh->SetSpriteUvSize(
        kFrameMeshSlot,
        S_VECTOR2{static_cast<float>(pTexture->GetImageWidth()) / pTexture->GetAllocWidth(),
                  static_cast<float>(pTexture->GetImageHeight()) / pTexture->GetAllocHeight()});
}

/** @ghidraAddress 0x17c888 */
void MainFrameLayer::EmitMainFrameSprite(unsigned int nInstancerIndex,
                                         unsigned int nSpriteKind,
                                         float flX,
                                         float flY) {
    if (nInstancerIndex >= 2 || nSpriteKind >= kMainFrameSpriteKindBound) {
        return;
    }
    ne::C_SPRITE_INSTANCING_2D *pInstancer = m_apInstancers[nInstancerIndex];
    const int nSlot = pInstancer->GetSpriteCount();
    if (nSlot >= static_cast<int>(pInstancer->GetCapacity())) {
        return;
    }

    if (nInstancerIndex == MainFrameInstancerOverlay) {
        const MainFrameOverlayLayout &layout = g_aMainFrameOverlayLayout[nSpriteKind];
        const SpriteUvEntry &uv = g_aSpriteUvTable[layout.nUvFrameIndex];
        pInstancer->SetSpritePosition(nSlot, S_VECTOR2{flX, flY});
        pInstancer->SetSpriteSize(nSlot, layout.size);
        pInstancer->SetSpriteAnchor(nSlot, layout.anchor);
        pInstancer->SetSpriteUvOrigin(nSlot, S_VECTOR2{uv.flOriginU, uv.flOriginV});
        pInstancer->SetSpriteUvSize(nSlot, S_VECTOR2{uv.flSizeU, uv.flSizeV});
    } else {
        pInstancer->SetSpritePosition(nSlot, S_VECTOR2{flX, flY});
    }

    pInstancer->SetSpriteColor(
        nSlot,
        kOverlayChannelMax,
        kOverlayChannelMax,
        kOverlayChannelMax,
        static_cast<unsigned int>(static_cast<int>(m_fadeChannel.GetCurrent())));
    pInstancer->SetSpriteCount(nSlot + 1);
}

/** @ghidraAddress 0x17c16c */
void MainFrameLayer::Build3dVertices() {
    const GameSystem *pGameSystem = GameSystem::GetGameSystem();

    // Both rectangles are centred on the origin, so the centre terms always evaluate to zero; the
    // binary computes them anyway.
    const float flFarX = pGameSystem->GetSheetFarX();
    const float flFarY = pGameSystem->GetSheetFarY();
    const float flOuterLeft = flFarX * -kFrameCentreFactor;
    const float flOuterRight = flFarX + flOuterLeft;
    const float flOuterBottom = flFarY * -kFrameCentreFactor;
    const float flOuterTop = flFarY + flOuterBottom;
    const float flCentreX = flOuterLeft + flFarX * kFrameCentreFactor;
    const float flCentreY = flOuterBottom + flFarY * kFrameCentreFactor;

    const float flSheetX = pGameSystem->GetSheetPosX();
    const float flSheetY = pGameSystem->GetSheetPosY();
    const float flInnerLeft = flCentreX - flSheetX * kFrameCentreFactor;
    const float flInnerRight = flSheetX + flInnerLeft;
    const float flInnerBottom = flCentreY - flSheetY * kFrameCentreFactor;
    const float flInnerTop = flSheetY + flInnerBottom;

    const float flBandRightX = flOuterLeft + kFrameBorderBandWidth;
    const float flBottomBandTopY = flOuterBottom + kFrameBorderBandHeight;
    const float flTopBandBottomY = flOuterTop - kFrameBorderBandHeight;
    const float flLeftStripRightX = flOuterLeft + kFrameBorderStripWidth;
    const float flRightStripLeftX = flOuterRight - kFrameBorderStripWidth;

    const S_VECTOR3 aBorderVertices[] = {
        {flOuterLeft, flOuterBottom, 0.0f},
        {flBandRightX, flOuterBottom, 0.0f},
        {flOuterLeft, flBottomBandTopY, 0.0f},
        {flBandRightX, flBottomBandTopY, 0.0f},
        {flOuterLeft, flTopBandBottomY, 0.0f},
        {flBandRightX, flTopBandBottomY, 0.0f},
        {flOuterLeft, flOuterTop, 0.0f},
        {flBandRightX, flOuterTop, 0.0f},
        {flOuterLeft, flBottomBandTopY, 0.0f},
        {flLeftStripRightX, flBottomBandTopY, 0.0f},
        {flOuterLeft, flTopBandBottomY, 0.0f},
        {flLeftStripRightX, flTopBandBottomY, 0.0f},
        {flRightStripLeftX, flBottomBandTopY, 0.0f},
        {flOuterRight, flBottomBandTopY, 0.0f},
        {flRightStripLeftX, flTopBandBottomY, 0.0f},
        {flOuterRight, flTopBandBottomY, 0.0f},
    };
    int nVertex = 0;
    for (const S_VECTOR3 &vertex : aBorderVertices) {
        m_pFrameMesh3d->SetPos(nVertex++, vertex);
    }

    // The ring's outer vertices take their X from the far rectangle but their Y from the sheet
    // rectangle; the mismatch is the binary's.
    const S_VECTOR3 aMarkerRingVertices[] = {
        {flOuterLeft * kMarkerRingOuterScale, flInnerBottom * kMarkerRingOuterScale, 0.0f},
        {flInnerLeft, flInnerBottom, 0.0f},
        {flOuterLeft * kMarkerRingOuterScale, flInnerTop * kMarkerRingOuterScale, 0.0f},
        {flInnerLeft, flInnerTop, 0.0f},
        {flOuterRight * kMarkerRingOuterScale, flInnerTop * kMarkerRingOuterScale, 0.0f},
        {flInnerRight, flInnerTop, 0.0f},
        {flOuterRight * kMarkerRingOuterScale, flInnerBottom * kMarkerRingOuterScale, 0.0f},
        {flInnerRight, flInnerBottom, 0.0f},
    };
    nVertex = 0;
    for (const S_VECTOR3 &vertex : aMarkerRingVertices) {
        m_pMarkerMesh3d->SetPos(nVertex++, vertex);
    }
}

/** @ghidraAddress 0x17bd50 */
void MainFrameLayer::SetOverlayLayout() {
    const RBUserSettingDataTheme theme = [RBUserSettingData sharedInstance].thema;

    const float flWidth = GameSystem::GetGameSystem()->GetViewportWidth();
    const float flHalfWidth = flWidth * kFrameCentreFactor;
    const float flLeftInner = flHalfWidth + kFrameInnerEdgeOffset;
    const float flRightInner = flLeftInner + kFrameInnerEdgeSpan;

    const float aTabColumnsX[] = {
        flLeftInner,
        flLeftInner + kFrameColumnInset,
        flRightInner - kFrameColumnInset,
        flRightInner,
    };
    const float aStripColumnsX[] = {
        kFrameColumnMargin,
        kFrameColumnInset,
        flLeftInner - kFrameColumnInset,
        flLeftInner - kFrameColumnMargin,
        flRightInner + kFrameColumnMargin,
        flRightInner + kFrameColumnInset,
        flWidth - kFrameColumnInset,
        flWidth - kFrameColumnMargin,
    };

    int nVertex = 0;
    for (const float flColumnX : aTabColumnsX) {
        m_pFrameMesh2d->SetPos(nVertex++, S_VECTOR2{flColumnX, kFrameTabTopY});
        m_pFrameMesh2d->SetPos(nVertex++, S_VECTOR2{flColumnX, kFrameBandBottomY});
    }
    for (const float flColumnX : aStripColumnsX) {
        m_pFrameMesh2d->SetPos(nVertex++, S_VECTOR2{flColumnX, kFrameStripTopY});
        m_pFrameMesh2d->SetPos(nVertex++, S_VECTOR2{flColumnX, kFrameBandBottomY});
    }

    for (ne::C_SPRITE_INSTANCING_2D *pInstancer : m_apInstancers) {
        pInstancer->SetSpriteCount(0);
    }

    const float flLeftLabelX =
        kFrameColumnMargin +
        ((flLeftInner - kFrameColumnMargin) - kFrameColumnMargin) * kFrameCentreFactor;
    const float flRightLabelX =
        (flRightInner + kFrameColumnMargin) +
        ((flWidth - kFrameColumnMargin) - (flRightInner + kFrameColumnMargin)) * kFrameCentreFactor;

    unsigned int nMarkerSpriteKind;
    if (theme == RBUserSettingDataThemeColette) {
        EmitMainFrameSprite(
            MainFrameInstancerOverlay, kColetteLabelSpriteLeft, flLeftLabelX, kFrameLabelTopY);
        EmitMainFrameSprite(
            MainFrameInstancerOverlay, kColetteLabelSpriteRight, flRightLabelX, kFrameLabelTopY);
        nMarkerSpriteKind = m_nMarker + kColetteMarkerSpriteOffset;
    } else {
        EmitMainFrameSprite(
            MainFrameInstancerOverlay, kFrameLabelSpriteLeft, flLeftLabelX, kFrameLabelTopY);
        EmitMainFrameSprite(
            MainFrameInstancerOverlay, kFrameLabelSpriteRight, flRightLabelX, kFrameLabelTopY);
        nMarkerSpriteKind = m_nMarker + kFrameMarkerSpriteOffset;
    }

    EmitMainFrameSprite(
        MainFrameInstancerOverlay, nMarkerSpriteKind, flRightLabelX, kFrameLabelMidY);
    EmitMainFrameSprite(MainFrameInstancerOverlay,
                        m_nDifficulty + kFrameDifficultyMarkerBase[m_nMarker],
                        flLeftLabelX,
                        kFrameLabelMidY);

    EmitMainFrameSprite(
        MainFrameInstancerFrame, kFrameMeshMarkerSprite, flHalfWidth, kFrameMarkerY);
}

/** @ghidraAddress 0x17c4dc */
void MainFrameLayer::SetMarker(int nMarker, int nDifficulty) {
    if (!m_bReady) {
        BuildSprites();
    }
    bool bChanged = m_nMarker != nMarker;
    if (bChanged) {
        m_nMarker = nMarker;
    }
    if (m_nDifficulty != nDifficulty) {
        m_nDifficulty = nDifficulty;
    } else if (!bChanged) {
        return;
    }
    SetOverlayLayout();
}

namespace {

constexpr unsigned int kMarkerMesh3dVertexCount = 8;
constexpr unsigned int kMarkerMesh3dIndexCount = 10;
constexpr int kFrameMesh3dIndexCount = 22;
constexpr int kFrameMesh2dIndexCount = 28;

constexpr unsigned int kMeshDrawMode = 4;
constexpr unsigned int kMarkerVertexFormat = 5;
constexpr unsigned int kTexturedVertexFormat = 7;
constexpr bool kVertexBufferExternal = true;
constexpr bool kIndexBufferExternal = false;

constexpr int kTexEnvParamSlotA = 1;
constexpr int kTexEnvParamSlotB = 0;
constexpr int kTexEnvParamValue = 1;

constexpr int kFrameQuadCount = 4;
constexpr int kQuadVertexCount = 4;
constexpr int kBorderFlippedQuadStart = 2;

constexpr int kOverlayBandCount = 3;
constexpr int kOverlayBandVertexCount = 8;
constexpr int kOverlayTabBandCount = 1;

constexpr unsigned int kOverlayInstancerCapacity = 6;
constexpr unsigned int kFrameInstancerCapacity = 1;

constexpr int kInstancerEmptyCount = 0;

constexpr unsigned char kVertexChannelMin = 0;
constexpr unsigned char kVertexChannelMax = 255;
constexpr unsigned char kVertexAlphaClear = 0;
constexpr unsigned char kVertexAlphaOpaque = 255;

// @ghidraAddress 0x30ce28
constexpr int kMarkerMeshIndices[] = {0, 1, 2, 3, 4, 5, 6, 7, 0, 1};

// @ghidraAddress 0x30ce50
constexpr short kFrameMesh2dIndices[] = {0,  1,  2,  3,  4,  5,  6,  7,  7,  8,  8,  9,  10, 11,
                                         12, 13, 14, 15, 15, 16, 16, 17, 18, 19, 20, 21, 22, 23};

// @ghidraAddress 0x2f1ae8
constexpr SpriteUvEntry kFrameBorderUv[kFrameQuadCount] = {
    {0.0f, 0.0f, 0.2578125f, 0.625f},
    {0.2890625f, 0.0f, 0.2578125f, 0.625f},
    {0.5625f, 0.0009765625f, 0.1875f, 0.8183594f},
    {0.765625f, 0.0009765625f, 0.1875f, 0.8183594f},
};

constexpr int kOverlayTabUvIndexDefault = 443;
constexpr int kOverlayStripUvIndexDefault = 444;
constexpr int kOverlayTabUvIndexColette = 451;
constexpr int kOverlayStripUvIndexColette = 452;

// Whether each corner takes the rectangle's far U and far V edge rather than its origin.
constexpr bool kBorderCornerOrderA[kQuadVertexCount][2] = {
    {false, true}, {false, false}, {true, true}, {true, false}};
constexpr bool kBorderCornerOrderB[kQuadVertexCount][2] = {
    {false, false}, {true, false}, {false, true}, {true, true}};
constexpr bool kOverlayCornerOrder[kOverlayBandVertexCount][2] = {{false, false},
                                                                  {false, true},
                                                                  {true, false},
                                                                  {true, true},
                                                                  {true, false},
                                                                  {true, true},
                                                                  {false, false},
                                                                  {false, true}};

inline S_VECTOR2 CornerUv(const SpriteUvEntry &rect, bool bFarU, bool bFarV) {
    return S_VECTOR2{bFarU ? rect.flOriginU + rect.flSizeU : rect.flOriginU,
                     bFarV ? rect.flOriginV + rect.flSizeV : rect.flOriginV};
}

// @ghidraAddress 0x3dedb8
struct FrameBorderUvTable {
    S_VECTOR2 aUv[kFrameMesh3dVertexCount] = {};
};

FrameBorderUvTable BuildFrameBorderUvTable() {
    FrameBorderUvTable table;
    for (int nQuad = 0; nQuad < kFrameQuadCount; ++nQuad) {
        const auto &order =
            nQuad < kBorderFlippedQuadStart ? kBorderCornerOrderA : kBorderCornerOrderB;
        for (int nCorner = 0; nCorner < kQuadVertexCount; ++nCorner) {
            table.aUv[nQuad * kQuadVertexCount + nCorner] =
                CornerUv(kFrameBorderUv[nQuad], order[nCorner][0], order[nCorner][1]);
        }
    }
    return table;
}

} // namespace

/** @ghidraAddress 0x17b654 */
void MainFrameLayer::BuildSprites() {
    // The default frame type is a sentinel meaning the frame the player has equipped.
    if (m_nFrameType == kDefaultFrameType) {
        m_nFrameType = GameSystem::GetGameSystem()->GetFrameType();
    }

    // Drop both atlases before reloading them, so a frame-type change does not leak the old ones.
    if (m_pFrameTexture != nullptr) {
        m_pFrameTexture->Release();
        m_pFrameTexture = nullptr;
    }
    if (m_pOverlayTexture != nullptr) {
        m_pOverlayTexture->Release();
        m_pOverlayTexture = nullptr;
    }
    // The sentinel survives only when the game system is itself unset, leaving the meshes
    // untextured.
    if (m_nFrameType != kDefaultFrameType) {
        m_pFrameTexture = ne::C_TEXTURE::FindOrLoadCached(g_aFrameTextureNames[m_nFrameType]);
        m_pOverlayTexture = ne::C_TEXTURE::FindOrLoadCached(g_szGmParts2TextureKey);
    }

    if (m_pMarkerMesh3d == nullptr) {
        m_pMarkerMesh3d = ne::CreatePolygon3dMesh(kMeshDrawMode,
                                                  kMarkerMesh3dVertexCount,
                                                  kMarkerVertexFormat,
                                                  kVertexBufferExternal,
                                                  kMarkerMesh3dIndexCount,
                                                  kIndexBufferExternal);
        m_pMarkerMesh3d->RegisterGlobal();
        m_pMarkerMesh3d->SetVisible(false);
        for (int nVertex = 0; nVertex < static_cast<int>(kMarkerMesh3dVertexCount); ++nVertex) {
            m_pMarkerMesh3d->SetPos(nVertex, S_VECTOR3{0.0f, 0.0f, 0.0f});
            m_pMarkerMesh3d->SetRGBA(nVertex,
                                     kVertexChannelMin,
                                     kVertexChannelMin,
                                     kVertexChannelMin,
                                     kVertexAlphaOpaque);
        }
        for (int nIndex = 0; nIndex < static_cast<int>(kMarkerMesh3dIndexCount); ++nIndex) {
            m_pMarkerMesh3d->SetIndex(nIndex,
                                      static_cast<unsigned short>(kMarkerMeshIndices[nIndex]));
        }
    }

    if (m_pFrameMesh3d == nullptr) {
        m_pFrameMesh3d = ne::CreatePolygon3dMesh(kMeshDrawMode,
                                                 kFrameMesh3dVertexCount,
                                                 kTexturedVertexFormat,
                                                 kVertexBufferExternal,
                                                 kFrameMesh3dIndexCount,
                                                 kIndexBufferExternal);
        m_pFrameMesh3d->RegisterGlobal();
    }
    m_pFrameMesh3d->SetTexture(m_pFrameTexture);
    m_pFrameMesh3d->SetVisible(true);
    m_pFrameMesh3d->SetTexEnvParam(kTexEnvParamSlotA, kTexEnvParamValue);
    m_pFrameMesh3d->SetTexEnvParam(kTexEnvParamSlotB, kTexEnvParamValue);

    static const FrameBorderUvTable kBorderUv = BuildFrameBorderUvTable();
    for (int nVertex = 0; nVertex < kFrameMesh3dVertexCount; ++nVertex) {
        m_pFrameMesh3d->SetPos(nVertex, S_VECTOR3{0.0f, 0.0f, 0.0f});
        m_pFrameMesh3d->SetRGBA(
            nVertex, kVertexChannelMax, kVertexChannelMax, kVertexChannelMax, kVertexAlphaClear);
        m_pFrameMesh3d->SetUvFromVec(nVertex, &kBorderUv.aUv[nVertex]);
    }

    // The vertex on each side of a quad boundary is repeated so the connecting triangles collapse.
    int nStripIndex = 0;
    for (int nVertex = 0; nVertex < kFrameMesh3dVertexCount; nVertex += kQuadVertexCount) {
        if (nVertex != 0) {
            m_pFrameMesh3d->SetIndex(nStripIndex++, static_cast<unsigned short>(nVertex));
        }
        for (int nCorner = 0; nCorner < kQuadVertexCount; ++nCorner) {
            m_pFrameMesh3d->SetIndex(nStripIndex++, static_cast<unsigned short>(nVertex + nCorner));
        }
        if (nVertex + kQuadVertexCount >= kFrameMesh3dVertexCount) {
            break;
        }
        m_pFrameMesh3d->SetIndex(nStripIndex++,
                                 static_cast<unsigned short>(nVertex + kQuadVertexCount - 1));
    }

    // The 2D overlay mesh hangs off the border mesh, so it inherits its transform.
    if (m_pFrameMesh2d == nullptr) {
        m_pFrameMesh2d = ne::CreatePolygon2dMesh(kMeshDrawMode,
                                                 kFrameMesh2dVertexCount,
                                                 kTexturedVertexFormat,
                                                 kVertexBufferExternal,
                                                 kFrameMesh2dIndexCount,
                                                 kIndexBufferExternal);
        m_pFrameMesh3d->AttachChild(m_pFrameMesh2d);
    }
    m_pFrameMesh2d->SetTexture(m_pOverlayTexture);
    m_pFrameMesh2d->SetVisible(true);

    const RBUserSettingDataTheme theme = [RBUserSettingData sharedInstance].thema;
    const bool bColette = theme == RBUserSettingDataThemeColette;
    const SpriteUvEntry &tabRect =
        g_aSpriteUvTable[bColette ? kOverlayTabUvIndexColette : kOverlayTabUvIndexDefault];
    const SpriteUvEntry &stripRect =
        g_aSpriteUvTable[bColette ? kOverlayStripUvIndexColette : kOverlayStripUvIndexDefault];

    S_VECTOR2 aOverlayUv[kFrameMesh2dVertexCount];
    for (int nBand = 0; nBand < kOverlayBandCount; ++nBand) {
        const SpriteUvEntry &rect = nBand < kOverlayTabBandCount ? tabRect : stripRect;
        for (int nCorner = 0; nCorner < kOverlayBandVertexCount; ++nCorner) {
            aOverlayUv[nBand * kOverlayBandVertexCount + nCorner] =
                CornerUv(rect, kOverlayCornerOrder[nCorner][0], kOverlayCornerOrder[nCorner][1]);
        }
    }

    for (int nVertex = 0; nVertex < kFrameMesh2dVertexCount; ++nVertex) {
        m_pFrameMesh2d->SetPos(nVertex, S_VECTOR2{0.0f, 0.0f});
        m_pFrameMesh2d->SetRGBA(
            nVertex, kVertexChannelMax, kVertexChannelMax, kVertexChannelMax, kVertexAlphaClear);
        m_pFrameMesh2d->SetUVFromVec(nVertex, &aOverlayUv[nVertex]);
    }
    for (int nIndex = 0; nIndex < kFrameMesh2dIndexCount; ++nIndex) {
        m_pFrameMesh2d->SetIndex(nIndex, static_cast<unsigned short>(kFrameMesh2dIndices[nIndex]));
    }

    // The frame instancer's texture comes from SetMainFrameTexture rather than from here.
    if (m_apInstancers[MainFrameInstancerOverlay] == nullptr) {
        m_apInstancers[MainFrameInstancerOverlay] =
            ne::CreateSpriteInstancer(kOverlayInstancerCapacity);
        m_pFrameMesh2d->AttachChild(m_apInstancers[MainFrameInstancerOverlay]);
    }
    m_apInstancers[MainFrameInstancerOverlay]->SetVisible(true);
    m_apInstancers[MainFrameInstancerOverlay]->SetRefCountedMember(m_pOverlayTexture);
    m_apInstancers[MainFrameInstancerOverlay]->SetSpriteCount(kInstancerEmptyCount);

    if (m_apInstancers[MainFrameInstancerFrame] == nullptr) {
        m_apInstancers[MainFrameInstancerFrame] =
            ne::CreateSpriteInstancer(kFrameInstancerCapacity);
        m_pFrameMesh2d->AttachChild(m_apInstancers[MainFrameInstancerFrame]);
    }
    m_apInstancers[MainFrameInstancerFrame]->SetVisible(true);
    m_apInstancers[MainFrameInstancerFrame]->SetSpriteCount(kInstancerEmptyCount);

    SetOverlayLayout();
    Build3dVertices();
    m_bReady = true;
}
