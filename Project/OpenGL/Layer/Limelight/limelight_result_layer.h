/**
 * @file
 * The Limelight-theme result-window layer, @c LimelightResultLayer.
 */

#pragma once

#include "playfieldlayerbase.h"

struct S_VECTOR2;
struct PartsDataRecord;

namespace ne {
class C_TEXTURE;
class C_SPRITE_INSTANCING;
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
    /**
     * @brief The process-wide Limelight result-window layer, created on first use.
     * @return The shared layer.
     * @ghidraAddress 0x123d54
     */
    static LimelightResultLayer *shared();

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
     * @brief Returns the result-window parts descriptor at @p nIndex.
     *
     * Selects the pad or phone parts table by the current device kind.
     * @param nIndex The parts-record index (below @c 0xff).
     * @return The parts descriptor.
     * @ghidraAddress 0x123838
     */
    PartsDataRecord *GetPartsData(unsigned int nIndex) const;

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
     * @param bShadowPass Non-zero for the half-intensity shadow pass.
     * @ghidraAddress 0x126ab4
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
     * @param bPaired Non-zero to draw the column's paired second glyph and shifted first glyph.
     * @param bPadZeros Non-zero to pad the leading positions with dimmed zeros.
     * @param nAlpha The glyph alpha.
     * @ghidraAddress 0x126cf8
     */
    void RenderNumber(float flSpacing,
                      int nValue,
                      int nMaxDigits,
                      const S_VECTOR2 &position,
                      unsigned int nBasePartId,
                      unsigned int bPaired,
                      int bPadZeros,
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
    // +0x08..+0x0f: descriptor state preceding the textures, still being worked out.
    unsigned char m_aReserved08[8] = {};      // +0x08
    ne::C_TEXTURE *m_pBackgroundTexture = {}; // +0x10: the selection-background atlas.
    ne::C_TEXTURE *m_pPartsTexture = {};      // +0x18: the result-parts atlas.
    ne::C_TEXTURE *m_pOverlayTexture = {};    // +0x20: the overlay atlas (left unset).
    ne::C_SPRITE_INSTANCING *m_apSprites[kSpriteSlotCount] =
        {};             // +0x28: the per-slot sprite batches.
    bool m_bBuilt = {}; // +0x68: set once the sprites are built.
    // +0x69..+0x6b is alignment padding before the default alpha.
    // unsigned char m_aPad69[3]; // +0x69 (alignment padding, compiler-inserted)
    int m_nDefaultAlpha = {}; // +0x6c: default alpha (255), cleared to 0 when the set is built.
    float m_flBaseScale = {}; // +0x70: a base scale the builder seeds (0.7).
    // +0x74..+0x13b: the remaining per-frame presentation state (tweens, slide timer, frame index),
    // still being worked out, kept as a reserved span to preserve the allocation size.
    unsigned char m_aReserved74[0xc8] = {}; // +0x74
    bool m_bBonusCueArmed = {};             // +0x13c: whether the bonus voice cue is still pending.
    // +0x13d..+0x13f is alignment padding before the bonus-cue timer.
    unsigned char m_aPad13d[3] = {}; // +0x13d
    float m_flBonusCueTimer = {};    // +0x140: time accumulated toward the bonus voice cue.
    // +0x144..+0x16f: the remaining layer state, still being worked out.
    unsigned char m_aReserved144[0x2c] = {}; // +0x144

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
