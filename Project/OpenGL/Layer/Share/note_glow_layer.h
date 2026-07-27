/**
 * @file
 * The note-glow (combo/aura) effect layer, @c NoteGlowLayer.
 */

#pragma once

#include "playfieldlayerbase.h"

namespace ne {
class C_TEXTURE;
class C_SPRITE_INSTANCING;
} // namespace ne

/**
 * @brief The small note-glow effect layer (the combo/aura glow shown at note-render time).
 *
 * A process-wide singleton, built on first access, deriving from @c PlayFieldLayerBase. The class
 * carries no RTTI, so the name is inferred from its @c GetNoteGlowLayer accessor and render-time use.
 * Only the fields the reconstructed methods touch are modelled; the trailing @c // +0xNN comments
 * document the original offsets for reference only.
 * @ghidraAddress NoteGlowLayer (engine effect layer, 0x40 bytes)
 */
class NoteGlowLayer : public PlayFieldLayerBase {
public:
    /**
     * @brief The process-wide note-glow layer, created on first use.
     * @return The shared layer.
     * @ghidraAddress 0x1769a8
     */
    static NoteGlowLayer *shared();

    /**
     * @brief Refreshes the theme and rebinds the @c gm_parts1 atlas to the sprite instancer.
     *
     * A no-op until the sprite instancer has been built.
     * @ghidraAddress 0x176a84
     */
    void SetTexture();

    /**
     * @brief Builds the glow sprite batch and binds its atlas on first use.
     *
     * Loads the @c gm_parts1 atlas, creates a two-sprite world batch attached under the background
     * layer, makes it visible, and flags additive blend. Guarded so it runs only once.
     * @ghidraAddress 0x1769f8
     */
    void InitializeSprites();

    /**
     * @brief Triggers the glow effect for one player colour.
     *
     * Builds the sprite batch on first use, then activates the colour's effect slot and resets its
     * timer.
     * @param nColor The player colour (0 or 1).
     * @ghidraAddress 0x176ad8
     */
    void CreateEffect(unsigned int nColor);

    // The number of player colours the glow tracks.
    static constexpr int kColorCount = 2;

private:
    /** @brief One per-colour glow effect slot: its active flag and animation timer. */
    struct EffectSlot {
        bool bActive = {};                 // +0x00: whether the colour's glow is animating.
        unsigned char aReserved01[3] = {}; // +0x01
        int nTimer = {};                   // +0x04: the glow's animation timer.
    };

    /**
     * @brief Constructs the layer: chains the base constructor, clears the sprite header and count
     * state, and seeds the default scale pair to one.
     * @ghidraAddress 0x176964
     */
    NoteGlowLayer();

    ne::C_TEXTURE *m_pTexture = {};          // +0x08: the effect atlas.
    ne::C_SPRITE_INSTANCING *m_pSprite = {}; // +0x10: the glow sprite instancer.
    unsigned char m_aReserved18[4] = {};     // +0x18
    int m_nCapacity = {};                    // +0x1c: the sprite-batch capacity.
    bool m_bLoaded = {};                     // +0x20: set once the sprite batch is built.
    unsigned char m_aReserved21[3] = {};     // +0x21
    EffectSlot m_aEffects[kColorCount] = {}; // +0x24: the two per-colour glow slots (stride 8).
    float m_aScale[2] = {};                  // +0x34: the default scale pair (one, one).
    unsigned char m_aReserved3c[4] = {};     // +0x3c: trailing state to the 0x40-byte size.
};

// code: language=C++
// kate: hl C++;
// vim: set ft=cpp :
