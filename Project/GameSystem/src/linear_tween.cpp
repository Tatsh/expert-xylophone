//
//  linear_tween.cpp
//  REFLEC BEAT plus
//
//  Reconstructed from Ghidra project rb458, program rb458. The shared five-float linear tween and
//  the per-layer functions that advance the channel embedded at each layer's own offset. Pure C++.
//

#include "linear_tween.h"

// Each layer embeds its tween channel at a fixed byte offset; the binary advances it in place.
namespace {

// The byte offset of the tween channel within each owning layer, keyed by the advancing function.
constexpr int kTitleFadeChannelOffset = 0xc4;       // CalculateTitleFade
constexpr int kTitleFadeValueChannelOffset = 0x110; // AdvanceTitleFadeValue
constexpr int kEasedProgressChannelOffset = 0x44;   // AdvanceEasedProgress
constexpr int kFcFadeChannelOffset = 0x6c;          // AdvanceFcFadeInterp
constexpr int kGradeGaugeChannelOffset = 0x6c;      // AdvanceGradeGaugeChannel
constexpr int kNumberFadeChannelOffset = 0x30;      // AdvanceNumberFadeInterp

// The byte offset, within the number-effect layer, of the flag AdvanceNumberFadeInterp raises once
// it has advanced its channel.
constexpr int kNumberFadeActiveFlagOffset = 0x44;

LinearTween *ChannelAt(void *pOwner, int nOffset) {
    return reinterpret_cast<LinearTween *>(static_cast<unsigned char *>(pOwner) + nOffset);
}

} // namespace

void LinearTween::Advance(float flDelta) {
    if (m_flElapsed >= m_flDuration) {
        return;
    }
    float elapsed = m_flElapsed + flDelta;
    if (elapsed > m_flDuration) {
        elapsed = m_flDuration;
    }
    m_flElapsed = elapsed;
    const float progress = m_flDuration == 0.0f ? 1.0f : elapsed / m_flDuration;
    m_flCurrent = m_flStart + progress * (m_flEnd - m_flStart);
}

/** @ghidraAddress 0x149ff4 */
void CalculateTitleFade(void *pLayer, int nDeltaFrames) {
    ChannelAt(pLayer, kTitleFadeChannelOffset)->Advance(static_cast<float>(nDeltaFrames));
}

/** @ghidraAddress 0x152548 */
void AdvanceTitleFadeValue(void *pLayer, int nDeltaFrames) {
    ChannelAt(pLayer, kTitleFadeValueChannelOffset)->Advance(static_cast<float>(nDeltaFrames));
}

/** @ghidraAddress 0x10a5fc */
void AdvanceEasedProgress(void *pState, float flDelta) {
    ChannelAt(pState, kEasedProgressChannelOffset)->Advance(flDelta);
}

/** @ghidraAddress 0x18795c */
void AdvanceFcFadeInterp(float flDeltaTime, void *pLayer) {
    ChannelAt(pLayer, kFcFadeChannelOffset)->Advance(flDeltaTime);
}

/** @ghidraAddress 0x120a74 */
void AdvanceGradeGaugeChannel(float flDeltaTime, void *pThis) {
    ChannelAt(pThis, kGradeGaugeChannelOffset)->Advance(flDeltaTime);
}

/** @ghidraAddress 0x189ef0 */
void AdvanceNumberFadeInterp(float flDeltaTime, void *pLayer) {
    LinearTween *pChannel = ChannelAt(pLayer, kNumberFadeChannelOffset);
    if (pChannel->m_flElapsed >= pChannel->m_flDuration) {
        return;
    }
    pChannel->Advance(flDeltaTime);
    // Mark the tween as having produced a value this frame.
    *(static_cast<unsigned char *>(pLayer) + kNumberFadeActiveFlagOffset) = 1;
}

/** @ghidraAddress 0x18bd58 */
void AdvanceScoreDigitInterp(float flDeltaTime, void *pAnim) {
    // A 0x18-byte counter record: value +0xc, start +0x4, end +0x8, elapsed +0x10, duration +0x14.
    // Unlike the shared tween it snaps the value to the end once complete.
    auto *pBytes = static_cast<unsigned char *>(pAnim);
    float &value = *reinterpret_cast<float *>(pBytes + 0xc);
    const float start = *reinterpret_cast<float *>(pBytes + 0x4);
    const float end = *reinterpret_cast<float *>(pBytes + 0x8);
    float &elapsed = *reinterpret_cast<float *>(pBytes + 0x10);
    const float duration = *reinterpret_cast<float *>(pBytes + 0x14);
    if (elapsed < duration) {
        float advanced = elapsed + flDeltaTime;
        if (advanced >= duration) {
            advanced = duration;
        }
        elapsed = advanced;
        value = start + (end - start) * advanced / duration;
    } else {
        value = end;
    }
}
