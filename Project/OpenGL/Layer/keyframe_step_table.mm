#include "keyframe_step_table.h"

#include <cstring>

namespace {

// The number of floats in one keyframe group: range start, range end, and value.
constexpr int kGroupStride = 3;

} // namespace

/** @ghidraAddress 0x10cd34 */
unsigned int
KeyframeStepTableLookup(float flTime, const void *pUnused, const float *pTable, int nEntries) {
    (void)pUnused; // The binary keeps this argument but does not use it.

    // Out of range below the first group's start, or above the last group's end, or empty.
    if (pTable[0] > flTime || nEntries < 1 || pTable[nEntries * kGroupStride - 2] < flTime) {
        return kKeyframeStepNoMatch;
    }

    // Walk the groups; return the value of the first whose [start, end] range contains the time.
    const float *pGroup = pTable;
    for (int nGroup = 0; nGroup < nEntries; ++nGroup) {
        const float flStart = pGroup[0];
        const float flEnd = pGroup[1];
        if (flStart <= flTime && flTime <= flEnd) {
            unsigned int nValue = {};
            std::memcpy(&nValue, &pGroup[2], sizeof(nValue));
            return nValue;
        }
        pGroup += kGroupStride;
    }
    return kKeyframeStepNoMatch;
}
