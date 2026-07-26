/**
 * @file
 * The play-field bounds effect layer, @c BoundsEffectLayer.
 */

#pragma once

#include "playfieldlayerbase.h"

/**
 * @brief The play-field bounds (edge) effect layer.
 *
 * A process-wide singleton, built on first access, deriving from @c PlayFieldLayerBase. The class
 * carries no RTTI, so the name is inferred from its @c GetBoundsEffectLayer / @c SetBoundsEffect*
 * accessors. Only the fields the reconstructed methods touch are modelled; the rest of the 0x310-byte
 * object is reserved. The trailing @c // +0xNN comments document the original offsets for reference.
 * @ghidraAddress BoundsEffectLayer (engine effect layer, 0x310 bytes)
 */
class BoundsEffectLayer : public PlayFieldLayerBase {
public:
    /**
     * @brief Sets the effect size from the user's bounds-effect-size setting.
     * @param flSize The effect size.
     * @ghidraAddress 0x1754c4
     */
    void SetEffectSize(float flSize);

    /**
     * @brief Sets one lane's bounds-light flag byte (the flash-active flag for that lane's edge).
     * @param flValue The flag value, truncated to a byte.
     * @param nLane The lane: 1 selects the first lane's flag, anything else the second.
     * @ghidraAddress 0x1754a8
     */
    void SetLaneLightFlag(float flValue, int nLane);

private:
    unsigned char m_aReserved08[0x2fc] = {}; // +0x08: layer state, still being worked out.
    unsigned char m_bLaneLight0 = {};        // +0x304: the first lane's bounds-light flag.
    unsigned char m_bLaneLight1 = {};        // +0x305: the second lane's bounds-light flag.
    unsigned char m_aReserved306[2] = {};    // +0x306
    float m_flEffectSize = {};               // +0x308: the user's effect size.
    unsigned char m_aReserved30c[4] = {};    // +0x30c: trailing state to the 0x310-byte size.
};

// code: language=C++
// kate: hl C++;
// vim: set ft=cpp :
