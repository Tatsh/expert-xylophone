/**
 * @file
 * The play-field clear-gauge layer, @c ClearGaugeLayer.
 */

#pragma once

#include "playfieldlayerbase.h"

struct S_VECTOR2;

namespace ne {
class C_SPRITE_INSTANCING_2D;
class C_TEXTURE;
} // namespace ne

/**
 * @brief The play-field clear-gauge layer.
 *
 * Draws each player side's clear gauge as a set of sprite batches over the background scene node. It
 * derives from @c PlayFieldLayerBase and is a process-wide singleton built on first access. The
 * trailing @c // +0xNN comments document the original 32-bit member offsets for reference only; the
 * object is always reached through named fields. Some of the layer's sprite-slot state between the
 * base fields and the recovered members below is still being worked out.
 */
class ClearGaugeLayer : public PlayFieldLayerBase {
public:
    // The number of player sides the gauge tracks.
    static constexpr int kSideCount = 2;
    // The number of sprite batches the gauge draws through.
    static constexpr int kBatchCount = 8;

    /** @brief Constructs the clear-gauge render layer. */
    ClearGaugeLayer();

    /**
     * @brief Appends the gauge's base icon quad, choosing its size and atlas frame by layout.
     *
     * Selects a quad size and atlas frame from the current orientation and gauge style (three
     * variants: phone, iPad default, and iPad alternate), then appends it to the first batch through
     * @c SetClearGaugeSprite on the given band.
     * @param nBottomBand Non-zero to place the icon on the lower gauge band, zero for the upper band.
     * @param nAlpha The icon's alpha.
     * @ghidraAddress 0x175bc8
     */
    void SetClearGaugeIcon(int nBottomBand, int nAlpha);

    /**
     * @brief Appends the gauge's fill marker quad for one side, scaled by that side's gauge value.
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
     * @brief Appends one gauge quad to a batch, positioned by orientation, band, and gauge style.
     *
     * The shared low-level writer behind @c SetClearGaugeIcon, @c SetClearGaugeMarker, and
     * @c SetClearGaugeDigits. It places the quad using the play-field gauge base rows (mirroring the
     * X and half-turning the quad on the two-side layout), writes the caller's anchor, size, and
     * atlas rectangle, and appends it to batch @p nBatch. Nothing is written once the batch is full.
     * @param nBatch The sprite batch to append to.
     * @param nBottomBand Non-zero to place the quad on the lower gauge band, zero for the upper band.
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
     * @brief Sets a side's clear-gauge value, clamped to the range zero to one.
     * @param flValue The gauge value (clamped to @c [0, 1]).
     * @param nSide The player side.
     * @ghidraAddress 0x175c90
     */
    void SetValue(float flValue, unsigned int nSide);

    /**
     * @brief A side's stored clear-gauge value.
     * @param nSide The player side.
     * @return The gauge value.
     * @ghidraAddress 0x175d04
     */
    float GetValue(unsigned int nSide) const;

    /**
     * @brief Clears both sides' clear-gauge value slots to zero (a per-play reset).
     * @ghidraAddress 0x175c70
     */
    void ClearValues();

    /**
     * @brief Sets the gauge style (the sprite-layout variant), taken from the user's gauge-style
     * setting.
     * @param nStyle The gauge style.
     * @ghidraAddress 0x175d68
     */
    void SetGaugeStyle(int nStyle);

    /**
     * @brief Sets whether the two-player (both-side) gauge is drawn.
     * @param bTwoSide Whether the 2P gauge is enabled.
     * @ghidraAddress 0x175d70
     */
    void SetTwoSideEnabled(bool bTwoSide);

    /**
     * @brief Begins the reveal fade-in, easing the gauge to fully opaque over @p flDuration
     * (snapping to opaque and marking the colour dirty immediately when the duration is
     * non-positive).
     * @param flDuration The fade duration, in frames.
     * @ghidraAddress 0x175d78
     */
    void StartFadeIn(float flDuration);

    /**
     * @brief Begins the reveal fade-out, easing the gauge to transparent over @p flDuration
     * (snapping to transparent and marking the colour dirty immediately when the duration is
     * non-positive).
     * @param flDuration The fade duration, in frames.
     * @ghidraAddress 0x175da8
     */
    void StartFadeOut(float flDuration);

    /**
     * @brief The process-wide clear-gauge layer, created on first use.
     * @return The shared clear-gauge layer.
     * @ghidraAddress 0x175aac
     */
    static ClearGaugeLayer *shared();

private:
    ne::C_TEXTURE *m_pTexture = {};                            // +0x08: the gauge atlas.
    ne::C_SPRITE_INSTANCING_2D *m_apSprites[kBatchCount] = {}; // +0x10: the eight sprite batches.
    // +0x50..+0x11f: the batches' per-slot capacity/count table and the sprite-index bookkeeping the
    // factory seeds; individual fields are still being worked out.
    unsigned char m_aLayerState50[0xd0] = {}; // +0x50
    bool m_bBuilt = {};                       // +0x118: whether the sprite batches have been built.
    // +0x119..+0x11f is alignment padding before the fade-tween block.
    unsigned char m_aPad119[7] = {}; // +0x119
    float m_flFadeFrom = {};         // +0x120: the reveal fade's start value.
    float m_flFadeTo = {};           // +0x124: the reveal fade's target value.
    float m_flFadeDuration = {};     // +0x128: the reveal fade's duration, in frames.
    float m_flFadeElapsed = {};      // +0x12c: the reveal fade's elapsed time, in frames.
    float m_flFadeCurrent = {};      // +0x130: the reveal fade's current value.
    bool m_bColorDirty = {};         // +0x134: set when the fade advances.
    // +0x135..+0x13f is alignment padding before the gauge-style field.
    unsigned char m_aPad135[11] = {}; // +0x135
    int m_nGaugeStyle = {};           // +0x140: the gauge style / sprite-layout variant.
    // Each side's clear-gauge value occupies an eight-byte slot (the float followed by four unused
    // bytes), so the two sides sit at +0x144 and +0x14c.
    struct ValueSlot {
        float flValue = {}; // +0x00: the side's clear-gauge value.
        int nUnused = {};   // +0x04: unused slot tail.
    };
    ValueSlot m_aValues[kSideCount] = {}; // +0x144
    int m_nTwoSideEnabled = {};           // +0x154: non-zero when the 2P gauge is drawn.
};

// code: language=C++
// kate: hl C++;
// vim: set ft=cpp :
