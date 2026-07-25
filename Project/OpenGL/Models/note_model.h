/**
 * @file
 * A live play-field note, @c NoteModel.
 */

#pragma once

#include "s_vector2.h"

struct RbffNoteRecord;

/**
 * @brief One path waypoint node: a start time and the two endpoints a note interpolates between.
 *
 * A 20-byte record; @c AdvanceNoteAlongWaypoint interpolates the note position from @c startPos
 * towards @c endPos by the elapsed fraction since @c flStartTime.
 */
struct WaypointNode {
    float flStartTime = {};  // +0x00: the node's start time.
    S_VECTOR2 startPos = {}; // +0x04: the interpolation start position.
    S_VECTOR2 endPos = {};   // +0x0c: the interpolation end position (the per-fraction delta).
};

/**
 * @brief One live note on the play field: its chart record, animation state, world position, and
 * judgement result.
 *
 * Spawned from an @c RbffNoteRecord when the chart reaches the note's lead-in and advanced each
 * frame by the note state machine until it is hit or missed. The trailing @c // +0xNN comments
 * document the original member offsets for reference only; the spans between the modelled members
 * are the note's animation and waypoint state, reserved to preserve the 1528-byte layout.
 * @ghidraAddress NoteModel (engine note struct, 1528 bytes)
 */
class NoteModel {
public:
    /**
     * @brief Constructs a note bound to its owning sheet: clears the play state, seeds every
     * sub-entry slot to its empty defaults, zeroes the waypoint block, and stores the font variant.
     * @param pSheet The owning note sheet.
     * @ghidraAddress 0x1319fc
     */
    explicit NoteModel(void *pSheet);

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
     * @brief Returns the note's target Y line: the screen edge the note travels toward.
     *
     * The travel-line fraction is chosen by the note's hold kind (the record's hold kind, or the own-
     * side flag for a synthetic note): kind 0 uses the near-lane slope, kind 1 uses the far-lane
     * slope, any other kind yields zero. The fraction is scaled by the game system's sheet inset.
     * @return The target Y coordinate.
     * @ghidraAddress 0x135310
     */
    float GetTargetLineY() const;

    /**
     * @brief Marks this note as touched (the frame's nearest-hit winner).
     * @ghidraAddress 0x13609c
     */
    void MarkTouched();

    /**
     * @brief Advances the note's position by one frame: saves the previous position, then either
     * follows its active waypoint or integrates its velocity over the frame delta.
     * @ghidraAddress 0x1336e4
     */
    void AdvancePosition();

    /**
     * @brief Interpolates the note's position along its current waypoint node by the elapsed
     * fraction since the node's start time.
     * @ghidraAddress 0x136960
     */
    void AdvanceAlongWaypoint();

    /**
     * @brief The state-machine fade-out step: advances the note's position and decays its fade
     * timer, transitioning to the finished state once the timer reaches zero.
     * @ghidraAddress 0x1334dc
     */
    void UpdateStepFadeOut();

    /**
     * @brief The state-machine shot step: advances the reflected note along its reversed velocity by
     * its speed and progress, stores the render position and draw flags, and finishes the note once
     * it flies below the play field.
     * @ghidraAddress 0x132b20
     */
    void UpdateStepShot();

    /** @brief The note's index in its sheet. */
    int GetNoteIndex() const {
        return m_nNoteIndex;
    }

    /** @brief The note-state-machine state. */
    int GetState() const {
        return m_nState;
    }

    /**
     * @brief Assigns the note's chart index and refreshes its record pointer from the owning
     *        manager's active chart.
     * @param nIndex The chart note index.
     * @ghidraAddress 0x131aa8
     */
    void SetNoteIndex(int nIndex);

    /**
     * @brief Detaches the note from any chart note: clears the chart index (to -1) and the record
     *        pointer.
     * @ghidraAddress 0x131ad8
     */
    void ResetBinding();

    /** @brief The no-side sentinel returned when the note has neither a record side nor own side. */
    static constexpr int kNoSideSentinel = 3;

    /** @brief The idle-type sentinel a synthetic note reports for its type when it has no own side. */
    static constexpr int kIdleTypeSentinel = 5;

    /** @brief The number of per-note sub-entry (hold/slide segment) slots. */
    static constexpr int kSubEntryCount = 16;

private:
    void *m_pSheet = {};            // +0x00: the owning note manager (NoteEffectMgr).
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
    unsigned char m_aReserved4c[8] = {};    // +0x4c: further animation state.
    float m_flShotSpeed = {};               // +0x54: the shot step's travel speed.
    float m_flShotProgress = {};            // +0x58: the shot step's travel progress.
    float m_flRenderX = {};                 // +0x5c: the note's render X coordinate.
    float m_flRenderY = {};                 // +0x60: the note's render Y coordinate.
    unsigned char m_aReserved64[0x10] = {}; // +0x64: further animation/long-note state.

    // One per-note sub-entry (a hold/slide segment slot): its kind, source note index, and seeded
    // state, filled by the constructor. The 0x48-byte stride and field roles are from the ctor.
    struct SubEntry {
        int nKind = {};                       // +0x00: the segment kind (5 = none).
        int nIndex = {};                      // +0x04: the source note index (-1 = none).
        unsigned char aReserved08[0x30] = {}; // +0x08: per-segment state, still being worked out.
        int nSeedA = {};                      // +0x38: a seed value (constructed to 5).
        int nSeedB = {};                      // +0x3c: a seed value (constructed to 0).
        int nSeedC = {};                      // +0x40: a seed value (constructed to 0).
        int nSeedD = {};                      // +0x44: a seed value (constructed to 5).
    };
    // +0x74..+0x4f3: the 16 per-note sub-entry slots.
    SubEntry m_aSubEntries[kSubEntryCount] = {}; // +0x74
    int m_nField4f4 = {};                    // +0x4f4: post-table state, still being worked out.
    int m_nField4f8 = {};                    // +0x4f8: post-table state, still being worked out.
    unsigned char m_aReserved4fc[0xc] = {};  // +0x4fc
    void *m_pField508 = {};                  // +0x508: cleared on construction.
    unsigned char m_aReserved510[0x10] = {}; // +0x510
    // +0x520: the waypoint/path animation block, zeroed on construction. +0x594 holds the
    // waypoint-active flag that switches AdvanceNotePosition onto the interpolated path.
    unsigned char m_aWaypointBlock0[0x74] = {}; // +0x520
    bool m_bWaypointActive = {};                // +0x594
    unsigned char m_aWaypointBlock1[0x2b] = {}; // +0x595
    WaypointNode *m_pCurrentWaypoint = {};      // +0x5c0: the current path waypoint node, or null.
    unsigned char m_aReserved5c8[0x8] = {};     // +0x5c8
    float m_flFadeTimer = {};                   // +0x5d0: the fade-out step's decaying timer.
    unsigned char m_aReserved5d4[4] = {};       // +0x5d4
    // +0x5d8: the two render draw flags, packed as one 16-bit store {bDrawFlag0, bDrawFlag1}.
    unsigned short m_wDrawFlags = {};
    unsigned char m_aReserved5da[5] = {}; // +0x5da
    bool m_bTouched = {};                 // +0x5df: the frame's nearest-hit winner flag.
    bool m_bOwnSide = {};     // +0x5e0: the note's own side flag, used when it has no record.
    bool m_bFontVariant = {}; // +0x5e1: the device font variant, set at construction.
    unsigned char m_aReserved5e2[0x16] = {}; // +0x5e2: trailing state to the 0x5f8-byte size.
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
