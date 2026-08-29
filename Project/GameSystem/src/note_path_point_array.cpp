#include "note_path_point_array.h"

#include <new>

/** @ghidraAddress 0x12f5b0 */
NotePathPoint *NotePathPointArray::AllocateEntries(int nCount) {
    auto *pEntries = new NotePathPoint[nCount];
    for (int i = 0; i < nCount; ++i) {
        pEntries[i].x = 0;
        pEntries[i].y = 0;
    }
    return pEntries;
}

/** @ghidraAddress 0x12f648 */
void NotePathPointArray::Append(const NotePathPoint &point) {
    if (m_nCount == m_nCapacity) {
        m_nCapacity += kGrowStep;
        NotePathPoint *pNew = AllocateEntries(m_nCapacity);
        NotePathPoint *pOld = m_pEntries;
        for (int i = 0; i < m_nCount; ++i) {
            pNew[i] = pOld[i];
        }
        delete[] pOld;
        m_pEntries = pNew;
    }
    m_pEntries[m_nCount] = point;
    ++m_nCount;
}
