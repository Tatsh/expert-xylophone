#pragma once

//
//  title_screen_layer_classic.h
//  REFLEC BEAT plus
//
//  The interactive title screen layer, as far as its hidden Konami-code swipe state machine and its
//  two fade channels observe it. This is the 0x898-byte gesture layer driven by ProcessTitleLayer /
//  RenderTitleScreenFrame, distinct from both the 0x168 rb::TitleClassicScene and the 0x898
//  rb::TitleColetteScene (whose swing/gesture/fade helpers were previously misattributed here and now
//  live on TitleColetteScene). The class is not fully modelled yet: only the fields the reconstructed
//  routines touch are named, with the surrounding object modelled as reserved spans so the named
//  fields land at their real offsets.
//
//  Reconstructed from Ghidra project rb458, program rb458. @ghidraAddress values are relative to
//  the program image base.
//

#include "linear_tween.h"

/**
 * @brief The interactive title screen layer, as far as its hidden-swipe state machine and fade
 * channels observe it.
 *
 * Only the two fade channels and the swipe-sequence fields are named; the rest of the 0x898-byte
 * object is reserved padding until the full class is modelled.
 * @ghidraAddress TitleScreenLayerClassic (engine layer, 0x898 bytes)
 */
class TitleScreenLayerClassic {
public:
    /**
     * @brief Advances the hidden-swipe state on a directional swipe, firing the secret effect and
     * latching the completion flag when the sequence completes.
     * @param iSwipeEvent The directional swipe id.
     * @ghidraAddress 0x152cc8
     */
    void AdvanceSwipeState(int iSwipeEvent);
    /**
     * @brief Advances the title fade channel by @p nDeltaFrames.
     * @ghidraAddress 0x149ff4
     */
    void CalculateFade(int nDeltaFrames);
    /**
     * @brief Advances the secondary title fade/tween channel by @p nDeltaFrames.
     * @ghidraAddress 0x152548
     */
    void AdvanceFadeValue(int nDeltaFrames);

private:
    unsigned char m_aReserved00[0xc4] = {};   // +0x000
    LinearTween m_fadeChannel;                // +0x0c4 title fade tween
    unsigned char m_aReserved0d8[0x38] = {};  // +0x0d8
    LinearTween m_fadeValueChannel;           // +0x110 secondary title fade/tween
    unsigned char m_aReserved124[0x3c] = {};  // +0x124
    int m_nSwipeState = {};                   // +0x160 hidden-swipe sequence state
    bool m_bSwipeTriggered = {};              // +0x164 latched when the swipe sequence completes
    unsigned char m_aReserved165[0x733] = {}; // +0x165 remainder of the object
};

// code: language=C++
// kate: hl C++;
// vim: set ft=cpp :
