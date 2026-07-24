/**
 * @file
 * The engine's 4x4 column-major matrix arithmetic helpers.
 */

#pragma once

#include "s_vector3.h"

/**
 * @brief Builds a look-at view matrix from an eye, a target, and an up vector.
 * @return @p pOutMatrix, so the result can be passed on inline.
 * @ghidraAddress 0x19844
 */
float *MakeLookAtMatrix(float *pOutMatrix, S_VECTOR3 *pEye, S_VECTOR3 *pTarget, S_VECTOR3 *pUp);
/**
 * @brief Builds an x-axis rotation matrix for the given angle, in radians.
 * @return @p pOutMatrix, so the result can be passed on inline.
 * @ghidraAddress 0x196b4
 */
float *MakeRotationMatrixX(float angle, float *pOutMatrix);
/**
 * @brief Builds a z-axis rotation matrix for the given angle, in radians.
 * @return @p pOutMatrix, so the result can be passed on inline.
 * @ghidraAddress 0x19728
 */
float *MakeRotationMatrixZ(float flAngle, float *pOutMatrix);
/**
 * @brief Builds a translation matrix for the given offset.
 * @ghidraAddress 0x19624
 */
void MakeTranslationMatrix(float *pOutMatrix, float x, float y, float z);
/**
 * @brief Builds a 4x4 column-major top-left-origin orthographic projection matrix.
 *
 * Maps x from @c [0, flWidth] to @c [-1, 1], y from @c [0, flHeight] to @c [1, -1] (flipped for
 * screen space), and z from @c [flNear, flFar] to @c [0, 1].
 * @ghidraAddress 0x19990
 */
void MakeOrthoMatrix(float flWidth, float flHeight, float flNear, float flFar, float *pOutMatrix);
/**
 * @brief Builds a 4x4 column-major perspective projection matrix from vertical field of view and
 * aspect ratio.
 *
 * Uses the engine's own depth-mapping sign convention rather than the textbook GL form.
 * @return @p pOutMatrix, so the result can be passed on inline.
 * @ghidraAddress 0x199f4
 */
float *
MakePerspectiveMatrix(float flFovY, float flAspect, float flNear, float flFar, float *pOutMatrix);
/**
 * @brief Composes @p pSource onto @p pAccumulator on the left, in place.
 *
 * Computes @c pAccumulator @c = @c pSource @c * @c pAccumulator (column-major), multiplying against
 * a copy of the accumulator so the in-place result does not alias its own input.
 * @ghidraAddress 0x18f10
 */
void ComposeMatrices(float *pAccumulator, float *pSource);
/**
 * @brief Multiplies two 4x4 column-major matrices: @c pOut @c = @c pLeft @c * @c pRight.
 * @ghidraAddress 0x18e40
 */
void MultiplyMatrix4x4(float *pOut, float *pLeft, float *pRight);
/**
 * @brief Computes the determinant of a 4x4 column-major matrix.
 * @ghidraAddress 0x194b4
 */
float Matrix4x4Determinant(float *pMatrix);
/**
 * @brief Inverts a 4x4 column-major matrix in place by the adjugate-over-determinant method.
 *
 * A singular matrix (zero determinant) is left unchanged.
 * @return @p pMatrix, so the result can be passed on inline.
 * @ghidraAddress 0x18fe0
 */
float *InvertMatrix4x4(float *pMatrix);
/**
 * @brief Sets a 4x4 column-major matrix to the identity matrix.
 * @ghidraAddress 0x18fac
 */
void SetMatrixIdentity(float *pMatrix);
/**
 * @brief Multiplies @p pMatrix by @p pRight on the right, in place.
 *
 * Computes @c pMatrix @c = @c pMatrix @c * @c pRight (column-major), multiplying against a copy of
 * @p pMatrix so the in-place result does not alias its own input.
 * @ghidraAddress 0x18d9c
 */
void MultiplyMatrixInPlace(float *pMatrix, float *pRight);
/**
 * @brief Builds a 4x4 column-major diagonal scale matrix.
 * @ghidraAddress 0x197ec
 */
void MakeScaleMatrix(float *pOutMatrix, float flScaleX, float flScaleY, float flScaleZ);
/**
 * @brief Sets a matrix's translation column, leaving the rest of the matrix intact.
 * @ghidraAddress 0x19660
 */
void SetMatrixTranslation(float *pMatrix, float x, float y, float z);
/**
 * @brief Sets the upper-left 3x3 of a matrix to a z-axis rotation, leaving the translation column
 * and bottom row intact.
 * @return @p pMatrix, so the result can be passed on inline.
 * @ghidraAddress 0x19798
 */
float *SetMatrixRotationZ3x3(float *pMatrix, float flAngle);
/**
 * @brief Sets the upper-left 3x3 of a matrix to a diagonal scale, zeroing the other 3x3 elements
 * and leaving the translation column and bottom row intact.
 * @ghidraAddress 0x19824
 */
void SetMatrixScale3x3(float *pMatrix, float flScaleX, float flScaleY, float flScaleZ);
/**
 * @brief Multiplies a 4-component row vector by a 4x4 column-major matrix: @c pOut @c = @c pVec4 @c *
 *        @c pMatrix.
 *
 * All four input components are read before any output is written, so @p pOut may alias @p pVec4.
 * @ghidraAddress 0x20e7c
 */
void MultiplyVector4ByMatrix(float *pOut, float *pVec4, float *pMatrix);
/**
 * @brief Multiplies a 4-component vector by a 4x4 column-major matrix in place.
 * @ghidraAddress 0x20e5c
 */
void MultiplyVector4ByMatrixInPlace(float *pVec4, float *pMatrix);
/**
 * @brief Transforms a 3D point by a 4x4 column-major matrix in place, applying the perspective
 *        divide.
 *
 * The point is taken as @c (x,y,z,1), transformed, and divided by the resulting homogeneous w
 * (assumed non-zero).
 * @ghidraAddress 0x20db0
 */
void TransformPointByMatrix(float *pPoint, float *pMatrix);

// code: language=C++
// kate: hl C++;
// vim: set ft=cpp :
