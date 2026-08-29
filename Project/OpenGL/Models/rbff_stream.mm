#include "rbff_stream.h"

#include <cstring>

namespace {
// The little-endian 'RBFF' magic word.
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
