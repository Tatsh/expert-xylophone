#include <cstring>

#include "tutorial_guide_layer.h"

namespace {

// The number of floats in one keyframe group: range start, range end, and value.
constexpr int kGroupStride = 3;

} // namespace

/** @ghidraAddress 0x10cd34 */
unsigned int
TutorialGuideLayer::KeyframeStepTableLookup(float flTime, const float *pTable, int nEntries) {

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
