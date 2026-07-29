/**
 * @file
 * The Limelight-theme result-window layer, @c LimelightResultLayer.
 */

#pragma once

#include "float_tween.h"
#include "playfieldlayerbase.h"

struct S_VECTOR2;
struct PartsDataRecord;
struct PhoneLayoutRecord;
struct PhoneLayoutRect;

namespace ne {
class C_TEXTURE;
class C_SPRITE_INSTANCING_2D;
} // namespace ne

/**
 * @brief One phone result-panel touch/button record: the tracked touch id, a pressed flag, a
 * tap-edge (just-released-inside) flag, and an initialised byte. The two flag bytes are together
 * the flags half-word the click latch writes as 0x100. The constructor resets the id to the "none"
 * sentinel and clears the flags.
 */
struct ResultButtonRecord {
    int nTouchId = {};  /*!< The tracked touch id (-1 when none). +0x00 */
    bool bDown = {};    /*!< Whether a tracked touch is currently pressing the button. +0x04 */
    bool bTapEdge = {}; /*!< Latched when a tracked touch is released inside the button. +0x05 */
    bool bInitialised = {};         /*!< Whether the button has been initialised. +0x06 */
    unsigned char m_aPad07[1] = {}; /*!< Alignment padding to the 8-byte stride. +0x07 */
};

/**
 * @brief The Limelight-theme result-window layer.
 *
 * A process-wide singleton, built on first access, deriving from @c PlayFieldLayerBase. It draws
 * the Limelight result panel through eight sprite instancers. The class carries no RTTI (it is
 * non-polymorphic), so the name is inferred from its singleton getter rather than confirmed from
 * the runtime metadata. Only the sprite-set fields used by @c InitializePhoneSpriteInstancers are
 * modelled so far; the remainder of the @c 0x170-byte layout is kept as a reserved span to preserve
 * the allocation size. The trailing @c // +0xNN comments document the original 32-bit offsets for
 * reference only.
 */
class LimelightResultLayer : public PlayFieldLayerBase {
public:
    // The number of result-screen bonus/EX display animation channels.
    static constexpr int kBonusAnimCount = 5;
    // The number of phone result-panel touch/button records.
    static constexpr int kButtonCount = 4;
    // The number of result-step animation slots.
    static constexpr int kStepAnimSlotCount = 2;

    /**
     * @brief The process-wide Limelight result-window layer, created on first use.
     * @return The shared layer.
     * @ghidraAddress 0x123d54
     */
    static LimelightResultLayer *shared();

    /**
     * @brief Initialises the phone (portrait) result-window state at the start of the result
     * screen.
     *
     * Marks the layer active, arms the bonus voice cue when the game system's result-bonus feature
     * is set, resets the bonus-cue timer, and records whether the Twitter share API is available.
     * @ghidraAddress 0x12ab60
     */
    void InitializePhoneResultLayer();

    /**
     * @brief The per-frame result-window update: advances the bonus tweens and decoration timers,
     * updates the bonus voice cue and the phone touch/share state, then dispatches to the Limelight
     * (iPad) or phone (portrait) render path.
     *
     * When the layer is not on an iPad it first recomputes the portrait-orientation flag from the
     * game system's viewport. It advances the five bonus channels, the signed slide/settle timer
     * (toward zero, at differing rates by sign), and the decoration rotation counter (wrapping
     * every 192 frames, its frame index the counter over 48, clamped to 0 through 3).
     * @param flDeltaTime The frame delta.
     * @ghidraAddress 0x12adac
     */
    void Update(float flDeltaTime);

    /**
     * @brief Renders the Limelight (iPad/landscape) result window for the current frame.
     *
     * Clears the eight instancers, then draws (when the window fade is non-zero) the panel frame
     * and furniture, the music jacket and character previews, the difficulty badge, the target
     * score and the signed distance from it, both sides' score gauges, the clear or failed stamp,
     * the grade badge, and the full-combo badge. It then cross-fades two sliding pages: the
     * per-side statistics table with its judgement counts, proportion gauges, and achievement-rate
     * comparison, and the bonus breakdown with its four rows and grand total. In the versus game
     * types the two page markers draw again at each page's own alpha. Positions come from the
     * load-time parts-anchor table.
     * @ghidraAddress 0x124acc
     */
    void RenderLimelightResultWindow();

