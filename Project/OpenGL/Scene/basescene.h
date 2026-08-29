/**
 * @file
 * @brief The scene base, @c rb::BaseScene (RTTI @c N2rb9BaseSceneE).
 */

#pragma once

#include "ctask.h"

namespace rb {

/**
 * @brief The base of the per-frame scenes and game UI layers (the clear gauge, score gauge, pause
 * gauge, title scenes, and the play scene).
 *
 * It derives from the engine's task node (@c ne::C_TASK, the priority-sorted per-frame
 * listener) and appends the shared presentation flags: the is-pad flag and whether
 * the device is the older type-9 hardware. Every concrete scene/layer derives from this base and
 * runs its constructor first, then overrides the per-frame callback and initialises its own fields.
 * The trailing @c // +0xNN comments document the original member offsets for reference only.
 */
class BaseScene : public ne::C_TASK {
public:
    /**
     * @brief Whether the device is an iPad (cached from @c IsPad at construction).
     * @return @c true on an iPad-idiom device.
     */
    bool IsPad() const {
        return m_bIsPad;
    }

    /**
     * @brief Whether the device is the older type-9 hardware.
     * @return @c true on the older type-9 hardware.
     */
    bool IsHardwareType9() const {
        return m_bHardwareType9;
    }

protected:
    /**
     * @brief Constructs the scene base: chains the task-node base constructor and caches the is-pad
     * and hardware-type flags. (The compiler installs the vtable.)
     * @ghidraAddress 0x18bd9c
     */
    BaseScene();

    bool m_bIsPad = {};         /*!< Whether the device is an iPad (from @c IsPad). +0x49 */
    bool m_bHardwareType9 = {}; /*!< Whether the device is the older type-9 hardware. +0x4a */
};

} // namespace rb
