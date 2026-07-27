/**
 * @file
 * The engine media-time stamp value type, @c C_TIME.
 */

#pragma once

/**
 * A media-time stamp used by the engine timers. Its sole field is the media time in seconds. The
 * binary reaches the two timer helpers through a @c double pointer to this first field (which, for a
 * single-field struct, is the object address); they are modelled here as members.
 * @ghidraAddress C_TIME (engine struct type)
 */
struct C_TIME {
    /**
     * @brief Stamps the timer with the current media time.
     * @ghidraAddress 0x366f8
     */
    void Start();

    /**
     * @brief The elapsed time since the last @c Start, in milliseconds.
     * @return The elapsed time, in milliseconds.
     * @ghidraAddress 0x3671c
     */
    float GetElapsedMillis() const;

    double m_flTime = {}; // +0x0
};

// code: language=C++
// kate: hl C++;
// vim: set ft=cpp :
