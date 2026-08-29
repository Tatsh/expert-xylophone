#include <cmath>
#include <cstring>

#import "matrixmath.h"
#import "s_vector2.h"
#import "s_vector3.h"
#import "vectormath.h"

constexpr int kMatrix4Order = 4;

enum {
    kMatrixTranslateX = 12,
    kMatrixTranslateY = 13,
    kMatrixTranslateZ = 14,
};

enum {
    kViewMatrixRowRight = 0,
    kViewMatrixRowUp = 1,
    kViewMatrixRowForward = 2,
};

// @ghidraAddress 0x2eea50
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
    if (lengthSquared > kNormalizeLengthSquaredEpsilon) {
        const float length = std::sqrt(lengthSquared);
        pVec->x /= length;
        pVec->y /= length;
        pVec->z /= length;
    }
}

/** @ghidraAddress 0x20c6c */
void AddVector3(S_VECTOR3 *pAccum, S_VECTOR3 *pB) {
    pAccum->x = pAccum->x + pB->x;
    pAccum->y = pAccum->y + pB->y;
    pAccum->z = pAccum->z + pB->z;
}

/** @ghidraAddress 0x20ca0 */
void SubtractVector3(S_VECTOR3 *pAccum, S_VECTOR3 *pB) {
    pAccum->x = pAccum->x - pB->x;
    pAccum->y = pAccum->y - pB->y;
    pAccum->z = pAccum->z - pB->z;
}

/** @ghidraAddress 0x20cd4 */
void ScaleVector3(float flScalar, S_VECTOR3 *pVec) {
    pVec->x = pVec->x * flScalar;
    pVec->y = pVec->y * flScalar;
    pVec->z = pVec->z * flScalar;
}

/** @ghidraAddress 0x20bc0 */
void AddVector2(S_VECTOR2 *pOut, S_VECTOR2 *pIn) {
    pOut->x = pOut->x + pIn->x;
    pOut->y = pOut->y + pIn->y;
}

/** @ghidraAddress 0x20be4 */
void SubtractVector2(S_VECTOR2 *pOut, S_VECTOR2 *pIn) {
    pOut->x = pOut->x - pIn->x;
    pOut->y = pOut->y - pIn->y;
}

/** @ghidraAddress 0x20c08 */
void ScaleVector2(S_VECTOR2 *pVec, float flScale) {
    pVec->x = pVec->x * flScale;
    pVec->y = pVec->y * flScale;
}

/** @ghidraAddress 0x20c20 */
float Vector2Length(S_VECTOR2 *pVec) {
    return std::sqrt(pVec->x * pVec->x + pVec->y * pVec->y);
}

