#include "curve.h"

/** @ghidraAddress 0x55638 */
float CalculateCurveInterpolation(const float *pPairs, int nCount, float flQueryX) {
    // Walk the {x, y} keyframe pairs and linearly interpolate y at flQueryX, clamping to the first
    // or last keyframe's y when the query falls outside the keyframe x range.
    const float flFirstX = pPairs[0];
    if (flQueryX < flFirstX) {
        return pPairs[1];
    }
    const int nLast = nCount - 1;
    if (flQueryX <= pPairs[nLast * 2] && nCount > 1) {
        float flSegmentStartX = flFirstX;
        for (int nSegment = 0; nSegment < nLast; ++nSegment) {
            const float flSegmentEndX = pPairs[(nSegment + 1) * 2];
            if (flSegmentStartX <= flQueryX && flQueryX <= flSegmentEndX) {
                const float flStartY = pPairs[nSegment * 2 + 1];
                const float flEndY = pPairs[(nSegment + 1) * 2 + 1];
                return flStartY + (flQueryX - flSegmentStartX) * (flEndY - flStartY) /
                                      (flSegmentEndX - flSegmentStartX);
            }
            flSegmentStartX = flSegmentEndX;
        }
    }
    return pPairs[nLast * 2 + 1];
}

/** @ghidraAddress 0x556d0 */
float CalculateCurveValue(const FloatCurve *pCurve, float flQueryX) {
    return CalculateCurveInterpolation(pCurve->pPairs, pCurve->nCount, flQueryX);
}
