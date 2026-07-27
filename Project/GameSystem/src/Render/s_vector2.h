/**
 * @file
 * The two-component float vector value type, @c S_VECTOR2.
 */

#pragma once

/**
 * A two-component float vector shared with the engine's sheet-layout helpers. Its components are
 * public (a deliberate exception to the usual encapsulation, shared with @c S_VECTOR3) so the maths
 * reads as @c v.x rather than through accessors.
 *
 * The two components carry three interchangeable name pairs that overlay the same storage, so a
 * value reads naturally in whatever role it is playing: @c x / @c y for a position or offset,
 * @c width / @c height for a size, and @c u / @c v for a texture coordinate. All three name the same
 * two floats; the layout is unchanged.
 * @ghidraAddress S_VECTOR2 (engine struct type)
 */
struct S_VECTOR2 {
    /** @brief Constructs a zero vector. */
    constexpr S_VECTOR2() : x(0.0f), y(0.0f) {
    }
    /** @brief Constructs a vector from its two components. */
    constexpr S_VECTOR2(float x, float y) : x(x), y(y) {
    }

    union {
        struct {
            float x; // +0x0
            float y; // +0x4
        };
        struct {
            float width;
            float height;
        };
        struct {
            float u;
            float v;
        };
    };
};

// code: language=C++
// kate: hl C++;
// vim: set ft=cpp :
