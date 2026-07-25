#include "playerfieldlayer.h"

#include "Share/bg_layer.h"
#include "neRender.h"
#include "neSpriteInstancing.h"
#include "neTexture.h"

// The process-wide player-field layer, created lazily by shared().
static PlayerFieldLayer *g_pPlayerFieldLayer = nullptr; // @ghidraAddress 0x3df2f0

namespace {

// The atlas the score number draws from (@ghidraAddress 0x3ceaa8).
constexpr const char *kTextureName = "00_texture/gm_parts2";

} // namespace

/** @ghidraAddress 0x18b668 */
PlayerFieldLayer *PlayerFieldLayer::shared() {
    if (g_pPlayerFieldLayer == nullptr) {
        // The binary allocates the raw object, runs the play-field base initialiser, then seeds the
        // presentation transform (identity scale) and zeroes the score-digit records;
        // value-initialisation covers the zeroing here.
        g_pPlayerFieldLayer = new PlayerFieldLayer();
    }
    return g_pPlayerFieldLayer;
}

/** @ghidraAddress 0x18b6fc */
void PlayerFieldLayer::CreateScoreNumberSpriteBatch() {
    if (m_bBuilt) {
        return;
    }

    // The sprite hangs beneath the shared background layer's render object rather than the global
    // scene root.
    BgLayer *pBackgroundLayer = BgLayer::GetBackgroundLayer();
    ne::C_RENDER *pParent = pBackgroundLayer->GetBackgroundRenderObject();

    m_pTexture = ne::C_TEXTURE::FindOrLoadCached(kTextureName);

    m_pSprite = ne::CreateWorldSpriteBatch(kSpriteCapacity);
    pParent->AttachChild(m_pSprite);
    m_pSprite->SetVisible(true);
    m_pSprite->SetRefCountedMember(m_pTexture);
    m_pSprite->SetSpriteCount(m_nSpriteCount);

    m_bBuilt = true;
}

/** @ghidraAddress 0x18b784 */
void PlayerFieldLayer::StartScoreFadeIn(float flDuration) {
    m_fadeChannel.SetStart(m_fadeChannel.GetCurrent());
    m_fadeChannel.SetEnd(1.0f);
    m_fadeChannel.SetDuration(flDuration);
    m_fadeChannel.SetElapsed(0.0f);
    if (flDuration <= 0.0f) {
        m_fadeChannel.SetCurrent(1.0f);
    }
}

/** @ghidraAddress 0x18b7ac */
void PlayerFieldLayer::StartScoreFadeOut(float flDuration) {
    m_fadeChannel.SetStart(m_fadeChannel.GetCurrent());
    m_fadeChannel.SetEnd(0.0f);
    m_fadeChannel.SetDuration(flDuration);
    m_fadeChannel.SetElapsed(0.0f);
    if (flDuration <= 0.0f) {
        m_fadeChannel.SetCurrent(0.0f);
    }
}

/** @ghidraAddress 0x18b7f4 */
void PlayerFieldLayer::SetScoreSideFlag(int nSide) {
    m_nScoreSideFlag = nSide;
}
