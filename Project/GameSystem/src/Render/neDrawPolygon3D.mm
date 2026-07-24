#include "neDrawPolygon3D.h"

#include <cassert>

#include "neGLES.h"
#include "neTexture.h"
#import "s_vector2.h"
#import "s_vector3.h"

namespace ne {

namespace {

// The scale mapping a normalised [0, 1] UV coordinate to the signed 16-bit fixed-point stored in the
// vertex buffer (@ghidraAddress 0x2eed04 for U, 0x2eed08 for V).
constexpr float kUvFixedPointScale = 32767.0f;

// The sentinel stored in an unset per-vertex attribute offset.
constexpr int kUnsetOffset = -1;

// The default texture-sampler parameters (min filter, mag filter, s wrap, t wrap) the constructor
// seeds (@ghidraAddress 0x2eecf0).
constexpr int kDefaultTexParams[] = {0, 0, 7, 7};

// The interleaved byte size of a 3D vertex position (three floats).
constexpr unsigned int kPositionStride = 0xc;

} // namespace

/** @ghidraAddress 0x285e8 */
C_DRAW_POLYGON_3D::C_DRAW_POLYGON_3D(unsigned int nDrawMode,
                                     unsigned int nVertexCount,
                                     unsigned int nVertexFormat,
                                     unsigned char bVertexBufferExternal,
                                     unsigned int nIndexCount,
                                     unsigned char bIndexBufferExternal) {
    // The base C_RENDER constructor and the derived vtable are installed by the compiler.
    m_nDrawMode = nDrawMode;
    m_nVertexFormat = nVertexFormat;
    m_nVertexCount = nVertexCount;
    m_nVertexStride = 0;
    // The per-vertex attribute offsets start unset; the buffer allocator derives the real ones.
    m_nPositionOffset = kUnsetOffset;
    m_nUvOffset = kUnsetOffset;
    m_nColorOffset = kUnsetOffset;
    m_nMatrixWeightOffset = kUnsetOffset;
    m_nMatrixIndexOffset = kUnsetOffset;
    m_nBoneComponentCount = 0;
    m_bVertexBufferExternal = bVertexBufferExternal != 0;
    m_dwVertexVbo = 0;
    m_nIndexCount = nIndexCount;
    m_dwDrawColor = nIndexCount;
    m_bIndexBufferExternal = bIndexBufferExternal != 0;
    m_dwIndexVbo = 0;
    m_flTranslateX = 0.0f;
    m_flTranslateY = 0.0f;
    m_flTranslateZ = 0.0f;
    m_flRotationZ = 0.0f;
    m_flScale = 1.0f;
    m_pBoneTranslate = nullptr;
    m_pBoneRotation = nullptr;
    m_pBoneScale = nullptr;
    m_nBlendMode = 0;
    m_aTexEnvParams[0] = kDefaultTexParams[0];
    m_aTexEnvParams[1] = kDefaultTexParams[1];
    m_aTexEnvParams[2] = kDefaultTexParams[2];
    m_aTexEnvParams[3] = kDefaultTexParams[3];
}

/** @ghidraAddress 0x287e8 */
void C_DRAW_POLYGON_3D::AllocateBuffers() {
    neGLESRenderer *pRenderer = GetGlRenderer();
    unsigned int nStride = 0;
    m_nVertexStride = 0;

    // Build the interleaved vertex stride and per-attribute byte offsets from the format bits. A 3D
    // position occupies three floats.
    if ((m_nVertexFormat & kVertexHasPosition) != 0) {
        nStride = kPositionStride;
        m_nVertexStride = static_cast<int>(nStride);
        m_nPositionOffset = 0;
    }
    if ((m_nVertexFormat & kVertexHasTexcoord) != 0) {
        m_nUvOffset = static_cast<int>(nStride);
        nStride += 4;
        m_nVertexStride = static_cast<int>(nStride);
    }
    if ((m_nVertexFormat & kVertexHasColor) != 0) {
        m_nColorOffset = static_cast<int>(nStride);
        nStride += 4;
        m_nVertexStride = static_cast<int>(nStride);
        m_pColorArray = new S_RGBA[m_nVertexCount];
    }
    if ((m_nVertexFormat & kVertexHasSkin) != 0) {
        m_nBoneComponentCount = 3;
        m_nMatrixWeightOffset = static_cast<int>(nStride);
        m_nMatrixIndexOffset = static_cast<int>(nStride) + 0xc;
        nStride += 0xf;
        m_nVertexStride = static_cast<int>(nStride);
        const int nMaxUnits = pRenderer->GetMaxVertexUnits();
        auto **ppTranslate = new void *[nMaxUnits];
        for (int i = 0; i < nMaxUnits; ++i) {
            ppTranslate[i] = nullptr;
        }
        m_pBoneTranslate = ppTranslate;
        m_pBoneRotation = new float[nMaxUnits];
        m_pBoneScale = new float[nMaxUnits];
    }

    // Allocate the interleaved vertex buffer; gen a GL vertex VBO and mark dirty unless caller-owned.
    m_pVertexArray = new unsigned char[static_cast<unsigned int>(m_nVertexCount) * nStride];
    if (!m_bVertexBufferExternal) {
        pRenderer->GenBuffer(&m_dwVertexVbo);
        m_bVertexDirty = true;
    }

    // Allocate the 16-bit index buffer; gen a GL index VBO and mark dirty unless caller-owned.
    m_pIndexArray = new unsigned short[static_cast<unsigned int>(m_nIndexCount)];
    if (!m_bIndexBufferExternal) {
        pRenderer->GenBuffer(&m_dwIndexVbo);
        m_bIndexDirty = true;
    }
}

/** @ghidraAddress 0x295a8 */
C_DRAW_POLYGON_3D *CreatePolygon3dMesh(unsigned int nDrawMode,
                                       unsigned int nVertexCount,
                                       unsigned int nVertexFormat,
                                       unsigned char bVertexBufferExternal,
                                       unsigned int nIndexCount,
                                       unsigned char bIndexBufferExternal) {
    auto *pMesh = new C_DRAW_POLYGON_3D(nDrawMode,
                                        nVertexCount,
                                        nVertexFormat,
                                        bVertexBufferExternal,
                                        nIndexCount,
                                        bIndexBufferExternal);
    pMesh->AllocateBuffers();
    return pMesh;
}

/** @ghidraAddress 0x29638 */
void C_DRAW_POLYGON_3D::SetPos(int nIndex, S_VECTOR3 position) {
    if ((m_nVertexFormat & kVertexHasPosition) == 0) {
        return;
    }
    assert(nIndex >= 0 && nIndex < m_nVertexCount);
    auto *pVertex = static_cast<unsigned char *>(m_pVertexArray) +
                    (m_nPositionOffset + m_nVertexStride * nIndex);
    auto *pPosition = reinterpret_cast<float *>(pVertex);
    pPosition[0] = position.x;
    pPosition[1] = position.y;
    pPosition[2] = position.z;
    m_bVertexDirty = true;
}

/** @ghidraAddress 0x29788 */
void C_DRAW_POLYGON_3D::SetRGBA(int nIndex,
                                unsigned char nRed,
                                unsigned char nGreen,
                                unsigned char nBlue,
                                unsigned char nAlpha) {
    if ((m_nVertexFormat & kVertexHasColor) == 0) {
        return;
    }
    assert(nIndex >= 0 && nIndex < m_nVertexCount);
    m_pColorArray[nIndex] = S_RGBA{nRed, nGreen, nBlue, nAlpha};
    // The binary writes both dirty bytes together as a single halfword of 0x0101.
    m_bVertexDirty = true;
    m_bColorDirty = true;
}

/** @ghidraAddress 0x29810 */
void C_DRAW_POLYGON_3D::SetAlpha(int nIndex, unsigned char nAlpha) {
    if ((m_nVertexFormat & kVertexHasColor) == 0) {
        return;
    }
    assert(nIndex >= 0 && nIndex < m_nVertexCount);
    m_pColorArray[nIndex].nAlpha = nAlpha;
    m_bVertexDirty = true;
    m_bColorDirty = true;
}

/** @ghidraAddress 0x296cc */
void C_DRAW_POLYGON_3D::SetUV(int nIndex, float flU, float flV) {
    if ((m_nVertexFormat & kVertexHasTexcoord) == 0) {
        return;
    }
    assert(nIndex >= 0 && nIndex < m_nVertexCount);
    auto *pVertex =
        static_cast<unsigned char *>(m_pVertexArray) + (m_nUvOffset + m_nVertexStride * nIndex);
    auto *pUv = reinterpret_cast<short *>(pVertex);
    // The U maps directly and the V is flipped, both to signed 16-bit fixed point.
    pUv[0] = static_cast<short>(static_cast<int>(flU * kUvFixedPointScale));
    pUv[1] = static_cast<short>(static_cast<int>((1.0 - static_cast<double>(flV)) *
                                                 static_cast<double>(kUvFixedPointScale)));
    m_bVertexDirty = true;
}

/** @ghidraAddress 0x296c4 */
void C_DRAW_POLYGON_3D::SetUvFromVec(int nIndex, const S_VECTOR2 *pUv) {
    SetUV(nIndex, pUv->x, pUv->y);
}

/** @ghidraAddress 0x29558 */
void C_DRAW_POLYGON_3D::SetTexture(C_TEXTURE *pTexture) {
    if (m_pTexture != nullptr) {
        m_pTexture->Release();
        m_pTexture = nullptr;
    }
    if (pTexture != nullptr) {
        pTexture->AddRef();
        m_pTexture = pTexture;
    }
}

/** @ghidraAddress 0x2959c */
void C_DRAW_POLYGON_3D::SetTexEnvParam(int nIndex, int nValue) {
    m_aTexEnvParams[nIndex] = nValue;
}

/** @ghidraAddress 0x29890 */
void C_DRAW_POLYGON_3D::SetIndex(int nIndex, unsigned short wValue) {
    assert(nIndex >= 0 && nIndex < m_nIndexCount);
    m_pIndexArray[nIndex] = wValue;
    m_bIndexDirty = true;
}

} // namespace ne
