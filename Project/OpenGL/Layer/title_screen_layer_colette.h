#pragma once

//
//  title_screen_layer_colette.h
//  REFLEC BEAT plus
//
//  The theme-2 (Colette) title screen layer, as far as its hidden-swipe state machine observes it.
//  Only the timer and swipe-sequence fields are named; the rest of the object is reserved padding
//  until the full class is modelled.
//
//  Reconstructed from Ghidra project rb458, program rb458. @ghidraAddress values are relative to
//  the program image base.
//

/**
 * @brief The theme-2 (Colette) title screen layer, as far as its hidden-swipe state machine
 * observes it. Only the timer and swipe-sequence fields are named.
 * @ghidraAddress TitleScreenLayerColette (engine layer)
 */
class TitleScreenLayerColette {
public:
    /**
     * @brief Advances the hidden-swipe state, rewinding the layer timer when the sequence completes.
     * @param iSwipeEvent The directional swipe id.
     * @ghidraAddress 0x1549b8
     */
    void AdvanceSwipeState(int iSwipeEvent);

private:
    unsigned char m_aReserved00[0x50] = {};  // +0x000
    int m_nSwipeTimer = {};                  // +0x050 timer rewound on a completed swipe
    unsigned char m_aReserved54[0x574] = {}; // +0x054
    int m_nSwipeState = {};                  // +0x5c8 hidden-swipe sequence state
    bool m_bSwipeTriggered = {};             // +0x5cc latched when the swipe sequence completes
};

// code: language=C++
// kate: hl C++;
// vim: set ft=cpp :
