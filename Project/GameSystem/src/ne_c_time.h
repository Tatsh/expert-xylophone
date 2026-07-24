/**
 * @file
 * The engine media-time stamp value type, @c C_TIME.
 */

#pragma once

/**
 * A media-time stamp used by the engine timers. Its sole field is the media time in seconds; the
 * @c GetElapsedMediaTime and @c StartMediaTimer helpers read and write it through a @c double
 * pointer to its first field.
 * @ghidraAddress C_TIME (engine struct type)
 */
struct C_TIME {
    double m_flTime = {}; // +0x0
};

// code: language=C++
// kate: hl C++;
// vim: set ft=cpp :
