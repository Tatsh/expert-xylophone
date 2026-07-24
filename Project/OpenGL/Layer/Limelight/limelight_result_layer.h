/**
 * @file
 * The Limelight-theme result-window layer, @c LimelightResultLayer.
 */

#pragma once

#include "playfieldlayerbase.h"

namespace ne {
class C_TEXTURE;
class C_SPRITE_INSTANCING;
} // namespace ne

/**
 * @brief The Limelight-theme result-window layer.
 *
 * A process-wide singleton, built on first access, deriving from @c PlayFieldLayerBase. It draws the
 * Limelight result panel through eight sprite instancers. The class carries no RTTI (it is
 * non-polymorphic), so the name is inferred from its singleton getter rather than confirmed from the
 * runtime metadata. Only the sprite-set fields used by @c InitializePhoneSpriteInstancers are modelled
 * so far; the remainder of the @c 0x170-byte layout is kept as a reserved span to preserve the
 * allocation size. The trailing @c // +0xNN comments document the original 32-bit offsets for
 * reference only.
 */
class LimelightResultLayer : public PlayFieldLayerBase {
public:
    /**
     * @brief The process-wide Limelight result-window layer, created on first use.
     * @return The shared layer.
     * @ghidraAddress 0x123d54
     */
    static LimelightResultLayer *shared();

    /**
     * @brief Lazily builds the eight result-window sprite instancers: loads the two atlases and
     * creates each instancer (registering it in the global scene tree, making it visible, binding
     * the edge slots' textures, and clearing its sprite count).
     *
     * Guarded so the sprites are built only once.
     * @ghidraAddress 0x123db0
     */
    void InitializePhoneSpriteInstancers();

    // The number of sprite-instancer slots the layer builds.
    static constexpr int kSpriteSlotCount = 8;

private:
    // +0x08..+0x0f: descriptor state preceding the textures, still being worked out.
    unsigned char m_aReserved08[8] = {};      // +0x08
    ne::C_TEXTURE *m_pBackgroundTexture = {}; // +0x10: the selection-background atlas.
    ne::C_TEXTURE *m_pPartsTexture = {};      // +0x18: the result-parts atlas.
    ne::C_TEXTURE *m_pOverlayTexture = {};    // +0x20: the overlay atlas (left unset).
    ne::C_SPRITE_INSTANCING *m_apSprites[kSpriteSlotCount] =
        {};             // +0x28: the per-slot sprite batches.
    bool m_bBuilt = {}; // +0x68: set once the sprites are built.
    // +0x69..+0x6b is alignment padding before the default alpha.
    // unsigned char m_aPad69[3]; // +0x69 (alignment padding, compiler-inserted)
    int m_nDefaultAlpha = {}; // +0x6c: default alpha (255), cleared to 0 when the set is built.
    float m_flBaseScale = {}; // +0x70: a base scale the builder seeds (0.7).
    // +0x74..+0x16f: the remaining layer state, still being worked out, kept as a reserved span to
    // preserve the allocation size.
    unsigned char m_aReserved74[0xfc] = {}; // +0x74
};

// code: language=C++
// kate: hl C++;
// vim: set ft=cpp :
