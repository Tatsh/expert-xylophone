/**
 * @file
 * The Classic-theme result-window layer, @c ResultWindowClassicLayer.
 */

#pragma once

#include "playfieldlayerbase.h"
#include "result_bonus_anim_channel.h"

struct PartsDataRecord;
struct PhoneLayoutRecord;
struct PhoneLayoutRect;
struct S_VECTOR2;
class Polygon2dTrail;

namespace ne {
class C_TEXTURE;
class C_SPRITE_INSTANCING_2D;
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
     * @brief Resets the five result-score/effect display animation channels to their zeroed initial
     * state, each easing from its current shown value to zero over @p flStartTime (snapping
     * immediately when non-positive), resets the four ribbon trails, and clears the score-animation
     * active flag.
     * @param flStartTime The animation base start time.
     * @ghidraAddress 0x1170c0
     */
    void ResetResultScoreAnimations(float flStartTime);

    /**
     * @brief Counts a gesture hold-timer down and fires the release cue when it expires.
     *
     * A no-op while the score/gesture-active flag is clear. Otherwise it accumulates the frame delta
     * into the hold timer and, once the timer passes the hold timeout, clears the active flag and
     * plays the themed release voice.
     * @param flDeltaTime The elapsed time since the last frame, in milliseconds.
     * @ghidraAddress 0x11738c
     */
    void UpdateGestureHoldTimer(float flDeltaTime);

    /**
     * @brief Resets the result-screen score/level display block to its per-round defaults.
     *
     * Sets the networked-play flag from the game type, clears the display counters and sentinels
     * (the music-track indices to -1), copies the player level and experience from the game system,
     * resolves the level-up threshold and gained experience, kicks off the customize asset load when
     * none is pending, arms the score/gesture-active flag from the result-bonus feature, and records
     * whether the Twitter share API is available.
     * @ghidraAddress 0x11541c
     */
    void ResetScoreDisplayState();

    /**
     * @brief Whether a customize-character texture swap is pending.
     * @return The reload flag.
     * @ghidraAddress 0x11c590
     */
    bool GetCustomizeReloadFlag() const {
        return m_bCustomizeReloadFlag;
    }

    /**
     * @brief Clears the pending customize-character texture-swap flag.
     * @ghidraAddress 0x11c598
     */
    void ClearCustomizeReloadFlag() {
        m_bCustomizeReloadFlag = false;
    }

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
     * @brief Returns a phone-layout separator record by index.
     *
     * Selects the portrait or landscape separator table by the layer's orientation flag and returns
     * the record at @p nIndex.
     * @param nIndex The separator-record index (0 through 45).
     * @return The separator record.
     * @ghidraAddress 0x114e18
     */
    const PhoneLayoutRecord *getSeparator_Phone(int nIndex) const;

    /**
     * @brief Resolves a phone-layout rectangle by index and state, offset relative to the viewport.
     *
     * Selects the state table on the iPad, otherwise the portrait or
     * landscape table by the orientation flag, copies the record's four floats to @p pOutRect, then
     * shifts the leading coordinate by the viewport's half or full width and height per the record's
     * anchor mode.
     * @param nIndex The position-record index.
     * @param pOutRect Receives the resolved rectangle.
     * @ghidraAddress 0x114e9c
     */
    void getPositionByState_Phone(int nIndex, PhoneLayoutRect *pOutRect) const;

