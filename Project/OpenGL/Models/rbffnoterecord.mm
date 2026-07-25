//
//  rbffnoterecord.mm
//  REFLEC BEAT plus
//
//  Methods over the parsed chart note record (RbffNoteRecord). Reconstructed from Ghidra project
//  rb458, program rb458. @ghidraAddress values are relative to the program image base.
//

#include "rbffnoterecord.h"

#include <cstring>

// The chain-segment index marker for an absent (head or tail) link.
namespace {
constexpr short kChainLinkNone = -1;
} // namespace

/** @ghidraAddress 0x12eadc */
void RbffNoteRecord::InitEmptyChain() {
    nChainLink = kChainLinkNone;
    nChainLinkNext = kChainLinkNone;
    std::memset(m_aChainExtra, 0, sizeof(m_aChainExtra));
}

/** @ghidraAddress 0x12eaf0 */
bool RbffNoteRecord::IsChainHead() const {
    return nChainLink == kChainLinkNone;
}
