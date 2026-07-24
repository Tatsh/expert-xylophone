#include "neDrawPolygon2D.h"

#include <cassert>

#include "neGLES.h"
#import "s_vector2.h"

namespace ne {

namespace {

// The sentinel stored in an unset per-vertex attribute offset.
constexpr int kUnsetOffset = -1;

// The default texture-sampler parameters (min filter, mag filter, s wrap, t wrap) the constructor
// seeds (@ghidraAddress 0x2eecf0).
constexpr int kDefaultTexParams[] = {0, 0, 7, 7};

} // namespace

/** @ghidraAddress 0x27374 */
C_DRAW_POLYGON_2D::C_DRAW_POLYGON_2D(unsigned int nDrawMode,
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
    m_nColorOffset = kUnsetOffset;
    m_nTexcoordOffset = kUnsetOffset;
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
    m_flRotationZ = 0.0f;
    m_flScale = 1.0f;
    m_pBoneTranslate = nullptr;
    m_pBoneRotation = nullptr;
    m_pBoneScale = nullptr;
    m_nBlendMode = 0;
    m_aTexParams[0] = kDefaultTexParams[0];
    m_aTexParams[1] = kDefaultTexParams[1];
    m_aTexParams[2] = kDefaultTexParams[2];
    m_aTexParams[3] = kDefaultTexParams[3];
}

/** @ghidraAddress 0x27568 */
void C_DRAW_POLYGON_2D::AllocateBuffers() {
    neGLESRenderer *pRenderer = GetGlRenderer();
    unsigned int nStride = 0;
    m_nVertexStride = 0;

    // Build the interleaved vertex stride and per-attribute byte offsets from the format bits.
    if ((m_nVertexFormat & kVertexHasPosition) != 0) {
        nStride = 8;
        m_nVertexStride = 8;
        m_nPositionOffset = 0;
    }
    if ((m_nVertexFormat & kVertexHasTexcoord) != 0) {
        m_nTexcoordOffset = static_cast<int>(nStride);
        nStride |= 4;
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

/** @ghidraAddress 0x28290 */
C_DRAW_POLYGON_2D *CreatePolygon2dMesh(unsigned int nDrawMode,
                                       unsigned int nVertexCount,
                                       unsigned int nVertexFormat,
                                       unsigned char bVertexBufferExternal,
                                       unsigned int nIndexCount,
                                       unsigned char bIndexBufferExternal) {
    auto *pMesh = new C_DRAW_POLYGON_2D(nDrawMode,
                                        nVertexCount,
                                        nVertexFormat,
                                        bVertexBufferExternal,
                                        nIndexCount,
                                        bIndexBufferExternal);
    pMesh->AllocateBuffers();
    return pMesh;
}

/** @ghidraAddress 0x28328 */
void C_DRAW_POLYGON_2D::SetPos(int nIndex, S_VECTOR2 position) {
    if ((m_nVertexFormat & kVertexHasPosition) == 0) {
        return;
    }
    assert(nIndex >= 0 && nIndex < m_nVertexCount);
    auto *pVertex = static_cast<unsigned char *>(m_pVertexArray) +
                    (m_nPositionOffset + m_nVertexStride * nIndex);
    auto *pPosition = reinterpret_cast<float *>(pVertex);
    pPosition[0] = position.x;
    pPosition[1] = position.y;
    m_bVertexDirty = true;
}

/** @ghidraAddress 0x28320 */
void C_DRAW_POLYGON_2D::SetPosFromVec(int nIndex, const S_VECTOR2 *pPosition) {
    SetPos(nIndex, *pPosition);
}

/** @ghidraAddress 0x28470 */
void C_DRAW_POLYGON_2D::SetRGBA(int nIndex,
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

/** @ghidraAddress 0x28578 */
void C_DRAW_POLYGON_2D::SetIndex(int nIndex, unsigned short wValue) {
    assert(nIndex >= 0 && nIndex < m_nIndexCount);
    m_pIndexArray[nIndex] = wValue;
    m_bIndexDirty = true;
}

} // namespace ne
