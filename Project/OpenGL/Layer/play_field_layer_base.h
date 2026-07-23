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

private:
    unsigned char m_bFontVariant = {}; // +0x00
    bool m_fIsHardwareType9 = {};      // +0x01
    int m_nThema = {};                 // +0x04

    friend PlayFieldLayerBase *InitBaseLayer(PlayFieldLayerBase *pLayer);
};

/**
 * @brief Initialise a play-field layer base from the current device and settings.
 *
 * Fills in the font variant, hardware type, and selected theme; this is the base-class initialiser
 * every layer factory runs before the subclass sets up its own fields.
 * @param pLayer The layer base to initialise.
 * @return @p pLayer.
 * @ghidraAddress 0x109d84
 */
PlayFieldLayerBase *InitBaseLayer(PlayFieldLayerBase *pLayer);

// code: language=C++
// kate: hl C++;
// vim: set ft=cpp :
