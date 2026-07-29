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

// The process-wide main-frame layer, created lazily by shared().
static MainFrameLayer *g_pMainFrameLayer = nullptr; // @ghidraAddress 0x3dedb0

// The shared parts atlas the frame's overlay mesh and sprites draw from.
static const char *const g_szGmParts2TextureKey = "00_texture/gm_parts2"; // @ghidraAddress 0x3ceaa8

namespace {

// The fields the constructor seeds: the default frame type and the default marker.
constexpr int kDefaultFrameType = 0x20;
constexpr int kDefaultMarker = 5;

// The frame's fully-opaque alpha endpoint (255).
constexpr float kFrameAlphaOpaque = 255.0f;
constexpr float kFrameAlphaTransparent = 0.0f;

// The frame mesh's single textured slot.
constexpr int kFrameMeshSlot = 0;

// The vertex counts of the two meshes the per-frame step fades: the 3D frame border and the 2D
// overlay mesh.
constexpr int kFrameMesh3dVertexCount = 16;
constexpr int kFrameMesh2dVertexCount = 24;

// The alpha at or below which the marker mesh counts as invisible and is hidden outright.
constexpr float kAlphaInvisibleEpsilon = 0.001f; // @ghidraAddress 0x30c244

// Halves a scaled dimension into a half-pixel UV offset.
constexpr float kUvHalf = 0.5f;

// The overlay sprite's fully-opaque channel value.
constexpr unsigned int kOverlayChannelMax = 255;

// One record of the main-frame overlay-layout table: the anchor, pixel size, and UV atlas-frame
// index of one overlay sprite, keyed by its sprite kind.
struct MainFrameOverlayLayout {
    S_VECTOR2 anchor;  // +0x00: the sprite's pivot offset.
    S_VECTOR2 size;    // +0x08: the sprite's pixel size.
    int nUvFrameIndex; // +0x10: the frame index into the shared sprite UV atlas.
};

// The main-frame overlay-layout table, keyed by sprite kind. Static read-only data embedded in the
// binary; @c EmitMainFrameSprite indexes it for the overlay instancer. The final entry is unused
// padding (the sprite-kind bound is one past the last live record). @ghidraAddress 0x30ce98
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

// The sprite-kind bound the emitter rejects at or above (the overlay-layout table's element count).
constexpr unsigned int kMainFrameSpriteKindBound = 0x49;

// The overlay-layout geometry, all in points. The frame mesh is two horizontal bands: a short
// centre tab (top edge at y=0) and the full-width bottom strip (top edge at y=7), both sharing the
// bottom edge at y=21. Each band is a run of columns; consecutive vertex indices give a column its
// top vertex then its bottom vertex. The two inner columns sit a fixed span either side of the
// screen centre; the strip's outer columns sit fixed insets in from the screen edges.
constexpr float kFrameInnerEdgeOffset = -123.5f; // @ghidraAddress 0x30ce1c: the left inner column's
                                                 //   offset from the screen centre.
constexpr float kFrameInnerEdgeSpan = 247.0f; // @ghidraAddress 0x30ce20: the span from the left to
                                              //   the right inner column (twice the half-offset).
constexpr float kFrameTabTopY = 0.0f;         // The centre tab's top edge.
constexpr float kFrameStripTopY = 7.0f;       // The bottom strip's top edge.
constexpr float kFrameBandBottomY = 21.0f;    // The shared bottom edge of both bands.
constexpr float kFrameColumnInset = 11.0f; // A column's inset from an inner edge or a screen edge.
constexpr float kFrameColumnMargin = 2.0f; // A column's small margin from an inner or screen edge.

// The label and marker sprite Y positions, and the centring divisor for the label-panel X spans.
constexpr float kFrameLabelTopY = 2.0f;    // The two top label sprites' Y.
constexpr float kFrameLabelMidY = 14.0f;   // The marker and difficulty label sprites' Y.
constexpr float kFrameMarkerY = 10.0f;     // The frame-mesh marker sprite's Y.
constexpr float kFrameCentreFactor = 0.5f; // Halves a span to centre a label panel within it.

// The overlay sprite kinds. The Colette theme (thema == 2) uses a distinct set of label and marker
// sprites; every other theme uses the base set.
constexpr unsigned int kFrameLabelSpriteLeft = 0;       // The left label, base themes.
constexpr unsigned int kFrameLabelSpriteRight = 1;      // The right label, base themes.
constexpr unsigned int kFrameMarkerSpriteOffset = 2;    // The marker sprite's base, base themes.
constexpr unsigned int kColetteLabelSpriteLeft = 0x42;  // The left label, Colette theme.
constexpr unsigned int kColetteLabelSpriteRight = 0x43; // The right label, Colette theme.
constexpr unsigned int kColetteMarkerSpriteOffset =
    0x44; // The marker sprite's base, Colette theme.
constexpr unsigned int kFrameMeshMarkerSprite =
    0x48; // The centred marker sprite on the frame mesh.

// The per-marker base sprite kind the difficulty index is added to for the difficulty label.
// @ghidraAddress 0x30ce88
constexpr int kFrameDifficultyMarkerBase[] = {6, 21, 36, 51};

// The 3D border's geometry, all in sheet units. The border is a picture frame of four quads: a
// bottom band, a top band, and a left and right vertical strip spanning between them. The band
// width is the hardcoded design width rather than the measured far width, so it only reaches the
// right edge on a 640-unit-wide sheet.
constexpr float kFrameBorderBandWidth = 640.0f; // @ghidraAddress 0x30531c
constexpr float kFrameBorderBandHeight = 33.0f; // @ghidraAddress 0x302d50, negated at 0x30ce24.
constexpr float kFrameBorderStripWidth = 24.0f; // The left and right strips' width.

// The factor the marker ring's outer corners are pushed out by. At 1000x the ring's outer edge is
// far off screen, so the ring covers everything outside the sheet rectangle. The binary reads this
// from the pooled 1000.0 literal it shares with unrelated call sites.
constexpr float kMarkerRingOuterScale = 1000.0f; // @ghidraAddress 0x2f8540

} // namespace

