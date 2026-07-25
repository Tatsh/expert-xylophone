/**
 * @file
 * The bounds-damage effect layer, @c DamageEffectLayer.
 */

#pragma once

#include "playfieldlayerbase.h"

/**
 * @brief The play-field damage/bounds effect layer: a pool of per-hit effect records plus the
 * per-lane display values and the user's effect-size setting.
 *
 * A process-wide singleton, built on first access, deriving from @c PlayFieldLayerBase. The class
 * carries no RTTI, so the name is inferred from its @c GetDamageEffectLayer / @c SetDamageEffect*
 * accessors. The trailing @c // +0xNN comments document the original offsets for reference only.
 * @ghidraAddress DamageEffectLayer (engine effect layer, 0x2b8 bytes)
 */
class DamageEffectLayer : public PlayFieldLayerBase {
public:
    // The number of pooled effect records and the number of player lanes.
    static constexpr int kEffectRecordCount = 32;
    static constexpr int kLaneCount = 2;

    /**
     * @brief Sets one lane's damage-effect display value.
     * @param nLane The player lane (0 or 1).
     * @param flValue The display value.
     * @ghidraAddress 0x174224
     */
    void SetLaneValue(int nLane, float flValue);

    /**
     * @brief Sets the effect size from the user's damage-effect-size setting.
     * @param flSize The effect size.
     * @ghidraAddress 0x174238
     */
    void SetEffectSize(float flSize);

private:
    // One pooled per-hit effect record (20 bytes): an active flag and its animation state.
    struct EffectRecord {
        bool bActive = {};                   // +0x00: whether the record holds a live effect.
        unsigned char aReserved01[7] = {};   // +0x01
        unsigned char aReserved08[0xc] = {}; // +0x08: the effect's animation state.
    };

    unsigned char m_aReserved08[0x1c] = {};           // +0x08: header state (a listener node etc.).
    EffectRecord m_aEffects[kEffectRecordCount] = {}; // +0x24: the pooled effect records.
    float m_aLaneValue[kLaneCount] = {};              // +0x2a4: the per-lane display values (1).
    float m_flEffectSize = {};                        // +0x2ac: the user's effect size (1).
    unsigned char m_aReserved2b0[8] = {};             // +0x2b0: trailing state to 0x2b8.
};

// code: language=C++
// kate: hl C++;
// vim: set ft=cpp :
