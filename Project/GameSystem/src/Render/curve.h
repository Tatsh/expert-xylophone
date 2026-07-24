/**
 * @file
 * The engine's piecewise-linear animation curve, @c FloatCurve, and its sampling helpers.
 */

#pragma once

/**
 * @brief A float animation curve: a keyframe count and a flat array of @c {x,y} pairs sorted
 *        ascending by x.
 */
struct FloatCurve {
    int nCount = {};          // +0x00: the number of keyframe pairs.
    const float *pPairs = {}; // +0x08: the flat {x, y} keyframe pairs.
};

/**
 * @brief Samples a piecewise-linear curve of @c {x,y} keyframe pairs at @p flQueryX.
 *
 * The result is clamped to the first or last keyframe's y value when @p flQueryX falls outside the
 * keyframe x range.
 * @param pPairs The flat @c {x,y} keyframe pairs, sorted ascending by x.
 * @param nCount The number of keyframe pairs.
 * @param flQueryX The x position to sample.
 * @return The interpolated y value.
 * @ghidraAddress 0x55638
 */
float CalculateCurveInterpolation(const float *pPairs, int nCount, float flQueryX);
/**
 * @brief Samples a @c FloatCurve at @p flQueryX.
 * @param pCurve The curve to sample.
 * @param flQueryX The x position to sample.
 * @return The interpolated y value.
 * @ghidraAddress 0x556d0
 */
float CalculateCurveValue(const FloatCurve *pCurve, float flQueryX);

// code: language=C++
// kate: hl C++;
// vim: set ft=cpp :
