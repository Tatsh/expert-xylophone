/**
 * @file
 * The note-trail layer, @c NoteTrailLayer.
 */

#pragma once

#include "playfieldlayerbase.h"

namespace ne {
class C_TEXTURE;
class C_SPRITE_INSTANCING;
} // namespace ne

/**
 * @brief The note-trail layer (the trailing ribbons behind long notes).
 *
 * A process-wide singleton, built on first access, deriving from @c PlayFieldLayerBase. It owns one
 * atlas and one sprite instancer, drawn beneath the shared background layer, that presents the note
 * trails, plus a table of per-trail records. The class carries no RTTI (it is non-polymorphic), so
 * the name is inferred from its singleton getter rather than confirmed from the runtime metadata.
 * Only the sprite-batch fields are modelled so far; the per-trail record table is kept as a reserved
 * span. The trailing @c // +0xNN comments document the original 32-bit offsets for reference only.
 */
class NoteTrailLayer : public PlayFieldLayerBase {
public:
    // The sprite-instancer capacity the layer builds.
    static constexpr unsigned int kSpriteCapacity = 0x28;

    /**
     * @brief The process-wide note-trail layer, created on first use.
     * @return The shared layer.
     * @ghidraAddress 0x184708
     */
    static NoteTrailLayer *shared();

    /**
     * @brief Lazily builds the note-trail sprite: loads the gm_parts1 atlas and creates the sprite
     * instancer (attaching it under the background layer's render object, making it visible, binding
     * the atlas, flagging additive blend, and, except on the tutorial hardware, enabling its two
     * texture-environment parameters).
     *
     * Guarded so the sprite is built only once.
     * @ghidraAddress 0x184758
     */
    void LoadNoteTrailSprites();

private:
    /**
     * @brief Constructs the layer, chaining the base constructor and zero-clearing its own state.
     * @ghidraAddress 0x1846b0
     */
    NoteTrailLayer();

    ne::C_TEXTURE *m_pTexture = {};          // +0x08: the gm_parts1 atlas.
    ne::C_SPRITE_INSTANCING *m_pSprite = {}; // +0x10: the note-trail sprite instancer.
    int m_nSpriteCount = {};                 // +0x18: the instancer's initial sprite count.
    bool m_bBuilt = {};                      // +0x1c: set once the sprite is built.
    // +0x1d..+0x1f is alignment padding before the per-trail records.
    // unsigned char m_aPad1d[3]; // +0x1d (alignment padding, compiler-inserted)
    // +0x20..+0x2af: the per-trail records, still being worked out, kept as a reserved span to
    // preserve the 0x2b0-byte allocation size.
    unsigned char m_aTrailRecords[0x290] = {}; // +0x20
};

// code: language=C++
// kate: hl C++;
// vim: set ft=cpp :
