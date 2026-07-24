/**
 * @file
 * The note-body layer, @c NoteBodyLayer.
 */

#pragma once

#include "playfieldlayerbase.h"

namespace ne {
class C_TEXTURE;
class C_SPRITE_INSTANCING;
} // namespace ne

/**
 * @brief The note-body layer (the falling note graphics).
 *
 * A process-wide singleton, built on first access, deriving from @c PlayFieldLayerBase. It owns one
 * atlas and three sprite instancers, drawn beneath the shared background layer, that present the
 * note bodies, plus a large table of per-note animation records. The class carries no RTTI (it is
 * non-polymorphic), so the name is inferred from its singleton getter rather than confirmed from the
 * runtime metadata. Only the sprite-batch fields are modelled so far; the per-note record table is
 * kept as a reserved span. The trailing @c // +0xNN comments document the original 32-bit offsets
 * for reference only.
 */
class NoteBodyLayer : public PlayFieldLayerBase {
public:
    // The number of note-body sprite instancers the layer builds.
    static constexpr int kBatchCount = 3;
    // The sprite-instancer capacity each batch is built with.
    static constexpr unsigned int kSpriteCapacity = 0x5a;

    /**
     * @brief The process-wide note-body layer, created on first use.
     * @return The shared layer.
     * @ghidraAddress 0x181310
     */
    static NoteBodyLayer *shared();

    /**
     * @brief Lazily builds the note-body sprites: loads the gm_parts1 atlas and creates the three
     * sprite instancers (attaching each under the background layer's render object, making it
     * visible, binding the atlas, flagging additive blend on the outer two, and, except on the
     * tutorial hardware, enabling each batch's two texture-environment parameters), then resets the
     * shared draw count.
     *
     * Guarded so the sprites are built only once.
     * @ghidraAddress 0x181360
     */
    void LoadNoteBodySprites();

private:
    /**
     * @brief Constructs the layer, chaining the base constructor and zero-clearing its own state.
     * @ghidraAddress 0x1812a0
     */
    NoteBodyLayer();

    ne::C_TEXTURE *m_pTexture = {}; // +0x08: the gm_parts1 atlas.
    ne::C_SPRITE_INSTANCING *m_apSprites[kBatchCount] =
        {};                                // +0x10: the per-batch sprite instancers.
    int m_aSpriteCounts[kBatchCount] = {}; // +0x28: each batch's initial count.
    bool m_bBuilt = {};                    // +0x34: set once the sprites are built.
    // +0x35..+0x37 is alignment padding before the base offset.
    // unsigned char m_aPad35[3]; // +0x35 (alignment padding, compiler-inserted)
    float m_flBaseOffset = {}; // +0x38: a base offset the constructor seeds to -1.
    // +0x3c..+0x43: further layer state, still being worked out, preceding the per-note records.
    unsigned char m_aReserved3c[8] = {}; // +0x3c
    // +0x44..+0x47f: the per-note animation records (each 0x24 bytes), still being worked out, kept
    // as a reserved span to preserve the 0x480-byte allocation size.
    unsigned char m_aNoteRecords[0x43c] = {}; // +0x44
};

// code: language=C++
// kate: hl C++;
// vim: set ft=cpp :
