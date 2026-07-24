/**
 * @file
 * The shared base class for the play-field theme layers.
 */

#pragma once

/**
 * @brief One player side's score-digit roll-up tween: the target value and the animation it plays
 * to reach it.
 *
 * The trailing @c // +0xNN comments document the original 32-bit member offsets for reference only.
 */
struct ScoreDigitField {
    int nTarget = {};      // +0x00: the target score value.
    float flFrom = {};     // +0x04: the animation's start value (the current value when armed).
    float flTo = {};       // +0x08: the animation's end value (the target as a float).
    float flCurrent = {};  // +0x0c: the current animated value.
    float flElapsed = {};  // +0x10: the elapsed animation time.
    float flDuration = {}; // +0x14: the animation duration, in seconds.
};

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
     * @brief A player side's score-digit roll-up record.
     * @param uSide The player side.
     * @return The side's score-digit field.
     */
    ScoreDigitField &GetScoreDigitField(unsigned int uSide) {
        return m_aScoreFields[uSide];
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
    // +0x08..+0x3f: the layer's presentation transform and flags (seeded by the shared() factory),
    // whose individual fields are still being worked out.
    unsigned char m_aLayerState08[0x38] = {}; // +0x08
    ScoreDigitField m_aScoreFields[2] = {};   // +0x40: the per-side score-digit roll-up records.
};

// code: language=C++
// kate: hl C++;
// vim: set ft=cpp :
