//
//  number_effect_layer.cpp
//  REFLEC BEAT plus
//
//  Reconstructed from Ghidra project rb458, program rb458. Pure C++.
//

#include "number_effect_layer.h"

#include "gamesystem.h"

namespace {
// The scroll-offset value the full-just-reflec challenge mode uses instead of zero.
constexpr float kChallengeScrollOffset = 5.0f;
} // namespace

/** @ghidraAddress 0x189ef0 */
void NumberEffectLayer::AdvanceFadeInterp(float flDeltaTime) {
    if (m_fadeChannel.GetElapsed() >= m_fadeChannel.GetDuration()) {
        return;
    }
    m_fadeChannel.Advance(flDeltaTime);
    m_bFadeActive = true;
}

/** @ghidraAddress 0x18a7a8 */
void NumberEffectLayer::SetBrightness(float flValue) {
    if (flValue < 0.0f) {
        flValue = 0.0f;
    } else if (flValue > 1.0f) {
        flValue = 1.0f;
    }
    m_flBrightness = flValue;
}

/** @ghidraAddress 0x18a988 */
void NumberEffectLayer::ResetOffsets() {
    // Each offset clears to zero, except in the full-just-reflec challenge mode which seeds five.
    const float flReset =
        GameSystem::GetGameSystem()->GetFullJustReflec() ? kChallengeScrollOffset : 0.0f;
    for (ScrollOffset &offset : m_aScrollOffset) {
        offset = ScrollOffset{};
        offset.flOffset = flReset;
    }
}
