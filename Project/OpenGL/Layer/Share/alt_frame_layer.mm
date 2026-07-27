//
//  alt_frame_layer.mm
//  REFLEC BEAT plus
//
//  The alternate play-field frame layer (AltFrameLayer). Reconstructed from Ghidra project rb458,
//  program rb458. @ghidraAddress values are relative to the program image base.
//

#include "alt_frame_layer.h"

#include "neRender.h"
#include "neSpriteInstancing.h"

// The process-wide alternate-frame layer, created lazily by shared().
static AltFrameLayer *g_pAltFrameLayer = nullptr; // @ghidraAddress 0x3deda8

namespace {
// The frame type and mode the constructor seeds.
constexpr int kDefaultFrameType = 0x20;
constexpr int kDefaultFrameMode = 5;
// The fully-opaque alpha endpoint the fade-in eases toward (a 0-to-255 alpha channel).
constexpr float kFrameAlphaOpaque = 255.0f;
} // namespace

/** @ghidraAddress 0x17a4a4 */
AltFrameLayer::AltFrameLayer() {
    m_nFrameType = kDefaultFrameType;
    m_nFrameMode = kDefaultFrameMode;
    // The sprite batches, counts, ready flag, and fade channel are zeroed by the member initialisers.
}

/** @ghidraAddress 0x17a4f8 */
AltFrameLayer *AltFrameLayer::shared() {
    if (g_pAltFrameLayer == nullptr) {
        // The binary allocates the raw 0x80-byte object and runs the constructor.
        g_pAltFrameLayer = new AltFrameLayer();
    }
    return g_pAltFrameLayer;
}

/** @ghidraAddress 0x17b054 */
void AltFrameLayer::StartFadeIn(float flDuration) {
    RenderMarkers();
    m_fadeChannel.SetStart(m_fadeChannel.GetCurrent());
    m_fadeChannel.SetEnd(kFrameAlphaOpaque);
    m_fadeChannel.SetDuration(flDuration);
    m_fadeChannel.SetElapsed(0.0f);
    if (flDuration <= 0.0f) {
        m_fadeChannel.SetCurrent(kFrameAlphaOpaque);
        m_bFadeDone = true;
    }
}

/** @ghidraAddress 0x17b0ac */
void AltFrameLayer::StartFadeOut(float flDuration) {
    m_fadeChannel.SetStart(m_fadeChannel.GetCurrent());
    m_fadeChannel.SetEnd(0.0f);
    m_fadeChannel.SetDuration(flDuration);
    m_fadeChannel.SetElapsed(0.0f);
    if (flDuration <= 0.0f) {
        m_fadeChannel.SetCurrent(0.0f);
        m_bFadeDone = true;
    }
}

/** @ghidraAddress 0x17aba8 */
void AltFrameLayer::SetFrameType(int nType) {
    if (m_nFrameType == nType) {
        return;
    }
    m_nFrameType = nType;
    m_bReady = false;
    BuildSprites();
}

/** @ghidraAddress 0x17b0d4 */
void AltFrameLayer::Process(float flDelta) {
    if (!m_bReady) {
        return;
    }

    const float flDuration = m_fadeChannel.GetDuration();
    bool bApply;
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
        bApply = true;
    } else {
        // The fade is complete; only apply the final alpha once (on the frame the flag latches).
        bApply = m_bFadeDone;
    }

    if (bApply) {
        m_bFadeDone = false;
        const auto nAlpha =
            static_cast<unsigned char>(static_cast<int>(m_fadeChannel.GetCurrent()));
        for (int nBatch = 0; nBatch < kSpriteSlotCount; ++nBatch) {
            for (int nSlot = 0; nSlot < m_aSpriteCounts[nBatch]; ++nSlot) {
                m_apSprites[nBatch]->SetColorAlpha(nSlot, nAlpha);
            }
        }
    }

    // Keep the two overlay batches visible.
    m_apSprites[1]->SetVisible(true);
    m_apSprites[2]->SetVisible(true);
}
