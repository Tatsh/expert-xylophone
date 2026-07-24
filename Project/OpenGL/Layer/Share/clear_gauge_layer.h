/**
 * @file
 * The play-field clear-gauge layer, @c ClearGaugeLayer.
 */

#pragma once

#include "playfieldlayerbase.h"

namespace ne {
class C_SPRITE_INSTANCING;
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
     * @brief The process-wide clear-gauge layer, created on first use.
     * @return The shared clear-gauge layer.
     * @ghidraAddress 0x175aac
     */
    static ClearGaugeLayer *shared();

private:
    // +0x08..+0x11f: the gauge's texture, its eight sprite batches, their capacity table, and the
    // per-slot sprite index bookkeeping the factory seeds; individual fields are still being worked
    // out.
    unsigned char m_aLayerState08[0x110] = {}; // +0x08
    bool m_bBuilt = {}; // +0x118: whether the sprite batches have been built.
    // +0x119..+0x11f is alignment padding before the fade-tween block.
    unsigned char m_aPad119[7] = {}; // +0x119
    float m_flFadeFrom = {};         // +0x120: the reveal fade's start value.
    float m_flFadeTo = {};           // +0x124: the reveal fade's target value.
    float m_flFadeDuration = {};     // +0x128: the reveal fade's duration, in frames.
    float m_flFadeElapsed = {};      // +0x12c: the reveal fade's elapsed time, in frames.
    float m_flFadeCurrent = {};      // +0x130: the reveal fade's current value.
    bool m_bColorDirty = {};         // +0x134: set when the fade advances.
    // +0x135..+0x143 is alignment padding before the per-side value slots.
    unsigned char m_aPad135[15] = {}; // +0x135
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
