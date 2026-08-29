/**
 * @file
 * The engine's piecewise-linear animation curve, @c FloatCurve, and its sampling helpers.
 */

#pragma once

/**
 * A float animation curve: a keyframe count and a flat array of `{x,y}` pairs sorted
 *        ascending by x.
 */
struct FloatCurve {
    int nCount = {};          /*!< The number of keyframe pairs. +0x00 */
    const float *pPairs = {}; /*!< The flat `{x,y}` keyframe pairs. +0x08 */
};

/**
 * Samples a piecewise-linear curve of `{x,y}` keyframe pairs at @p flQueryX.
 *
 * The result is clamped to the first or last keyframe's y value when @p flQueryX falls outside the
 * keyframe x range.
 * @param pPairs The flat `{x,y}` keyframe pairs, sorted ascending by x.
 * @param nCount The number of keyframe pairs.
 * @param flQueryX The x position to sample.
 * @return The interpolated y value.
 * @ghidraAddress 0x55638
 */
float CalculateCurveInterpolation(const float *pPairs, int nCount, float flQueryX);
/**
 * Samples a @c FloatCurve at @p flQueryX.
 * @param pCurve The curve to sample.
 * @param flQueryX The x position to sample.
 * @return The interpolated y value.
 * @ghidraAddress 0x556d0
 */
float CalculateCurveValue(const FloatCurve *pCurve, float flQueryX);
