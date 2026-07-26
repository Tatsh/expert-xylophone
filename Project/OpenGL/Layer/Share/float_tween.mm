//
//  float_tween.mm
//  REFLEC BEAT plus
//
//  The delayed linear value tween (FloatTween). Reconstructed from Ghidra project rb458, program
//  rb458. @ghidraAddress values are relative to the program image base.
//

#include "float_tween.h"

/** @ghidraAddress 0x12af38 */
float FloatTween::Advance(float flDeltaTime) {
    const float flReachEnd = m_flDuration + m_flDelay;
    // Once the accumulator has reached the ramp's end the tween holds its last value.
    if (m_flElapsed >= flReachEnd) {
        return m_flCurrent;
    }
    // Advance the accumulator, clamped so it does not overshoot the ramp's end.
    float flAdvanced = m_flElapsed + flDeltaTime;
    if (flAdvanced > flReachEnd) {
        flAdvanced = flReachEnd;
    }
    m_flElapsed = flAdvanced;
    // The normalised ramp position; a zero-duration ramp jumps straight to the end.
    float flT = m_flDuration == 0.0f ? 1.0f : (flAdvanced - m_flDelay) / m_flDuration;
    if (flT < 0.0f) {
        flT = 0.0f;
    }
    m_flCurrent = m_flFrom + flT * (m_flTo - m_flFrom);
    return m_flCurrent;
}
