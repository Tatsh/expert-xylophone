/**
 * @file
 * The two-component float vector value type, @c S_VECTOR2.
 */

#pragma once

/**
 * A two-component float vector shared with the engine's sheet-layout helpers. Its components are
 * public (a deliberate exception to the usual encapsulation, shared with @c S_VECTOR3) so the maths
 * reads as @c v.x rather than through accessors.
 * @ghidraAddress S_VECTOR2 (engine struct type)
 */
struct S_VECTOR2 {
    /** @brief Constructs a zero vector. */
    S_VECTOR2() = default;
    /** @brief Constructs a vector from its two components. */
    S_VECTOR2(float x, float y) : x(x), y(y) {
    }

    float x = {}; // +0x0
    float y = {}; // +0x4
};

// code: language=C++
// kate: hl C++;
// vim: set ft=cpp :
