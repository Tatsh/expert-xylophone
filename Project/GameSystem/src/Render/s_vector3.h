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
 * @ghidraAddress S_VECTOR3 (engine struct type)
 */
struct S_VECTOR3 {
    /** @brief Constructs a zero vector. */
    S_VECTOR3() = default;
    /** @brief Constructs a vector from its three components. */
    S_VECTOR3(float x, float y, float z) : x(x), y(y), z(z) {
    }

    float x = {}; // +0x0
    float y = {}; // +0x4
    float z = {}; // +0x8
};

// code: language=C++
// kate: hl C++;
// vim: set ft=cpp :
