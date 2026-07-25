#pragma once

//
//  full_combo_effect_layer.h
//  REFLEC BEAT plus
//
//  Reconstructed from Ghidra project rb458, program rb458. @ghidraAddress values are relative to
//  the program image base. The layer is not fully modelled yet, so only the fade/scale channel
//  (and reserved spans positioning it at its real offset) is named.
//

#include "linear_tween.h"

/**
 * @brief The full-combo effect layer, as far as its fade/scale channel is concerned.
 * @ghidraAddress FullComboEffectLayer (engine layer)
 */
class FullComboEffectLayer {
public:
    /**
     * @brief Advances the fade/scale channel by @p flDeltaTime.
     * @ghidraAddress 0x18795c
     */
    void AdvanceFadeInterp(float flDeltaTime);

private:
    unsigned char m_aReserved00[0x6c] = {}; // +0x00
    LinearTween m_fadeChannel;              // +0x6c
};

// code: language=C++
// kate: hl C++;
// vim: set ft=cpp :
