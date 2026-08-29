#include "note_chain_link.h"

#include <cstring>

/** @ghidraAddress 0x12eadc */
NoteChainLink::NoteChainLink() {
    m_nPrev = kNone;
    m_nNext = kNone;
    m_nPartner = 0;
    m_nMarker = 0;
    std::memset(m_aReserved08, 0, sizeof(m_aReserved08));
}
