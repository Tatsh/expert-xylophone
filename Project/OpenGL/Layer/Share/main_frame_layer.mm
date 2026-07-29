#include "main_frame_layer.h"

#include "RBMacros.h"
#include "RBUserSettingData.h"
#include "gamesystem.h"
#include "neDrawPolygon2D.h"
#include "neDrawPolygon3D.h"
#include "neSpriteInstancing.h"
#include "neTexture.h"
#include "s_vector2.h"
#include "sprite_uv_table.h"

// The process-wide main-frame layer, created lazily by shared().
static MainFrameLayer *g_pMainFrameLayer = nullptr; // @ghidraAddress 0x3dedb0

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
