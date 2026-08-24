/**
 * @file
 * The result-window layout position bank shared by the Colette result renderers.
 */

#pragma once

#include "s_vector2.h"

/** @brief The number of position records in the result-window layout position bank. */
constexpr int kResultLayoutPositionCount = 228;

/**
 * @brief The result-window layout position bank: a flat array of anchor positions the result-bonus
 * panel and the number renderers index by slot.
 *
 * Filled at runtime by the result-layout-table initialisers (a zero-initialised @c __common global
 * in the binary).
 *
 * @ghidraAddress 0x3d4630
 */
extern S_VECTOR2 g_aResultLayoutPosition[kResultLayoutPositionCount];

// code: language=C++
// kate: hl C++;
// vim: set ft=cpp :
