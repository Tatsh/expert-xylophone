#pragma once

//
//  title_swipe_state.h
//  REFLEC BEAT plus
//
//  The title-screen hidden-swipe state machines, driven by the title layers' touch handling.
//
//  Reconstructed from Ghidra project rb458, program rb458. @ghidraAddress values are relative to
//  the program image base.
//

/**
 * @brief Advances the classic title layer's hidden-swipe state on a directional swipe, firing the
 * secret effect and latching the completion flag when the sequence completes.
 * @param pLayer The classic title layer (swipe state at +0x160).
 * @param iSwipeEvent The directional swipe id.
 * @ghidraAddress 0x152cc8
 */
void AdvanceTitleSwipeState(void *pLayer, int iSwipeEvent);

/**
 * @brief Advances the theme-2 title layer's hidden-swipe state, additionally rewinding the layer's
 * timer when the sequence completes.
 * @param pLayer The theme-2 title layer (swipe state at +0x5c8).
 * @param iSwipeEvent The directional swipe id.
 * @ghidraAddress 0x1549b8
 */
void AdvanceTitle2SwipeState(void *pLayer, int iSwipeEvent);

// code: language=C++
// kate: hl C++;
// vim: set ft=cpp :
