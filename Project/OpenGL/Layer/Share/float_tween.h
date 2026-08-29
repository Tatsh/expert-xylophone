/**
 * @file
 * The delayed linear value tween, @c FloatTween.
 */

#pragma once

/**
 * A delayed linear interpolation between two values.
 *
 * After a lead-in delay elapses, the current value ramps linearly from a start to an end value over
 * the ramp duration; @c Advance steps the ramp by one frame and caches the result.
 *
 * Reconstructed type @c FloatTween: engine tween descriptor, six floats.
 */
class FloatTween {
public:
    /**
     * Advances the tween by @p flDeltaTime and returns its current value.
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

    /**
     * The last computed value.
     * @return The last computed value.
     */
    float GetCurrent() const {
        return m_flCurrent;
    }

    /**
     * Sets the ramp's start value.
     * @param flFrom The ramp's start value.
     */
    void SetFrom(float flFrom) {
        m_flFrom = flFrom;
    }

    /**
     * Sets the ramp's end value.
     * @param flTo The ramp's end value.
     */
    void SetTo(float flTo) {
        m_flTo = flTo;
    }

    /**
     * Sets the ramp duration applied after the delay elapses.
     * @param flDuration The ramp duration.
     */
    void SetDuration(float flDuration) {
        m_flDuration = flDuration;
    }

    /**
     * Sets the lead-in delay subtracted from the accumulator.
     * @param flDelay The lead-in delay.
     */
    void SetDelay(float flDelay) {
        m_flDelay = flDelay;
    }

    /**
     * Sets the accumulated time.
     * @param flElapsed The accumulated time.
     */
    void SetElapsed(float flElapsed) {
        m_flElapsed = flElapsed;
    }

    /**
     * Sets the last computed value.
     * @param flCurrent The last computed value.
     */
    void SetCurrent(float flCurrent) {
        m_flCurrent = flCurrent;
    }

private:
    float m_flFrom = {};
    float m_flTo = {};
    float m_flDuration = {};
    float m_flDelay = {};
    float m_flElapsed = {};
    float m_flCurrent = {};
};
