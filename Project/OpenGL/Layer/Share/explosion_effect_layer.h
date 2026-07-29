/**
 * @file
 * The note-burst explosion effect layer, @c ExplosionEffectLayer.
 */

#pragma once

#include "playfieldlayerbase.h"
#include "s_vector2.h"

namespace ne {
class C_SPRITE_INSTANCING_2D;
} // namespace ne

/**
 * @brief The note-burst explosion effect layer.
 *
 * A process-wide singleton, built on first access, deriving from @c PlayFieldLayerBase. It keeps two
 * per-player-colour banks of nineteen effect slots, each drawn through one of two world-space sprite
 * instancers, and spawns a burst in the first free slot when a note is scored. The trailing
 * @c // +0xNN comments document the original 32-bit offsets for reference only.
 */
class ExplosionEffectLayer : public PlayFieldLayerBase {
public:
    // The number of player-colour banks and the effect slots per bank.
    static constexpr int kBankCount = 2;
    static constexpr int kSlotsPerBank = 19;
    // The capacity each bank's sprite instancer is created with.
    static constexpr int kSpriteCapacity = 0x26;

    /**
     * @brief The process-wide explosion effect layer, created on first use.
     * @ghidraAddress 0x176ed0
     */
    static ExplosionEffectLayer *shared();

    /**
     * @brief Lazily builds the two effect sprite instancers and attaches them to the background
     * scene node.
     * @ghidraAddress 0x176f20
     */
    void InitializeSprites();

    /**
     * @brief Spawns a burst in the first free slot of the given colour bank.
     * @param nColor The player-colour bank (0 or 1).
     * @param nJudge The judgement type that triggered the burst (0 through 2).
     * @param flPosX The burst X position.
     * @param flPosY The burst Y position.
     * @ghidraAddress 0x177138
     */
    void CreateExplosionEffect(unsigned int nColor, int nJudge, float flPosX, float flPosY);

    /**
     * @brief Advances every live burst for one frame and re-emits its sprite.
     *
     * Clears both banks' live sprite counts, then for each colour bank whose effect type is enabled:
     * picks the per-bank play-colour alpha and mirror rotation from whether the bank matches the
     * game system's current play colour, and for each active slot advances its animation timer by the
     * frame delta, deactivating it once past the burst lifetime, otherwise (while the bank's alpha is
     * non-zero) emitting the slot's sprite at the animation frame's UV cell from the burst UV table
     * (indexed by the slot's judgement and its clamped animation phase). Finally publishes each bank's
     * live sprite count to its instancer.
     * @param flDeltaTime The frame delta.
     * @ghidraAddress 0x177260
     */
    void Process(float flDeltaTime);

    /**
     * @brief Sets a colour bank's explosion texture type, rebinding its instancer texture and
     * clearing every effect slot when the type changes.
     * @param nColor The player-colour bank (0 or 1).
     * @param nType The explosion texture type (0 through 18).
     * @ghidraAddress 0x176fb8
     */
    void SetEffectType(unsigned int nColor, int nType);

    /**
     * @brief Sets the burst size applied to every effect sprite's scale.
     * @param flSize The burst size, from the user setting.
     * @ghidraAddress 0x177130
     */
    void SetEffectSize(float flSize);

    /**
     * @brief Stores a lane's play-colour alpha, scaling the unit-interval value to a byte.
     * @param flAlpha The alpha, in the range zero to one.
     * @param nLane The lane (0 selects the first bank's byte, non-zero the second).
     * @ghidraAddress 0x17710c
     */
    void SetPlayColorAlpha(float flAlpha, int nLane);

    // The number of explosion texture types.
    static constexpr int kEffectTypeCount = 19;

private:
    /**
     * @brief Appends one explosion-effect sprite to a lane's instancer.
     *
     * Writes the next free slot of the lane's sprite batch with a fixed 84-point anchor and
     * 168-point size, the caller's position and animation-frame UV origin, a fixed UV cell size, the
     * layer's current burst scale on both axes, the caller's rotation, and opaque white modulated by
     * @p nAlpha; then advances the lane's live sprite count. A no-op when the batch is full.
     * @param nLane The lane (bank) to append to.
     * @param pPosition The sprite's world position.
     * @param pUvOrigin The animation-frame UV origin.
     * @param nAlpha The sprite alpha.
     * @param flRotation The sprite rotation, in radians.
     * @ghidraAddress 0x1776ac
     */
    void SetExplosionEffectSprite(unsigned int nLane,
                                  const S_VECTOR2 *pPosition,
                                  const S_VECTOR2 *pUvOrigin,
                                  int nAlpha,
                                  float flRotation);

    // Constructs the layer: clears the sprite set and every effect slot.
    // @ghidraAddress 0x176e18
    ExplosionEffectLayer();

    /** @brief One live burst: its activity, animation timer, judgement, and position. */
    struct EffectEntry {
        bool bActive = {};              // +0x00: whether the slot holds a live burst.
        unsigned char m_aPad01[3] = {}; // +0x01
        float flTimer = {};             // +0x04: the burst animation timer, advanced each frame.
        int nJudge = {};                // +0x08: the judgement type that spawned the burst.
        S_VECTOR2 position = {};        // +0x0c: the burst position.
    };

    // +0x08: the two world-space sprite instancers, one per bank.
    ne::C_SPRITE_INSTANCING_2D *m_apSprites[kBankCount] = {}; // +0x08
    int m_aSpriteCount[kBankCount] = {};    // +0x18: each bank's live sprite count.
    int m_aSpriteCapacity[kBankCount] = {}; // +0x20: each instancer's capacity.
    bool m_bBuilt = {};                     // +0x28: set once the sprites are built.
    unsigned char m_aPad29[3] = {};         // +0x29
    int m_aEffectType[kBankCount] = {};     // +0x2c: each bank's current explosion texture type.
    EffectEntry m_aBanks[kBankCount][kSlotsPerBank] = {}; // +0x34: the two effect-slot banks.
    unsigned char m_aPlayColorAlpha[kBankCount] = {}; // +0x32c: per-lane play-colour alpha bytes.
    // +0x32e..+0x32f is alignment padding before the effect size.
    unsigned char m_aPad32e[2] = {};      // +0x32e
    float m_flEffectSize = {};            // +0x330: the burst size from the user setting.
    unsigned char m_aReserved334[4] = {}; // +0x334
};

// code: language=Objective-C++
// kate: hl Objective-C++;
// vim: set ft=objcpp :
