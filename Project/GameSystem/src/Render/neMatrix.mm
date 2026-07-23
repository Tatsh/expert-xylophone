#import <cmath>
#import <cstring>

#import "../../../neEngineBridge.h"

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
