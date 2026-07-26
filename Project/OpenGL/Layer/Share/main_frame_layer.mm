#include "main_frame_layer.h"

#include "neSpriteInstancing.h"

// The process-wide main-frame layer, created lazily by shared().
static MainFrameLayer *g_pMainFrameLayer = nullptr; // @ghidraAddress 0x3dedb0

namespace {

// The fields the constructor seeds: the default frame type and the sprite capacity.
constexpr int kDefaultFrameType = 0x20;
constexpr int kDefaultSpriteCapacity = 5;

// The frame's fully-opaque alpha endpoint (255).
constexpr float kFrameAlphaOpaque = 255.0f;
constexpr float kFrameAlphaTransparent = 0.0f;

} // namespace

// The binary inlines this constructor into shared (0x17b5d4).
MainFrameLayer::MainFrameLayer() {
    // The base constructor and the zero-initialised members clear the layer; the constructor then
    // seeds the two non-zero defaults.
    m_nFrameType = kDefaultFrameType;
    m_nSpriteCapacity = kDefaultSpriteCapacity;
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
