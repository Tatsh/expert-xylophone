/**
 * @file
 * The three-component float vector value type, @c S_VECTOR3.
 */

#pragma once

/**
 * A three-component float vector used by the engine's matrix and camera maths. Modelled on
 * @c S_VECTOR2: the binary passes these helpers a raw @c float[3], and this POD layout of three
 * consecutive floats matches it exactly, so a pointer to one is interchangeable with that pointer.
 * The components are public so the maths reads as @c v->x rather than an indexed access.
 *
 * As with @c S_VECTOR2, the three components carry two interchangeable name pairs that overlay the
 * same storage: @c x / @c y / @c z for a position or direction, and @c r / @c g / @c b for a colour.
 * Both name the same three floats; the layout is unchanged.
 * @ghidraAddress S_VECTOR3 (engine struct type)
 */
struct S_VECTOR3 {
    /** @brief Constructs a zero vector. */
    constexpr S_VECTOR3() : x(0.0f), y(0.0f), z(0.0f) {
    }
    /** @brief Constructs a vector from its three components. */
    constexpr S_VECTOR3(float x, float y, float z) : x(x), y(y), z(z) {
    }

    union {
        struct {
            float x; // +0x0
            float y; // +0x4
            float z; // +0x8
        };
        struct {
            float r;
            float g;
            float b;
        };
    };
};

// code: language=C++
// kate: hl C++;
// vim: set ft=cpp :
