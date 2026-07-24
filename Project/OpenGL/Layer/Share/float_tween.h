/**
 * @file
 * The delayed linear value tween, @c FloatTween.
 */

#pragma once

/**
 * @brief A delayed linear interpolation between two values.
 *
 * After a lead-in delay elapses, the current value ramps linearly from @c flFrom to @c flTo over
 * @c flDuration; @c Advance steps the ramp by one frame and caches the result. The trailing
 * @c // +0xNN comments document the original member offsets for reference only.
 * @ghidraAddress FloatTween (engine tween descriptor, six floats)
 */
struct FloatTween {
    /**
     * @brief Advances the tween by @p flDeltaTime and returns its current value.
     *
     * Before the delay elapses the cached value is returned unchanged; afterwards the accumulator is
     * advanced (clamped not to overshoot), the normalised ramp position is computed, and the
     * interpolated value is cached and returned.
     * @param flDeltaTime The elapsed frame time.
     * @return The updated current value.
     * @ghidraAddress 0x12af38
     */
    float Advance(float flDeltaTime);

    float flFrom = {};     // +0x00: the start value.
    float flTo = {};       // +0x04: the end value.
    float flDuration = {}; // +0x08: the ramp duration after the delay elapses.
    float flDelay = {};    // +0x0c: the lead-in delay subtracted from the accumulator.
    float flElapsed = {};  // +0x10: the accumulated time, advanced by the frame delta.
    float flCurrent = {};  // +0x14: the last computed value, returned while idle.
};

// code: language=C++
// kate: hl C++;
// vim: set ft=cpp :
