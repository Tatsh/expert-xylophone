/**
 * @file
 * The Classic-theme result-window layer, @c ResultWindowClassicLayer.
 */

#pragma once

#include "playfieldlayerbase.h"

struct PartsDataRecord;
struct S_VECTOR2;
class Polygon2dTrail;

namespace ne {
class C_TEXTURE;
class C_SPRITE_INSTANCING;
} // namespace ne

/**
 * @brief The Classic-theme result-window layer.
 *
 * Draws the Classic result panel; a process-wide singleton built on first access, deriving from
 * @c PlayFieldLayerBase. The sprite-set state (two textures, eight sprite instancers, four ribbon
 * trails, and the lazy-build guard) is reconstructed; the remaining fields of the @c 0x1c0-byte
 * layout are still being worked out and kept as reserved spans to preserve the allocation size.
 */
class ResultWindowClassicLayer : public PlayFieldLayerBase {
public:
    /**
     * @brief The process-wide Classic result-window layer, created on first use.
     * @return The shared layer.
     * @ghidraAddress 0x1151fc
     */
    static ResultWindowClassicLayer *shared();

    /**
     * @brief Returns a result-window parts descriptor by index for the current device.
     *
     * Selects the pad or phone parts table by the device kind and returns the record at @p nIndex.
     * @param nIndex The parts-record index (0 through 239).
     * @return The parts descriptor.
     * @ghidraAddress 0x114b78
     */
    const PartsDataRecord *getPartsData(int nIndex) const;

    /**
     * @brief Returns a phone-layout parts descriptor by index.
     *
     * Always reads the static phone parts table.
     * @param nIndex The parts-record index (0 through 125).
     * @return The parts descriptor.
     * @ghidraAddress 0x114c10
     */
    const PartsDataRecord *getPartsData_Phone(int nIndex) const;

    /**
     * @brief Lazily builds the layer's sprite set: loads the two textures, creates the eight sprite
     * instancers (registering each in the global scene tree, making it visible, binding the slot's
     * texture, and clearing its sprite count), and initialises the four ribbon trails.
     *
     * Guarded so the set is built only once.
     * @ghidraAddress 0x11524c
     */
    void InitSpriteSetsLazy();

    /**
     * @brief Resolves a phone-layout position by index, offset relative to the play-field viewport.
     *
     * Looks up a @c PhoneAnchorRecord from the portrait or landscape table (selected by the layer's
     * orientation flag), copies its base coordinate, then shifts it by the viewport's half or full
     * width and height per the record's anchor mode.
     * @param nIndex The position-record index (0 through 81).
     * @param pOutPosition Receives the resolved position.
     * @ghidraAddress 0x114c80
     */
    void getPosition_Phone(int nIndex, S_VECTOR2 *pOutPosition) const;

    /**
     * @brief Emits one result-window part sprite by part id into an instancer slot.
     *
     * Looks up the part's placement rectangle and UV-palette rectangle and appends a quad to the
     * slot; part ids at or above the table bound are ignored. The main pass draws at full alpha, the
     * shadow pass at half intensity.
     * @param flRotation The sprite rotation, in radians.
     * @param flScaleX The sprite X scale.
     * @param flScaleY The sprite Y scale.
     * @param nSlot The instancer slot to append to.
     * @param nPartId The part id.
     * @param position The sprite's world position.
     * @param nAlpha The sprite's alpha.
     * @param bShadowPass Non-zero for the half-intensity shadow pass.
     * @ghidraAddress 0x115864
     */
    void EmitPartSprite(float flRotation,
                        float flScaleX,
                        float flScaleY,
                        unsigned int nSlot,
                        unsigned int nPartId,
                        const S_VECTOR2 &position,
                        unsigned int nAlpha,
                        int bShadowPass);

    /**
     * @brief Renders a right-to-left digit sequence from a chosen glyph bank.
     *
     * Splits @p nValue into up to @p nDigitCount decimal digits and emits each glyph (part id
     * @p nGlyphBase plus the digit) right to left, advancing by each glyph's width less
     * @p flSpacing. The score and rating banks carry paired glyphs and small kerning nudges, and
     * the leading positions are optionally padded with dimmed zeros.
     * @param nValue The value to render.
     * @param nDigitCount The maximum number of digits.
     * @param pOrigin The right-hand start position.
     * @param nGlyphBase The glyph bank's base part id (its '0').
     * @param bLeadingZero Non-zero to draw the paired/leading glyph when the value is zero.
     * @param bPadRight Non-zero to pad the leading positions with dimmed zeros.
     * @param nAlpha The glyph alpha.
     * @param flSpacing The extra gap subtracted between glyphs.
     * @ghidraAddress 0x115514
     */
    void RenderDigitSequence(int nValue,
                             int nDigitCount,
                             const S_VECTOR2 *pOrigin,
                             unsigned int nGlyphBase,
                             unsigned int bLeadingZero,
                             int bPadRight,
                             unsigned int nAlpha,
                             float flSpacing);

