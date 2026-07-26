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
NoteChainLink::NoteChainLink() {
    // The binary sets both segment indices to the unset marker, then clears the following eight
    // bytes (the partner, the marker, and the reserved tail) as one store.
    m_nPrev = kNone;
    m_nNext = kNone;
    m_nPartner = 0;
    m_nMarker = 0;
    std::memset(m_aReserved08, 0, sizeof(m_aReserved08));
}