// The binary inlines this constructor into shared (0x17b5d4).
MainFrameLayer::MainFrameLayer() {
    // The base constructor and the zero-initialised members clear the layer; the constructor then
    // seeds the two non-zero defaults.
    m_nFrameType = kDefaultFrameType;
    m_nMarker = kDefaultMarker;
}

/** @ghidraAddress 0x17b5d4 */
MainFrameLayer *MainFrameLayer::shared() {
    if (g_pMainFrameLayer == nullptr) {
        // The binary allocates the raw 0x78-byte object and runs the constructor inline.
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
    // A non-positive duration snaps straight to opaque and marks the fade done.
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
    // A non-positive duration snaps straight to transparent and marks the fade done.
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
    // Re-lay-out the overlay and the 3D border whenever the viewport has changed size.
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
        // Advance the fade toward its end, clamping the elapsed time to the duration.
        float flElapsed = m_fadeChannel.GetElapsed() + flDelta;
        if (flElapsed > flDuration) {
            flElapsed = flDuration;
        }
        m_fadeChannel.SetElapsed(flElapsed);
        const float flFraction = flDuration == 0.0f ? 1.0f : flElapsed / flDuration;
        m_fadeChannel.SetCurrent(m_fadeChannel.GetStart() +
                                 flFraction * (m_fadeChannel.GetEnd() - m_fadeChannel.GetStart()));
        // Raised and then cleared again below; the apply path is shared with the snapped fade.
        m_bFadeDone = true;
    } else if (!m_bFadeDone) {
        // The fade is complete and its final alpha has already been applied.
        return;
    }
    m_bFadeDone = false;

    // Push the fade alpha into both meshes and every live sprite slot.
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

    // The marker mesh is hidden outright once the fade has taken it to invisible.
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

    // The frame texture's source dimensions in points (its image size divided by the retina scale).
    const float flPointWidth = static_cast<float>(pTexture->GetImageWidth()) / pTexture->GetScale();
    const float flPointHeight =
        static_cast<float>(pTexture->GetImageHeight()) / pTexture->GetScale();

    // The mesh's single slot draws the whole texture: its anchor is the half-point centre (rounded
    // to whole pixels), its size the full point dimensions, its UV origin zero, and its UV size the
    // source image fraction of the allocated (power-of-two) texture.
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

    // The overlay instancer places the sprite by size, anchor, and UV atlas frame from the layout
    // table; the frame-mesh instancer takes only the position.
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

    // Draw white with the frame fade channel's current value as the alpha, then claim the slot.
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

    // The outer rectangle is the sheet plus its margins; the inner one is the sheet itself. Both
    // are centred on the origin, so the centre terms below always evaluate to zero. The binary
    // computes them anyway and they are kept to show where the inner edges are measured from.
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

    // The border's shared edges: the bands' right edge, the two bands' inner edges, and the inner
    // edge of each vertical strip.
    const float flBandRightX = flOuterLeft + kFrameBorderBandWidth;
    const float flBottomBandTopY = flOuterBottom + kFrameBorderBandHeight;
    const float flTopBandBottomY = flOuterTop - kFrameBorderBandHeight;
    const float flLeftStripRightX = flOuterLeft + kFrameBorderStripWidth;
    const float flRightStripLeftX = flOuterRight - kFrameBorderStripWidth;

    // The four quads, in the order the 22-index triangle strip walks them. Every vertex sits on the
    // z=0 plane.
    const S_VECTOR3 aBorderVertices[] = {
        // The bottom band.
        {flOuterLeft, flOuterBottom, 0.0f},
        {flBandRightX, flOuterBottom, 0.0f},
        {flOuterLeft, flBottomBandTopY, 0.0f},
        {flBandRightX, flBottomBandTopY, 0.0f},
        // The top band.
        {flOuterLeft, flTopBandBottomY, 0.0f},
        {flBandRightX, flTopBandBottomY, 0.0f},
        {flOuterLeft, flOuterTop, 0.0f},
        {flBandRightX, flOuterTop, 0.0f},
        // The left strip, spanning between the two bands.
        {flOuterLeft, flBottomBandTopY, 0.0f},
        {flLeftStripRightX, flBottomBandTopY, 0.0f},
        {flOuterLeft, flTopBandBottomY, 0.0f},
        {flLeftStripRightX, flTopBandBottomY, 0.0f},
        // The right strip.
        {flRightStripLeftX, flBottomBandTopY, 0.0f},
        {flOuterRight, flBottomBandTopY, 0.0f},
        {flRightStripLeftX, flTopBandBottomY, 0.0f},
        {flOuterRight, flTopBandBottomY, 0.0f},
    };
    int nVertex = 0;
    for (const S_VECTOR3 &vertex : aBorderVertices) {
        m_pFrameMesh3d->SetPos(nVertex++, vertex);
    }

    // The marker ring: four corners, each an outer vertex followed by the sheet corner it pairs
    // with, walked anticlockwise from the bottom left. The outer vertices take their X from the far
    // rectangle but their Y from the sheet rectangle; the mismatch is the binary's, and at this
    // scale it makes no visible difference.
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
    // The theme selects which label and marker sprites the overlay emits. The binary reads it first,
    // inside an autorelease scope, before touching the geometry.
    const RBUserSettingDataTheme theme = [RBUserSettingData sharedInstance].thema;

    // The frame width in points, its centre, and the two inner columns a fixed span either side of
    // that centre.
    const float flWidth = GameSystem::GetGameSystem()->GetViewportWidth();
    const float flHalfWidth = flWidth * kFrameCentreFactor;
    const float flLeftInner = flHalfWidth + kFrameInnerEdgeOffset;
    const float flRightInner = flLeftInner + kFrameInnerEdgeSpan;

    // The centre tab: four columns spanning the top edge (y=0) down to the shared band bottom.
    const float aTabColumnsX[] = {
        flLeftInner,
        flLeftInner + kFrameColumnInset,
        flRightInner - kFrameColumnInset,
        flRightInner,
    };
    // The bottom strip: eight columns spanning its own top edge (y=7) down to the shared band
    // bottom, symmetric about the centre (screen edges, then a step in, then either side of the two
    // inner edges).
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

    // Each column contributes two consecutive mesh vertices: its top vertex then its bottom vertex.
    int nVertex = 0;
    for (const float flColumnX : aTabColumnsX) {
        m_pFrameMesh2d->SetPos(nVertex++, S_VECTOR2{flColumnX, kFrameTabTopY});
        m_pFrameMesh2d->SetPos(nVertex++, S_VECTOR2{flColumnX, kFrameBandBottomY});
    }
    for (const float flColumnX : aStripColumnsX) {
        m_pFrameMesh2d->SetPos(nVertex++, S_VECTOR2{flColumnX, kFrameStripTopY});
        m_pFrameMesh2d->SetPos(nVertex++, S_VECTOR2{flColumnX, kFrameBandBottomY});
    }

    // Clear both overlay instancers before re-emitting this frame's sprites into them.
    for (ne::C_SPRITE_INSTANCING_2D *pInstancer : m_apInstancers) {
        pInstancer->SetSpriteCount(0);
    }

    // The two label panels are centred within the strip's leftmost and rightmost inner spans.
    const float flLeftLabelX =
        kFrameColumnMargin +
        ((flLeftInner - kFrameColumnMargin) - kFrameColumnMargin) * kFrameCentreFactor;
    const float flRightLabelX =
        (flRightInner + kFrameColumnMargin) +
        ((flWidth - kFrameColumnMargin) - (flRightInner + kFrameColumnMargin)) * kFrameCentreFactor;

    // The two top labels, then the marker sprite base, differ by theme.
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

    // The marker label sits at the mid row on the right; the difficulty label mirrors it on the
    // left, its sprite kind the difficulty index added to this marker's difficulty-sprite base.
    EmitMainFrameSprite(
        MainFrameInstancerOverlay, nMarkerSpriteKind, flRightLabelX, kFrameLabelMidY);
    EmitMainFrameSprite(MainFrameInstancerOverlay,
                        m_nDifficulty + kFrameDifficultyMarkerBase[m_nMarker],
                        flLeftLabelX,
                        kFrameLabelMidY);

    // The centred marker sits on the frame-mesh instancer.
    EmitMainFrameSprite(
        MainFrameInstancerFrame, kFrameMeshMarkerSprite, flHalfWidth, kFrameMarkerY);
}

