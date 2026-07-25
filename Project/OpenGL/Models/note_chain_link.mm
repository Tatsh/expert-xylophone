//
//  note_chain_link.mm
//  REFLEC BEAT plus
//
//  The chain-link block embedded in each chart note record. Reconstructed from Ghidra project
//  rb458, program rb458. @ghidraAddress values are relative to the program image base.
//

#include "note_chain_link.h"

#include <cstring>

/** @ghidraAddress 0x12eadc */
void NoteChainLink::InitEmpty() {
    m_nPrev = kNone;
    m_nNext = kNone;
    std::memset(m_aReserved04, 0, sizeof(m_aReserved04));
}
