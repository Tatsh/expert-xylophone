/**
 * @file
 * The player-field score layer, @c PlayerFieldLayer.
 */

#pragma once

#include "playfieldlayerbase.h"

/**
 * @brief One player side's score-digit roll-up tween: the target value and the animation it plays
 * to reach it.
 *
 * The trailing @c // +0xNN comments document the original 32-bit member offsets for reference only.
 */
struct ScoreDigitField {
    int nTarget = {};      // +0x00: the target score value.
    float flFrom = {};     // +0x04: the animation's start value (the current value when armed).
    float flTo = {};       // +0x08: the animation's end value (the target as a float).
    float flCurrent = {};  // +0x0c: the current animated value.
    float flElapsed = {};  // +0x10: the elapsed animation time.
    float flDuration = {}; // +0x14: the animation duration, in seconds.
};

/**
 * @brief The play-field layer that draws each side's rolling score digits and lane gauges.
 *
 * A process-wide singleton built on first access. The trailing @c // +0xNN comments document the
 * original 32-bit member offsets for reference only; the presentation-transform fields between the
 * base and the score records are still being worked out.
 */
class PlayerFieldLayer : public PlayFieldLayerBase {
public:
    // The number of player sides.
    static constexpr int kSideCount = 2;

    /**
     * @brief A player side's score-digit roll-up record.
     * @param uSide The player side.
     * @return The side's score-digit field.
     */
    ScoreDigitField &GetScoreDigitField(unsigned int uSide) {
        return m_aScoreFields[uSide];
    }

    /**
     * @brief The shared player-field layer, created on first use.
     * @return The shared player-field layer.
     * @ghidraAddress 0x18b668
     */
    static PlayerFieldLayer *shared();

private:
    // +0x08..+0x3f: the layer's presentation transform and flags (seeded by shared()), whose
    // individual fields are still being worked out.
    unsigned char m_aLayerState08[0x38] = {};        // +0x08
    ScoreDigitField m_aScoreFields[kSideCount] = {}; // +0x40: the per-side score-digit records.
};

// code: language=C++
// kate: hl C++;
// vim: set ft=cpp :
