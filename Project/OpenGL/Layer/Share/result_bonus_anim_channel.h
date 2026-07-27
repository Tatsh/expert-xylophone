/**
 * @file
 * The result-screen bonus/EX display animation channel, shared by the theme result layers.
 */

#pragma once

/**
 * @brief One result-screen bonus/EX display animation channel: eases a shown value from a start to a
 * target over a duration. A 24-byte record (six floats).
 */
struct ResultBonusAnimChannel {
    float flStart = {};    // +0x00: the animation's start value.
    float flTarget = {};   // +0x04: the animation's target value.
    float flDuration = {}; // +0x08: the animation's duration.
    float flElapsed = {};  // +0x0c: the animation's elapsed time.
    float flReserved = {}; // +0x10: a further per-channel value.
    float flCurrent = {};  // +0x14: the current (shown) value.
};

// code: language=C++
// kate: hl C++;
// vim: set ft=cpp :
