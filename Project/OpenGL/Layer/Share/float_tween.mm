#include "float_tween.h"

/** @ghidraAddress 0x12af38 */
float FloatTween::Advance(float flDeltaTime) {
    const float flReachEnd = m_flDuration + m_flDelay;
    if (m_flElapsed >= flReachEnd) {
        return m_flCurrent;
    }
    float flAdvanced = m_flElapsed + flDeltaTime;
    if (flAdvanced > flReachEnd) {
        flAdvanced = flReachEnd;
    }
    m_flElapsed = flAdvanced;
    float flT = m_flDuration == 0.0f ? 1.0f : (flAdvanced - m_flDelay) / m_flDuration;
    if (flT < 0.0f) {
        flT = 0.0f;
    }
    m_flCurrent = m_flFrom + flT * (m_flTo - m_flFrom);
    return m_flCurrent;
}
