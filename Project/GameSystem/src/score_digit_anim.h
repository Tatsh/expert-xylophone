#pragma once

//
//  score_digit_anim.h
//  REFLEC BEAT plus
//
//  Reconstructed from Ghidra project rb458, program rb458. @ghidraAddress values are relative to
//  the program image base.
//

/**
 * @brief A score-counter roll-up record: a compact value/start/end/elapsed/duration tuple that
 * snaps to the end value once complete.
 * @ghidraAddress ScoreDigitAnim (engine 0x18-byte record)
 */
class ScoreDigitAnim {
public:
    /**
     * @brief Advances the roll-up by @p flDeltaTime, snapping the value to the end once complete.
     * @ghidraAddress 0x18bd58
     */
    void Advance(float flDeltaTime);

private:
    unsigned char m_aReserved00[0x04] = {}; // +0x00
    float m_flStart = {};                   // +0x04 start value
    float m_flEnd = {};                     // +0x08 end value
    float m_flValue = {};                   // +0x0c current displayed value
    float m_flElapsed = {};                 // +0x10 elapsed time so far
    float m_flDuration = {};                // +0x14 total duration
};

// code: language=C++
// kate: hl C++;
// vim: set ft=cpp :