    /**
     * @brief Renders the phone (portrait) result window for the current frame.
     *
     * The phone-layout twin of @c RenderLimelightResultWindow: it clears the eight instancers, then
     * draws the backdrop, side rail, header bar, and footer band, two nine-patch panel boxes and
     * the panel rules, the jacket and character previews (from the captured image in portrait), the
     * score fields, the grade and full-combo badges, and the clear, failed, or winner stamp. It
     * then cross-fades the statistics page (a nine-patch box, the column headings, and one
     * eight-column row per side) against the bonus breakdown page, and lights the page dot for the
     * selected page. Positions are resolved through the phone anchor tables rather than read from
     * the parts-anchor table.
     * @ghidraAddress 0x127b04
     */
    void RenderPhoneResultWindow();

    /**
     * @brief Updates the phone result screen's touch handling and Twitter-share button.
     *
     * Enables the gesture buttons once the panel is fully shown, runs the four phone-part buttons,
     * then tracks the centre side-slider: a horizontal drag past the threshold toggles the slider
     * value (with a themed sound) in single-player, and the share button's tap edge posts the
     * result to Twitter (dark-title variant).
     * @ghidraAddress 0x1240ec
     */
    void UpdatePhoneTouchAndShare();

    /**
     * @brief Updates the four phone-part result buttons' touch state and publishes the overall
     * pressed state.
     *
     * For each button it claims an active touch whose position falls inside the button's
     * by-state anchor rectangle, tracks it while it presses, and latches a tap-edge when the touch
     * is released inside. After the four buttons it publishes the overall pressed state: one while
     * any touch is active, the just-released latch on the frame the last touch ends, otherwise
     * zero.
     * @ghidraAddress 0x12434c
     */
    void UpdatePhonePartTouchStates();

    /**
     * @brief Whether the result screen's confirm button has been tapped this play.
     *
     * The confirm signal is the first phone-part button's tap-edge latch; the result-finalise state
     * polls it to know the player has acknowledged the result.
     * @return @c true once the confirm button's tap edge has latched.
     */
    bool IsResultConfirmed() const {
        return m_aButtons[0].bTapEdge;
    }

    /** @brief Clears the result-confirm tap-edge latch. */
    void ClearResultConfirmed() {
        m_aButtons[0].bTapEdge = false;
    }

    /**
     * @brief Resets the five bonus/EX display animation channels to their zeroed initial state,
     * each easing from its current shown value to zero over @p flStartTime (snapping to zero
     * immediately when @p flStartTime is non-positive), and disarms the bonus voice cue.
     * @param flStartTime The animation base start time.
     * @ghidraAddress 0x124000
     */
    void ResetResultBonusAnimations(float flStartTime);

    /**
     * @brief Opens the five bonus/EX display channels for the phone result screen's appear
     * animation.
     *
     * Each channel eases from its current shown value up to one; the first channel's duration is
     * the caller's base time (and it snaps to fully shown when that is non-positive), while the
     * later four use fixed durations and staggered elapsed seeds so they cascade in.
     * @param flBaseTime The appear animation's base time.
     * @ghidraAddress 0x123f60
     */
    void SetupOpenTweenPhone(float flBaseTime);

    /**
     * @brief Clears the five result-bonus display values and refreshes the current theme.
     *
     * Zeroes the clear, miss, rank, first-play, and experience bonus fields, then re-reads the
     * user's current theme (through the base layer's theme refresh).
     * @ghidraAddress 0x123da4
     */
    void ResetThemeSelectState();

    /**
     * @brief Lazily builds the eight result-window sprite instancers: loads the two atlases and
     * creates each instancer (registering it in the global scene tree, making it visible, binding
     * the edge slots' textures, and clearing its sprite count).
     *
     * Guarded so the sprites are built only once.
     * @ghidraAddress 0x123db0
     */
    void InitializePhoneSpriteInstancers();

    /**
     * @brief Binds a texture to one phone sprite instancer and rescales all its slots to the
     * texture's dimensions.
     *
     * With a null texture, or a zero-capacity instancer, only the instancer's texture is set (no
     * slot rescale).
     * @param nPhoneIndex The phone-instancer index.
     * @param pTexture The texture to bind, or null to clear it.
     * @ghidraAddress 0x123e8c
     */
    void SetPhoneInstancerTextureAndScale(unsigned int nPhoneIndex, ne::C_TEXTURE *pTexture);

    /**
     * @brief Returns the result-window parts descriptor at @p nIndex.
     *
     * Selects the pad or phone parts table by the current device kind. The routine takes only the
     * index (in @c x0) and never touches the layer, so it is a static member rather than an
     * instance method.
     * @param nIndex The parts-record index (below @c 0xff).
     * @return The parts descriptor.
     * @ghidraAddress 0x123838
     */
    static PartsDataRecord *GetPartsData(unsigned int nIndex);

