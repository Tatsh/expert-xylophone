//
//  note_effect_mgr.mm
//  REFLEC BEAT plus
//
//  The process-wide note manager (NoteEffectMgr). Reconstructed from Ghidra project rb458, program
//  rb458. @ghidraAddress values are relative to the program image base.
//

#include "note_effect_mgr.h"

#include "deviceenvironment.h"
#include "note_model.h"

// The process-wide note manager, created lazily by shared().
static NoteEffectMgr *g_pNoteEffectMgr = nullptr; // @ghidraAddress 0x3de050

/** @ghidraAddress 0x136bec */
NoteEffectMgr::NoteEffectMgr() {
    // The header, combo, tier, and render sub-table are zeroed by the member initialisers; the
    // binary clears them explicitly. Only the active-slot indices start at the -1 empty marker.
    for (long &nSlot : m_aActiveSlot) {
        nSlot = kActiveSlotNone;
    }
    m_bFontVariant = IsPad();
}

/** @ghidraAddress 0x1373a0 */
void NoteEffectMgr::ClearNotePositionCache() {
    for (RenderEntry &entry : m_aRenderTable) {
        entry.nCachedPosition = -1;
    }
}

/** @ghidraAddress 0x137018 */
NoteModel *NoteEffectMgr::FindNoteByIndex(int nIndex) {
    // A valid in-range index maps straight to its pooled object (when the pool covers it).
    if (nIndex >= 0 && nIndex < m_nNoteCount) {
        if (m_nPoolCapacity <= nIndex) {
            return nullptr;
        }
        return m_ppNotePool[nIndex];
    }
    // Otherwise scan the pool for an object whose note index matches.
    for (int i = 0; i < m_nPoolCapacity; ++i) {
        NoteModel *pNote = m_ppNotePool[i];
        if (pNote != nullptr && pNote->GetNoteIndex() == nIndex) {
            return pNote;
        }
    }
    return nullptr;
}

/** @ghidraAddress 0x1371a4 */
void NoteEffectMgr::EnsureNoteObjectCapacity(int nCount) {
    if (m_nPoolCapacity >= nCount) {
        return;
    }
    // Grow both arrays; the active list is reallocated but left for InitNoteObjects to populate.
    auto **ppNewPool = new NoteModel *[nCount];
    auto **ppNewActive = new NoteModel *[nCount];
    // Carry the existing pooled objects across, then construct a fresh note for each added slot.
    int i = 0;
    for (; i < m_nPoolCapacity; ++i) {
        ppNewPool[i] = m_ppNotePool[i];
    }
    for (; i < nCount; ++i) {
        ppNewPool[i] = new NoteModel(this);
    }
    delete[] m_ppNotePool;
    delete[] m_ppActiveList;
    m_ppNotePool = ppNewPool;
    m_nPoolCapacity = nCount;
    m_ppActiveList = ppNewActive;
}

/** @ghidraAddress 0x136b9c */
NoteEffectMgr *NoteEffectMgr::shared() {
    if (g_pNoteEffectMgr == nullptr) {
        // The binary allocates the raw 0x168-byte object and runs the constructor.
        g_pNoteEffectMgr = new NoteEffectMgr();
    }
    return g_pNoteEffectMgr;
}
