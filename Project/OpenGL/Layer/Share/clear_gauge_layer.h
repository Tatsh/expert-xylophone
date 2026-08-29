/**
 * @file
 * The play-field clear-gauge layer, @c ClearGaugeLayer.
 */

#pragma once

#include "playfieldlayerbase.h"

struct GaugeGlyphDesc;
struct S_VECTOR2;

namespace ne {
class C_SPRITE_INSTANCING_2D;
class C_TEXTURE;
} // namespace ne

/**
 * The play-field clear-gauge layer.
 *
 * Draws each player side's clear gauge as a set of sprite batches over the background scene node.
 * It derives from @c PlayFieldLayerBase and is a process-wide singleton built on first access. The
 * trailing @c // +0xNN comments document the original 32-bit member offsets for reference only; the
 * object is always reached through named fields. Some of the layer's sprite-slot state between the
 * base fields and the recovered members below is still being worked out.
 */
class ClearGaugeLayer : public PlayFieldLayerBase {
public:
    /** The number of player sides the gauge tracks. */
    static constexpr int kSideCount = 2;
    /** The number of sprite batches the gauge draws through. */
    static constexpr int kBatchCount = 8;

    /** Constructs the clear-gauge render layer. */
    ClearGaugeLayer();

    /**
     * Builds the gauge's eight sprite batches on first use.
     *
     * Loads the gm_parts2 atlas, creates each batch sized from the capacity table, attaches it
     * under the background layer, makes it visible, binds the atlas, and clears its sprite count.
     * The second batch additionally enables the two-side gauge. Finally seeds both bands' base
     * icons. Guarded so it runs only once.
     * @ghidraAddress 0x175afc
     */
    void CreateSprites();

    /**
     * Advances the reveal fade and rebuilds the gauge's sprite batches for the frame.
     *
     * Eases the reveal fade toward its target over its duration (marking the colour dirty), clears
     * every batch's sprite count, and then for each drawn side (the first side only when the
     * two-side gauge is enabled) appends its icon, fill marker, and digits at an alpha taken from
     * the current fade value scaled by the side's alpha multiplier.
     * @param flDelta The frame's elapsed time, in frames.
     * @ghidraAddress 0x175dd4
     */
    void Process(float flDelta);

    /**
     * Appends the gauge's base icon quad, choosing its size and atlas frame by layout.
     *
     * Selects a quad size and atlas frame from the current orientation and gauge style (three
     * variants: phone, iPad default, and iPad alternate), then appends it to the first batch
     * through
     * @c SetClearGaugeSprite on the given band.
     * @param nBottomBand Non-zero to place the icon on the lower gauge band, zero for the upper
     * band.
     * @param nAlpha The icon's alpha.
     * @ghidraAddress 0x175bc8
     */
    void SetClearGaugeIcon(int nBottomBand, int nAlpha);

    /**
     * Appends the gauge's fill marker quad for one side, scaled by that side's gauge value.
     *
     * Chooses the marker's anchor, height, width, and atlas frame by orientation and gauge style,
     * reads the side's stored gauge value through @c GetValue, and appends the quad to the second
     * batch with both its pixel width and its atlas U span scaled by the value (a horizontal fill).
     * @param nSide The player side, also selecting the gauge band.
     * @param nAlpha The marker's alpha.
     * @ghidraAddress 0x175eec
     */
    void SetClearGaugeMarker(unsigned int nSide, int nAlpha);

    /**
     * Appends the gauge's percentage readout for one side: two labels and up to four digits.
     *
     * Reads the side's gauge value, scales it into a per-mille percentage (so a full gauge reads as
     * @c 100.0), and appends the two fixed labels (a separator and the percent sign) plus the
     * thousands, hundreds, tens, and ones digits, suppressing leading zeros above the tens place.
     * The glyphs come from the platform's label and digit tables, switching to a high-value variant
     * at or above seventy percent, with each digit positioned by its place and the iPad default
     * style recentred horizontally.
     * @param nSide The player side, also selecting the gauge band.
     * @param nAlpha The readout's alpha.
     * @ghidraAddress 0x176000
     */
    void SetClearGaugeDigits(unsigned int nSide, int nAlpha);