    /**
     * @brief Resolves a phone-layout anchor position by index, offset relative to the play field.
     *
     * Looks up a @c PhoneAnchorRecord from the portrait or default table (selected by the layer's
     * orientation flag), copies its base coordinate, then shifts it by the play-field viewport's
     * half or full width and height per the record's anchor mode.
     * @param nIndex The position-record index (0 through 87).
     * @param pOutPosition Receives the resolved position.
     * @ghidraAddress 0x123940
     */
    void getPosition_Phone(int nIndex, S_VECTOR2 *pOutPosition) const;

    /**
     * @brief Resolves a by-state phone-layout rectangle by index, offset relative to the play
     * field.
     *
     * Selects the state table on the iPad, otherwise the portrait or default table by the
     * orientation flag; copies the record's four floats to @p pOutRect, then shifts the leading
     * coordinate by the viewport's half or full width and height per the record's anchor mode.
     * @param nIndex The position-record index (0 through 3).
     * @param pOutRect Receives the resolved rectangle.
     * @ghidraAddress 0x123b5c
     */
    void getPositionByState_Phone(int nIndex, PhoneLayoutRect *pOutRect) const;

    /**
     * @brief Returns a phone-layout glyph descriptor by index.
     *
     * Always reads the pad parts table (which doubles as the phone glyph-metrics table), regardless
     * of device kind.
     * @param nIndex The glyph-record index (0 through 141).
     * @return The glyph descriptor.
     * @ghidraAddress 0x1238d0
     */
    static PartsDataRecord *getPartsData_Phone(int nIndex);

    /**
     * @brief Returns a phone-layout separator record by index.
     *
     * Selects the portrait or default separator table by the layer's orientation flag and returns
     * the record at @p nIndex.
     * @param nIndex The separator-record index (0 through 51).
     * @return The separator record.
     * @ghidraAddress 0x123ad8
     */
    const PhoneLayoutRecord *getSeparator_Phone(int nIndex) const;

    /**
     * @brief Resolves the single phone-layout centre-position rectangle, offset by the viewport.
     *
     * Copies the state, portrait, or default centre record (selected by the is-pad flag and
     * orientation flags) to @p pOutRect. When the state flag is clear the leading coordinate is
     * shifted by half the viewport width and height.
     * @param pOutRect Receives the resolved rectangle.
     * @ghidraAddress 0x123cc8
     */
    void getCenterPosition_Phone(PhoneLayoutRect *pOutRect) const;

    /**
     * @brief Renders a small unsigned integer as centred phone digit-glyph sprites.
     *
     * Splits @p nValue into up to four decimal digits (at least one is drawn), centres the run
     * about
     * @p position using a nominal seven-pixel glyph width, and emits each digit's glyph (bank base
     * @c 0x39 plus the digit) right to left through @c RenderPhoneResultSpriteById, stepping left
     * by each glyph's own width plus one pixel.
     * @param nValue The value to render (up to four digits).
     * @param pPosition The centre position of the digit run.
     * @param nAlpha The sprite alpha.
     * @ghidraAddress 0x12a11c
     */
    void RenderPhoneNumberDigitsRow(int nValue, const S_VECTOR2 *pPosition, unsigned int nAlpha);

    /**
     * @brief Renders a multi-digit decimal number in the phone result layout, right to left from a
     * position plus offset.
     *
     * Splits @p nValue into up to @p nMaxDigits digits, tracking the significant count; when the
     * value is zero and @p nFlags bit 0 is set, one digit is still drawn. Starting from
     * @p pPosition plus @p pOffset, each significant digit's glyph (@p nBasePartId plus the digit)
     * is drawn and the cursor stepped left by that glyph's own width less @p flSpacing; when the
     * paired flag is set, a second glyph ten ids above the base is drawn beside the ones digit.
     * When
     * @p bPadZeros is set, the remaining leading positions are filled with the base glyph in a
     * dimmed pass.
     * @param flSpacing The spacing subtracted from each glyph's width when advancing.
     * @param nValue The value to render.
     * @param nMaxDigits The maximum number of digits.
     * @param pPosition The base position.
     * @param pOffset The offset added to the base position.
     * @param nBasePartId The glyph part id of the digit zero.
     * @param nFlags Bit 0 forces a zero digit and enables the paired ones-place glyph.
     * @param bPadZeros Whether to dim-pad the leading positions to @p nMaxDigits.
     * @param nAlpha The sprite alpha.
     * @ghidraAddress 0x129d04
     */
    void RenderPhoneNumber(float flSpacing,
                           int nValue,
                           int nMaxDigits,
                           const S_VECTOR2 *pPosition,
                           const S_VECTOR2 *pOffset,
                           unsigned int nBasePartId,
                           unsigned int nFlags,
                           int bPadZeros,
                           unsigned int nAlpha);

