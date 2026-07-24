/**
 * @file
 * The score-digit number layer, @c NumberLayer.
 */

#pragma once

#include "playfieldlayerbase.h"

namespace ne {
class C_TEXTURE;
class C_SPRITE_INSTANCING;
} // namespace ne

/**
 * @brief The score-digit number layer.
 *
 * A process-wide singleton, built on first access, deriving from @c PlayFieldLayerBase. It owns two
 * atlases and two sprite instancers, drawn beneath the shared background layer, that present the
 * score digits. The class carries no RTTI (it is non-polymorphic), so the name is inferred from its
 * singleton getter rather than confirmed from the runtime metadata. The trailing @c // +0xNN comments
 * document the original 32-bit offsets for reference only.
 */
class NumberLayer : public PlayFieldLayerBase {
public:
    /**
     * @brief The process-wide number layer, created on first use.
     * @return The shared layer.
     * @ghidraAddress 0x17dde0
     */
    static NumberLayer *shared();

    /**
     * @brief Lazily builds the number layer's sprites: loads the two atlases and creates the two
     * sprite instancers (attaching each under the background layer's render object, making it
     * visible, binding its atlas, and seeding its sprite count).
     *
     * Guarded so the sprites are built only once.
     * @ghidraAddress 0x17de30
     */
    void InitializeNumberLayer();

    // The number of number-layer sprite instancers the layer builds.
    static constexpr int kSpriteSlotCount = 2;

private:
    /**
     * @brief Constructs the layer, chaining the base constructor and zero-clearing its own state.
     * @ghidraAddress 0x17dd98
     */
    NumberLayer();

    ne::C_TEXTURE *m_pPartsTexture = {};  // +0x08: the gm_parts2 atlas.
    ne::C_TEXTURE *m_pEffectTexture = {}; // +0x10: the ti_parts_eff atlas.
    ne::C_SPRITE_INSTANCING *m_apSprites[kSpriteSlotCount] =
        {};                                     // +0x18: the per-slot sprite batches.
    int m_aSpriteCounts[kSpriteSlotCount] = {}; // +0x28: each slot's initial count.
    bool m_bBuilt = {};                         // +0x30: set once the sprites are built.
    // +0x31..+0x33 is alignment padding before the trailing state.
    unsigned char m_aPad31[3] = {}; // +0x31
    // +0x34..+0x47: further layer state (two ints, a byte flag, and one more int the constructor
    // zero-clears) still being worked out, kept to preserve the 0x48-byte allocation size.
    int m_nReserved34 = {};              // +0x34
    int m_nReserved38 = {};              // +0x38
    bool m_bReserved3c = {};             // +0x3c
    unsigned char m_aPad3d[3] = {};      // +0x3d
    int m_nReserved40 = {};              // +0x40
    unsigned char m_aReserved44[4] = {}; // +0x44
};

// code: language=C++
// kate: hl C++;
// vim: set ft=cpp :
