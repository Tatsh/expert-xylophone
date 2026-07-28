#include "main_frame_layer.h"

#include "neSpriteInstancing.h"
#include "neTexture.h"
#include "s_vector2.h"

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
    if (m_pFrameMesh == nullptr) {
        return;
    }
    m_pFrameMesh->SetRefCountedMember(pTexture);
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
    m_pFrameMesh->SetSpriteAnchor(
        kFrameMeshSlot,
        S_VECTOR2{static_cast<float>(static_cast<int>(flPointWidth * kUvHalf)),
                  static_cast<float>(static_cast<int>(flPointHeight * kUvHalf))});
    m_pFrameMesh->SetSpriteSize(kFrameMeshSlot, S_VECTOR2{flPointWidth, flPointHeight});
    m_pFrameMesh->SetSpriteUvOrigin(kFrameMeshSlot, S_VECTOR2{0.0f, 0.0f});
    m_pFrameMesh->SetSpriteUvSize(
        kFrameMeshSlot,
        S_VECTOR2{static_cast<float>(pTexture->GetImageWidth()) / pTexture->GetAllocWidth(),
                  static_cast<float>(pTexture->GetImageHeight()) / pTexture->GetAllocHeight()});
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