    /**
     * @brief Renders the result screen's total-score digits in the phone result layout.
     *
     * Sums the five result-bonus values, scales the total to tenths, and renders up to seven digits
     * right to left from @p pPosition: the ones place from one glyph bank and the higher places
     * from another, with a marker glyph drawn below the ones digit. At least two digits are drawn;
     * alpha is halved for the leading positions beyond the significant digits.
     * @param pPosition The right edge of the digit run.
     * @param nAlpha The sprite alpha.
     * @ghidraAddress 0x12a928
     */
    void RenderPhoneTotalScoreDigits(const S_VECTOR2 *pPosition, unsigned int nAlpha);

    /**
     * @brief Renders a multiplier value (in tenths) in the phone result layout.
     *
     * Scales @p flMultiplier to tenths, splits it into up to three digits, and draws them right to
     * left from @p pPosition using the multiplier glyph bank, inserting a marker glyph beside the
     * ones digit. At least two digits are drawn; alpha is halved for the leading positions beyond
     * the significant digits.
     * @param flMultiplier The multiplier value.
     * @param pPosition The right edge of the digit run.
     * @param nAlpha The sprite alpha.
     * @ghidraAddress 0x12a760
     */
    void RenderPhoneMultiplierDigitSprites(float flMultiplier,
                                           const S_VECTOR2 *pPosition,
                                           unsigned int nAlpha);

    /**
     * @brief Renders a percentage value (a leading marker, digits, and a decimal point) in the
     * phone result layout.
     *
     * Splits @p nValue into up to four decimal digits (drawing at least two), centres the run about
     * @p pPosition using a fixed six-pixel glyph advance, draws the leading marker glyph, then each
     * digit (bank base @c 0x39 plus the digit) right to left, inserting the decimal-point glyph
     * after the ones digit.
     * @param nValue The percentage value (as an integer of tenths of a percent).
     * @param pPosition The centre position of the value.
     * @param nAlpha The sprite alpha.
     * @ghidraAddress 0x12a50c
     */
    void RenderPhonePercentValue(int nValue, const S_VECTOR2 *pPosition, unsigned int nAlpha);

    /**
     * @brief Renders a fraction (@p nNumerator over @p nDenominator) in the phone result layout.
     *
     * Centres the whole run about @p pPosition using a nominal seven-pixel per-digit width, then
     * draws the denominator digits right to left, a separating slash glyph, and the numerator
     * digits, so the fraction reads numerator-slash-denominator left to right. Each digit steps the
     * cursor left by seven pixels (drawn at a six-pixel inset); the slash steps by one (drawn at a
     * seven-pixel inset).
     * @param nNumerator The fraction's numerator (up to four digits).
     * @param nDenominator The fraction's denominator (up to four digits).
     * @param pPosition The centre position of the fraction.
     * @param nAlpha The sprite alpha.
     * @ghidraAddress 0x12a27c
     */
    void RenderPhoneFraction(int nNumerator,
                             int nDenominator,
                             const S_VECTOR2 *pPosition,
                             unsigned int nAlpha);

    /**
     * @brief Emits one result-window part sprite by part id.
     *
     * Looks up the part's placement rectangle and UV-palette entry, then appends a quad to the
     * layer's shared instancer slot. Part id @c 0xff is a no-op used to skip optional parts. The
     * main pass draws at full alpha; the shadow pass draws the same quad at half intensity.
     * @param flRotation The sprite rotation, in radians.
     * @param flScaleX The sprite X scale.
     * @param flScaleY The sprite Y scale.
     * @param nSlot The instancer slot to append to.
     * @param nPartId The part id (below @c 0xff).
     * @param position The sprite's world position.
     * @param nAlpha The sprite's alpha.
     * @param bShadowPass Whether this is the half-intensity shadow pass.
     * @ghidraAddress 0x126ab4
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
     * @brief Emits one part sprite drawing a slot's whole bound texture at the given size.
     *
     * The texture's used-image fraction of its power-of-two allocation becomes the sprite's UV
     * rectangle. A no-op when the slot is out of range, empty, or unbound.
     * @param nSlot The instancer slot (0 through 7).
     * @param position The sprite's world position.
     * @param size The sprite's pixel size.
     * @param nAlpha The sprite's alpha.
     * @ghidraAddress 0x126b78
     */
    void EmitTexturedPart(unsigned long nSlot,
                          const S_VECTOR2 &position,
                          const S_VECTOR2 &size,
                          unsigned int nAlpha);
    /**
     * @brief Emits one part sprite from a slot's bound texture, deriving both the pixel size (the
     *        texture's used size over its scale) and the UV rectangle (the used fraction of the
     *        allocation), and scaling the alpha by the layer's fade factor.
     * @param nSlot The instancer slot (0 through 7).
     * @param position The sprite's world position.
     * @param nBaseAlpha The base alpha, scaled by the layer fade.
     * @ghidraAddress 0x126c34
     */
    void EmitAutoUvPart(unsigned long nSlot, const S_VECTOR2 &position, unsigned int nBaseAlpha);

