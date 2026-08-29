/**
 * @file
 * The engine's five-float linear-interpolation channel, @c LinearTween.
 *
 * A recurring engine idiom: a start value, an end value, a duration, the elapsed time, and the
 * current interpolated value, embedded directly in a UI layer as a value type. Many layers advance
 * one such channel per frame; each owning layer has its own header.
 */

#pragma once

/**
 * A five-float linear-interpolation channel: current = start + t*(end - start), where
 * t = elapsed / duration clamped to 1.
 *
 * A value type embedded directly in the UI layers that animate one channel per frame.
 *
 * Reconstructed type @c LinearTween: engine tween sub-object.
 */
class LinearTween {
public:
    /**
     * Advances the channel by @p flDelta and recomputes the current value, unless it has
     * already reached its duration. The elapsed time is clamped to the duration; a zero duration
     * forces the progress to 1.
     * @param flDelta The time (or frame count) to advance by.
     */
    void Advance(float flDelta);

    /**
     * The elapsed time so far.
     * @return The elapsed time, never above the duration.
     */
    float GetElapsed() const {
        return m_flElapsed;
    }

    /**
     * The channel's total duration.
     * @return The total duration.
     */
    float GetDuration() const {
        return m_flDuration;
    }

    /**
     * The last computed interpolated value.
     * @return The last computed interpolated value.
     */
    float GetCurrent() const {
        return m_flCurrent;
    }

    /**
     * The interpolation start value.
     * @return The interpolation start value.
     */
    float GetStart() const {
        return m_flStart;
    }

    /**
     * The interpolation end value.
     * @return The interpolation end value.
     */
    float GetEnd() const {
        return m_flEnd;
    }

    /**
     * Sets the interpolation start value.
     * @param flStart The interpolation start value.
     */
    void SetStart(float flStart) {
        m_flStart = flStart;
    }

    /**
     * Sets the interpolation end value.
     * @param flEnd The interpolation end value.
     */
    void SetEnd(float flEnd) {
        m_flEnd = flEnd;
    }

    /**
     * Sets the total duration.
     * @param flDuration The total duration.
     */
    void SetDuration(float flDuration) {
        m_flDuration = flDuration;
    }

    /**
     * Sets the elapsed time so far.
     * @param flElapsed The elapsed time.
     */
    void SetElapsed(float flElapsed) {
        m_flElapsed = flElapsed;
    }

    /**
     * Sets the last computed interpolated value.
     * @param flCurrent The interpolated value.
     */
    void SetCurrent(float flCurrent) {
        m_flCurrent = flCurrent;
    }

private:
    float m_flStart = {};
    float m_flEnd = {};
    float m_flDuration = {};
    float m_flElapsed = {};
    float m_flCurrent = {};
};
