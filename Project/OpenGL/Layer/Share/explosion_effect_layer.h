/**
 * @file
 * The note-burst explosion effect layer, @c ExplosionEffectLayer.
 */

#pragma once

#include "playfieldlayerbase.h"

namespace ne {
class C_SPRITE_INSTANCING;
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

private:
    // Constructs the layer: clears the sprite set and every effect slot.
    // @ghidraAddress 0x176e18
    ExplosionEffectLayer();

    /** @brief One live burst: its activity, animation timer, judgement, and position. */
    struct EffectEntry {
        bool bActive = {};              // +0x00: whether the slot holds a live burst.
        unsigned char m_aPad01[3] = {}; // +0x01
        int nTimer = {};                // +0x04: the burst animation timer.
        int nJudge = {};                // +0x08: the judgement type that spawned the burst.
        float flPosX = {};              // +0x0c: the burst X position.
        float flPosY = {};              // +0x10: the burst Y position.
    };

    // +0x08: the two world-space sprite instancers, one per bank.
    ne::C_SPRITE_INSTANCING *m_apSprites[kBankCount] = {}; // +0x08
    unsigned char m_aReserved18[8] = {};                   // +0x18
    int m_aSpriteCapacity[kBankCount] = {};                // +0x20: each instancer's capacity.
    bool m_bBuilt = {};                                    // +0x28: set once the sprites are built.
    unsigned char m_aReserved29[11] = {};                  // +0x29
    EffectEntry m_aBanks[kBankCount][kSlotsPerBank] = {};  // +0x34: the two effect-slot banks.
    unsigned char m_aReserved32c[12] = {};                 // +0x32c: trailing layer state.
};

// code: language=Objective-C++
// kate: hl Objective-C++;
// vim: set ft=objcpp :