    /**
     * @brief Emits one glyph sprite at a resolved position index plus an offset, dimmable.
     *
     * Resolves the base position from the phone anchor table by @p nPositionIndex, adds @p offset,
     * looks up the glyph placement rectangle from the pad parts table by @p nCharCode and its
     * texture rectangle from the Limelight glyph UV palette, then appends the quad to the slot with
     * the given rotation and scale. Character codes at or above the pad glyph bound are ignored.
     * The main pass draws at full intensity, the shadow pass at half.
     * @param nSlot The instancer slot to append to.
     * @param nCharCode The glyph character code (below the pad glyph bound).
     * @param nPositionIndex The phone anchor-position index.
     * @param offset The offset added to the resolved position.
     * @param nAlpha The glyph alpha.
     * @param bShadowPass Whether this is the half-intensity shadow pass.
     * @param flRotation The glyph rotation, in radians.
     * @param flScaleX The glyph X scale.
     * @param flScaleY The glyph Y scale.
     * @ghidraAddress 0x12a01c
     */
    void RenderPhonePartWithOffset(unsigned int nSlot,
                                   unsigned int nCharCode,
                                   int nPositionIndex,
                                   const S_VECTOR2 &offset,
                                   unsigned int nAlpha,
                                   bool bShadowPass,
                                   float flRotation,
                                   float flScaleX,
                                   float flScaleY);

    /**
     * @brief Emits one glyph sprite at a position plus an offset, dimmable.
     *
     * Looks up the glyph placement rectangle from the pad parts table by @p nCharCode and its
     * texture rectangle from the Limelight glyph UV palette, adds @p offset to @p position, and
     * appends the quad to the slot with the given rotation and scale. Character codes at or above
     * the pad glyph bound are ignored. The main pass draws at full intensity, the shadow pass at
     * half.
     * @param nSlot The instancer slot to append to.
     * @param nCharCode The glyph character code (below the pad glyph bound).
     * @param position The glyph's base position.
     * @param offset The offset added to the base position.
     * @param nAlpha The glyph alpha.
     * @param bShadowPass Whether this is the half-intensity shadow pass.
     * @param flRotation The glyph rotation, in radians.
     * @param flScaleX The glyph X scale.
     * @param flScaleY The glyph Y scale.
     * @ghidraAddress 0x129f84
     */
    void EmitPhonePartWithOffset(unsigned int nSlot,
                                 unsigned int nCharCode,
                                 const S_VECTOR2 &position,
                                 const S_VECTOR2 &offset,
                                 unsigned int nAlpha,
                                 bool bShadowPass,
                                 float flRotation,
                                 float flScaleX,
                                 float flScaleY);

    /**
     * @brief Emits one result part at a phone layout anchor plus an offset (a convenience wrapper).
     *
     * Resolves the base position from the phone anchor table by @p nAnchorIndex, adds @p offset,
     * and renders the part by id at that position with unit Y scale, no rotation, and the main
     * (undimmed) pass.
     * @param nSlot The instancer slot to append to.
     * @param nPartId The result-part id.
     * @param nAnchorIndex The phone anchor-position index.
     * @param pOffset The offset added to the resolved position.
     * @param nAlpha The part alpha.
     * @param flScaleX The part X scale.
     * @ghidraAddress 0x12a6cc
     */
    void EmitPhonePartAtAnchor(unsigned int nSlot,
                               unsigned int nPartId,
                               unsigned int nAnchorIndex,
                               const S_VECTOR2 *pOffset,
                               unsigned int nAlpha,
                               float flScaleX);

