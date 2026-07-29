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
    float flStart = {};    /*!< The animation's start value. +0x00 */
    float flTarget = {};   /*!< The animation's target value. +0x04 */
    float flDuration = {}; /*!< The animation's duration. +0x08 */
    float flElapsed = {};  /*!< The animation's elapsed time. +0x0c */
    float flReserved = {}; /*!< A further per-channel value. +0x10 */
    float flCurrent = {};  /*!< The current (shown) value. +0x14 */
};

// code: language=C++
// kate: hl C++;
// vim: set ft=cpp :
