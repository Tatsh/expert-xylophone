#import <cmath>
#import <cstring>

#import "../../../neEngineBridge.h"

// The order (row and column count) of the square matrices this module operates on.
constexpr int kMatrix4Order = 4;

// Element indices of the translation column in a column-major 4x4 matrix.
enum {
    kMatrixTranslateX = 12,
    kMatrixTranslateY = 13,
    kMatrixTranslateZ = 14,
};

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
