#include "main_frame_layer.h"

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
    if (m_pMainSprite != nullptr) {
        m_pMainSprite->SetVisible(bEnabled);
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
