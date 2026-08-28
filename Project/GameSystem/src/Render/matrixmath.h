/**
 * @file
 * The engine's 4x4 column-major matrix arithmetic helpers.
 */

#pragma once

#include "s_vector3.h"

/**
 * @brief Builds a look-at view matrix from an eye, a target, and an up vector.
 * @param pOut The 16-element output matrix.
 * @param pEye The camera position.
 * @param pTarget The look-at target.
 * @param pUp The up direction.
 * @return @p pOut, so the result can be passed on inline.
 * @ghidraAddress 0x19844
 */
float *MakeLookAtMatrix(float *pOut, S_VECTOR3 *pEye, S_VECTOR3 *pTarget, S_VECTOR3 *pUp);
/**
 * @brief Builds an x-axis rotation matrix for the given angle, in radians.
 * @param flAngle The rotation angle, in radians.
 * @param pOut The 16-element output matrix.
 * @return @p pOut, so the result can be passed on inline.
 * @ghidraAddress 0x196b4
 */
float *MakeRotationMatrixX(float flAngle, float *pOut);
/**
 * @brief Builds a z-axis rotation matrix for the given angle, in radians.
 * @param flAngle The rotation angle, in radians.
 * @param pOut The 16-element output matrix.
 * @return @p pOut, so the result can be passed on inline.
 * @ghidraAddress 0x19728
 */
float *MakeRotationMatrixZ(float flAngle, float *pOut);
/**
 * @brief Builds a translation matrix for the given offset.
 * @param pOutMatrix The 16-element output matrix.
 * @param x The x translation.
 * @param y The y translation.
 * @param z The z translation.
 * @ghidraAddress 0x19624
 */
void MakeTranslationMatrix(float *pOutMatrix, float x, float y, float z);
/**
 * @brief Builds a translation matrix from a three-component translation vector.
 * @param pOutMatrix The 16-element output matrix.
 * @param pTranslation The three-component translation (x, y, z).
 * @ghidraAddress 0x1966c
 */
void MakeTranslationMatrix(float *pOutMatrix, const float *pTranslation);
/**
 * @brief Builds a 4x4 column-major top-left-origin orthographic projection matrix.
 *
 * Maps x from @c [0, flWidth] to @c [-1, 1], y from @c [0, flHeight] to @c [1, -1] (flipped for
 * screen space), and z from @c [flNear, flFar] to @c [0, 1].
 * @param flWidth The orthographic width.
 * @param flHeight The orthographic height.
 * @param flNear The near clip plane.
 * @param flFar The far clip plane.
 * @param pOutMatrix The 16-element output matrix.
 * @ghidraAddress 0x19990
 */
void MakeOrthoMatrix(float flWidth, float flHeight, float flNear, float flFar, float *pOutMatrix);
/**
 * @brief Builds a 4x4 column-major perspective projection matrix from vertical field of view and
 * aspect ratio.
 *
 * Uses the engine's own depth-mapping sign convention rather than the textbook GL form.
 * @param flFovY The vertical field of view, in radians.
 * @param flAspect The aspect ratio.
 * @param flNear The near clip plane.
 * @param flFar The far clip plane.
 * @param pOutMatrix The 16-element output matrix.
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
 * @param pAccumulator The accumulator matrix, updated in place.
 * @param pSource The matrix composed onto the accumulator from the left.
 * @ghidraAddress 0x18f10
 */
void ComposeMatrices(float *pAccumulator, float *pSource);
/**
 * @brief Multiplies two 4x4 column-major matrices: @c pResult @c = @c pLeft @c * @c pRight.
 *
 * @p pResult is not safe to alias either operand: @p pLeft is re-read for every output column.
 * @param pResult The 16-element output matrix.
 * @param pLeft The left operand.
 * @param pRight The right operand.
 * @ghidraAddress 0x18e40
 */
void MultiplyMatrix4x4(float *pResult, float *pLeft, float *pRight);
/**
 * @brief Computes the determinant of a 4x4 column-major matrix.
 * @param pMatrix The matrix to measure.
 * @return The matrix's determinant.
 * @ghidraAddress 0x194b4
 */
