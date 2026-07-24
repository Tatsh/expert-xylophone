/**
 * @file
 * The keyframe step-table lookup helper.
 */

#pragma once

// The sentinel returned by KeyframeStepTableLookup when the query time is out of range: the raw
// 32-bit value 10, which callers that read the result as a float see as the bit pattern 1.4e-44.
constexpr unsigned int kKeyframeStepNoMatch = 10;

/**
 * @brief Looks up a keyframe step table by time, returning the value of the range that contains it.
 *
 * The table is a flat array of three-float groups @c {rangeStart, rangeEnd, value}, where each
 * group's end equals the next group's start. The value is returned as its raw 32-bit representation
 * (the binary returns it in an integer register); callers reinterpret it as needed.
 * @param flTime The query time.
 * @param pUnused An unused parameter the binary keeps.
 * @param pTable The keyframe table, three floats per group.
 * @param nEntries The number of groups.
 * @return The matching group's raw 32-bit value, or @c kKeyframeStepNoMatch when out of range.
 * @ghidraAddress 0x10cd34
 */
unsigned int
KeyframeStepTableLookup(float flTime, const void *pUnused, const float *pTable, int nEntries);

// code: language=C++
// kate: hl C++;
// vim: set ft=cpp :
