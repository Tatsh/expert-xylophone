//
//  linear_tween.cpp
//  REFLEC BEAT plus
//
//  Reconstructed from Ghidra project rb458, program rb458. The shared five-float linear tween.
//  Pure C++.
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
