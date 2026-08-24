/**
 * @file
 * The delayed linear value tween, @c FloatTween.
 */

#pragma once

/**
 * @brief A delayed linear interpolation between two values.
 *
 * After a lead-in delay elapses, the current value ramps linearly from a start to an end value over
 * the ramp duration; @c Advance steps the ramp by one frame and caches the result. The trailing
 * @c // +0xNN comments document the original member offsets for reference only.
 *
 * Reconstructed type @c FloatTween: engine tween descriptor, six floats.
 */
class FloatTween {
public:
    /**
     * @brief Advances the tween by @p flDeltaTime and returns its current value.
     *
     * Before the delay elapses the cached value is returned unchanged; afterwards the accumulator
     * is advanced (clamped not to overshoot), the normalised ramp position is computed, and the
     * interpolated value is cached and returned.
     * @param flDeltaTime The elapsed frame time.
     * @return The updated current value.
     *
     * The compiler emits this tween utility at three addresses (the play, result, and a further
     * animation-channel screen each get a copy); all are byte-identical and collapse to this one
     * method.
     * @ghidraAddress 0x12af38
     * @ghidraAddress 0x7b350
     * @ghidraAddress 0x11c954
     */
    float Advance(float flDeltaTime);

    /** @brief The last computed value. */
    float GetCurrent() const {
        return m_flCurrent;
    }

    /** @brief Sets the ramp's start value. */
    void SetFrom(float flFrom) {
        m_flFrom = flFrom;
    }

    /** @brief Sets the ramp's end value. */
    void SetTo(float flTo) {
        m_flTo = flTo;
    }

    /** @brief Sets the ramp duration applied after the delay elapses. */
    void SetDuration(float flDuration) {
        m_flDuration = flDuration;
    }

    /** @brief Sets the lead-in delay subtracted from the accumulator. */
    void SetDelay(float flDelay) {
        m_flDelay = flDelay;
    }

    /** @brief Sets the accumulated time. */
    void SetElapsed(float flElapsed) {
        m_flElapsed = flElapsed;
    }

    /** @brief Sets the last computed value. */
    void SetCurrent(float flCurrent) {
        m_flCurrent = flCurrent;
    }

private:
    float m_flFrom = {};     // +0x00: the start value.
    float m_flTo = {};       // +0x04: the end value.
    float m_flDuration = {}; // +0x08: the ramp duration after the delay elapses.
    float m_flDelay = {};    // +0x0c: the lead-in delay subtracted from the accumulator.
    float m_flElapsed = {};  // +0x10: the accumulated time, advanced by the frame delta.
    float m_flCurrent = {};  // +0x14: the last computed value, returned while idle.
};

// code: language=C++
// kate: hl C++;
// vim: set ft=cpp :
