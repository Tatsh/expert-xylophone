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
    PlayFieldLayerBase();

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

private:
    unsigned char m_bFontVariant = {}; // +0x00
    bool m_fIsHardwareType9 = {};      // +0x01
    int m_nThema = {};                 // +0x04
};

// code: language=C++
// kate: hl C++;
// vim: set ft=cpp :
