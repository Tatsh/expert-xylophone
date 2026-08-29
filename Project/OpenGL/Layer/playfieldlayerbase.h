/**
 * @file
 * The shared base class for the play-field theme layers.
 */

#pragma once

/**
 * Shared base for the play-field theme layers.
 *
 * Holds the presentation context common to every theme layer: the is-pad flag, whether the device
 * is the older hardware type, and the selected theme. Concrete play-field layers (the clear gauge,
 * the player-field score layer, the effect layers) derive from it.
 */
class PlayFieldLayerBase {
public:
    /**
     * Whether the device is an iPad (seeded from @c IsPad at construction).
     * @return @c true on an iPad-idiom device.
     */
    bool IsPad() const {
        return m_bIsPad;
    }

    /**
     * Whether the device is the older (type 9) hardware.
     * @return @c true on the older type-9 hardware.
     */
    bool IsHardwareType9() const {
        return m_fIsHardwareType9;
    }

    /**
     * The selected theme identifier.
     * @return The selected theme identifier.
     */
    int GetThema() const {
        return m_nThema;
    }

    /**
     * Re-reads the user's theme setting into the layer.
     *
     * Called once per layer during theme initialisation to refresh @c m_nThema from the current
     * @c RBUserSettingData theme.
     * @ghidraAddress 0x109e04
     */
    void RefreshThema();

    /**
     * The base layer-release hook: releases nothing.
     *
     * A concrete layer's destructor releases its own resources and then chains this empty base
     * hook. The base holds only value fields, so it has nothing to release.
     * @ghidraAddress 0x109e00
     */
    void ReleaseResources() {
    }

protected:
    /**
     * Constructs the layer base from the current device and settings.
     *
     * Fills in the is-pad flag, hardware type, and selected theme. Every concrete layer's
     * constructor runs this base constructor before setting up its own fields. The binary returns
     * @c this for chaining, but the callers ignore it.
     * @ghidraAddress 0x109d84
     */
    PlayFieldLayerBase();

private:
    bool m_bIsPad = {};
    bool m_fIsHardwareType9 = {};
    int m_nThema = {};
};
