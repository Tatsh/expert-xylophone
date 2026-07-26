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

    /**
     * @brief Sets the layer brightness, clamped to the range [0, 1].
     * @param flValue The brightness value.
     * @ghidraAddress 0x18a7a8
     */
    void SetBrightness(float flValue);

    /**
     * @brief Resets the two scroll offsets to zero, or to five in the full-just-reflec challenge
     * mode.
     * @ghidraAddress 0x18a988
     */
    void ResetOffsets();

private:
    // The number of scroll-offset words the layer tracks.
    static constexpr int kOffsetCount = 2;

    unsigned char m_aReserved00[0x30] = {}; // +0x00
    LinearTween m_fadeChannel;              // +0x30 (five floats, ending at +0x44)
    bool m_bFadeActive = {};                // +0x44 raised once the channel advances a frame
    unsigned char m_aReserved45[0x1b] = {}; // +0x45
    float m_flBrightness = {};              // +0x60: the layer brightness (0 to 1).
    unsigned char m_aReserved64[0x20] = {}; // +0x64
    // +0x84: the two scroll offsets, each occupying an 8-byte slot (the offset in the low word).
    struct ScrollOffset {
        float flOffset = {};
        unsigned char aReserved04[4] = {};
    } m_aScrollOffset[kOffsetCount] = {};
};

// code: language=C++
// kate: hl C++;
// vim: set ft=cpp :