    /**
     * @brief Renders a compact (no decimal point) score as centred digit glyphs.
     *
     * Splits @p nValue into up to four digits (at least one), centres the run about @p position
     * using the zero glyph's advance, and emits each digit right to left stepping by its own width.
     * @param nValue The value to render.
     * @param position The centre position of the digit run.
     * @param nAlpha The glyph alpha.
     * @ghidraAddress 0x115928
     */
    void RenderScoreDigitsCompact(int nValue, const S_VECTOR2 &position, unsigned int nAlpha);

    /**
     * @brief Renders an integer and fractional value joined by a dot glyph, centred as one run.
     *
     * Splits both parts into up to four digits each (at least one), centres the combined run
     * (integer digits, the dot, and fraction digits) about @p position using the zero glyph's
     * advance, then emits the integer digits, the dot glyph, and the fraction digits right to left.
     * @param nIntegerValue The integer part.
     * @param nFractionValue The fractional part.
     * @param position The centre position of the run.
     * @param nAlpha The glyph alpha.
     * @ghidraAddress 0x115ac0
     */
    void RenderScoreDigitsWithDot(int nIntegerValue,
                                  int nFractionValue,
                                  const S_VECTOR2 &position,
                                  unsigned int nAlpha);

    /**
     * @brief Renders a value padded to at least two digits with a dot glyph after the ones digit.
     *
     * Splits @p nValue into up to four digits (at least two) and emits each digit right to left from
     * @p position stepping by its own width, inserting the dot glyph after the ones digit.
     * @param nValue The value to render.
     * @param position The right-hand start position.
     * @param nAlpha The glyph alpha.
     * @ghidraAddress 0x115d7c
     */
    void RenderScorePaddedWithDot(int nValue, const S_VECTOR2 &position, unsigned int nAlpha);

    /**
     * @brief Renders a number field of glyphs at an offset position, with an optional paired glyph
     *        and dimmed leading-zero padding.
     *
     * Splits @p nValue into up to @p nDigitCount digits, offsets @p position by @p offset, and emits
     * each glyph (character code @p nGlyphBase plus the digit) right to left through the glyph
     * dispatcher, advancing by each glyph's width less @p flSpacing. When the leading-zero flag is
     * set the first digit also draws a paired glyph ten codes up, and when @p bPadRight is set the
     * remaining positions are drawn as dimmed glyphs.
     * @param nValue The value to render.
     * @param nDigitCount The maximum number of digits.
     * @param position The base position.
     * @param offset The offset added to the base position.
     * @param nGlyphBase The glyph bank's base character code.
     * @param bLeadingZero Non-zero to draw the paired first glyph.
     * @param bPadRight Non-zero to pad the leading positions with dimmed glyphs.
     * @param nAlpha The glyph alpha.
     * @param flSpacing The extra gap subtracted between glyphs.
     * @ghidraAddress 0x115f4c
     */
    void RenderNumberFieldWithPad(int nValue,
                                  int nDigitCount,
                                  const S_VECTOR2 &position,
                                  const S_VECTOR2 &offset,
                                  unsigned int nGlyphBase,
                                  unsigned int bLeadingZero,
                                  int bPadRight,
                                  unsigned int nAlpha,
                                  float flSpacing);

    /**
     * @brief Renders a value as centred digit glyphs, advancing by each glyph's own width.
     *
     * Splits @p nValue into up to four digits (rendering at least one significant digit), centres
     * the run about @p pPosition using a nominal seven-pixel glyph width, then emits each digit
     * (glyph base @c 0x39 plus the digit) right to left, stepping the cursor by each glyph's own
     * width plus one pixel. All glyphs draw at unit scale and full intensity.
     * @param nValue The value to render.
     * @param pPosition The centre position of the run.
     * @param nAlpha The glyph alpha.
     * @ghidraAddress 0x1166a8
     */
    void RenderDigitRowSpacedByWidth(int nValue, const S_VECTOR2 *pPosition, unsigned int nAlpha);

    /**
     * @brief Renders two digit groups separated by a separator glyph, centred as one run.
     *
     * Splits both values into up to four digits each (rendering at least one significant digit
     * per group), centres the combined run about @p pPosition using a nominal seven-pixel glyph
     * width, then emits the run right to left: the denominator digits, the separator glyph, then
     * the numerator digits. Each digit is drawn a fixed inset left of the advancing cursor, which
     * steps by the glyph width; the separator adds a small extra gap. All glyphs draw at unit scale
     * and full intensity.
     * @param nNumerator The left-hand (numerator) value.
     * @param nDenominator The right-hand (denominator) value.
     * @param pPosition The centre position of the run.
     * @param nAlpha The glyph alpha.
     * @ghidraAddress 0x116258
     */
    void RenderRatioDigits(int nNumerator,
                           int nDenominator,
                           const S_VECTOR2 *pPosition,
                           unsigned int nAlpha);

