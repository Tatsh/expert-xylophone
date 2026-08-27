/**
 * @file
 * The long-note layer, @c LongNoteLayer.
 */

#pragma once

#include "playfieldlayerbase.h"
#include "s_vector2.h"

namespace ne {
class C_TEXTURE;
class C_SPRITE_INSTANCING_2D;
} // namespace ne

/**
 * @brief The long-note layer (the held-note connector graphics).
 *
 * A process-wide singleton, built on first access, deriving from @c PlayFieldLayerBase. It owns one
 * atlas and three sprite instancers, drawn beneath the shared background layer, that present the
 * long-note connectors, plus a pool of per-note draw records. The class carries no RTTI (it is
 * non-polymorphic), so the name is taken from the @c long_note_layer.mm path its assertions embed.
 * The trailing @c // +0xNN comments document the original 32-bit offsets for reference only.
 */
class LongNoteLayer : public PlayFieldLayerBase {
public:
    /** @brief The number of connector sprite instancers the layer builds. */
    static constexpr int kBatchCount = 3;
    /** @brief The sprite-instancer capacity each batch is built with. */
    static constexpr unsigned int kSpriteCapacity = 0x5a;

    /**
     * @brief The process-wide long-note layer, created on first use.
     * @return The shared layer.
     * @ghidraAddress 0x181310
     */
    static LongNoteLayer *shared();

    /**
     * @brief Lazily builds the long-note sprites: loads the gm_parts1 atlas and creates the three
     * sprite instancers (attaching each under the background layer's render object, making it
     * visible, binding the atlas, flagging additive blend on the outer two, and, except on the
     * tutorial hardware, enabling each batch's two texture-environment parameters), then resets the
     * shared draw count.
     *
     * Guarded so the sprites are built only once.
     * @ghidraAddress 0x181360
     */
    void LoadSprites();

    /**
     * @brief Consumes every queued note record and emits the connector sprites it describes.
     *
     * Restarts the batch counts and advances the shared pulse clock, wrapping it into its period,
     * then walks the record pool up to the shared draw count. Each live record is consumed and
     * emits four body segments — plus a pulse segment while it is flagged and the clock is in its
     * first half, and a tail once the connector is long enough — at the alpha its frame-table
     * entry, side factor, and own alpha scale give it, rotated to the connector's direction (or to
     * the record's own rotation when it carries one). The second shape selector chooses the
     * alternate sprite set. Finally each batch's emitted count is published and the shared pool is
     * released.
     * @param flDelta The elapsed frame count.
     * @ghidraAddress 0x181510
     */
    void BuildLongNoteConnectorSprites(float flDelta);

    /**
     * @brief Emits one long-note sprite of the given type into its batch.
     *
     * Looks the type up in the descriptor table for its batch, anchor, size, and UV-table index,
     * and appends a sprite at @p pPosition. The stretchable body types size to the layout height
     * and scale both axes by @p flScale; the fixed-length types take their height from @p flLength
     * and draw at unit y-scale. The colour is always opaque white modulated by @p nAlpha.
     * @param nType The sprite type (0 through 35).
     * @param pPosition The sprite position.
     * @param nAlpha The sprite alpha.
     * @param flLength The sprite height for the fixed-length types.
     * @param flRotation The sprite rotation, in radians.
     * @param flScale The sprite scale factor.
     * @ghidraAddress 0x1818b4
     */
    void CreateSprite(int nType,
                      const S_VECTOR2 *pPosition,
                      unsigned int nAlpha,
                      float flLength,
                      float flRotation,
                      float flScale);

private:
    /**
     * @brief Constructs the layer, chaining the base constructor and zero-clearing its own state.
     * @ghidraAddress 0x1812a0
     */
    LongNoteLayer();

    ne::C_TEXTURE *m_pTexture = {}; // +0x08: the gm_parts1 atlas.
    ne::C_SPRITE_INSTANCING_2D *m_apSprites[kBatchCount] =
        {};                                // +0x10: the per-batch sprite instancers.
    int m_aSpriteCounts[kBatchCount] = {}; // +0x28: each batch's initial count.
    bool m_bBuilt = {};                    // +0x34: set once the sprites are built.
    // +0x35..+0x37 is alignment padding before the base offset.
    // unsigned char m_aPad35[3]; // +0x35 (alignment padding, compiler-inserted)
    // +0x38: the shared pulse clock, advanced each frame and wrapped into its period. The
    // constructor seeds it to -1.
    float m_flPulseClock = {};

    /**
     * @brief One pooled connector draw record (36 bytes): its active flag, the two shape selectors,
     * the note colour, the connector's two endpoints, three more flags, an alpha scale, and an
     * optional rotation override.
     */
    struct NoteRecord {
        bool bActive = {};         // +0x00: whether the slot holds a live connector.
        unsigned char nFlagA = {}; // +0x01: the first shape selector.
        unsigned char nFlagB = {}; // +0x02: the second shape selector.
        // unsigned char m_aPad03[1] = {}; // +0x03
        int nColor = {};           // +0x04: the note colour.
        S_VECTOR2 startPoint;      // +0x08: the connector's start point.
        S_VECTOR2 endPoint;        // +0x10: the connector's end point.
        unsigned char nFlagC = {}; // +0x18: gates the pulse-phase sprite.
        unsigned char nFlagD = {}; // +0x19: indexes the frame-alpha table.
        unsigned char nFlagE = {}; // +0x1a: set when the record carries its own rotation.
        // unsigned char m_aPad1b[1] = {}; // +0x1b
        float flAlphaScale = {}; // +0x1c: scales the record's emitted alpha.
        float flRotation = {};   // +0x20: the rotation used when nFlagE is set.
    };
    // The number of pooled connector draw records.
    static constexpr int kNoteRecordCount = 30;
    // +0x3c..+0x473: the pooled connector draw records.
    NoteRecord m_aNoteRecords[kNoteRecordCount] = {}; // +0x3c
    // unsigned char m_aReserved474[0xc] = {};           // +0x474: trailing state to the 0x480
    // size.

public:
    /**
     * @brief Queues a connector into the first free pool slot.
     *
     * Scans the pool from its head for a free slot and, on finding one, stores the note colour, the
     * two shape selectors and three flags, the connector's two endpoints, the alpha scale, and the
     * rotation override, then advances the shared draw count. A full pool drops the note.
     * @param nColor The note colour (0 or 1).
     * @param nFlagA The first shape selector.
     * @param nFlagB The second shape selector.
     * @param flStartX The connector's start X.
     * @param flStartY The connector's start Y.
     * @param flEndX The connector's end X.
     * @param flEndY The connector's end Y.
     * @param nFlagC Gates the pulse-phase sprite.
     * @param nFlagD Indexes the frame-alpha table.
     * @param flAlphaScale Scales the record's emitted alpha.
     * @param nFlagE Set when @p flRotation is used instead of the derived angle.
     * @param flRotation The rotation used when @p nFlagE is set.
     * @ghidraAddress 0x181440
     */
    void Create(int nColor,
                unsigned char nFlagA,
                unsigned char nFlagB,
                float flStartX,
                float flStartY,
                float flEndX,
                float flEndY,
                unsigned char nFlagC,
                unsigned char nFlagD,
                float flAlphaScale,
                unsigned char nFlagE,
                float flRotation);
};

// code: language=C++
// kate: hl C++;
// vim: set ft=cpp :
