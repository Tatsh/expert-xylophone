#include <cmath>
#include <cstring>

#import "neEngineBridge.h"

// The order (row and column count) of the square matrices this module operates on.
constexpr int kMatrix4Order = 4;

// Element indices of the translation column in a column-major 4x4 matrix.
enum {
    kMatrixTranslateX = 12,
    kMatrixTranslateY = 13,
    kMatrixTranslateZ = 14,
};

// Row indices of the rotation basis in a column-major view matrix.
enum {
    kViewMatrixRowRight = 0,
    kViewMatrixRowUp = 1,
    kViewMatrixRowForward = 2,
};

// Squared-length threshold below which a vector is treated as zero-length and left
// unnormalised. In the binary this is the rodata float at 0x2eea50 (0x179abe15 == 1e-24f).
constexpr float kNormalizeLengthSquaredEpsilon = 1e-24f;

/** @ghidraAddress 0x20cf8 */
float DotProductVector3(S_VECTOR3 *pA, S_VECTOR3 *pB) {
    return pA->x * pB->x + pA->y * pB->y + pA->z * pB->z;
}

/** @ghidraAddress 0x20d68 */
void CrossProductVector3(S_VECTOR3 *pOut, S_VECTOR3 *pB) {
    // Computed in place, so read the original components before overwriting any of them.
    const S_VECTOR3 a = *pOut;
    pOut->x = a.y * pB->z - a.z * pB->y;
    pOut->y = a.z * pB->x - a.x * pB->z;
    pOut->z = a.x * pB->y - a.y * pB->x;
}

/** @ghidraAddress 0x20d20 */
void NormalizeVector3(S_VECTOR3 *pVec) {
    const float lengthSquared = pVec->x * pVec->x + pVec->y * pVec->y + pVec->z * pVec->z;
    // Leave a near-zero-length vector unchanged to avoid dividing by zero.
    if (lengthSquared > kNormalizeLengthSquaredEpsilon) {
        const float length = std::sqrt(lengthSquared);
        pVec->x /= length;
        pVec->y /= length;
        pVec->z /= length;
    }
}

/** @ghidraAddress 0x18fac */
void SetMatrixIdentity(float *pMatrix) {
    static const float kIdentity[] = {
        1.0f,
        0.0f,
        0.0f,
        0.0f, //
        0.0f,
        1.0f,
        0.0f,
        0.0f, //
        0.0f,
        0.0f,
        1.0f,
        0.0f, //
        0.0f,
        0.0f,
        0.0f,
        1.0f, //
    };
    // The binary vectorises this as four constant identity-row stores.
    std::memcpy(pMatrix, kIdentity, sizeof(kIdentity));
}

/** @ghidraAddress 0x19624 */
void MakeTranslationMatrix(float *pOutMatrix, float x, float y, float z) {
    SetMatrixIdentity(pOutMatrix);
    pOutMatrix[kMatrixTranslateX] = x;
    pOutMatrix[kMatrixTranslateY] = y;
    pOutMatrix[kMatrixTranslateZ] = z;
}

/** @ghidraAddress 0x196b4 */
float *MakeRotationMatrixX(float flAngle, float *pOut) {
    SetMatrixIdentity(pOut);
    const float flSin = std::sin(flAngle);
    const float flCos = std::cos(flAngle);
    // Rotate in the Y-Z plane, leaving the X axis fixed (column-major):
    //   [ 1    0     0    0 ]
    //   [ 0   cos  -sin   0 ]
    //   [ 0   sin   cos   0 ]
    //   [ 0    0     0    1 ]
    pOut[5] = flCos;
    pOut[6] = flSin;
    pOut[9] = -flSin;
    pOut[10] = flCos;
    return pOut;
}

/** @ghidraAddress 0x18e40 */
void MultiplyMatrix4x4(float *pResult, float *pLeft, float *pRight) {
    // Column-major product pResult = pLeft * pRight. Each result column is a linear
    // combination of pLeft's four columns, weighted by the matching right-hand column's
    // components. The binary broadcasts each pRight component across a NEON lane
    // (fmul-by-lane) and accumulates the four scaled columns (fadd); the loops below are
    // the scalar equivalent. Like the binary, pLeft is read afresh for every output
    // column, so the routine is not safe when pResult aliases an operand — ComposeMatrices
    // copies the accumulator to a temporary for exactly this reason.
    for (int col = 0; col < kMatrix4Order; ++col) {
        const float *pRightColumn = &pRight[col * kMatrix4Order];
        float *pResultColumn = &pResult[col * kMatrix4Order];
        for (int row = 0; row < kMatrix4Order; ++row) {
            pResultColumn[row] = pLeft[row] * pRightColumn[0] +
                                 pLeft[kMatrix4Order + row] * pRightColumn[1] +
                                 pLeft[2 * kMatrix4Order + row] * pRightColumn[2] +
                                 pLeft[3 * kMatrix4Order + row] * pRightColumn[3];
        }
    }
}

/** @ghidraAddress 0x18f10 */
void ComposeMatrices(float *pAccumulator, float *pSource) {
    // The result aliases the accumulator (the right-hand operand), so multiply against a copy.
    float matrixCopy[16];
    std::memcpy(matrixCopy, pAccumulator, sizeof(matrixCopy));
    MultiplyMatrix4x4(pAccumulator, pSource, matrixCopy);
}

// Writes one basis axis into a view-matrix row: the axis components spread across the three
// rotation columns, and -dot(eye, axis) into the translation column.
static inline void SetViewMatrixAxisRow(float *pOut, int row, S_VECTOR3 *pAxis, S_VECTOR3 *pEye) {
    pOut[row] = pAxis->x;
    pOut[row + kMatrix4Order] = pAxis->y;
    pOut[row + 2 * kMatrix4Order] = pAxis->z;
    pOut[row + 3 * kMatrix4Order] = -DotProductVector3(pEye, pAxis);
}

/** @ghidraAddress 0x19844 */
float *MakeLookAtMatrix(float *pOut, S_VECTOR3 *pEye, S_VECTOR3 *pTarget, S_VECTOR3 *pUp) {
    // Camera basis. forward points from the target back towards the eye.
    S_VECTOR3 forward{pEye->x - pTarget->x, pEye->y - pTarget->y, pEye->z - pTarget->z};
    NormalizeVector3(&forward);

    // right = normalize(up x forward). CrossProductVector3 overwrites its first argument, which
    // starts out holding the caller's up vector.
    S_VECTOR3 right = *pUp;
    CrossProductVector3(&right, &forward);
    NormalizeVector3(&right);

    // up = normalize(forward x right), re-orthogonalising the up vector against the basis.
    S_VECTOR3 up = forward;
    CrossProductVector3(&up, &right);
    NormalizeVector3(&up);

    // The rotation rows hold the basis vectors (the view matrix is the transpose of the camera
    // orientation); each translation-column entry is -dot(eye, axis).
    SetViewMatrixAxisRow(pOut, kViewMatrixRowRight, &right, pEye);
    SetViewMatrixAxisRow(pOut, kViewMatrixRowUp, &up, pEye);
    SetViewMatrixAxisRow(pOut, kViewMatrixRowForward, &forward, pEye);

    // Bottom row (0, 0, 0, 1).
    pOut[3] = 0.0f;
    pOut[7] = 0.0f;
    pOut[11] = 0.0f;
    pOut[15] = 1.0f;
    return pOut;
}
