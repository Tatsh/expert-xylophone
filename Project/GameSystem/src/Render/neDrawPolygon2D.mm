#include "neDrawPolygon2D.h"

#include <cassert>

#import "neEngineBridge.h"

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
                                     unsigned int nVertexFormat,
                                     unsigned int nVertexCount,
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
