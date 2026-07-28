/**
 * @file
 * The Limelight-theme result-window layer, @c LimelightResultLayer.
 */

#pragma once

#include "playfieldlayerbase.h"
#include "result_bonus_anim_channel.h"

struct S_VECTOR2;
struct PartsDataRecord;
struct PhoneLayoutRecord;
struct PhoneLayoutRect;

namespace ne {
class C_TEXTURE;
class C_SPRITE_INSTANCING_2D;
} // namespace ne

/**
 * @brief The Limelight-theme result-window layer.
 *
 * A process-wide singleton, built on first access, deriving from @c PlayFieldLayerBase. It draws the
 * Limelight result panel through eight sprite instancers. The class carries no RTTI (it is
 * non-polymorphic), so the name is inferred from its singleton getter rather than confirmed from the
 * runtime metadata. Only the sprite-set fields used by @c InitializePhoneSpriteInstancers are modelled
 * so far; the remainder of the @c 0x170-byte layout is kept as a reserved span to preserve the
 * allocation size. The trailing @c // +0xNN comments document the original 32-bit offsets for
 * reference only.
 */
class LimelightResultLayer : public PlayFieldLayerBase {
public:
    // The number of result-screen bonus/EX display animation channels.
    static constexpr int kBonusAnimCount = 5;

    /**
     * @brief The process-wide Limelight result-window layer, created on first use.
     * @return The shared layer.
     * @ghidraAddress 0x123d54
     */
    static LimelightResultLayer *shared();

    /**
     * @brief Initialises the phone (portrait) result-window state at the start of the result screen.
     *
     * Marks the layer active, arms the bonus voice cue when the game system's result-bonus feature is
     * set, resets the bonus-cue timer, and records whether the Twitter share API is available.
     * @ghidraAddress 0x12ab60
     */
    void InitializePhoneResultLayer();

    /**
     * @brief Resets the five bonus/EX display animation channels to their zeroed initial state, each
     * easing from its current shown value to zero over @p flStartTime (snapping to zero immediately
     * when @p flStartTime is non-positive), and disarms the bonus voice cue.
     * @param flStartTime The animation base start time.
     * @ghidraAddress 0x124000
     */
    void ResetResultBonusAnimations(float flStartTime);

    /**
     * @brief Opens the five bonus/EX display channels for the phone result screen's appear animation.
     *
     * Each channel eases from its current shown value up to one; the first channel's duration is the
     * caller's base time (and it snaps to fully shown when that is non-positive), while the later
     * four use fixed durations and staggered elapsed seeds so they cascade in.
     * @param flBaseTime The appear animation's base time.
     * @ghidraAddress 0x123f60
     */
    void SetupOpenTweenPhone(float flBaseTime);

    /**
     * @brief Clears the five result-bonus display values and refreshes the current theme.
     *
     * Zeroes the clear, miss, rank, first-play, and experience bonus fields, then re-reads the user's
     * current theme (through the base layer's theme refresh).
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
     * With a null texture, or a zero-capacity instancer, only the instancer's texture is set (no slot
     * rescale).
     * @param nPhoneIndex The phone-instancer index.
     * @param pTexture The texture to bind, or null to clear it.
     * @ghidraAddress 0x123e8c
     */
    void SetPhoneInstancerTextureAndScale(unsigned int nPhoneIndex, ne::C_TEXTURE *pTexture);

