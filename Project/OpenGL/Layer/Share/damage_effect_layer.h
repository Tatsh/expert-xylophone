/**
 * @file
 * @brief The bounds-damage effect layer, @c DamageEffectLayer.
 */

#pragma once

#include "playfieldlayerbase.h"

struct S_VECTOR2;

namespace ne {
class C_TEXTURE;
class C_SPRITE_INSTANCING_2D;
} // namespace ne

/**
 * @brief The play-field damage/bounds effect layer: a pool of per-hit effect records plus the
 * per-lane display values and the user's effect-size setting.
 *
 * A process-wide singleton, built on first access, deriving from @c PlayFieldLayerBase. The class
 * carries no RTTI, so the name is inferred from its @c GetDamageEffectLayer / @c SetDamageEffect*
 * accessors. The trailing @c // +0xNN comments document the original offsets for reference only.
 *
 * Reconstructed type @c DamageEffectLayer: engine effect layer, 0x2b8 bytes.
 */
class DamageEffectLayer : public PlayFieldLayerBase {
public:
    /** @brief The number of pooled effect records. */
    static constexpr int kEffectRecordCount = 32;
    /** @brief The number of player lanes. */
    static constexpr int kLaneCount = 2;

    /**
     * @brief The process-wide damage-effect layer, created on first use.
     * @return The shared layer.
     * @ghidraAddress 0x173f7c
     */
    static DamageEffectLayer *shared();

    /**
     * @brief Builds the effect sprite batch and binds the style's atlas on first use.
     *
     * Reads the user's bounds-effect style, loads the matching atlas (default / limelight /
     * colette), creates the world sprite batch sized to the layer's capacity, attaches it under the
     * background layer, makes it visible, and flags additive blend. Guarded so it runs only once.
     * @ghidraAddress 0x173fcc
     */
    void InitializeSprites();

    /**
     * @brief Spawns a bounds-damage effect for a player colour at a screen position.
     *
     * Claims the first inactive pooled record and fills its colour, position, and reset timer. A
     * full pool drops the effect.
     * @param nColor The player colour (0 or 1).
     * @param flPosX The effect's screen x.
     * @param flPosY The effect's screen y.
     * @ghidraAddress 0x174190
     */
    void CreateBoundsDamage(int nColor, float flPosX, float flPosY);

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

    /**
     * @brief Advances and redraws every live damage effect for the frame.
     *
     * Resets the sprite count, then for each pooled record advances its animation timer; an effect
     * past its lifetime is deactivated, otherwise its current animation frame's UV is selected (by
     * colour and frame) and its sprite emitted at the record's position. Finally commits the sprite
     * count to the instancer.
     * @param flDelta The frame's elapsed time, in frames.
     * @ghidraAddress 0x174240
     */
    void Process(float flDelta);

private:
    /**
     * @brief Emits one bounds-damage sprite instance into the batch.
     *
     * Writes the next sprite slot with a fixed anchor and quad size, the animation-frame UV, the
     * layer's effect scale, and opaque white modulated by the lane's alpha. On the Colette theme
     * the position is nudged vertically; a negative y mirrors the sprite a half-turn and uses the
     * second lane's alpha. Advances the sprite count.
     * @param nColor The player colour (0 or 1), also selecting the lane alpha.
     * @param pUv The animation-frame UV origin.
     * @param pPosition The instance position; a negative y mirrors the sprite.
     * @ghidraAddress 0x174538
     */
    void EmitSprite(int nColor, const S_VECTOR2 *pUv, const S_VECTOR2 *pPosition);

    /**
     * @brief Constructs the layer: chains the base constructor, clears the sprite/texture header
     * and the pooled effect records, and seeds the two lane values and the effect size to one.
     * @ghidraAddress 0x173f10
     */
    DamageEffectLayer();

    // One pooled per-hit effect record (20 bytes): an active flag, colour, position, and timer.
    struct EffectRecord {
        bool bActive = {}; // +0x00: whether the record holds a live effect.
        // unsigned char aReserved01[3] = {}; // +0x01
        int nColor = {};    // +0x04: the effect's player colour.
        float flPosX = {};  // +0x08: the effect's screen x.
        float flPosY = {};  // +0x0c: the effect's screen y.
        float flTimer = {}; // +0x10: the effect's animation timer, in frames.
    };

    ne::C_TEXTURE *m_pTexture = {};             // +0x08: the bound effect atlas.
    ne::C_SPRITE_INSTANCING_2D *m_pSprite = {}; // +0x10: the effect sprite instancer.
    int m_nSpriteCount = {};                    // +0x18: the batch's live sprite count.
    int m_nCapacity = {};                       // +0x1c: the sprite-batch capacity.
    bool m_bLoaded = {};                        // +0x20: set once the sprite batch is built.
    // unsigned char m_aReserved21[3] = {};              // +0x21
    EffectRecord m_aEffects[kEffectRecordCount] = {}; // +0x24: the pooled effect records.
    float m_aLaneValue[kLaneCount] = {};              // +0x2a4: the per-lane display values (1).
    float m_flEffectSize = {};                        // +0x2ac: the user's effect size (1).
    int m_nStyle = {};                                // +0x2b0: the bounds-effect style (0/1/2).
    // unsigned char m_aReserved2b4[4] = {};             // +0x2b4: trailing state to 0x2b8.
};