    /**
     * Appends one gauge quad to a batch, positioned by orientation, band, and gauge style.
     *
     * The shared low-level writer behind @c SetClearGaugeIcon, @c SetClearGaugeMarker, and
     * @c SetClearGaugeDigits. It places the quad using the play-field gauge base rows (mirroring
     * the X and half-turning the quad on the two-side layout), writes the caller's anchor, size,
     * and atlas rectangle, and appends it to batch @p nBatch. Nothing is written once the batch is
     * full.
     * @param nBatch The sprite batch to append to.
     * @param nBottomBand Non-zero to place the quad on the lower gauge band, zero for the upper
     * band.
     * @param pQuad The quad's anchor (@c pQuad[0]) and size (@c pQuad[1]), in that order.
     * @param nAlpha The quad's alpha.
     * @param uvOrigin The atlas rectangle origin.
     * @param uvSize The atlas rectangle size.
     * @ghidraAddress 0x1763d0
     */
    void SetClearGaugeSprite(unsigned int nBatch,
                             int nBottomBand,
                             const S_VECTOR2 *pQuad,
                             int nAlpha,
                             S_VECTOR2 uvOrigin,
                             S_VECTOR2 uvSize);

    /**
     * Sets a side's clear-gauge value, clamped to the range zero to one.
     * @param flValue The gauge value (clamped to @c [0, 1]).
     * @param nSide The player side.
     * @ghidraAddress 0x175c90
     */
    void SetValue(float flValue, unsigned int nSide);

    /**
     * A side's stored clear-gauge value.
     * @param nSide The player side.
     * @return The gauge value.
     * @ghidraAddress 0x175d04
     */
    float GetValue(unsigned int nSide) const;

    /**
     * Clears both sides' clear-gauge value slots to zero (a per-play reset).
     * @ghidraAddress 0x175c70
     */
    void ClearValues();

    /**
     * Sets the gauge style (the sprite-layout variant), taken from the user's gauge-style
     * setting.
     * @param nStyle The gauge style.
     * @ghidraAddress 0x175d68
     */
    void SetGaugeStyle(int nStyle);

    /**
     * Sets whether the two-player (both-side) gauge is drawn.
     * @param bTwoSide Whether the 2P gauge is enabled.
     * @ghidraAddress 0x175d70
     */
    void SetTwoSideEnabled(bool bTwoSide);

    /**
     * Begins the reveal fade-in, easing the gauge to fully opaque over @p flDuration
     * (snapping to opaque and marking the colour dirty immediately when the duration is
     * non-positive).
     * @param flDuration The fade duration, in frames.
     * @ghidraAddress 0x175d78
     */
    void StartFadeIn(float flDuration);

    /**
     * Begins the reveal fade-out, easing the gauge to transparent over @p flDuration
     * (snapping to transparent and marking the colour dirty immediately when the duration is
     * non-positive).
     * @param flDuration The fade duration, in frames.
     * @ghidraAddress 0x175da8
     */
    void StartFadeOut(float flDuration);

    /**
     * The process-wide clear-gauge layer, created on first use.
     * @return The shared clear-gauge layer.
     * @ghidraAddress 0x175aac
     */
    static ClearGaugeLayer *shared();

private:
    void EmitGlyph(const GaugeGlyphDesc &glyph,
                   unsigned int nBatch,
                   unsigned int nSide,
                   int nAlpha,
                   const float *pAnchorX);

    ne::C_TEXTURE *m_pTexture = {};                            // +0x08
    ne::C_SPRITE_INSTANCING_2D *m_apSprites[kBatchCount] = {}; // +0x10
    // +0x50..+0x117: batch sprite capacities then per-slot bookkeeping, one region because the
    // constructor copies it through two windows eight entries apart.
    static constexpr int kBatchStateCount = 50;
    int m_aBatchState[kBatchStateCount] = {}; // +0x50
    bool m_bBuilt = {};                       // +0x118
    // unsigned char m_aPad119[7] = {}; // +0x119
    float m_flFadeFrom = {};     // +0x120
    float m_flFadeTo = {};       // +0x124
    float m_flFadeDuration = {}; // +0x128: in frames.
    float m_flFadeElapsed = {};  // +0x12c: in frames.
    float m_flFadeCurrent = {};  // +0x130
    bool m_bColorDirty = {};     // +0x134: set when the fade advances.
    // unsigned char m_aPad135[3] = {};              // +0x135
    float m_aSideAlphaScale[kSideCount] = {1, 1}; // +0x138
    int m_nGaugeStyle = {};                       // +0x140
    // Each side's value occupies an eight-byte slot, so the two sides sit at +0x144 and +0x14c.
    struct ValueSlot {
        float flValue = {}; /*!< The side's clear-gauge value. +0x00 */
        int nUnused = {};   /*!< Unused slot tail. +0x04 */
    };
    ValueSlot m_aValues[kSideCount] = {}; // +0x144
    int m_nTwoSideEnabled = {};           // +0x154
};
