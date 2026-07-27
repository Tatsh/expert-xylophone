/**
 * @file
 * The note-result effect layer, @c NoteResultLayer.
 */

#pragma once

#include "playfieldlayerbase.h"
#include "s_vector2.h"

namespace ne {
class C_SPRITE_INSTANCING_2D;
class C_TEXTURE;
} // namespace ne

/**
 * @brief One sprite descriptor in a star-glyph layout table (a 20-byte record).
 *
 * Describes one drawable sprite (a star animation frame or a single digit glyph): its anchor offset,
 * its pixel size, and the atlas-frame number that indexes the shared sprite UV table. The layout
 * table is selected by device (pad or phone) and indexed by frame kind (records 0 through 6) or digit
 * value plus seven (records 7 through 16).
 */
struct StarSpriteDescriptor {
    S_VECTOR2 anchor = {}; // +0x00: the sprite anchor offset.
    S_VECTOR2 size = {};   // +0x08: the sprite pixel size.
    int nAtlasFrame = {};  // +0x10: the atlas-frame number indexing the shared sprite UV table.
};

// The star-glyph layout tables: one record per star frame (0 through 6) then one per digit glyph
// (0 through 9), selected by device. Read-only data embedded in the binary.
extern const StarSpriteDescriptor g_aStarGlyphTablePad[];   // @ghidraAddress 0x30f858
extern const StarSpriteDescriptor g_aStarGlyphTablePhone[]; // @ghidraAddress 0x30f9ac

/**
 * @brief The note-result effect layer.
 *
 * A process-wide singleton, built on first access, deriving from @c PlayFieldLayerBase. It animates
 * up to twelve result "star" quads, each with a numeric label, through one sprite instancer, spawned
 * as notes are judged. The class name and source path are taken from the binary's embedded
 * @c note_result_layer.mm assert. The trailing @c // +0xNN comments document the original 32-bit
 * offsets for reference only.
 */
class NoteResultLayer : public PlayFieldLayerBase {
public:
    // The number of result-quad positions.
    static constexpr int kPositionCount = 12;
    // The number of judgement types a result quad can show.
    static constexpr int kJudgeTypeCount = 4;

    /**
     * @brief The process-wide note-result effect layer, created on first use.
     * @ghidraAddress 0x1892fc
     */
    static NoteResultLayer *shared();

    /**
     * @brief Activates the result quad at @p nPos with a judgement and numeric label.
     * @param nPos The result position (0 through 11).
     * @param nJudge The judgement type (0 through 3).
     * @param nNumber The numeric label to draw.
     * @ghidraAddress 0x1895e8
     */
    void Create(unsigned int nPos, int nJudge, int nNumber);

    /**
     * @brief Sets one of the two quad-group scales.
     * @param flValue The scale value.
     * @param nWhich The group (0 = the first six quads, non-zero = the last six).
     * @ghidraAddress 0x1895d4
     */
    void SetScale(float flValue, int nWhich);

    /**
     * @brief Recomputes the twelve result-quad screen positions for the current game resolution.
     *
     * Lays the quads out in four vertical rows, each x taken from a fixed normalised column
     * (@c -0.5, @c 0, @c 0.5) scaled by half the sheet width, and each y from the row's base offset
     * plus the normalised row y scaled by half the sheet height.
     * @ghidraAddress 0x1893f0
     */
    void BuildQuadPositions();

    /**
     * @brief Lazily builds the layer's sprite instancer.
     *
     * Seeds the base sprite size (halved on the phone), rebuilds the quad positions, loads the
     * @c gm_parts2 atlas, and creates and attaches the instancer under the background layer. Guarded
     * so it runs only once.
     * @ghidraAddress 0x18934c
     */
    void CreateSpriteInstancer();

    /**
     * @brief Advances every active result quad by one frame and emits its star and digit sprites.
     *
     * Each of the twelve quads advances its timer, deactivates once past its lifetime, and otherwise
     * projects its world position to the screen, picks its star animation frame from its kind and
     * timer, and emits the star sprite plus one sprite per digit of its numeric label (laid out
     * centred, and mirrored on the single-player left side). The live sprite count is then published
     * to the instancer.
     * @param flDeltaTime The frame delta, in seconds.
     * @ghidraAddress 0x1896a4
     */
    void Update(float flDeltaTime);

private:
    // Constructs the layer: clears the quad positions and records and seeds the default scale.
    // @ghidraAddress 0x189294
    NoteResultLayer();

    /**
     * @brief Emits one sprite slot (a star frame or a digit glyph) into the instancer.
     *
     * Writes the vertex position, copies the descriptor's anchor and size, looks up the atlas UV by
     * the descriptor's frame number, applies the flip rotation, sets the uniform scale to @p flSize,
     * and writes an opaque-white colour at @p nAlpha, then advances the live slot counter.
     * @param flSize The uniform sprite scale.
     * @param position The vertex screen position.
     * @param bFlip Whether to flip the sprite horizontally (a half-turn rotation).
     * @param nAlpha The sprite alpha.
     * @param descriptor The sprite descriptor (anchor, size, and atlas-frame number).
     * @ghidraAddress 0x189aec
     */
    void EmitStarSprite(float flSize,
                        const S_VECTOR2 &position,
                        bool bFlip,
                        unsigned int nAlpha,
                        const StarSpriteDescriptor &descriptor);

    /** @brief One animated result quad: its activity, judgement kind, timer, and numeric label. */
    struct ResultQuad {
        bool bActive = {};              // +0x00: whether the quad is animating.
        unsigned char m_aPad01[3] = {}; // +0x01
        int nJudge = {};                // +0x04: the judgement kind, selecting its animation frame.
        float flTimer = {};             // +0x08: the quad's elapsed animation time.
        int nNumber = {};               // +0x0c: the numeric label drawn beside the quad.
    };

    ne::C_TEXTURE *m_pTexture = {};              // +0x08: the gm_parts2 atlas.
    ne::C_SPRITE_INSTANCING_2D *m_pSprites = {}; // +0x10: the result sprite instancer.
    int m_nSpriteCount = {}; // +0x18: the instancer's live sprite count this frame.
    S_VECTOR2 m_aQuadPos[kPositionCount] = {}; // +0x1c: each quad's screen position.
    int m_nState = {};                         // +0x7c: the layer's animation state.
    bool m_bCreated = {};                      // +0x80: set once the effect is created.
    unsigned char m_aPad81[3] = {};            // +0x81
    float m_flBaseSize = {};                   // +0x84: the base sprite size the quads scale by.
    ResultQuad m_aQuads[kPositionCount] = {};  // +0x88: the twelve quad records (end at +0x148).
    float m_flScaleA = {};                     // +0x148: the scale for the first six quads.
    float m_flScaleB = {};                     // +0x14c: the scale for the last six quads.
};

// code: language=Objective-C++
// kate: hl Objective-C++;
// vim: set ft=objcpp :