    /**
     * @brief Returns the result-window parts descriptor at @p nIndex.
     *
     * Selects the pad or phone parts table by the current device kind.
     * @param nIndex The parts-record index (below @c 0xff).
     * @return The parts descriptor.
     * @ghidraAddress 0x123838
     */
    PartsDataRecord *GetPartsData(unsigned int nIndex) const;

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
     * Splits @p nValue into up to four decimal digits (at least one is drawn), centres the run about
     * @p position using a nominal seven-pixel glyph width, and emits each digit's glyph (bank base
     * @c 0x39 plus the digit) right to left through @c RenderPhoneResultSpriteById, stepping left by
     * each glyph's own width plus one pixel.
     * @param nValue The value to render (up to four digits).
     * @param pPosition The centre position of the digit run.
     * @param nAlpha The sprite alpha.
     * @ghidraAddress 0x12a11c
     */
    void RenderPhoneNumberDigitsRow(int nValue, const S_VECTOR2 *pPosition, unsigned int nAlpha);

    /**
     * @brief Renders a percentage value (a leading marker, digits, and a decimal point) in the phone
     * result layout.
     *
     * Splits @p nValue into up to four decimal digits (drawing at least two), centres the run about
     * @p pPosition using a fixed six-pixel glyph advance, draws the leading marker glyph, then each
     * digit (bank base @c 0x39 plus the digit) right to left, inserting the decimal-point glyph after
     * the ones digit.
     * @param nValue The percentage value (as an integer of tenths of a percent).
     * @param pPosition The centre position of the value.
     * @param nAlpha The sprite alpha.
     * @ghidraAddress 0x12a50c
     */
    void RenderPhonePercentValue(int nValue, const S_VECTOR2 *pPosition, unsigned int nAlpha);

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
     * the given rotation and scale. Character codes at or above the pad glyph bound are ignored. The
     * main pass draws at full intensity, the shadow pass at half.
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
     * appends the quad to the slot with the given rotation and scale. Character codes at or above the
     * pad glyph bound are ignored. The main pass draws at full intensity, the shadow pass at half.
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
     * Resolves the base position from the phone anchor table by @p nAnchorIndex, adds @p offset, and
     * renders the part by id at that position with unit Y scale, no rotation, and the main (undimmed)
     * pass.
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
     * @brief Emits one part sprite drawing a slot's whole bound texture, centred (half-size anchor).
     *
     * Sizes the quad by the texture's own scale factor, derives its UV rectangle from the used
     * image over its allocation, and centres it via a half-size anchor. The alpha is @p nScale times
     * the layer base scale; the colour intensity is taken from @p nIntensity. A no-op when the slot
     * is out of range or empty (the binary does not null-check the bound texture).
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
     * Splits @p nValue into up to four decimal digits (at least one is drawn), centres the run about
     * @p position using the zero-glyph advance, and emits each digit's glyph part right to left,
     * stepping left by each glyph's own width.
     * @param nValue The value to render (up to four digits).
     * @param position The centre position of the digit run.
     * @param nAlpha The sprite alpha.
     * @ghidraAddress 0x12705c
     */
    void RenderDigits(int nValue, const S_VECTOR2 &position, unsigned int nAlpha);

    /**
     * @brief Renders a multi-digit decimal number as right-aligned glyph sprites from a chosen glyph
     *        bank, with optional leading-zero padding and per-column layout tweaks.
     *
     * Splits @p nValue into up to @p nMaxDigits decimal digits and emits each digit's glyph (part id
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

    // The number of sprite-instancer slots the layer builds.
    static constexpr int kSpriteSlotCount = 8;

private:
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
     * Looks up the glyph's placement rectangle from the pad parts table indexed by @p nPartId and its
     * texture rectangle from the Limelight glyph UV palette, then appends the quad to the slot at
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

    // +0x08..+0x0f: descriptor state preceding the textures, still being worked out.
    unsigned char m_aReserved08[8] = {};      // +0x08
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
    // +0x78..+0xc3: further per-frame presentation state, still being worked out.
    unsigned char m_aReserved78[0x4c] = {};                            // +0x78
    ResultBonusAnimChannel m_aBonusAnimChannels[kBonusAnimCount] = {}; // +0xc4: the bonus/EX
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
    // rb::GameScene::ComputeResultBonusesAndExperience and cleared together by ResetThemeSelectState.
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
     * When the cue is armed, the timer accumulates the frame delta; once it passes the threshold the
     * cue is disarmed and themed voice 7 is loaded and played.
     * @param flDeltaTime The frame delta.
     * @ghidraAddress 0x1240a8
     */
    void UpdateBonusSoundCueTimer(float flDeltaTime);
};

// code: language=C++
// kate: hl C++;
// vim: set ft=cpp :
