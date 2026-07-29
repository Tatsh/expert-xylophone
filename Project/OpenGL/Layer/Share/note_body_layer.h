/**
 * @file
 * The note-body layer, @c NoteBodyLayer.
 */

#pragma once

#include "playfieldlayerbase.h"

namespace ne {
class C_TEXTURE;
class C_SPRITE_INSTANCING_2D;
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

    /**
     * @brief Advances the queued note records by one frame and emits the long-note connector
     * sprites they describe. Reconstruction pending.
     * @param flDelta The elapsed frame count.
     * @ghidraAddress 0x181510
     */
    void BuildLongNoteConnectorSprites(float flDelta);

private:
    /**
     * @brief Constructs the layer, chaining the base constructor and zero-clearing its own state.
     * @ghidraAddress 0x1812a0
     */
    NoteBodyLayer();

    ne::C_TEXTURE *m_pTexture = {}; // +0x08: the gm_parts1 atlas.
    ne::C_SPRITE_INSTANCING_2D *m_apSprites[kBatchCount] =
        {};                                // +0x10: the per-batch sprite instancers.
    int m_aSpriteCounts[kBatchCount] = {}; // +0x28: each batch's initial count.
    bool m_bBuilt = {};                    // +0x34: set once the sprites are built.
    // +0x35..+0x37 is alignment padding before the base offset.
    // unsigned char m_aPad35[3]; // +0x35 (alignment padding, compiler-inserted)
    float m_flBaseOffset = {}; // +0x38: a base offset the constructor seeds to -1.

    /**
     * @brief One pooled note-body draw record (36 bytes): its active flag, the two shape selectors,
     * the note colour, two position/parameter vector pairs, three end flags, and two scale values.
     */
    struct NoteRecord {
        bool bActive = {};              // +0x00: whether the slot holds a live note body.
        unsigned char nFlagA = {};      // +0x01: the first shape selector.
        unsigned char nFlagB = {};      // +0x02: the second shape selector.
        unsigned char m_aPad03[1] = {}; // +0x03
        int nColor = {};                // +0x04: the note colour.
        float flX = {};                 // +0x08: the note X.
        float flY = {};                 // +0x0c: the note Y.
        float flParamX = {};            // +0x10: the note's second X parameter.
        float flParamY = {};            // +0x14: the note's second Y parameter.
        unsigned char nFlagC = {};      // +0x18: a third shape/end flag.
        unsigned char nFlagD = {};      // +0x19: a fourth flag.
        unsigned char nFlagE = {};      // +0x1a: a fifth flag.
        unsigned char m_aPad1b[1] = {}; // +0x1b
        float flScaleX = {};            // +0x1c: the note X scale.
        float flScaleY = {};            // +0x20: the note Y scale.
    };
    // The number of pooled note-body draw records.
    static constexpr int kNoteRecordCount = 30;
    // +0x3c..+0x473: the pooled note-body draw records.
    NoteRecord m_aNoteRecords[kNoteRecordCount] = {}; // +0x3c
    unsigned char m_aReserved474[0xc] = {};           // +0x474: trailing state to the 0x480 size.

public:
    /**
     * @brief Spawns a note body into the first free pool slot.
     *
     * Scans the pool from its head for a free slot and, on finding one, stores the note colour, the
     * two shape selectors and three end flags, the position and parameter vectors, and the two scale
     * values, then advances the shared draw count. A full pool drops the note.
     * @param nColor The note colour (0 or 1).
     * @param nFlagA The first shape selector.
     * @param nFlagB The second shape selector.
     * @param flX The note X.
     * @param flY The note Y.
     * @param flParamX The note's second X parameter.
     * @param flParamY The note's second Y parameter.
     * @param nFlagC A third shape/end flag.
     * @param nFlagD A fourth flag.
     * @param flScaleX The note X scale.
     * @param nFlagE A fifth flag.
     * @param flScaleY The note Y scale.
     * @ghidraAddress 0x181440
     */
    void Create(int nColor,
                unsigned char nFlagA,
                unsigned char nFlagB,
                float flX,
                float flY,
                float flParamX,
                float flParamY,
                unsigned char nFlagC,
                unsigned char nFlagD,
                float flScaleX,
                unsigned char nFlagE,
                float flScaleY);
};

// code: language=C++
// kate: hl C++;
// vim: set ft=cpp :
