//
//  note_effect_mgr.mm
//  REFLEC BEAT plus
//
//  The process-wide note manager (NoteEffectMgr). Reconstructed from Ghidra project rb458, program
//  rb458. @ghidraAddress values are relative to the program image base.
//

#include "note_effect_mgr.h"

#include "deviceenvironment.h"

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

/** @ghidraAddress 0x136b9c */
NoteEffectMgr *NoteEffectMgr::shared() {
    if (g_pNoteEffectMgr == nullptr) {
        // The binary allocates the raw 0x168-byte object and runs the constructor.
        g_pNoteEffectMgr = new NoteEffectMgr();
    }
    return g_pNoteEffectMgr;
}
