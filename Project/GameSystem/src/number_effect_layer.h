#pragma once

//
//  number_effect_layer.h
//  REFLEC BEAT plus
//
//  Reconstructed from Ghidra project rb458, program rb458. @ghidraAddress values are relative to
//  the program image base. The layer is not fully modelled yet, so only the fade channel and active
//  flag (and reserved spans positioning them at their real offsets) are named.
//

#include "linear_tween.h"

/**
 * @brief The number-effect layer, as far as its fade channel and active flag are concerned.
 * @ghidraAddress NumberEffectLayer (engine layer)
 */
class NumberEffectLayer {
public:
    /**
     * @brief Advances the fade channel by @p flDeltaTime and raises the active flag.
     * @ghidraAddress 0x189ef0
     */
    void AdvanceFadeInterp(float flDeltaTime);

private:
    unsigned char m_aReserved00[0x30] = {}; // +0x00
    LinearTween m_fadeChannel;              // +0x30 (five floats, ending at +0x44)
    bool m_bFadeActive = {};                // +0x44 raised once the channel advances a frame
};

// code: language=C++
// kate: hl C++;
// vim: set ft=cpp :
