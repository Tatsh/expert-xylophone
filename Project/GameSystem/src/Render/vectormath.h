/**
 * @file
 * The engine's two- and three-component vector arithmetic helpers.
 */

#pragma once

#include "s_vector2.h"
#include "s_vector3.h"

/**
 * @brief Adds a two-component vector into another in place: @c pOut @c += @c pIn.
 * @ghidraAddress 0x20bc0
 */
void AddVector2(S_VECTOR2 *pOut, S_VECTOR2 *pIn);
/**
 * @brief Subtracts a two-component vector from another in place: @c pOut @c -= @c pIn.
 * @ghidraAddress 0x20be4
 */
void SubtractVector2(S_VECTOR2 *pOut, S_VECTOR2 *pIn);
/**
 * @brief Scales a two-component vector in place by a scalar.
 * @ghidraAddress 0x20c08
 */
void ScaleVector2(S_VECTOR2 *pVec, float flScale);
/**
 * @brief Returns the Euclidean length of a two-component vector.
 * @ghidraAddress 0x20c20
 */
float Vector2Length(S_VECTOR2 *pVec);
/**
 * @brief Normalizes a two-component vector in place, guarding against a near-zero length.
 * @ghidraAddress 0x20c38
 */
void NormalizeVector2(S_VECTOR2 *pVec);
/**
 * @brief Adds a 3-component vector into another in place: @c pAccum @c += @c pB.
 * @ghidraAddress 0x20c6c
 */
void AddVector3(S_VECTOR3 *pAccum, S_VECTOR3 *pB);
/**
 * @brief Subtracts a 3-component vector from another in place: @c pAccum @c -= @c pB.
 * @ghidraAddress 0x20ca0
 */
void SubtractVector3(S_VECTOR3 *pAccum, S_VECTOR3 *pB);
/**
 * @brief Scales a 3-component vector in place by a scalar.
 * @ghidraAddress 0x20cd4
 */
void ScaleVector3(float flScalar, S_VECTOR3 *pVec);
/**
 * @brief Computes the dot product of two 3-component vectors.
 * @return The dot product @c pA · @c pB.
 * @ghidraAddress 0x20cf8
 */
float DotProductVector3(S_VECTOR3 *pA, S_VECTOR3 *pB);
/**
 * @brief Computes the cross product @c pOut @c = @c pOut @c × @c pB in place.
 * @ghidraAddress 0x20d68
 */
void CrossProductVector3(S_VECTOR3 *pOut, S_VECTOR3 *pB);
/**
 * @brief Normalizes a 3-component vector in place, guarding against a near-zero length.
 * @ghidraAddress 0x20d20
 */
void NormalizeVector3(S_VECTOR3 *pVec);

// code: language=C++
// kate: hl C++;
// vim: set ft=cpp :
