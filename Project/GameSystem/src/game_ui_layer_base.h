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
 * It embeds the engine's task node (@c SortedListenerNode, the priority-sorted per-frame listener /
 * @c ne::C_TASK) at offset 0 and appends the shared presentation flags: the font variant and whether
 * the device is the older type-9 hardware. Every concrete UI layer derives from this base and runs
 * its constructor first, then installs its own dispatch table and initialises its own fields. The
 * trailing @c // +0xNN comments document the original member offsets for reference only.
 */
class GameUiLayerBase : public SortedListenerNode {
public:
    /**
     * @brief The font-variant identifier cached for the current device.
     */
    bool IsFontVariant() const {
        return m_bFontVariant;
    }

    /**
     * @brief Whether the device is the older type-9 hardware.
     */
    bool IsHardwareType9() const {
        return m_bHardwareType9;
    }

protected:
    /**
     * @brief Constructs the UI-layer base: chains the task-node base constructor, installs the base
     * UI-layer dispatch table, and caches the font-variant and hardware-type flags.
     * @ghidraAddress 0x18bd9c
     */
    GameUiLayerBase();

    bool m_bFontVariant = {};   // +0x49: the cached font variant for the current device.
    bool m_bHardwareType9 = {}; // +0x4a: whether the device is the older type-9 hardware.
};

// code: language=C++
// kate: hl C++;
// vim: set ft=cpp :
