/**
 * @file
 * The shared base class for the play-field theme layers.
 */

#pragma once

/**
 * @brief Shared base for the play-field theme layers.
 *
 * Holds the presentation context common to every theme layer: the font variant, whether the device
 * is the older hardware type, and the selected theme. The trailing @c // +0xNN comments document the
 * original 32-bit offsets for reference only.
 */
class PlayFieldLayerBase {
public:
    /**
     * @brief The font-variant identifier for the current device.
     */
    unsigned char GetFontVariant() const {
        return m_bFontVariant;
    }

    /**
     * @brief Whether the device is the older (type 9) hardware.
     */
    bool IsHardwareType9() const {
        return m_fIsHardwareType9;
    }

    /**
     * @brief The selected theme identifier.
     */
    int GetThema() const {
        return m_nThema;
    }

    /**
     * @brief The shared play-field layer that draws the score digits and lane gauges, created on
     * first use.
     * @return The shared player-field layer.
     * @ghidraAddress 0x18b668
     */
    static PlayFieldLayerBase *shared();

protected:
    /**
     * @brief Initialise the layer base from the current device and settings.
     *
     * Fills in the font variant, hardware type, and selected theme; every layer factory runs this
     * before the subclass sets up its own fields. The binary returns @c this for chaining, but the
     * callers ignore it, so the method returns void.
     * @ghidraAddress 0x109d84
     */
    void InitBase();

private:
    unsigned char m_bFontVariant = {}; // +0x00
    bool m_fIsHardwareType9 = {};      // +0x01
    int m_nThema = {};                 // +0x04
};

/**
 * @brief Animates a side's score-digit field towards a target value over a duration.
 * @param flDuration The roll-up duration, in seconds.
 * @param pLayer The player-field layer.
 * @param uSide The player side.
 * @param nValue The target score value.
 * @ghidraAddress 0x18b7cc
 */
void SetScoreDigitTarget(float flDuration,
                         PlayFieldLayerBase *pLayer,
                         unsigned int uSide,
                         int nValue);

// code: language=C++
// kate: hl C++;
// vim: set ft=cpp :
