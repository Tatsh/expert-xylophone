/**
 * @file
 * The gameplay task, @c PlayTask.
 */

#pragma once

#include "game_ui_layer_base.h"

class PauseGaugeLayer;

/**
 * @brief The gameplay task: the per-frame state machine that drives a play session from set-up
 * through the notes to the result screen and exit.
 *
 * A process-wide singleton registered in the engine task list at priority 1. It derives from
 * @c GameUiLayerBase (and thus the @c ne::C_TASK node) and overrides the per-frame callback with its
 * state-machine dispatch. The trailing @c // +0xNN comments document the original member offsets for
 * reference only; the tail sub-state fields between the recovered members are still being worked out.
 */
class PlayTask : public GameUiLayerBase {
public:
    /**
     * @brief Returns the singleton gameplay task, constructing it (and registering it in the task
     * list at priority 1) on first use.
     * @param ppOut The caller-held slot that holds, and receives, the singleton pointer.
     * @ghidraAddress 0x12ee88
     */
    static void GetInstance(PlayTask **ppOut);

    /**
     * @brief Ticks the pause gauge and reports whether gameplay is active this frame.
     *
     * When the game is not paused, releases any pause-gauge charge and returns true. When paused,
     * charges the gauge (unless it is being held) and returns false.
     * @return @c true when gameplay is active (unpaused), @c false when paused.
     * @ghidraAddress 0x14b6e0
     */
    bool RefreshPauseGaugeAndGetActiveFlag();

private:
    /**
     * @brief Constructs the task: chains the UI-layer base constructor, installs the play dispatch
     * table, zero-clears the play state, and seeds the initial state to 2.
     * @ghidraAddress 0x14a21c
     */
    PlayTask();

    int m_nState = {};    // +0x4c: the current state-machine state (dispatched each frame).
    int m_nPlayTime = {}; // +0x50: the accumulated play time, advanced by the frame delta.
    // +0x54..+0x63: further per-frame play sub-state (timers, the score tracker), still being worked
    // out.
    unsigned char m_aReserved54[0x10] = {}; // +0x54
    bool m_bPauseGaugeHeld = {};            // +0x64: whether the pause gauge is being held down.
    unsigned char m_aReserved65[0x03] = {}; // +0x65
    PauseGaugeLayer *m_pPauseGauge = {};    // +0x68: the owned pause-gauge layer, or null.
    int m_nInitialState = {};               // +0x70: the state the task starts in (2).
    // +0x74..+0x8f: trailing play state to the 0x90-byte object size, still being worked out.
    unsigned char m_aReserved74[0x1c] = {}; // +0x74
};

// code: language=C++
// kate: hl C++;
// vim: set ft=cpp :
