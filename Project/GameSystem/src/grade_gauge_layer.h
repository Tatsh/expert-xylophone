#pragma once

//
//  grade_gauge_layer.h
//  REFLEC BEAT plus
//
//  Reconstructed from Ghidra project rb458, program rb458. @ghidraAddress values are relative to
//  the program image base. The layer is not fully modelled yet, so only the fields the reconstructed
//  methods touch (and reserved spans positioning them at their real offsets) are named.
//

#include "linear_tween.h"

/**
 * @brief The grade-gauge display layer, as far as its interpolation channel and per-side grade
 * values are concerned.
 * @ghidraAddress GradeGaugeLayer (engine layer)
 */
class GradeGaugeLayer {
public:
    // The number of player sides the grade display tracks.
    static constexpr int kSideCount = 2;

    /**
     * @brief Advances the grade-gauge channel by @p flDeltaTime.
     * @ghidraAddress 0x120a74
     */
    void AdvanceChannel(float flDeltaTime);

    /**
     * @brief Seeds the per-side grade values from the active score tracker's play records.
     * @ghidraAddress 0x1208c4
     */
    void InitializeGradeValuesFromTracker();

private:
    unsigned char m_aReserved00[0x6c] = {}; // +0x00
    LinearTween m_gaugeChannel;             // +0x6c
    // +0x80..+0x87: the cached viewport size, still being worked out.
    unsigned char m_aReserved80[8] = {}; // +0x80
    int m_aGradeValues[kSideCount] = {}; // +0x88: the per-side grade value from the play record.
};

// code: language=C++
// kate: hl C++;
// vim: set ft=cpp :