/** @ghidraAddress 0x20c38 */
void NormalizeVector2(S_VECTOR2 *pVec) {
    const float lengthSquared = pVec->x * pVec->x + pVec->y * pVec->y;
    if (lengthSquared > kNormalizeLengthSquaredEpsilon) {
        const float length = std::sqrt(lengthSquared);
        pVec->x /= length;
        pVec->y /= length;
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
    std::memcpy(pMatrix, kIdentity, sizeof(kIdentity));
}

/** @ghidraAddress 0x1966c */
void MakeTranslationMatrix(float *pOutMatrix, const float *pTranslation) {
    MakeTranslationMatrix(pOutMatrix, pTranslation[0], pTranslation[1], pTranslation[2]);
}

/** @ghidraAddress 0x19624 */
void MakeTranslationMatrix(float *pOutMatrix, float x, float y, float z) {
    SetMatrixIdentity(pOutMatrix);
    pOutMatrix[kMatrixTranslateX] = x;
    pOutMatrix[kMatrixTranslateY] = y;
    pOutMatrix[kMatrixTranslateZ] = z;
}

/** @ghidraAddress 0x19990 */
void MakeOrthoMatrix(float flWidth, float flHeight, float flNear, float flFar, float *pOutMatrix) {
    // Top-left-origin projection, so y maps [0, height] -> [1, -1] rather than [-1, 1].
    static const float kZeroMatrix[16] = {};
    std::memcpy(pOutMatrix, kZeroMatrix, sizeof(kZeroMatrix));
    const float flDepth = flFar - flNear;
    pOutMatrix[0] = 2.0f / flWidth;
    pOutMatrix[5] = -2.0f / flHeight;
    pOutMatrix[10] = 1.0f / flDepth;
    pOutMatrix[15] = 1.0f;
    pOutMatrix[kMatrixTranslateX] = -1.0f;
    pOutMatrix[kMatrixTranslateY] = 1.0f;
    pOutMatrix[kMatrixTranslateZ] = -flNear / flDepth;
}

/** @ghidraAddress 0x199f4 */
float *
MakePerspectiveMatrix(float flFovY, float flAspect, float flNear, float flFar, float *pOutMatrix) {
    // The depth terms keep the engine's sign convention (positive m[10] and m[14]), not the
    // textbook GL negative form.
    const float flFocal = std::tan(flFovY * 0.5f);
    const float flDepth = flFar - flNear;
    static const float kZeroMatrix[16] = {};
    std::memcpy(pOutMatrix, kZeroMatrix, sizeof(kZeroMatrix));
    pOutMatrix[0] = 1.0f / (flFocal * flAspect);
    pOutMatrix[5] = 1.0f / flFocal;
    pOutMatrix[10] = (flNear + flFar) / flDepth;
    pOutMatrix[11] = -1.0f;
    pOutMatrix[14] = (flNear + flNear) * flFar / flDepth;
    return pOutMatrix;
}

/** @ghidraAddress 0x196b4 */
float *MakeRotationMatrixX(float flAngle, float *pOut) {
    SetMatrixIdentity(pOut);
    const float flSin = std::sin(flAngle);
    const float flCos = std::cos(flAngle);
    pOut[5] = flCos;
    pOut[6] = flSin;
    pOut[9] = -flSin;
    pOut[10] = flCos;
    return pOut;
}

/** @ghidraAddress 0x19728 */
float *MakeRotationMatrixZ(float flAngle, float *pOut) {
    const float flSin = std::sin(flAngle);
    const float flCos = std::cos(flAngle);
    pOut[0] = flCos;
    pOut[1] = flSin;
    pOut[2] = 0.0f;
    pOut[3] = 0.0f;
    pOut[4] = -flSin;
    pOut[5] = flCos;
    pOut[6] = 0.0f;
    pOut[7] = 0.0f;
    pOut[8] = 0.0f;
    pOut[9] = 0.0f;
    pOut[10] = 1.0f;
    pOut[11] = 0.0f;
    pOut[12] = 0.0f;
    pOut[13] = 0.0f;
    pOut[14] = 0.0f;
    pOut[15] = 1.0f;
    return pOut;
}

/** @ghidraAddress 0x18e40 */
void MultiplyMatrix4x4(float *pResult, float *pLeft, float *pRight) {
    // pLeft is reread for every output column, so pResult must not alias either operand.
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

/** @ghidraAddress 0x18d9c */
void MultiplyMatrixInPlace(float *pMatrix, float *pRight) {
    // The in-place matrix is the left operand, which MultiplyMatrix4x4 cannot alias.
    float matrixCopy[16];
    std::memcpy(matrixCopy, pMatrix, sizeof(matrixCopy));
    MultiplyMatrix4x4(pMatrix, matrixCopy, pRight);
}

/** @ghidraAddress 0x19660 */
void SetMatrixTranslation(float *pMatrix, float x, float y, float z) {
    pMatrix[kMatrixTranslateX] = x;
    pMatrix[kMatrixTranslateY] = y;
    pMatrix[kMatrixTranslateZ] = z;
}

/** @ghidraAddress 0x197ec */
void MakeScaleMatrix(float *pOutMatrix, float flScaleX, float flScaleY, float flScaleZ) {
    static const float kZeroMatrix[16] = {};
    std::memcpy(pOutMatrix, kZeroMatrix, sizeof(kZeroMatrix));
    pOutMatrix[0] = flScaleX;
    pOutMatrix[5] = flScaleY;
    pOutMatrix[10] = flScaleZ;
    pOutMatrix[15] = 1.0f;
}

/** @ghidraAddress 0x19798 */
float *SetMatrixRotationZ3x3(float *pMatrix, float flAngle) {
    const float flSin = std::sin(flAngle);
    const float flCos = std::cos(flAngle);
    pMatrix[0] = flCos;
    pMatrix[1] = flSin;
    pMatrix[2] = 0.0f;
    pMatrix[4] = -flSin;
    pMatrix[5] = flCos;
    pMatrix[6] = 0.0f;
    pMatrix[8] = 0.0f;
    pMatrix[9] = 0.0f;
    pMatrix[10] = 1.0f;
    return pMatrix;
}

/** @ghidraAddress 0x19824 */
void SetMatrixScale3x3(float *pMatrix, float flScaleX, float flScaleY, float flScaleZ) {
    pMatrix[0] = flScaleX;
    pMatrix[1] = 0.0f;
    pMatrix[2] = 0.0f;
    pMatrix[4] = 0.0f;
    pMatrix[5] = flScaleY;
    pMatrix[6] = 0.0f;
    pMatrix[8] = 0.0f;
    pMatrix[9] = 0.0f;
    pMatrix[10] = flScaleZ;
}

static inline void SetViewMatrixAxisRow(float *pOut, int row, S_VECTOR3 *pAxis, S_VECTOR3 *pEye) {
    pOut[row] = pAxis->x;
    pOut[row + kMatrix4Order] = pAxis->y;
    pOut[row + 2 * kMatrix4Order] = pAxis->z;
    pOut[row + 3 * kMatrix4Order] = -DotProductVector3(pEye, pAxis);
}

/** @ghidraAddress 0x19844 */
float *MakeLookAtMatrix(float *pOut, S_VECTOR3 *pEye, S_VECTOR3 *pTarget, S_VECTOR3 *pUp) {
    S_VECTOR3 forward{pEye->x - pTarget->x, pEye->y - pTarget->y, pEye->z - pTarget->z};
    NormalizeVector3(&forward);

    // CrossProductVector3 overwrites its first argument, which holds the caller's up vector.
    S_VECTOR3 right = *pUp;
    CrossProductVector3(&right, &forward);
    NormalizeVector3(&right);

    S_VECTOR3 up = forward;
    CrossProductVector3(&up, &right);
    NormalizeVector3(&up);

    SetViewMatrixAxisRow(pOut, kViewMatrixRowRight, &right, pEye);
    SetViewMatrixAxisRow(pOut, kViewMatrixRowUp, &up, pEye);
    SetViewMatrixAxisRow(pOut, kViewMatrixRowForward, &forward, pEye);

    pOut[3] = 0.0f;
    pOut[7] = 0.0f;
    pOut[11] = 0.0f;
    pOut[15] = 1.0f;
    return pOut;
}

/** @ghidraAddress 0x20e7c */
void MultiplyVector4ByMatrix(float *pOut, float *pVec4, float *pMatrix) {
    // Every input component is read before any output is written, so an in-place call is safe.
    const float x = pVec4[0];
    const float y = pVec4[1];
    const float z = pVec4[2];
    const float w = pVec4[3];
    pOut[0] = x * pMatrix[0] + y * pMatrix[4] + z * pMatrix[8] + w * pMatrix[12];
    pOut[1] = x * pMatrix[1] + y * pMatrix[5] + z * pMatrix[9] + w * pMatrix[13];
    pOut[2] = x * pMatrix[2] + y * pMatrix[6] + z * pMatrix[10] + w * pMatrix[14];
    pOut[3] = x * pMatrix[3] + y * pMatrix[7] + z * pMatrix[11] + w * pMatrix[15];
}

/** @ghidraAddress 0x20e5c */
void MultiplyVector4ByMatrixInPlace(float *pVec4, float *pMatrix) {
    MultiplyVector4ByMatrix(pVec4, pVec4, pMatrix);
}

/** @ghidraAddress 0x194b4 */
float Matrix4x4Determinant(float *pMatrix) {
    // The term grouping follows the binary's accumulation order to keep the rounding identical.
    return (pMatrix[3] * pMatrix[6] * pMatrix[9] * pMatrix[12] +
            pMatrix[11] * pMatrix[2] * pMatrix[5] * pMatrix[12] +
            pMatrix[7] * pMatrix[10] * pMatrix[1] * pMatrix[12] +
            pMatrix[7] * pMatrix[2] * pMatrix[13] * pMatrix[8] +
            pMatrix[3] * pMatrix[14] * pMatrix[5] * pMatrix[8] +
            pMatrix[10] * pMatrix[13] * pMatrix[4] * pMatrix[3] +
            pMatrix[15] * pMatrix[9] * pMatrix[4] * pMatrix[2] +
            pMatrix[0] * pMatrix[5] * pMatrix[10] * pMatrix[15] +
            pMatrix[0] * pMatrix[9] * pMatrix[14] * pMatrix[7] +
            pMatrix[0] * pMatrix[13] * pMatrix[6] * pMatrix[11] +
            pMatrix[11] * pMatrix[14] * pMatrix[4] * pMatrix[1] +
            pMatrix[15] * pMatrix[6] * pMatrix[1] * pMatrix[8]) -
           pMatrix[0] * pMatrix[5] * pMatrix[14] * pMatrix[11] -
           pMatrix[15] * pMatrix[0] * pMatrix[9] * pMatrix[6] -
           pMatrix[7] * pMatrix[10] * pMatrix[0] * pMatrix[13] -
           pMatrix[15] * pMatrix[10] * pMatrix[4] * pMatrix[1] -
           pMatrix[14] * pMatrix[9] * pMatrix[4] * pMatrix[3] -
           pMatrix[11] * pMatrix[13] * pMatrix[4] * pMatrix[2] -
           pMatrix[7] * pMatrix[14] * pMatrix[1] * pMatrix[8] -
           pMatrix[15] * pMatrix[2] * pMatrix[5] * pMatrix[8] -
           pMatrix[3] * pMatrix[6] * pMatrix[13] * pMatrix[8] -
           pMatrix[11] * pMatrix[6] * pMatrix[1] * pMatrix[12] -
           pMatrix[3] * pMatrix[10] * pMatrix[5] * pMatrix[12] -
           pMatrix[7] * pMatrix[2] * pMatrix[9] * pMatrix[12];
}

/** @ghidraAddress 0x18fe0 */
float *InvertMatrix4x4(float *pMatrix) {
    // The shared two-factor products keep the multiplication grouping identical to the binary's.
    const float flDet = Matrix4x4Determinant(pMatrix);
    if (flDet == 0.0f) {
        return pMatrix;
    }
    const float flInvDet = 1.0f / flDet;
    const float m0 = pMatrix[0];
    const float m1 = pMatrix[1];
    const float m2 = pMatrix[2];
    const float m3 = pMatrix[3];
    const float m4 = pMatrix[4];
    const float m5 = pMatrix[5];
    const float m6 = pMatrix[6];
    const float m7 = pMatrix[7];
    const float m8 = pMatrix[8];
    const float m9 = pMatrix[9];
    const float m10 = pMatrix[10];
    const float m11 = pMatrix[11];
    const float m12 = pMatrix[12];
    const float m13 = pMatrix[13];
    const float m14 = pMatrix[14];
    const float m15 = pMatrix[15];
    const float p94 = m9 * m4;
    const float p138 = m13 * m8;
    const float p512 = m5 * m12;
    const float p134 = m13 * m4;
    const float p58 = m5 * m8;
    const float p912 = m9 * m12;
    const float p130 = m13 * m0;
    const float p81 = m8 * m1;
    const float p90 = m9 * m0;
    const float p121 = m12 * m1;
    const float p50 = m5 * m0;
    const float p41 = m4 * m1;
    pMatrix[0] =
        flInvDet *
        ((((m5 * m10 * m15 + m9 * m14 * m7 + m13 * m6 * m11) - m5 * m14 * m11) - m15 * m9 * m6) -
         m7 * m10 * m13);
    pMatrix[4] =
        flInvDet *
        ((((m11 * m14 * m4 + m15 * m6 * m8 + m7 * m10 * m12) - m15 * m10 * m4) - m7 * m14 * m8) -
         m11 * m6 * m12);
    pMatrix[8] =
        flInvDet * ((((m15 * p94 + m7 * p138 + m11 * p512) - m11 * p134) - m15 * p58) - m7 * p912);
    pMatrix[12] =
        flInvDet * ((((m10 * p134 + m14 * p58 + m6 * p912) - m14 * p94) - m6 * p138) - m10 * p512);
    pMatrix[1] =
        flInvDet *
        ((((m14 * m13 * m3 + m11 * m14 * m1 + m15 * m9 * m2) - m15 * m10 * m1) - m9 * m14 * m3) -
         m11 * m13 * m2);
    pMatrix[5] =
        flInvDet *
        ((((m11 * m12 * m2 + m14 * m8 * m3 + m15 * m10 * m0) - m11 * m14 * m0) - m15 * m8 * m2) -
         m10 * m12 * m3);
    pMatrix[9] =
        flInvDet * ((((p912 * m3 + m15 * p81 + m11 * p130) - m15 * p90) - p138 * m3) - m11 * p121);
    pMatrix[13] =
        flInvDet * ((((m10 * p121 + p138 * m2 + m14 * p90) - m10 * p130) - m14 * p81) - p912 * m2);
    pMatrix[2] =
        flInvDet *
        ((((m7 * m13 * m2 + m15 * m6 * m1 + m5 * m14 * m3) - m7 * m14 * m1) - m15 * m5 * m2) -
         m13 * m6 * m3);
    pMatrix[6] =
        flInvDet *
        ((((m6 * m12 * m3 + m15 * m4 * m2 + m7 * m14 * m0) - m15 * m6 * m0) - m14 * m4 * m3) -
         m7 * m12 * m2);
    pMatrix[10] =
        flInvDet * ((((m7 * p121 + p134 * m3 + m15 * p50) - m7 * p130) - m15 * p41) - p512 * m3);
    pMatrix[3] =
        flInvDet *
        ((((m9 * m6 * m3 + m7 * m10 * m1 + m11 * m5 * m2) - m11 * m6 * m1) - m5 * m10 * m3) -
         m7 * m9 * m2);
    pMatrix[7] =
        flInvDet *
        ((((m7 * m8 * m2 + m10 * m4 * m3 + m11 * m6 * m0) - m7 * m10 * m0) - m11 * m4 * m2) -
         m6 * m8 * m3);
    pMatrix[11] =
        flInvDet * ((((p58 * m3 + m11 * p41 + m7 * p90) - m11 * p50) - p94 * m3) - m7 * p81);
    pMatrix[14] =
        flInvDet * ((((p512 * m2 + m14 * p41 + m6 * p130) - m14 * p50) - p134 * m2) - m6 * p121);
    pMatrix[15] =
        flInvDet * ((((m6 * p81 + p94 * m2 + m10 * p50) - m6 * p90) - m10 * p41) - p58 * m2);
    return pMatrix;
}

/** @ghidraAddress 0x20db0 */
void TransformPointByMatrix(S_VECTOR3 *pPoint, const float *pMatrix) {
    // The resulting homogeneous w is assumed non-zero.
    const float x = pPoint->x;
    const float y = pPoint->y;
    const float z = pPoint->z;
    const float flInvW = 1.0f / (pMatrix[15] + x * pMatrix[3] + y * pMatrix[7] + z * pMatrix[11]);
    pPoint->x = flInvW * (pMatrix[12] + x * pMatrix[0] + y * pMatrix[4] + z * pMatrix[8]);
    pPoint->y = flInvW * (pMatrix[13] + x * pMatrix[1] + y * pMatrix[5] + z * pMatrix[9]);
    pPoint->z = flInvW * (pMatrix[14] + x * pMatrix[2] + y * pMatrix[6] + z * pMatrix[10]);
}
