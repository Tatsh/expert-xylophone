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

private:
    /**
     * @brief Constructs the layer: chains the base constructor, clears the sprite header and count
     * state, and seeds the default scale pair to one.
     * @ghidraAddress 0x176964
     */
    NoteGlowLayer();

    ne::C_TEXTURE *m_pTexture = {};          // +0x08: the effect atlas.
    ne::C_SPRITE_INSTANCING *m_pSprite = {}; // +0x10: the glow sprite instancer.
    unsigned char m_aReserved18[0x1c] = {};  // +0x18: further header/count state.
    float m_aScale[2] = {};                  // +0x34: the default scale pair (one, one).
    unsigned char m_aReserved3c[4] = {};     // +0x3c: trailing state to the 0x40-byte size.
};

// code: language=C++
// kate: hl C++;
// vim: set ft=cpp :
