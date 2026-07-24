#include "neDrawPolygon2D.h"

#include <cassert>

#import "neEngineBridge.h"

namespace ne {

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
