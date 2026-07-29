//
//  rbff_stream.mm
//  REFLEC BEAT plus
//
//  The RBFF chart-stream cursor and header helpers. Reconstructed from Ghidra project rb458,
//  program rb458. @ghidraAddress values are relative to the program image base.
//

#include "rbff_stream.h"

#include <cstring>

namespace {
// The little-endian 'RBFF' magic word ('R' | 'B' << 8 | 'F' << 16 | 'F' << 24).
constexpr unsigned int kRbffMagic = 0x46464252;
} // namespace

/** @ghidraAddress 0x12e918 */
void InitRbffStreamCursor(RbffStreamCursor *pCursor) {
    if (pCursor != nullptr) {
        pCursor->nField0 = 0;
    }
    pCursor->nField4 = 0;
    pCursor->nField8 = 0;
    pCursor->nFieldC = 0;
}

/** @ghidraAddress 0x12e92c */
bool CheckRbffMagic(const void *pData) {
    unsigned int magic;
    std::memcpy(&magic, pData, sizeof(magic));
    return magic == kRbffMagic;
}
