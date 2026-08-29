/**
 * @file
 * @brief The two-component float vector value type, @c S_VECTOR2.
 */

#pragma once

/**
 * @brief A two-component float vector shared with the engine's sheet-layout helpers.
 *
 * Its components are public (a deliberate exception to the usual encapsulation, shared with
 * @c S_VECTOR3) so the maths reads as @c v.x rather than through accessors.
 *
 * The two components carry three interchangeable name pairs that overlay the same storage, so a
 * value reads naturally in whatever role it is playing: @c x / @c y for a position or offset,
 * @c width / @c height for a size, and @c u / @c v for a texture coordinate. All three name the
 * same two floats; the layout is unchanged.
 *
 * Reconstructed type @c S_VECTOR2: engine struct type.
 */
struct S_VECTOR2 {
    /** @brief Constructs a zero vector. */
    constexpr S_VECTOR2() : x(0.0f), y(0.0f) {
    }
    /**
     * @brief Constructs a vector from its two components.
     * @param x The x component.
     * @param y The y component.
     */
    constexpr S_VECTOR2(float x, float y) : x(x), y(y) {
    }

    union {
        /** @brief The position or offset reading of the two components. */
        struct {
            float x; /*!< The first component as a horizontal position or offset. +0x0 */
            float y; /*!< The second component as a vertical position or offset. +0x4 */
        };
        /** @brief The size reading of the same two components. */
        struct {
            float width;  /*!< The first component as a horizontal extent. Aliases @c x. */
            float height; /*!< The second component as a vertical extent. Aliases @c y. */
        };
        /** @brief The texture-coordinate reading of the same two components. */
        struct {
            float u; /*!< The first component as a horizontal texture coordinate. Aliases @c x. */
            float v; /*!< The second component as a vertical texture coordinate. Aliases @c y. */
        };
    };
};
