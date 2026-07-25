//
//  music_sheet.mm
//  REFLEC BEAT plus
//
//  The note-chart reader/parser (MusicSheet). Reconstructed from Ghidra project rb458, program
//  rb458. @ghidraAddress values are relative to the program image base.
//

#include "music_sheet.h"

#include "rbffnoterecord.h"

/** @ghidraAddress 0x13183c */
RbffNoteRecord *MusicSheet::GetNoteRecordByIndex(int nIndex) {
    if (nIndex < 0 || nIndex >= m_nNoteCount) {
        return nullptr;
    }
    // The pool is a contiguous array of records; kNoteRecordStride equals sizeof(RbffNoteRecord).
    return &m_pNotePool[nIndex];
}