    /**
     * @brief Resolves the single phone-layout centre-position rectangle, offset by the viewport.
     *
     * Copies the state, portrait, or landscape centre record (selected by the state and orientation
     * flags) to @p pOutRect. When the state flag is clear the leading coordinate is shifted by half
     * the viewport width and height.
     * @param pOutRect Receives the resolved rectangle.
     * @ghidraAddress 0x115008
     */
    void getCenterPosition_Phone(PhoneLayoutRect *pOutRect) const;

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
     * @param bShadowPass True for the half-intensity shadow pass.
     * @ghidraAddress 0x115864
     */
    void EmitPartSprite(float flRotation,
                        float flScaleX,
                        float flScaleY,
                        unsigned int nSlot,
                        unsigned int nPartId,
                        const S_VECTOR2 &position,
                        unsigned int nAlpha,
                        bool bShadowPass);

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
     * @param bLeadingZero True to draw the paired/leading glyph when the value is zero.
     * @param bPadRight True to pad the leading positions with dimmed zeros.
     * @param nAlpha The glyph alpha.
     * @param flSpacing The extra gap subtracted between glyphs.
     * @ghidraAddress 0x115514
     */
    void RenderDigitSequence(int nValue,
                             int nDigitCount,
                             const S_VECTOR2 *pOrigin,
                             unsigned int nGlyphBase,
                             bool bLeadingZero,
                             bool bPadRight,
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
     * @param bLeadingZero True to draw the paired first glyph.
     * @param bPadRight True to pad the leading positions with dimmed glyphs.
     * @param nAlpha The glyph alpha.
     * @param flSpacing The extra gap subtracted between glyphs.
     * @ghidraAddress 0x115f4c
     */
    void RenderNumberFieldWithPad(int nValue,
                                  int nDigitCount,
                                  const S_VECTOR2 &position,
                                  const S_VECTOR2 &offset,
                                  unsigned int nGlyphBase,
                                  bool bLeadingZero,
                                  bool bPadRight,
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
     * @brief Binds a texture into a slot and refreshes every existing sprite's size and UV rect.
     *
     * Sets the slot's ref-counted bound texture to @p pTexture, then, for each sprite already in the
     * slot, resizes it to the texture image size over its scale factor, zeroes its UV origin, and
     * sets its UV size to the used region (image size over allocated power-of-two size). Does nothing
     * if the slot is empty or @p pTexture is null.
     * @param nSlot The instancer slot.
     * @param pTexture The texture to bind.
     * @ghidraAddress 0x115348
     */
    void SetInstancerTextureAndRefreshSlots(unsigned int nSlot, ne::C_TEXTURE *pTexture);

    /**
     * @brief Toggles the customize character preview, loading its texture into the preview slot.
     *
     * When the preview is hidden, records @p nCharacterId, marks it shown, resolves the character's
     * unlock entry (its category becomes the cached sub-id and its item the asset variant), builds
     * the customize asset path, loads that texture, and binds it into the preview instancer slot
     * (slot 6). When the preview is already shown, marks it hidden and records @p nCharacterId as the
     * pending id for the next toggle.
     * @param nCharacterId The character/costume id to preview.
     * @ghidraAddress 0x11c5a0
     */
    void ToggleCustomizeCharacterTexture(unsigned int nCharacterId);

    /**
     * @brief Emits one glyph sprite anchored by a separator record, at that record's scale.
     *
     * Fetches the separator record @p nSepIndex, which supplies the anchored base position (offset
     * relative to the viewport per its anchor mode), the sprite X scale (its width field), and the
     * sprite rotation (its height field). Looks up the glyph's placement and glyph UV rectangles by
     * @p nCharCode, adds @p offset to the anchored position, and appends the full-intensity quad.
     * Character codes at or above the glyph-table bound, or separator indices at or above the table
     * count, are ignored.
     * @param nSlot The instancer slot to append to.
     * @param nSepIndex The separator-record index.
     * @param nCharCode The glyph character code (below the glyph-table bound).
     * @param offset The offset added to the anchored position.
     * @param nAlpha The glyph alpha.
     * @ghidraAddress 0x116dc0
     */
    void RenderGlyphAtSeparator(unsigned int nSlot,
                                int nSepIndex,
                                unsigned int nCharCode,
                                const S_VECTOR2 &offset,
                                unsigned int nAlpha);

    /**
     * @brief Draws a slot's whole bound texture image as one quad at a position and size.
     *
     * Reads the slot's bound texture, computes the used UV region (image size over allocated
     * power-of-two size), and appends a full-intensity quad of the given size at the given position.
     * Does nothing if the slot is empty or has no bound texture.
     * @param nSlot The instancer slot.
     * @param position The quad's world position.
     * @param size The quad's size, in pixels.
     * @param nAlpha The quad alpha.
     * @ghidraAddress 0x116950
     */
    void BlitInstancerTextureSlot(unsigned int nSlot,
                                  const S_VECTOR2 &position,
                                  const S_VECTOR2 &size,
                                  unsigned int nAlpha);

    /**
     * @brief Draws a slot's bound texture image scaled by the texture's own scale factor.
     *
     * Like BlitInstancerTextureSlot, but sizes the quad by the texture's stored scale factor and
     * draws it at the layer's default alpha, with the alpha channel driven by @p nScale times the
     * layer's default scale.
     * @param nSlot The instancer slot.
     * @param position The quad's world position.
     * @param nScale The scale units multiplied into the alpha.
     * @ghidraAddress 0x116a0c
     */
    void RenderSpriteInstancerSlotScaled(unsigned int nSlot,
                                         const S_VECTOR2 &position,
                                         unsigned int nScale);

    /**
     * @brief Draws a slot's bound texture image centred on a position (half-size anchor).
     *
     * Like RenderSpriteInstancerSlotScaled's sizing, but anchors the quad at half its size so it is
     * centred on @p position, and takes explicit alpha and intensity.
     * @param nSlot The instancer slot.
     * @param position The quad's centre position.
     * @param nAlpha The quad alpha.
     * @param nIntensity The quad colour intensity.
     * @ghidraAddress 0x116ad0
     */
    void RenderSpriteInstancerSlotHalfScale(unsigned int nSlot,
                                            const S_VECTOR2 &position,
                                            unsigned int nAlpha,
                                            unsigned int nIntensity);

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
     * @param bDimmed True for the half-intensity dimmed pass.
     * @param flRotation The glyph rotation, in radians.
     * @param flScaleX The glyph X scale.
     * @param flScaleY The glyph Y scale.
     * @ghidraAddress 0x1161cc
     */
    void DispatchGlyphSpriteFromTable(unsigned int nSlot,
                                      unsigned int nCharCode,
                                      const S_VECTOR2 *pPosition,
                                      unsigned int nAlpha,
                                      bool bDimmed,
                                      float flRotation,
                                      float flScaleX,
                                      float flScaleY);

    /**
     * @brief Emits one phone-table glyph sprite at a position plus an offset, with rotation and
     *        scale.
     *
     * Looks up the glyph's placement rectangle from the phone parts table and its glyph UV-palette
     * rectangle, adds @p offset to @p position, and appends the quad to the slot. Character codes at
     * or above the glyph-table bound are ignored. The main pass draws at full intensity, the shadow
     * pass at half.
     * @param nSlot The instancer slot to append to.
     * @param nCharCode The glyph character code (below the glyph-table bound).
     * @param position The glyph's base position.
     * @param offset The offset added to the base position.
     * @param nAlpha The glyph alpha.
     * @param bShadowPass True for the half-intensity shadow pass.
     * @param flRotation The glyph rotation, in radians.
     * @param flScaleX The glyph X scale.
     * @param flScaleY The glyph Y scale.
     * @ghidraAddress 0x116b94
     */
    void RenderTableSpriteAtIndex(unsigned int nSlot,
                                  unsigned int nCharCode,
                                  const S_VECTOR2 &position,
                                  const S_VECTOR2 &offset,
                                  unsigned int nAlpha,
                                  bool bShadowPass,
                                  float flRotation,
                                  float flScaleX,
                                  float flScaleY);

    /**
     * @brief Emits one phone-table glyph sprite at a resolved position index plus an offset.
     *
     * Resolves the base position from the phone position table by @p nPositionIndex, then behaves as
     * RenderTableSpriteAtIndex: looks up the glyph rectangle and UV rectangle, adds @p offset, and
     * appends the quad with the given rotation and scale (half intensity on the shadow pass).
     * @param nSlot The instancer slot to append to.
     * @param nCharCode The glyph character code (below the glyph-table bound).
     * @param nPositionIndex The phone position-record index.
     * @param offset The offset added to the resolved position.
     * @param nAlpha The glyph alpha.
     * @param bShadowPass True for the half-intensity shadow pass.
     * @param flRotation The glyph rotation, in radians.
     * @param flScaleX The glyph X scale.
     * @param flScaleY The glyph Y scale.
     * @ghidraAddress 0x116cc0
     */
    void RenderTableSpriteWithOffset(unsigned int nSlot,
                                     unsigned int nCharCode,
                                     int nPositionIndex,
                                     const S_VECTOR2 &offset,
                                     unsigned int nAlpha,
                                     bool bShadowPass,
                                     float flRotation,
                                     float flScaleX,
                                     float flScaleY);

    /**
     * @brief Emits one glyph sprite at a resolved position index plus an offset, X-scaled only.
     *
     * Resolves the base position from the phone position table by @p nPositionIndex, adds @p offset,
     * then dispatches the glyph through the glyph dispatcher with the given X scale (unit Y scale, no
     * rotation, full intensity).
     * @param nSlot The instancer slot to append to.
     * @param nCharCode The glyph character code (below the glyph-table bound).
     * @param nPositionIndex The phone position-record index.
     * @param offset The offset added to the resolved position.
     * @param nAlpha The glyph alpha.
     * @param flScaleX The glyph X scale.
     * @ghidraAddress 0x116c2c
     */
    void RenderSpriteWithPositionOffset(unsigned int nSlot,
                                        unsigned int nCharCode,
                                        int nPositionIndex,
                                        const S_VECTOR2 &offset,
                                        unsigned int nAlpha,
                                        float flScaleX);

    // The number of sprite-instancer slots the layer builds.
    static constexpr int kSpriteSlotCount = 8;
    // The number of ribbon trails the layer builds (during the first slot's setup).
    static constexpr int kTrailCount = 4;
    // The number of result-score/effect display animation channels.
    static constexpr int kScoreAnimCount = 5;
    // The number of phone-layout position records.
    static constexpr int kPositionRecordCount = 82;

private:
    /**
     * @brief Begins loading the customize-character main asset for the result screen. Reconstruction
     * pending.
     * @ghidraAddress 0x11c66c
     */
    void BeginCustomizeMainAsset();

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
    ne::C_SPRITE_INSTANCING_2D *m_apSprites[kSpriteSlotCount] =
        {};                    // +0x18: the per-slot sprite batches.
    bool m_bSpritesBuilt = {}; // +0x58: set once the set is built.
    // +0x59..+0x5b is alignment padding before the default alpha.
    // unsigned char m_aPad59[3]; // +0x59 (alignment padding, compiler-inserted)
    unsigned int m_nDefaultAlpha = {}; // +0x5c: the default sprite alpha (255).
    float m_flDefaultScale = {};       // +0x60: the default sprite scale (1.0).
    int m_nNetworkPlay =
        {}; // +0x64: set for a networked/online play (game type not single-player).
    // +0x68..+0x70: further layer state (transform vectors and per-cell fields) still being worked
    // out, kept as a reserved span to preserve the allocation size.
    unsigned char m_aReserved68[9] = {}; // +0x68
    bool m_bCustomizeReloadFlag =
        {}; // +0x71: set when a customize-character texture swap is pending.
    // +0x72..+0xb7: further layer state, still being worked out.
    unsigned char m_aReserved72[0x46] = {}; // +0x72
    // +0xb8..+0x12f: the five result-score/effect display animation channels.
    ResultBonusAnimChannel m_aScoreAnimChannels[kScoreAnimCount] = {}; // +0xb8
    Polygon2dTrail *m_apTrails[kTrailCount] = {};                      // +0x130: the ribbon trails.
    bool m_bScoreAnimActive =
        {}; // +0x150: set while the score animation (and gesture hold) is active.
    // +0x151..+0x153 is alignment padding before the gesture-hold timer.
    unsigned char m_aPad151[3] = {}; // +0x151
    float m_flGestureHoldTimer = {}; // +0x154: accumulates toward the gesture-hold release timeout.
    // +0x158..+0x15f: further layer state, still being worked out.
    unsigned char m_aReserved158[8] = {}; // +0x158
    int m_nPlayerLevel = {};  // +0x160: the player's level, copied from the game system.
    int m_nPlayerExp = {};    // +0x164: the player's experience, from the game system.
    int m_nGainedExp = {};    // +0x168: the experience gained this play (when levelling).
    int m_nExpThreshold = {}; // +0x16c: the level-up experience threshold.
    bool m_bReachedCap = {};  // +0x170: set when the level cap is reached (no threshold).
    // +0x171..+0x173 is alignment padding.
    unsigned char m_aPad171[3] = {}; // +0x171
    int m_nDisplayCounterA = {};     // +0x174: a per-round display counter, reset to zero.
    int m_nDisplayCounterB = {};     // +0x178: a second per-round display counter.
    bool m_bDisplayFlagC = {};       // +0x17c: a per-round display flag, reset to zero.
    // +0x17d..+0x17f is alignment padding.
    unsigned char m_aPad17d[3] = {}; // +0x17d
    int m_nLevelUpStep = {};         // +0x180: the level-up animation step.
    int m_nTrackIndexA = {};         // +0x184: a music-track index sentinel (-1 when unset).
    bool m_bCustomizePending = {};   // +0x188: whether a customize asset swap is pending.
    // +0x189..+0x18b is alignment padding.
    unsigned char m_aPad189[3] = {}; // +0x189
    int m_nUnlockStep = {};          // +0x18c: the unlock-progression step.
    int m_nTrackIndexB = {};         // +0x190: a second music-track index sentinel (-1).
    int m_nTrackIndexC = {};         // +0x194: the resolved music-track index (-1 when unset).
    // +0x198..+0x19f: further progression state, still being worked out.
    unsigned char m_aReserved198[8] = {}; // +0x198
    bool m_bCustomizePreviewShown = {}; // +0x1a0: whether the customize character preview is shown.
    // +0x1a1..+0x1a3 is alignment padding.
    unsigned char m_aPad1a1[3] = {};  // +0x1a1
    int m_nUnlockCounter = {};        // +0x1a4: an unlock counter, reset to zero.
    int m_nCustomizeCharacterId = {}; // +0x1a8: the shown customize character/costume id (-1 none).
    int m_nCustomizeSubId = {};       // +0x1ac: the customize character's cached unlock sub-id.
    int m_nCustomizePendingId = {}; // +0x1b0: the customize character id pending on the next toggle
                                    //         (-1 when none).
    bool m_bTwitterAvailable = {};  // +0x1b4: whether the Twitter share API is available.
    bool m_bPortrait = {};          // +0x1b5: selects the portrait position/separator tables.
    // +0x1b6..+0x1bf: trailing layer state, still being worked out.
    unsigned char m_aReserved1b6[0xa] = {}; // +0x1b6
};

// code: language=Objective-C++
// kate: hl Objective-C++;
// vim: set ft=objcpp :