/** @ghidraAddress 0x17c4dc */
void MainFrameLayer::SetMarker(int nMarker, int nDifficulty) {
    if (!m_bReady) {
        BuildSprites();
    }
    // Record the new marker/difficulty; re-lay-out the overlay only when one of them changed.
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

// The marker mesh's vertex and index counts: an eight-vertex ring closed by repeating its first two
// vertices. The two textured meshes' vertex counts are kFrameMesh3dVertexCount and
// kFrameMesh2dVertexCount above; these are their index counts.
constexpr unsigned int kMarkerMesh3dVertexCount = 8;
constexpr unsigned int kMarkerMesh3dIndexCount = 10;
constexpr int kFrameMesh3dIndexCount = 22;
constexpr int kFrameMesh2dIndexCount = 28;

// The mesh factory's draw mode, its two vertex formats (the untextured marker and the textured frame
// meshes), and its buffer-ownership flags.
constexpr unsigned int kMeshDrawMode = 4;
constexpr unsigned int kMarkerVertexFormat = 5;
constexpr unsigned int kTexturedVertexFormat = 7;
constexpr bool kVertexBufferExternal = true;
constexpr bool kIndexBufferExternal = false;

// The border mesh's two texture-environment parameter slots, both set to one.
constexpr int kTexEnvParamSlotA = 1;
constexpr int kTexEnvParamSlotB = 0;
constexpr int kTexEnvParamValue = 1;

// The 3D border is four quads of four vertices; the last two walk their atlas corners in a different
// order from the first two.
constexpr int kFrameQuadCount = 4;
constexpr int kQuadVertexCount = 4;
constexpr int kBorderFlippedQuadStart = 2;

// The 2D overlay is three eight-vertex bands: the centre tab, then the two bottom-strip bands.
constexpr int kOverlayBandCount = 3;
constexpr int kOverlayBandVertexCount = 8;
constexpr int kOverlayTabBandCount = 1;

// The two instancers' capacities: six overlay sprites, and the frame mesh's single slot.
constexpr unsigned int kOverlayInstancerCapacity = 6;
constexpr unsigned int kFrameInstancerCapacity = 1;

// The sprite count each instancer is rebuilt empty at.
constexpr int kInstancerEmptyCount = 0;

// The colours freshly built vertices take: the marker's opaque black, and the frame meshes' white at
// zero alpha (the fade pass in Process supplies the real alpha).
constexpr unsigned char kVertexChannelMin = 0;
constexpr unsigned char kVertexChannelMax = 255;
constexpr unsigned char kVertexAlphaClear = 0;
constexpr unsigned char kVertexAlphaOpaque = 255;

// The marker mesh's ten strip indices: its eight ring vertices, then the first two again to close
// the ring (@ghidraAddress 0x30ce28).
constexpr int kMarkerMeshIndices[] = {0, 1, 2, 3, 4, 5, 6, 7, 0, 1};

// The 2D overlay mesh's twenty-eight strip indices: three eight-vertex bands joined by a degenerate
// index pair each (@ghidraAddress 0x30ce50).
constexpr short kFrameMesh2dIndices[] = {0,  1,  2,  3,  4,  5,  6,  7,  7,  8,  8,  9,  10, 11,
                                         12, 13, 14, 15, 15, 16, 16, 17, 18, 19, 20, 21, 22, 23};

// The 3D border's four atlas rectangles, one per quad (@ghidraAddress 0x2f1ae8).
constexpr SpriteUvEntry kFrameBorderUv[kFrameQuadCount] = {
    {0.0f, 0.0f, 0.2578125f, 0.625f},
    {0.2890625f, 0.0f, 0.2578125f, 0.625f},
    {0.5625f, 0.0009765625f, 0.1875f, 0.8183594f},
    {0.765625f, 0.0009765625f, 0.1875f, 0.8183594f},
};

// The shared-atlas rows the overlay's centre tab and bottom strip draw from. The Colette theme takes
// a different pair.
constexpr int kOverlayTabUvIndexDefault = 443;
constexpr int kOverlayStripUvIndexDefault = 444;
constexpr int kOverlayTabUvIndexColette = 451;
constexpr int kOverlayStripUvIndexColette = 452;

// Whether each corner takes the rectangle's far U and far V edge rather than its origin. The border's
// first two quads walk their corners in one order and its last two in another; every overlay band
// uses the third order.
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

// Expands one corner of an atlas rectangle into a UV pair.
inline S_VECTOR2 CornerUv(const SpriteUvEntry &rect, bool bFarU, bool bFarV) {
    return S_VECTOR2{bFarU ? rect.flOriginU + rect.flSizeU : rect.flOriginU,
                     bFarV ? rect.flOriginV + rect.flSizeV : rect.flOriginV};
}

// The 3D border mesh's sixteen UV pairs. The binary computes them once from the four atlas
// rectangles above into a one-shot-guarded function-local static (@ghidraAddress 0x3dedb8).
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
    // The default frame type is a sentinel meaning "whatever frame the player has equipped"; resolve
    // it once and keep the resolved type.
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
    // The sentinel survives only when the game system is itself unset, in which case the layer builds
    // its meshes untextured.
    if (m_nFrameType != kDefaultFrameType) {
        m_pFrameTexture = ne::C_TEXTURE::FindOrLoadCached(g_aFrameTextureNames[m_nFrameType]);
        m_pOverlayTexture = ne::C_TEXTURE::FindOrLoadCached(g_szGmParts2TextureKey);
    }

    // The marker's ring, built once. Its vertices stay at the origin until Build3dVertices lays them
    // out, and it starts hidden.
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

    // The frame border's mesh. Unlike the marker it is re-textured on every build.
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

    // Stitch the four quads into one triangle strip, repeating the vertex on each side of a quad
    // boundary so the connecting triangles collapse.
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

    // The Colette theme draws the overlay from a different pair of atlas rows.
    const RBUserSettingDataTheme theme = [RBUserSettingData sharedInstance].thema;
    const bool bColette = theme == RBUserSettingDataThemeColette;
    const SpriteUvEntry &tabRect =
        g_aSpriteUvTable[bColette ? kOverlayTabUvIndexColette : kOverlayTabUvIndexDefault];
    const SpriteUvEntry &stripRect =
        g_aSpriteUvTable[bColette ? kOverlayStripUvIndexColette : kOverlayStripUvIndexDefault];

    // The centre tab takes the first rectangle and the two bottom-strip bands the second; all three
    // walk their corners in the same order.
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

    // Both sprite instancers hang off the overlay mesh and are rebuilt empty. Only the overlay
    // instancer is textured here; the frame instancer's texture comes from SetMainFrameTexture.
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
