/**
 * @file
 * The C_TASK-derived game UI layer base, @c GameUiLayerBase.
 */

#pragma once

#include "listener_list.h"

/**
 * @brief The base of the per-frame game UI layers (the clear gauge, score gauge, pause gauge, and
 * title-screen layers).
 *
 * It derives from the engine's task node (@c SortedListenerNode, the priority-sorted per-frame
 * listener / @c ne::C_TASK) and appends the shared presentation flags: the is-pad flag and whether
 * the device is the older type-9 hardware. Every concrete UI layer derives from this base and runs
 * its constructor first, then overrides the per-frame callback and initialises its own fields. The
 * trailing @c // +0xNN comments document the original member offsets for reference only.
 */
class GameUiLayerBase : public SortedListenerNode {
public:
    /**
     * @brief Whether the device is an iPad (cached from @c IsPad at construction).
     */
    bool IsPad() const {
        return m_bIsPad;
    }

    /**
     * @brief Whether the device is the older type-9 hardware.
     */
    bool IsHardwareType9() const {
        return m_bHardwareType9;
    }

protected:
    /**
     * @brief Constructs the UI-layer base: chains the task-node base constructor and caches the
     * is-pad and hardware-type flags. (The compiler installs the vtable.)
     * @ghidraAddress 0x18bd9c
     */
    GameUiLayerBase();

    bool m_bIsPad = {};         // +0x49: whether the device is an iPad (from IsPad()).
    bool m_bHardwareType9 = {}; // +0x4a: whether the device is the older type-9 hardware.
};

// code: language=C++
// kate: hl C++;
// vim: set ft=cpp :
