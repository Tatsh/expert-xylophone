/**
 * @file
 * @brief The replay/ghost application helper for the note play field.
 */

#pragma once

/**
 * @brief Loads the saved replay/ghost for the current song and stamps each live note with its
 * recorded judgement.
 *
 * Operates on the process-wide AppDelegate, game system, and note-effect manager: loads the replay
 * for the current music id and difficulty, then walks the replay note array in lockstep with the
 * live note list, writing each ghost-side note's recorded judge, JR flag, and long rate (and, for
 * slide notes, each sub-point's judge).
 * @ghidraAddress 0x14fd30
 */
void ApplyReplayGhostToNotes();

// code: language=Objective-C++
// kate: hl Objective-C++;
// vim: set ft=objcpp :
