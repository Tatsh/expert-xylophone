#pragma once

//
//  linear_tween.h
//  REFLEC BEAT plus
//
//  A recurring engine idiom: a five-float linear-interpolation channel embedded in a UI layer
//  (a start value, an end value, a duration, the elapsed time, and the current interpolated value).
//  Many layers advance one such channel per frame; each owning layer has its own header.
//
//  Reconstructed from Ghidra project rb458, program rb458. @ghidraAddress values are relative to
//  the program image base.
//

/**
 * @brief A five-float linear-interpolation channel: current = start + t*(end - start), where
 * t = elapsed / duration clamped to 1.
 *
 * A value type embedded directly in the UI layers that animate one channel per frame.
 * @ghidraAddress LinearTween (engine tween sub-object)
 */
class LinearTween {
public:
    /**
     * @brief Advances the channel by @p flDelta and recomputes the current value, unless it has
     * already reached its duration. The elapsed time is clamped to the duration; a zero duration
     * forces the progress to 1.
     * @param flDelta The time (or frame count) to advance by.
     */
    void Advance(float flDelta);

    /** @brief The elapsed time so far. */
    float GetElapsed() const {
        return m_flElapsed;
    }

    /** @brief The channel's total duration. */
    float GetDuration() const {
        return m_flDuration;
    }

private:
    float m_flStart = {};    // +0x00 interpolation start value
    float m_flEnd = {};      // +0x04 interpolation end value
    float m_flDuration = {}; // +0x08 total duration
    float m_flElapsed = {};  // +0x0c elapsed time so far
    float m_flCurrent = {};  // +0x10 last computed interpolated value
};

// code: language=C++
// kate: hl C++;
// vim: set ft=cpp :
