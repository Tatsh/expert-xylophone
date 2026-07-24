/**
 * @file
 * The note-charge layer, @c NoteChargeLayer.
 */

#pragma once

#include "playfieldlayerbase.h"

namespace ne {
class C_TEXTURE;
class C_SPRITE_INSTANCING;
} // namespace ne

/**
 * @brief The note-charge layer (the charge-note build-up graphics).
 *
 * A process-wide singleton, built on first access, deriving from @c PlayFieldLayerBase. It owns one
 * atlas and one sprite instancer, drawn beneath the shared background layer, that presents the
 * charge-note graphics, plus a large table of per-charge records. Its instancer capacity is the sum
 * of a per-group capacity table computed by the constructor. The class carries no RTTI (it is
 * non-polymorphic), so the name is inferred from its singleton getter rather than confirmed from the
 * runtime metadata. Only the sprite-batch fields are modelled so far; the record table is kept as a
 * reserved span. The trailing @c // +0xNN comments document the original 32-bit offsets for
 * reference only.
 */
class NoteChargeLayer : public PlayFieldLayerBase {
public:
    /**
     * @brief The process-wide note-charge layer, created on first use.
     * @return The shared layer.
     * @ghidraAddress 0x180bf8
     */
    static NoteChargeLayer *shared();

    /**
     * @brief Lazily builds the note-charge sprite: loads the gm_parts1 atlas and creates the sprite
     * instancer sized to the accumulated capacity (attaching it under the background layer's render
     * object, making it visible, binding the atlas, flagging additive blend, and, except on the
     * tutorial hardware, enabling its two texture-environment parameters).
     *
     * Guarded so the sprite is built only once.
     * @ghidraAddress 0x180c48
     */
    void LoadNoteChargeSprites();

private:
    /**
     * @brief Constructs the layer, chaining the base constructor, zero-clearing its record tables,
     * and accumulating the per-group capacity table into the instancer capacity.
     * @ghidraAddress 0x180b54
     */
    NoteChargeLayer();

    ne::C_TEXTURE *m_pTexture = {};          // +0x08: the gm_parts1 atlas.
    ne::C_SPRITE_INSTANCING *m_pSprite = {}; // +0x10: the note-charge sprite instancer.
    // +0x18..+0x1b: further state, still being worked out, preceding the capacity.
    unsigned char m_aReserved18[4] = {}; // +0x18
    int m_nSpriteCapacity = {}; // +0x1c: the accumulated instancer capacity (sprite count).
    bool m_bBuilt = {};         // +0x20: set once the sprite is built.
    // +0x21..+0x1b37: the per-charge record tables, still being worked out, kept as a reserved span
    // to preserve the 0x1b38-byte allocation size.
    unsigned char m_aChargeRecords[0x1b17] = {}; // +0x21
};

// code: language=C++
// kate: hl C++;
// vim: set ft=cpp :
