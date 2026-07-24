/**
 * @file
 * A live play-field note, @c NoteModel.
 */

#pragma once

#include "s_vector2.h"

struct RbffNoteRecord;

/**
 * @brief One live note on the play field: its chart record, animation state, world position, and
 * judgement result.
 *
 * Spawned from an @c RbffNoteRecord when the chart reaches the note's lead-in and advanced each
 * frame by the note state machine until it is hit or missed. The trailing @c // +0xNN comments
 * document the original member offsets for reference only; the spans between the modelled members
 * are the note's animation and waypoint state, reserved to preserve the 1516-byte layout.
 * @ghidraAddress NoteModel (engine note struct, 1516 bytes)
 */
class NoteModel {
public:
    /**
     * @brief Reports whether the note should be horizontally mirrored for the current play side.
     *
     * With no chart record, or a record whose side is out of range, the note's own side flag
     * decides (returning the no-partner sentinel when unset). Otherwise the note is flipped when its
     * side differs from the game system's current play side.
     * @return @c 1 when the note's X should be flipped, @c 0 when not, @c 3 as the no-side sentinel.
     * @ghidraAddress 0x135e84
     */
    int IsSideFlipped() const;

    /** @brief The no-side sentinel returned when the note has neither a record side nor own side. */
    static constexpr int kNoSideSentinel = 3;

private:
    void *m_pSheet = {};            // +0x00: the owning note sheet.
    RbffNoteRecord *m_pRecord = {}; // +0x08: the parsed chart record, or null for a synthetic note.
    int m_nNoteIndex = {};          // +0x10: the note's index in its sheet.
    int m_nState = {};              // +0x14: the note-state-machine state.
    int m_nSubState = {};           // +0x18: the sub-state within the state.
    int m_nRivalMode = {};          // +0x1c: the rival-play mode.
    int m_nKind = {};               // +0x20: the note kind.
    int m_nJudgeGrade = {};         // +0x24: the judgement grade.
    S_VECTOR2 m_basePos = {};       // +0x28: the note's base (spawn) position.
    float m_flSpawnTime = {};       // +0x30: the spawn time.
    S_VECTOR2 m_pos = {};           // +0x34: the current position.
    S_VECTOR2 m_prevPos = {};       // +0x3c: the previous-frame position.
    S_VECTOR2 m_velocity = {};      // +0x44: the per-frame velocity.
    unsigned char m_aReserved4c[0x594] = {}; // +0x4c: animation, long-note, and waypoint state.
    bool m_bOwnSide = {}; // +0x5e0: the note's own side flag, used when it has no record.
    unsigned char m_aReserved5e1[0xb] = {}; // +0x5e1
};

// code: language=C++
// kate: hl C++;
// vim: set ft=cpp :