    /**
     * @brief Emits one part sprite drawing a slot's whole bound texture, centred (half-size
     * anchor).
     *
     * Sizes the quad by the texture's own scale factor, derives its UV rectangle from the used
     * image over its allocation, and centres it via a half-size anchor. The alpha is @p nScale
     * times the layer base scale; the colour intensity is taken from @p nIntensity. A no-op when
     * the slot is out of range or empty (the binary does not null-check the bound texture).
     * @param nSlot The instancer slot (0 through 7).
     * @param position The sprite's centre position.
     * @param nScale The scale units multiplied into the alpha.
     * @param nIntensity The sprite colour intensity.
     * @ghidraAddress 0x129c34
     */
    void EmitPhoneHalfScaleTexturedPart(unsigned int nSlot,
                                        const S_VECTOR2 &position,
                                        unsigned int nScale,
                                        unsigned int nIntensity);

    /**
     * @brief Renders a small unsigned integer as centred Limelight digit-glyph sprites.
     *
     * Splits @p nValue into up to four decimal digits (at least one is drawn), centres the run
     * about
     * @p position using the zero-glyph advance, and emits each digit's glyph part right to left,
     * stepping left by each glyph's own width.
     * @param nValue The value to render (up to four digits).
     * @param position The centre position of the digit run.
     * @param nAlpha The sprite alpha.
     * @ghidraAddress 0x12705c
     */
    void RenderDigits(int nValue, const S_VECTOR2 &position, unsigned int nAlpha);

    /**
     * @brief Renders a multi-digit decimal number as right-aligned glyph sprites from a chosen
     * glyph bank, with optional leading-zero padding and per-column layout tweaks.
     *
     * Splits @p nValue into up to @p nMaxDigits decimal digits and emits each digit's glyph (part
     * id
     * @p nBasePartId plus the digit) right to left, advancing by each glyph's width less
     * @p flSpacing. The score and rating columns carry paired glyphs and small vertical or
     * horizontal alignment nudges; when @p bPadZeros is set, the remaining leading positions are
     * drawn as dimmed grey zeros.
     * @param flSpacing The extra gap subtracted between glyphs.
     * @param nValue The value to render.
     * @param nMaxDigits The maximum number of digits.
     * @param position The right-hand start position of the run.
     * @param nBasePartId The glyph bank's base part id (its '0').
     * @param bPaired Whether to draw the column's paired second glyph and shifted first glyph.
     * @param bPadZeros Whether to pad the leading positions with dimmed zeros.
     * @param nAlpha The glyph alpha.
     * @ghidraAddress 0x126cf8
     */
    void RenderNumber(float flSpacing,
                      int nValue,
                      int nMaxDigits,
                      const S_VECTOR2 &position,
                      unsigned int nBasePartId,
                      bool bPaired,
                      bool bPadZeros,
                      unsigned int nAlpha);

    /**
     * @brief Renders a value with a decimal-point glyph inserted after the ones digit.
     *
     * Emits up to four digit glyphs right to left (at least two are drawn), inserting the point
     * glyph after the least-significant digit; used for the rate percentage such as 98.7.
     * @param nValue The value to render (the point sits after its ones digit).
     * @param position The right-hand start position.
     * @param nAlpha The glyph alpha.
     * @ghidraAddress 0x1274b0
     */
    void RenderPercentValue(int nValue, const S_VECTOR2 &position, unsigned int nAlpha);

    /**
     * @brief Renders a "denominator / numerator" fraction as digit glyphs with a slash glyph.
     *
     * Centres the combined run about @p position using the uniform zero-glyph advance, draws the
     * denominator digits right to left, then the slash glyph, then the numerator digits.
     * @param nNumerator The numerator value.
     * @param nDenominator The denominator value.
     * @param position The centre position of the run.
     * @param nAlpha The glyph alpha.
     * @ghidraAddress 0x1271f4
     */
    void RenderFraction(int nNumerator,
                        int nDenominator,
                        const S_VECTOR2 &position,
                        unsigned int nAlpha);

    /**
     * @brief Renders the result screen's total-score digits in the Limelight (pad) layout.
     *
     * Sums the five result-bonus values, scales the total to tenths, and draws up to seven places
     * right to left from @p pPosition: the ones place from one glyph bank and the higher places
     * from another, with a separator glyph beside the ones digit. At least two places are drawn;
     * the leading places beyond the significant digits draw at half alpha. The cursor steps left by
     * each glyph's own width plus a fixed gap, but only by the gap across the separator.
     * @param pPosition The right edge of the digit run.
     * @param nAlpha The sprite alpha.
     * @ghidraAddress 0x1278a0
     */
    void RenderLimelightTotalScore(const S_VECTOR2 *pPosition, unsigned int nAlpha);

