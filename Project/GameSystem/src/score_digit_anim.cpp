//
//  score_digit_anim.cpp
//  REFLEC BEAT plus
//
//  Reconstructed from Ghidra project rb458, program rb458. Pure C++.
//

#include "score_digit_anim.h"

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
