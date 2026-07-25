//
//  alt_frame_layer.mm
//  REFLEC BEAT plus
//
//  The alternate play-field frame layer (AltFrameLayer). Reconstructed from Ghidra project rb458,
//  program rb458. @ghidraAddress values are relative to the program image base.
//

#include "alt_frame_layer.h"

// The process-wide alternate-frame layer, created lazily by shared().
static AltFrameLayer *g_pAltFrameLayer = nullptr; // @ghidraAddress 0x3deda8

namespace {
// The frame type and mode the constructor seeds.
constexpr int kDefaultFrameType = 0x20;
constexpr int kDefaultFrameMode = 5;
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
