/**
 * @file
 * The engine's two- and three-component vector arithmetic helpers.
 */

#pragma once

#include "s_vector2.h"
#include "s_vector3.h"

/**
 * Adds a two-component vector into another in place: @c pOut @c += @c pIn.
 * @param pOut The accumulator, updated in place.
 * @param pIn The vector to add.
 * @ghidraAddress 0x20bc0
 */
void AddVector2(S_VECTOR2 *pOut, S_VECTOR2 *pIn);
/**
 * Subtracts a two-component vector from another in place: @c pOut @c -= @c pIn.
 * @param pOut The accumulator, updated in place.
 * @param pIn The vector to subtract.
 * @ghidraAddress 0x20be4
 */
void SubtractVector2(S_VECTOR2 *pOut, S_VECTOR2 *pIn);
/**
 * Scales a two-component vector in place by a scalar.
 * @param pVec The vector, scaled in place.
 * @param flScale The scale factor.
 * @ghidraAddress 0x20c08
 */
void ScaleVector2(S_VECTOR2 *pVec, float flScale);
/**
 * Returns the Euclidean length of a two-component vector.
 * @param pVec The vector to measure.
 * @return The vector's Euclidean length.
 * @ghidraAddress 0x20c20
 */
float Vector2Length(S_VECTOR2 *pVec);
/**
 * Normalizes a two-component vector in place, guarding against a near-zero length.
 * @param pVec The vector, normalised in place.
 * @ghidraAddress 0x20c38
 */
void NormalizeVector2(S_VECTOR2 *pVec);
/**
 * Adds a 3-component vector into another in place: @c pAccum @c += @c pB.
 * @param pAccum The accumulator, updated in place.
 * @param pB The vector to add.
 * @ghidraAddress 0x20c6c
 */
void AddVector3(S_VECTOR3 *pAccum, S_VECTOR3 *pB);
/**
 * Subtracts a 3-component vector from another in place: @c pAccum @c -= @c pB.
 * @param pAccum The accumulator, updated in place.
 * @param pB The vector to subtract.
 * @ghidraAddress 0x20ca0
 */
void SubtractVector3(S_VECTOR3 *pAccum, S_VECTOR3 *pB);
/**
 * Scales a 3-component vector in place by a scalar.
 * @param flScalar The scale factor.
 * @param pVec The vector, scaled in place.
 * @ghidraAddress 0x20cd4
 */
void ScaleVector3(float flScalar, S_VECTOR3 *pVec);
/**
 * Computes the dot product of two 3-component vectors.
 * @param pA The first vector.
 * @param pB The second vector.
 * @return The dot product @c pA · @c pB.
 * @ghidraAddress 0x20cf8
 */
float DotProductVector3(S_VECTOR3 *pA, S_VECTOR3 *pB);
/**
 * Computes the cross product @c pOut @c = @c pOut @c × @c pB in place.
 * @param pOut The left operand, overwritten with the cross product.
 * @param pB The right operand.
 * @ghidraAddress 0x20d68
 */
void CrossProductVector3(S_VECTOR3 *pOut, S_VECTOR3 *pB);
/**
 * Normalizes a 3-component vector in place, guarding against a near-zero length.
 * @param pVec The vector, normalised in place.
 * @ghidraAddress 0x20d20
 */
void NormalizeVector3(S_VECTOR3 *pVec);
