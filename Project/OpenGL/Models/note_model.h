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

    /**
     * @brief Reports whether the note is on the current play side.
     *
     * With no chart record, or a record whose side is out of range, the note's own-side flag decides
     * (returning the no-side sentinel when unset). Otherwise the note is on the play side when its
     * side matches the game system's current play side.
     * @return @c 1 when the note is on the play side, @c 0 when not, @c 3 as the no-side sentinel.
     * @ghidraAddress 0x134924
     */
    int IsOnPlaySide() const;

    /**
     * @brief Returns the play-field Y bound for a virtual-lane band index.
     *
     * The nine bands run from the top edge (bands 0 through 3, at decreasing fractions of the field
     * height), through the centre (band 4, which is zero), to the bottom edge (bands 5 through 8).
     * The returned bound is twice the band's edge times its fraction.
     * @param nBand The band index (0 through 8).
     * @return The Y bound for the band.
     * @ghidraAddress 0x1360a8
     */
    static float GetVirtualBoundY(int nBand);

    /**
     * @brief Returns the note's across-field X position.
     *
     * Looks up the lane fraction for the note's hold kind and display lane (from its chart record,
     * or the own-side fallback for a synthetic note) and scales it by the game system's sheet-inset
     * half-width.
     * @return The across-field X position.
     * @ghidraAddress 0x1352b8
     */
    float GetLaneX() const;

    /**
     * @brief Returns the note's play side.
     *
     * Reads the chart record's side, or (for a synthetic note) derives it from the own-side flag,
     * returning the no-side sentinel when the flag is unset.
     * @return The play side, or the no-side sentinel.
     * @ghidraAddress 0x133a24
     */
    int GetSide() const;

    /**
     * @brief Returns the note's type.
     *
     * Reads the chart record's type, or (for a synthetic note) returns a fixed value from the
     * own-side flag (the idle sentinel when the flag is unset).
     * @return The note type.
     * @ghidraAddress 0x1336c0
     */
    int GetType() const;

    /**
     * @brief Returns the note's chart start time, or -1 when it has no record.
     * @return The start time.
     * @ghidraAddress 0x13490c
     */
    int GetStartTime() const;

    /**
     * @brief Returns the note's hit time.
     *
     * From a chart record, the hit time is the sum of the record's two time stamps; for a synthetic
     * note it is the spawn time plus a fixed lead, and zero when the note has neither.
     * @return The hit time.
     * @ghidraAddress 0x13353c
     */
    float GetHitTime() const;

    /**
     * @brief Returns the note's kind, or -1 when it has no chart record.
     * @return The note kind.
     * @ghidraAddress 0x136a20
     */
    int GetKind() const;

    /**
     * @brief Returns the number of slide points in a slide (type 3) note.
     *
     * Assumes a chart record is present (a slide note always has one).
     * @return The slide-point count.
     * @ghidraAddress 0x1369e8
     */
    int GetSlidePointCount() const;

    /**
     * @brief Marks this note as touched (the frame's nearest-hit winner).
     * @ghidraAddress 0x13609c
     */
    void MarkTouched();

    /** @brief The no-side sentinel returned when the note has neither a record side nor own side. */
    static constexpr int kNoSideSentinel = 3;

    /** @brief The idle-type sentinel a synthetic note reports for its type when it has no own side. */
    static constexpr int kIdleTypeSentinel = 5;

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
    unsigned char m_aReserved4c[0x593] = {}; // +0x4c: animation, long-note, and waypoint state.
    bool m_bTouched = {}; // +0x5df: set when this note is the frame's nearest-hit winner.
    bool m_bOwnSide = {}; // +0x5e0: the note's own side flag, used when it has no record.
    unsigned char m_aReserved5e1[0xb] = {}; // +0x5e1
};

/**
 * @brief The note lane-position table: the across-field fractions for the note lanes, plus the lane
 * spread span and the wide-lane fractions for the alternate lane kind.
 *
 * Seeded once by @c InitNoteLaneTable and read by @c GetNoteLaneFraction. The trailing @c // +0xNN
 * comments document the original offsets within the table's global. The leading span is unused
 * padding preceding the seeded fields.
 */
struct NoteLaneTable {
    unsigned char m_aReserved00[0x28] = {}; // +0x00: unused padding before the seeded fields.
    float flLaneFrac0 = {};                 // +0x28: lane 0 fraction (leftmost).
    float flLaneFrac1 = {};                 // +0x2c: lane 1 fraction.
    float flLaneFrac2 = {};                 // +0x30: lane 2 fraction.
    float flLaneFrac4 = {};                 // +0x34: lane 4 fraction (lane 3 is the zero centre).
    float flLaneFrac5 = {};                 // +0x38: lane 5 fraction.
    float flLaneFrac6 = {};                 // +0x3c: lane 6 fraction (rightmost).
    float flLaneSpread = {};                // +0x40: the lane spread span.
    float flWideLaneLeft = {};              // +0x44: the alternate kind's left wide-lane fraction.
    float flWideLaneRight = {};             // +0x48: the alternate kind's right wide-lane fraction.
};

/**
 * @brief Seeds the note lane-position table with the across-field lane fractions, spread span, and
 * wide-lane fractions.
 * @ghidraAddress 0x136afc
 */
void InitNoteLaneTable();

/**
 * @brief Returns a note lane's across-field position fraction.
 *
 * For the ordinary lane kind, returns the lane's fraction (the centre lane is zero, and out-of-range
 * lanes are zero). For the alternate wide-lane kind, the two wide lanes use the wide-lane fractions
 * and every other lane is zero.
 * @param nKind The lane kind.
 * @param nLane The lane index.
 * @return The lane's position fraction.
 * @ghidraAddress 0x136a38
 */
float GetNoteLaneFraction(int nKind, int nLane);

/**
 * @brief Projects a note's screen point onto the play-field intersection line, in place.
 *
 * Builds the screen pick ray through @p pPointInOut, intersects it with the downward reference
 * plane, and writes the resulting X and Y back into @p pPointInOut.
 * @param pPointInOut The screen point in; the projected intersection point out.
 * @ghidraAddress 0x1372e4
 */
void ProjectNoteHitPoint(S_VECTOR2 *pPointInOut);

// code: language=C++
// kate: hl C++;
// vim: set ft=cpp :
