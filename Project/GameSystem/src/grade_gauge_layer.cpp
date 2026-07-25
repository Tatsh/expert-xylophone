//
//  grade_gauge_layer.cpp
//  REFLEC BEAT plus
//
//  Reconstructed from Ghidra project rb458, program rb458. Pure C++.
//

#include "grade_gauge_layer.h"

#include "ScoreTracker.h"

/** @ghidraAddress 0x120a74 */
void GradeGaugeLayer::AdvanceChannel(float flDeltaTime) {
    m_gaugeChannel.Advance(flDeltaTime);
}

/** @ghidraAddress 0x1208c4 */
void GradeGaugeLayer::InitializeGradeValuesFromTracker() {
    for (int nSide = 0; nSide < kSideCount; ++nSide) {
        m_aGradeValues[nSide] =
            ScoreTracker::shared()->GetPlayRecordField10(static_cast<unsigned int>(nSide));
    }
}
