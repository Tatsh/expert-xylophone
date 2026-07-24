#pragma once

//
//  title_swipe_state.h
//  REFLEC BEAT plus
//
//  The title-screen hidden-swipe/flick state machines. These are instance methods of the two title
//  layer classes (classic and theme-2), which are not fully modelled yet: only the fields the state
//  machines touch are named, with the surrounding object modelled as reserved spans so the named
//  fields land at their real offsets.
//
//  Reconstructed from Ghidra project rb458, program rb458. @ghidraAddress values are relative to
//  the program image base.
//

#include "linear_tween.h"

/**
 * @brief The directional-swipe and button inputs that drive the hidden title sequences, classified
 * by the title layer's touch handling from flick direction and the corner hit-boxes. The sequence
 * is the Konami code: up, up, down, down, left, right, left, right, B, A.
 */
enum TitleSwipeInput {
    kTitleSwipeUp = 0,       /*!< An upward flick. */
    kTitleSwipeDown = 1,     /*!< A downward flick. */
    kTitleSwipeLeft = 2,     /*!< A leftward flick. */
    kTitleSwipeRight = 3,    /*!< A rightward flick. */
    kTitleSwipeButtonA = 4,  /*!< The "A" confirm input that completes a sequence. */
    kTitleSwipeButtonB = 5,  /*!< The "B" input, the penultimate step. */
    kTitleSwipeAltLeft = 6,  /*!< The leftward flick of the gesture layer's alternate branch. */
    kTitleSwipeAltRight = 7, /*!< The rightward flick of the gesture layer's alternate branch. */
};

/**
 * @brief The progress steps through the Konami-code swipe sequence (up, up, down, down, left,
 * right, left, right, B, A). The value is how far the sequence has been entered; the gesture layer
 * adds an alternate left/right/left/right branch that ends in the Hinabita toggle.
 */
enum TitleSwipeStep {
    kSwipeStepNone = 0,             /*!< No input entered yet. */
    kSwipeStepUp1 = 1,              /*!< First up entered. */
    kSwipeStepUp2 = 2,              /*!< Second up entered. */
    kSwipeStepDown1 = 3,            /*!< First down entered. */
    kSwipeStepDown2 = 4,            /*!< Second down entered. */
    kSwipeStepLeft1 = 5,            /*!< First left entered. */
    kSwipeStepRight1 = 6,           /*!< First right entered. */
    kSwipeStepLeft2 = 7,            /*!< Second left entered. */
    kSwipeStepRight2 = 8,           /*!< Second right entered. */
    kSwipeStepButtonB = 9,          /*!< B entered; the next A completes the swing sequence. */
    kSwipeStepComplete = 10,        /*!< The swing sequence completed. */
    kGestureStepAltLeft1 = 0xf,     /*!< First left of the gesture layer's alternate branch. */
    kGestureStepAltRight1 = 0x10,   /*!< First right of the alternate branch. */
    kGestureStepAltLeft2 = 0x11,    /*!< Second left of the alternate branch. */
    kGestureStepAltRight2 = 0x12,   /*!< Second right of the alternate branch. */
    kGestureStepAltButtonB = 0x13,  /*!< B of the alternate branch; the next A toggles Hinabita. */
    kGestureStepAltComplete = 0x14, /*!< The Hinabita alternate sequence completed. */
};

/**
 * @brief The classic title screen layer, as far as its hidden-gesture state machines observe it.
 *
 * Only the timer, swipe-sequence, and flick-gesture fields are named; the rest of the 0x898-byte
 * object is reserved padding until the full class is modelled.
 * @ghidraAddress TitleScreenLayer (engine layer, 0x898 bytes)
 */
struct TitleScreenLayer {
    /**
     * @brief Advances the hidden-swipe state on a directional swipe, firing the secret effect and
     * latching the completion flag when the sequence completes.
     * @param iSwipeEvent The directional swipe id.
     * @ghidraAddress 0x152cc8
     */
    void AdvanceSwipeState(int iSwipeEvent);
    /**
     * @brief Advances the flick-gesture state machine, toggling the hidden Hinabita mode when
     * sequence A completes and the swing direction when sequence B completes.
     * @param inputCode The directional gesture id.
     * @return The played sound handle after the swing toggle, or @c 0 otherwise. (Only the caller's
     * completion call, @c inputCode 4, uses the result; the binary leaves its object pointer in the
     * return register on the partial-step paths, which no caller reads.)
     * @ghidraAddress 0x597a8
     */
    unsigned int AdvanceGestureState(int inputCode);
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

    unsigned char m_aReserved00[0x54] = {};   // +0x000
    int m_nGestureTimer = {};                 // +0x054 timer rewound on a completed gesture
    unsigned char m_aReserved58[0x04] = {};   // +0x058
    int m_nTimerClear1 = {};                  // +0x05c cleared on the Hinabita toggle
    int m_nTimerClear2 = {};                  // +0x060 cleared on the Hinabita toggle
    unsigned char m_aReserved64[0x60] = {};   // +0x064
    LinearTween m_fadeChannel;                // +0x0c4 title fade tween
    unsigned char m_aReserved0d8[0x38] = {};  // +0x0d8
    LinearTween m_fadeValueChannel;           // +0x110 secondary title fade/tween
    unsigned char m_aReserved124[0x3c] = {};  // +0x124
    int m_nSwipeState = {};                   // +0x160 hidden-swipe sequence state
    bool m_bSwipeTriggered = {};              // +0x164 latched when the swipe sequence completes
    unsigned char m_aReserved165[0x5cb] = {}; // +0x165
    int m_nGestureState = {};                 // +0x730 flick-gesture sequence state
    bool m_bGestureTriggered = {};            // +0x734 latched when a flick sequence completes
    bool m_bSwingToggle = {};                 // +0x735 swing-direction toggle
    unsigned char m_aReserved736[0x02] = {};  // +0x736
    int m_nSwingDelta = {};                   // +0x738 resulting swing delta (+1 or -1)
    unsigned char m_aReserved73c[0x04] = {};  // +0x73c
    bool m_bHinabitaMode = {};                // +0x740 hidden Hinabita campaign toggle
    unsigned char m_aReserved741[0x157] = {}; // +0x741 remainder of the object
};

/**
 * @brief The theme-2 (Colette) title screen layer, as far as its hidden-swipe state machine
 * observes it. Only the timer and swipe-sequence fields are named.
 * @ghidraAddress TitleScreenLayer2 (engine layer)
 */
struct TitleScreenLayer2 {
    /**
     * @brief Advances the hidden-swipe state, rewinding the layer timer when the sequence completes.
     * @param iSwipeEvent The directional swipe id.
     * @ghidraAddress 0x1549b8
     */
    void AdvanceSwipeState(int iSwipeEvent);

    unsigned char m_aReserved00[0x50] = {};  // +0x000
    int m_nSwipeTimer = {};                  // +0x050 timer rewound on a completed swipe
    unsigned char m_aReserved54[0x574] = {}; // +0x054
    int m_nSwipeState = {};                  // +0x5c8 hidden-swipe sequence state
    bool m_bSwipeTriggered = {};             // +0x5cc latched when the swipe sequence completes
};

// code: language=C++
// kate: hl C++;
// vim: set ft=cpp :
