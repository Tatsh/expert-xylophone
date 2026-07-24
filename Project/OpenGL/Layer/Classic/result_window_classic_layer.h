/**
 * @file
 * The Classic-theme result-window layer, @c ResultWindowClassicLayer.
 */

#pragma once

#include "playfieldlayerbase.h"

struct PartsDataRecord;
class Polygon2dTrail;

namespace ne {
class C_TEXTURE;
class C_SPRITE_INSTANCING;
} // namespace ne

/**
 * @brief The Classic-theme result-window layer.
 *
 * Draws the Classic result panel; a process-wide singleton built on first access, deriving from
 * @c PlayFieldLayerBase. The sprite-set state (two textures, eight sprite instancers, four ribbon
 * trails, and the lazy-build guard) is reconstructed; the remaining fields of the @c 0x1c0-byte
 * layout are still being worked out and kept as reserved spans to preserve the allocation size.
 */
class ResultWindowClassicLayer : public PlayFieldLayerBase {
public:
    /**
     * @brief The process-wide Classic result-window layer, created on first use.
     * @return The shared layer.
     * @ghidraAddress 0x1151fc
     */
    static ResultWindowClassicLayer *shared();

    /**
     * @brief Returns a result-window parts descriptor by index for the current device.
     *
     * Selects the pad or phone parts table by the device kind and returns the record at @p nIndex.
     * @param nIndex The parts-record index (0 through 239).
     * @return The parts descriptor.
     * @ghidraAddress 0x114b78
     */
    const PartsDataRecord *getPartsData(int nIndex) const;

    /**
     * @brief Returns a phone-layout parts descriptor by index.
     *
     * Always reads the static phone parts table.
     * @param nIndex The parts-record index (0 through 125).
     * @return The parts descriptor.
     * @ghidraAddress 0x114c10
     */
    const PartsDataRecord *getPartsData_Phone(int nIndex) const;

    /**
     * @brief Lazily builds the layer's sprite set: loads the two textures, creates the eight sprite
     * instancers (registering each in the global scene tree, making it visible, binding the slot's
     * texture, and clearing its sprite count), and initialises the four ribbon trails.
     *
     * Guarded so the set is built only once.
     * @ghidraAddress 0x11524c
     */
    void InitSpriteSetsLazy();

    // The number of sprite-instancer slots the layer builds.
    static constexpr int kSpriteSlotCount = 8;
    // The number of ribbon trails the layer builds (during the first slot's setup).
    static constexpr int kTrailCount = 4;

private:
    ne::C_TEXTURE *m_pBackgroundTexture = {}; // +0x08: the selection-background atlas.
    ne::C_TEXTURE *m_pPartsTexture = {};      // +0x10: the result-parts atlas.
    ne::C_SPRITE_INSTANCING *m_apSprites[kSpriteSlotCount] =
        {};                    // +0x18: the per-slot sprite batches.
    bool m_bSpritesBuilt = {}; // +0x58: set once the set is built.
    // +0x59..+0x5b is alignment padding before the default alpha.
    unsigned char m_aPad59[3] = {};    // +0x59
    unsigned int m_nDefaultAlpha = {}; // +0x5c: the default sprite alpha (255).
    float m_flDefaultScale = {};       // +0x60: the default sprite scale (1.0).
    // +0x64..+0x12f: further layer state (transform vectors and per-cell fields) still being worked
    // out, kept as a reserved span to preserve the allocation size.
    unsigned char m_aReserved64[0xcc] = {};       // +0x64
    Polygon2dTrail *m_apTrails[kTrailCount] = {}; // +0x130: the ribbon trails.
    // +0x150..+0x1bf: the remaining layer state, still being worked out.
    unsigned char m_aReserved150[0x70] = {}; // +0x150
};

// code: language=Objective-C++
// kate: hl Objective-C++;
// vim: set ft=objcpp :
