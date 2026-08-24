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
 * same storage: @c x / @c y / @c z for a position or direction, and @c r / @c g / @c b for a
 * colour. Both name the same three floats; the layout is unchanged.
 *
 * Reconstructed type @c S_VECTOR3: engine struct type.
 */
struct S_VECTOR3 {
    /** @brief Constructs a zero vector. */
    constexpr S_VECTOR3() : x(0.0f), y(0.0f), z(0.0f) {
    }
    /** @brief Constructs a vector from its three components. */
    constexpr S_VECTOR3(float x, float y, float z) : x(x), y(y), z(z) {
    }

    union {
        /** @brief The position or direction reading of the three components. */
        struct {
            float x; /*!< The first component as a horizontal position or direction. +0x0 */
            float y; /*!< The second component as a vertical position or direction. +0x4 */
            float z; /*!< The third component as a depth position or direction. +0x8 */
        };
        /** @brief The colour reading of the same three components. */
        struct {
            float r; /*!< The first component as a red channel. Aliases @c x. */
            float g; /*!< The second component as a green channel. Aliases @c y. */
            float b; /*!< The third component as a blue channel. Aliases @c z. */
        };
    };
};

// code: language=C++
// kate: hl C++;
// vim: set ft=cpp :