float Matrix4x4Determinant(float *pMatrix);
/**
 * @brief Inverts a 4x4 column-major matrix in place by the adjugate-over-determinant method.
 *
 * A singular matrix (zero determinant) is left unchanged.
 * @param pMatrix The matrix, inverted in place.
 * @return @p pMatrix, so the result can be passed on inline.
 * @ghidraAddress 0x18fe0
 */
float *InvertMatrix4x4(float *pMatrix);
/**
 * @brief Sets a 4x4 column-major matrix to the identity matrix.
 * @param pMatrix The matrix to overwrite with the identity.
 * @ghidraAddress 0x18fac
 */
void SetMatrixIdentity(float *pMatrix);
/**
 * @brief Multiplies @p pMatrix by @p pRight on the right, in place.
 *
 * Computes @c pMatrix @c = @c pMatrix @c * @c pRight (column-major), multiplying against a copy of
 * @p pMatrix so the in-place result does not alias its own input.
 * @param pMatrix The accumulator matrix, updated in place.
 * @param pRight The right operand.
 * @ghidraAddress 0x18d9c
 */
void MultiplyMatrixInPlace(float *pMatrix, float *pRight);
/**
 * @brief Builds a 4x4 column-major diagonal scale matrix.
 * @param pOutMatrix The 16-element output matrix.
 * @param flScaleX The x scale.
 * @param flScaleY The y scale.
 * @param flScaleZ The z scale.
 * @ghidraAddress 0x197ec
 */
void MakeScaleMatrix(float *pOutMatrix, float flScaleX, float flScaleY, float flScaleZ);
/**
 * @brief Sets a matrix's translation column, leaving the rest of the matrix intact.
 * @param pMatrix The matrix whose translation column is set.
 * @param x The x translation.
 * @param y The y translation.
 * @param z The z translation.
 * @ghidraAddress 0x19660
 */
void SetMatrixTranslation(float *pMatrix, float x, float y, float z);
/**
 * @brief Sets the upper-left 3x3 of a matrix to a z-axis rotation, leaving the translation column
 * and bottom row intact.
 * @param pMatrix The matrix whose upper-left 3x3 is set.
 * @param flAngle The rotation angle, in radians.
 * @return @p pMatrix, so the result can be passed on inline.
 * @ghidraAddress 0x19798
 */
float *SetMatrixRotationZ3x3(float *pMatrix, float flAngle);
/**
 * @brief Sets the upper-left 3x3 of a matrix to a diagonal scale, zeroing the other 3x3 elements
 * and leaving the translation column and bottom row intact.
 * @param pMatrix The matrix whose upper-left 3x3 is set.
 * @param flScaleX The x scale.
 * @param flScaleY The y scale.
 * @param flScaleZ The z scale.
 * @ghidraAddress 0x19824
 */
void SetMatrixScale3x3(float *pMatrix, float flScaleX, float flScaleY, float flScaleZ);
/**
 * @brief Multiplies a 4-component row vector by a 4x4 column-major matrix:
 *        @c pOut @c = @c pVec4 @c * @c pMatrix.
 *
 * All four input components are read before any output is written, so @p pOut may alias @p pVec4.
 * @param pOut The four-element output vector.
 * @param pVec4 The four-element input vector.
 * @param pMatrix The 16-element matrix.
 * @ghidraAddress 0x20e7c
 */
void MultiplyVector4ByMatrix(float *pOut, float *pVec4, float *pMatrix);
/**
 * @brief Multiplies a 4-component vector by a 4x4 column-major matrix in place.
 * @param pVec4 The four-element vector, transformed in place.
 * @param pMatrix The 16-element matrix.
 * @ghidraAddress 0x20e5c
 */
void MultiplyVector4ByMatrixInPlace(float *pVec4, float *pMatrix);
/**
 * @brief Transforms a 3D point by a 4x4 column-major matrix in place, applying the perspective
 *        divide.
 *
 * The point is taken as @c (x,y,z,1), transformed, and divided by the resulting homogeneous w
 * (assumed non-zero).
 * @param pPoint The point, transformed in place.
 * @param pMatrix The 16-element matrix.
 * @ghidraAddress 0x20db0
 */
void TransformPointByMatrix(S_VECTOR3 *pPoint, const float *pMatrix);
