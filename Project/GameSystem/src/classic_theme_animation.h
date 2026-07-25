#pragma once

//
//  classic_theme_animation.h
//  REFLEC BEAT plus
//
//  Reconstructed from Ghidra project rb458, program rb458. @ghidraAddress values are relative to
//  the program image base. The layer is not fully modelled yet, so only the eased-progress channel
//  (and reserved spans positioning it at its real offset) is named.
//

#include "linear_tween.h"

/**
 * @brief The classic-theme animation state, as far as its eased-progress channel is concerned.
 * @ghidraAddress ClassicThemeAnimation (engine layer)
 */
class ClassicThemeAnimation {
public:
    /**
     * @brief Advances the eased-progress channel by @p flDelta.
     * @ghidraAddress 0x10a5fc
     */
    void AdvanceEasedProgress(float flDelta);

private:
    unsigned char m_aReserved00[0x44] = {}; // +0x00
    LinearTween m_easeChannel;              // +0x44
};

// code: language=C++
// kate: hl C++;
// vim: set ft=cpp :