    /**
     * @brief Renders a one-decimal rating value as small glyph sprites with a decimal point.
     *
     * Scales @p flValue by ten and splits it into up to three digits (at least two), emitting each
     * from the rating glyph bank right to left with a per-glyph vertical offset; inserts the point
     * glyph after the ones digit and halves the alpha for the fractional digit.
     * @param flValue The rating value.
     * @param position The right-hand start position.
     * @param nAlpha The glyph alpha.
     * @ghidraAddress 0x127680
     */
    void RenderRatingValue(float flValue, const S_VECTOR2 &position, unsigned int nAlpha);

    /** @brief Stores the five result-bonus display values computed at the end of a play. */
    void SetResultBonuses(
        float flClear, float flMiss, float flRank, float flFirstPlay, float flExperience) {
        m_flClearBonus = flClear;
        m_flMissBonus = flMiss;
        m_flRankBonus = flRank;
        m_flFirstPlayBonus = flFirstPlay;
        m_flExperienceBonus = flExperience;
    }

    /** @brief Stores the pair of result score values the scene seeds at set-up. */
    void SetResultScores(int nScore, int nScoreHi) {
        m_nResultScore = nScore;
        m_nResultScoreHi = nScoreHi;
    }

    // The number of sprite-instancer slots the layer builds.
    static constexpr int kSpriteSlotCount = 8;

private:
    /**
     * @brief Constructs the layer: chains the base-layer constructor, then zero-clears its state
     * and seeds the non-zero defaults — the default part alpha (255), the current-step and
     * per-button touch-id "none" sentinels (-1), and the cleared flags. The binary inlines this
     * into @c shared.
     * @ghidraAddress 0x12abb4
     */
    LimelightResultLayer();

    /**
     * @brief Emits one phone-layout part sprite positioned relative to a separator field, offset by
     * a caller-supplied delta.
     *
     * A no-op when the part index or separator index is out of range. The part's anchor, size, and
     * atlas frame come from the pad parts table (the frame indexing the glyph UV palette); the
     * position is the separator record's base, viewport-anchored by its anchor mode, plus the
     * offset delta. The separator record's carried width and height supply the sprite's X scale and
     * rotation. The sprite draws opaque white at the given alpha.
     * @param nSlot The target sprite slot.
     * @param nSeparatorIndex The separator-record index (0 through 51).
     * @param nPartIndex The part index (0 through 141) into the pad parts table.
     * @param pOffset The position offset added to the separator base.
     * @param nAlpha The sprite alpha.
     * @ghidraAddress 0x129a64
     */
    void RenderPhoneSpriteFieldAligned(unsigned int nSlot,
                                       unsigned int nSeparatorIndex,
                                       unsigned int nPartIndex,
                                       const S_VECTOR2 *pOffset,
                                       unsigned int nAlpha);

    // Appends one fully-specified quad to a slot's sprite instancer, if the slot exists and is not
    // full; the shared low-level emit behind all the part helpers.
    // @ghidraAddress 0x12ac64
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

    /**
     * @brief Emits one glyph sprite from the pad parts table by part id, dimmable.
     *
     * Looks up the glyph's placement rectangle from the pad parts table indexed by @p nPartId and
     * its texture rectangle from the Limelight glyph UV palette, then appends the quad to the slot
     * at
     * @p position with the given rotation and scale. Part ids at or above the pad glyph table count
     * are ignored. The main pass draws at full intensity, the dimmed pass at half.
     * @param nSlot The instancer slot to append to.
     * @param nPartId The glyph part id (below the pad glyph table count).
     * @param position The glyph's world position.
     * @param nAlpha The glyph alpha.
     * @param bDimmed Whether this is the half-intensity dimmed pass.
     * @param flRotation The glyph rotation, in radians.
     * @param flScaleX The glyph X scale.
     * @param flScaleY The glyph Y scale.
     * @ghidraAddress 0x1299d8
     */
    void RenderPhoneResultSpriteById(unsigned int nSlot,
                                     unsigned int nPartId,
                                     const S_VECTOR2 &position,
                                     unsigned int nAlpha,
                                     bool bDimmed,
                                     float flRotation,
                                     float flScaleX,
                                     float flScaleY);

