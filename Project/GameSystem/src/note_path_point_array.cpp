//
//  note_path_point_array.cpp
//  REFLEC BEAT plus
//
//  Reconstructed from Ghidra project rb458, program rb458. The growable path-point array the
//  MusicSheet chart parsers append to. Pure C++, so a .cpp at the GameSystem source root.
//

#include "note_path_point_array.h"

#include <new>

/** @ghidraAddress 0x12f5b0 */
NotePathPoint *NotePathPointArray::AllocateEntries(int nCount) {
    // Reserve nCount entries and zero every one. The binary ignores the array argument and returns
    // the fresh buffer for the caller to store.
    auto *pEntries = new NotePathPoint[nCount];
    for (int i = 0; i < nCount; ++i) {
        pEntries[i].m_nX = 0;
        pEntries[i].m_nY = 0;
    }
    return pEntries;
}

/** @ghidraAddress 0x12f648 */
void NotePathPointArray::Append(const NotePathPoint &point) {
    if (m_nCount == m_nCapacity) {
        // Full: grow the buffer, copy the existing entries across, and release the old one.
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
