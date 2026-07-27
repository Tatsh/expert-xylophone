/**
 * @file
 * The bounds-damage effect layer, @c DamageEffectLayer.
 */

#pragma once

#include "playfieldlayerbase.h"

namespace ne {
class C_TEXTURE;
class C_SPRITE_INSTANCING;
} // namespace ne

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
     * @brief The process-wide damage-effect layer, created on first use.
     * @return The shared layer.
     * @ghidraAddress 0x173f7c
     */
    static DamageEffectLayer *shared();

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

    /**
     * @brief Refreshes the theme, reads the user's bounds-effect style, and binds the matching
     * effect atlas (default / limelight / colette) to the sprite instancer.
     * @ghidraAddress 0x1740cc
     */
    void SetBoundsDamageStyle();

private:
    /**
     * @brief Constructs the layer: chains the base constructor, clears the sprite/texture header and
     * the pooled effect records, and seeds the two lane values and the effect size to one.
     * @ghidraAddress 0x173f10
     */
    DamageEffectLayer();

    // One pooled per-hit effect record (20 bytes): an active flag and its animation state.
    struct EffectRecord {
        bool bActive = {};                   // +0x00: whether the record holds a live effect.
        unsigned char aReserved01[7] = {};   // +0x01
        unsigned char aReserved08[0xc] = {}; // +0x08: the effect's animation state.
    };

    ne::C_TEXTURE *m_pTexture = {};          // +0x08: the bound effect atlas.
    ne::C_SPRITE_INSTANCING *m_pSprite = {}; // +0x10: the effect sprite instancer.
    unsigned char m_aReserved18[0xc] = {};   // +0x18: further header state (a listener node etc.).
    EffectRecord m_aEffects[kEffectRecordCount] = {}; // +0x24: the pooled effect records.
    float m_aLaneValue[kLaneCount] = {};              // +0x2a4: the per-lane display values (1).
    float m_flEffectSize = {};                        // +0x2ac: the user's effect size (1).
    int m_nStyle = {};                                // +0x2b0: the bounds-effect style (0/1/2).
    unsigned char m_aReserved2b4[4] = {};             // +0x2b4: trailing state to 0x2b8.
};

// code: language=C++
// kate: hl C++;
// vim: set ft=cpp :