    // +0x08: the overall phone-part pressed state, published each frame: 1 while any touch is
    // active, 0x100 on the frame the last touch releases, else 0.
    unsigned short m_nPressedState = {}; // +0x08
    // +0x0a: set on a frame the side-slider commits a left/right swipe, cleared otherwise.
    bool m_bSliderSwiped = {}; // +0x0a
    // +0x0b..+0x0f: further descriptor state preceding the textures, still being worked out.
    unsigned char m_aReserved0b[5] = {};      // +0x0b
    ne::C_TEXTURE *m_pBackgroundTexture = {}; // +0x10: the selection-background atlas.
    ne::C_TEXTURE *m_pPartsTexture = {};      // +0x18: the result-parts atlas.
    ne::C_TEXTURE *m_pOverlayTexture = {};    // +0x20: the overlay atlas (left unset).
    ne::C_SPRITE_INSTANCING_2D *m_apSprites[kSpriteSlotCount] =
        {};                // +0x28: the per-slot sprite batches.
    bool m_bBuilt = {};    // +0x68: set once the sprites are built.
    bool m_bPortrait = {}; // +0x69: selects the portrait phone anchor-position table.
    // +0x6a..+0x6b is alignment padding before the default alpha.
    // unsigned char m_aPad6a[2]; // +0x6a (alignment padding, compiler-inserted)
    int m_nDefaultAlpha = {}; // +0x6c: default alpha (255), cleared to 0 when the set is built.
    float m_flBaseScale = {}; // +0x70: a base scale the builder seeds (0.7).
    int m_nActive = {};       // +0x74: set once the phone result screen is initialised and running.
    float m_flSlideTimer =
        {}; // +0x78: a signed slide/settle timer, advanced toward zero each frame.
    // +0x7c: the four phone result-panel touch/button records the constructor seeds (each a touch
    // id reset to -1, a flags half-word, and an initialised byte).
    ResultButtonRecord m_aButtons[kButtonCount] = {}; // +0x7c
    // +0x9c: the current result step index, reset to -1 (the "none" sentinel). The phone
    // touch/share handler reuses this slot as the side-slider's tracked touch id (also the "none"
    // sentinel).
    int m_nCurrentStep = {};     // +0x9c
    float m_flSliderStartX = {}; // +0xa0: the side-slider touch's start X, for the drag threshold.
    int m_nRotationCounter =
        {};                    // +0xa4: the decoration rotation counter, wrapping each 192 frames.
    int m_nRotationFrame = {}; // +0xa8: the decoration animation frame index (0 through 3).
    // +0xac..+0xc3: the two result-step animation slots the constructor clears (three parallel int
    // fields per slot at +0xac, +0xb4, and +0xbc, stride 4).
    int m_aStepAnimA[kStepAnimSlotCount] = {};             // +0xac
    int m_aStepAnimB[kStepAnimSlotCount] = {};             // +0xb4
    int m_aStepAnimC[kStepAnimSlotCount] = {};             // +0xbc
    FloatTween m_aBonusAnimChannels[kBonusAnimCount] = {}; // +0xc4: the bonus/EX
                                                           //        animation channels.
    bool m_bBonusCueArmed = {}; // +0x13c: whether the bonus voice cue is still pending.
    // +0x13d..+0x13f is alignment padding before the bonus-cue timer.
    unsigned char m_aPad13d[3] = {}; // +0x13d
    float m_flBonusCueTimer = {};    // +0x140: time accumulated toward the bonus voice cue.
    // +0x144..+0x14b: further presentation state, still being worked out.
    unsigned char m_aReserved144[8] = {}; // +0x144
    bool m_bTwitterAvailable = {};        // +0x14c: whether the Twitter share API is available.
    // +0x14d..+0x14f is alignment padding before the bonus values.
    unsigned char m_aPad14d[3] = {}; // +0x14d
    // +0x150..+0x163: the five result-bonus display values, computed by
    // rb::GameScene::ComputeResultBonusesAndExperience and cleared together by
    // ResetThemeSelectState.
    float m_flClearBonus = {};     // +0x150: the clear bonus.
    float m_flMissBonus = {};      // +0x154: the miss (full-combo/miss1/miss2) bonus.
    float m_flRankBonus = {};      // +0x158: the rank (B/A/AA/AAA/AAAP) bonus.
    float m_flFirstPlayBonus = {}; // +0x15c: the first-play bonus (plus any pastel field bonus).
    float m_flExperienceBonus =
        {};                    // +0x160: the experience-point total shown on the result screen.
    int m_nResultScore = {};   // +0x164: the result score value seeded from the scene.
    int m_nResultScoreHi = {}; // +0x168: the second result score value seeded from the scene.
    // unsigned char m_aReserved16c[4]; // +0x16c (trailing pad to the 0x170-byte allocation)

    /**
     * @brief Advances the bonus voice-cue timer and fires the cue once past its threshold.
     *
     * When the cue is armed, the timer accumulates the frame delta; once it passes the threshold
     * the cue is disarmed and themed voice 7 is loaded and played.
     * @param flDeltaTime The frame delta.
     * @ghidraAddress 0x1240a8
     */
    void UpdateBonusSoundCueTimer(float flDeltaTime);
};

// code: language=C++
// kate: hl C++;
// vim: set ft=cpp :
