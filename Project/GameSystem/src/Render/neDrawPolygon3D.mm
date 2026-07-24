#include "neDrawPolygon3D.h"

#include <cassert>

namespace ne {

/** @ghidraAddress 0x29890 */
void C_DRAW_POLYGON_3D::SetIndex(int nIndex, unsigned short wValue) {
    assert(nIndex >= 0 && nIndex < m_nIndexCount);
    m_pIndexArray[nIndex] = wValue;
    m_bIndexDirty = true;
}

} // namespace ne
