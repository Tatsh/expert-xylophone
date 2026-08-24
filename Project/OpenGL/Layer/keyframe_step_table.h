/**
 * @file
 * The keyframe step-table lookup helper.
 */

#pragma once

/**
 * @brief The sentinel returned by @c KeyframeStepTableLookup when the query time is out of range.
 *
 * The raw 32-bit value 10, which callers that read the result as a float see as the bit pattern
 * 1.4e-44.
 */
constexpr unsigned int kKeyframeStepNoMatch = 10;

// The lookup itself is @c TutorialGuideLayer::KeyframeStepTableLookup (its sole caller is that
// layer's finger-sprite animation); it is declared with the class in tutorial_guide_layer.h.

// code: language=C++
// kate: hl C++;
// vim: set ft=cpp :
