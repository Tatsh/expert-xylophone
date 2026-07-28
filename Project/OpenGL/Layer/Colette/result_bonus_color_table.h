/**
 * @file
 * The result-window bonus colour palette shared by the Colette result renderers.
 */

#pragma once

/**
 * @brief One result-bonus colour: a red, green, and blue channel, each in @c [0, 255] as a float.
 */
struct ResultBonusColor {
    float flRed = {};   // +0x00: the red channel.
    float flGreen = {}; // +0x04: the green channel.
    float flBlue = {};  // +0x08: the blue channel.
};

// The number of colours in the result-bonus palette (the ROM table holds seven populated entries).
constexpr int kResultBonusColorCount = 7;

// The result-bonus colour palette, indexed by a bonus/colour index. Read-only ROM data in the
// binary. @ghidraAddress 0x2fe7d0
extern const ResultBonusColor g_aResultBonusColor[kResultBonusColorCount];

// code: language=C++
// kate: hl C++;
// vim: set ft=cpp :