    /**
     * @brief Renders a value as centred digit glyphs with a leading glyph and an inline dot glyph.
     *
     * Splits @p nValue into up to four digits (rendering at least two significant digits), centres
     * the run about @p pPosition using a fixed six-pixel glyph advance, and emits the glyphs right
     * to left: a leading glyph, then each digit (glyph base @c 0x39 plus the digit), inserting a
     * narrow dot glyph after the ones digit. All glyphs draw at unit scale and full intensity.
     * @param nValue The value to render.
     * @param pPosition The centre position of the run.
     * @param nAlpha The glyph alpha.
     * @ghidraAddress 0x1164e8
     */
    void RenderDecimalWithDotGlyph(int nValue, const S_VECTOR2 *pPosition, unsigned int nAlpha);

    /**
     * @brief Emits one glyph sprite from the glyph table by character code.
     *
     * Looks up the glyph's placement rectangle (from the parts table indexed by @p nCharCode) and
     * its glyph UV-palette rectangle, then appends a quad to the slot. Character codes at or above
     * the glyph-table bound are ignored. The main pass draws at full intensity, the dimmed pass at
     * half.
     * @param nSlot The instancer slot to append to.
     * @param nCharCode The glyph character code (below the glyph-table bound).
     * @param pPosition The glyph's world position.
     * @param nAlpha The glyph alpha.
     * @param bDimmed Non-zero for the half-intensity dimmed pass.
     * @param flRotation The glyph rotation, in radians.
     * @param flScaleX The glyph X scale.
     * @param flScaleY The glyph Y scale.
     * @ghidraAddress 0x1161cc
     */
    void DispatchGlyphSpriteFromTable(unsigned int nSlot,
                                      unsigned int nCharCode,
                                      const S_VECTOR2 *pPosition,
                                      unsigned int nAlpha,
                                      int bDimmed,
                                      float flRotation,
                                      float flScaleX,
                                      float flScaleY);

    // The number of sprite-instancer slots the layer builds.
    static constexpr int kSpriteSlotCount = 8;
    // The number of ribbon trails the layer builds (during the first slot's setup).
    static constexpr int kTrailCount = 4;
    // The number of phone-layout position records.
    static constexpr int kPositionRecordCount = 82;

private:
    // Appends one fully-specified quad to a slot's sprite instancer, if the slot exists and is not
    // full; the shared low-level emit behind the part helpers.
    // @ghidraAddress 0x116808
    void AppendSpriteToSlot(const S_VECTOR2 &position,
                            const S_VECTOR2 &anchor,
                            const S_VECTOR2 &size,
                            const S_VECTOR2 &uvOrigin,
                            const S_VECTOR2 &uvSize,
                            float flRotation,
                            const S_VECTOR2 &scale,
                            unsigned int nSlot,
                            unsigned int nIntensity,
                            unsigned int nAlpha);

    ne::C_TEXTURE *m_pBackgroundTexture = {}; // +0x08: the selection-background atlas.
    ne::C_TEXTURE *m_pPartsTexture = {};      // +0x10: the result-parts atlas.
    ne::C_SPRITE_INSTANCING *m_apSprites[kSpriteSlotCount] =
        {};                    // +0x18: the per-slot sprite batches.
    bool m_bSpritesBuilt = {}; // +0x58: set once the set is built.
    // +0x59..+0x5b is alignment padding before the default alpha.
    // unsigned char m_aPad59[3]; // +0x59 (alignment padding, compiler-inserted)
    unsigned int m_nDefaultAlpha = {}; // +0x5c: the default sprite alpha (255).
    float m_flDefaultScale = {};       // +0x60: the default sprite scale (1.0).
    // +0x64..+0x12f: further layer state (transform vectors and per-cell fields) still being worked
    // out, kept as a reserved span to preserve the allocation size.
    unsigned char m_aReserved64[0xcc] = {};       // +0x64
    Polygon2dTrail *m_apTrails[kTrailCount] = {}; // +0x130: the ribbon trails.
    // +0x150..+0x1b4: further layer state, still being worked out.
    unsigned char m_aReserved150[0x65] = {}; // +0x150
    bool m_bPortrait = {}; // +0x1b5: selects the portrait position/separator tables.
    // +0x1b6..+0x1bf: trailing layer state, still being worked out.
    unsigned char m_aReserved1b6[0xa] = {}; // +0x1b6
};

// code: language=Objective-C++
// kate: hl Objective-C++;
// vim: set ft=objcpp :
