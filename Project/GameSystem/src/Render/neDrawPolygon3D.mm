#include "neDrawPolygon3D.h"

#include <cassert>

#import "neEngineBridge.h"

namespace ne {

namespace {

// The scale mapping a normalised [0, 1] UV coordinate to the signed 16-bit fixed-point stored in the
// vertex buffer (@ghidraAddress 0x2eed04 for U, 0x2eed08 for V).
constexpr float kUvFixedPointScale = 32767.0f;

} // namespace

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

/** @ghidraAddress 0x29890 */
void C_DRAW_POLYGON_3D::SetIndex(int nIndex, unsigned short wValue) {
    assert(nIndex >= 0 && nIndex < m_nIndexCount);
    m_pIndexArray[nIndex] = wValue;
    m_bIndexDirty = true;
}

} // namespace ne
