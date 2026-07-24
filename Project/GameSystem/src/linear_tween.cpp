//
//  linear_tween.cpp
//  REFLEC BEAT plus
//
//  Reconstructed from Ghidra project rb458, program rb458. The shared five-float linear tween and
//  the per-layer methods that advance the channel embedded in each layer. Pure C++.
//

#include "linear_tween.h"

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

/** @ghidraAddress 0x10a5fc */
void ClassicThemeAnimation::AdvanceEasedProgress(float flDelta) {
    m_easeChannel.Advance(flDelta);
}

/** @ghidraAddress 0x18795c */
void FullComboEffectLayer::AdvanceFadeInterp(float flDeltaTime) {
    m_fadeChannel.Advance(flDeltaTime);
}

/** @ghidraAddress 0x120a74 */
void GradeGaugeLayer::AdvanceChannel(float flDeltaTime) {
    m_gaugeChannel.Advance(flDeltaTime);
}

/** @ghidraAddress 0x189ef0 */
void NumberEffectLayer::AdvanceFadeInterp(float flDeltaTime) {
    if (m_fadeChannel.m_flElapsed >= m_fadeChannel.m_flDuration) {
        return;
    }
    m_fadeChannel.Advance(flDeltaTime);
    m_bFadeActive = true;
}

/** @ghidraAddress 0x18bd58 */
void ScoreDigitAnim::Advance(float flDeltaTime) {
    // Unlike the shared tween this snaps the displayed value to the end once complete.
    if (m_flElapsed < m_flDuration) {
        float elapsed = m_flElapsed + flDeltaTime;
        if (elapsed >= m_flDuration) {
            elapsed = m_flDuration;
        }
        m_flElapsed = elapsed;
        m_flValue = m_flStart + (m_flEnd - m_flStart) * elapsed / m_flDuration;
    } else {
        m_flValue = m_flEnd;
    }
}
