/**
 * @file
 * A live play-field note, @c NoteModel.
 */

#pragma once

#include "s_vector2.h"

class RbffNoteRecord;

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
     * sub-entry slot to its empty defaults, zeroes the waypoint block, and stores the is-pad flag.
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
     * @brief Returns the judge result recorded for slide point @p nIndex of a slide (type 3) note,
     * or the miss sentinel (5) when the index is past the slide-point count.
     * @param nIndex The slide-point index.
     * @return The per-point judge result, or 5 when out of range.
     * @ghidraAddress 0x1369f4
     */
    int GetSlidePointJudge(int nIndex) const;

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

    /**
     * @brief The state-machine approach step (state 1): tracks the note's lead-in until its path
     * head time is reached, then links its path and advances it. Reconstruction pending.
     * @ghidraAddress 0x131bc0
     */
    void UpdateStepApproach();

    /**
     * @brief The state-machine existing step (state 2): advances the note, reflects it off the play
     * field, and judges its timing or miss. Reconstruction pending.
     * @ghidraAddress 0x131e3c
     */
    void UpdateStepExisted();

    /**
     * @brief The state-machine long-touched step (state 3): follows the held long-note path and
     * registers touches, scoring on completion. Reconstruction pending.
     * @ghidraAddress 0x1324c4
     */
    void UpdateStepLongTouched();

    /**
     * @brief The state-machine slide-existing step (state 5): advances a slide note along its path.
     * Reconstruction pending.
     * @ghidraAddress 0x132be0
     */
    void UpdateStepSlideExisted();

    /**
     * @brief Dispatches one per-frame note update to the step handler for the note's current state.
     * @ghidraAddress 0x131b64
     */
    void UpdateStep();

    /**
     * @brief Initialises the note for activation: seeds its full play state from its chart record
     * before it enters the active list. Reconstruction pending.
     * @ghidraAddress 0x134128
     */
    void Init();

    /**
     * @brief Resets the note's play state to its pre-play defaults for a replay. Reconstruction
     * pending.
     * @ghidraAddress 0x131ae8
     */
    void ResetPlayState();

    /**
     * @brief Sets the note's spawn geometry and route for the coming play, then propagates the same
     * position, spawn time, and route along the note's linked chain. Reconstruction pending.
     * @ghidraAddress 0x13498c
     */
    void SetRoute();

    /**
     * @brief Sets this note's shot direction (clamped to [-2, 2]) and propagates it, its spawn
     * position, and its spawn time along the note's linked chain, re-routing each.
     * @param nDirection The requested shot direction.
     * @ghidraAddress 0x1335ec
     */
    void SetShotDirection(int nDirection);

    /**
     * @brief Returns the play colour of the note bound at this note's start index, or the
     * no-active-note sentinel (5) when none is active.
     * @return The active note's rival-mode colour, or 5.
     * @ghidraAddress 0x1361b0
     */
    int GetActiveNoteColor() const;

    /**
     * @brief The shot-phase step: decays the shot lifetime timer and dispatches to the per-colour
     * shot handler (player, CPU, or ghost) until the note leaves its shot phase.
     * @ghidraAddress 0x133774
     */
    void CheckShot();

    /**
     * @brief The player-controlled shot handler. Reconstruction pending.
     * @ghidraAddress 0x1361ec
     */
    void CheckShotPlayer();

    /**
     * @brief The CPU-controlled shot handler. Reconstruction pending.
     * @ghidraAddress 0x136480
     */
    void CheckShotCPU();

    /**
     * @brief The ghost (replay) shot handler. Reconstruction pending.
     * @ghidraAddress 0x13663c
     */
    void CheckShotGhost();

    /**
     * @brief Tests whether a touch point hits this note, reporting the squared touch distance.
     *
     * Only a player note in its existing or slide-existing state can be hit, and only once the judge
     * clock is inside its hit window or it is close enough below its target line. The note's
     * side-mirrored screen position is compared against the touch point, and a hit requires the
     * squared distance to fall within the sheet's touch radius.
     * @param flX The touch X.
     * @param flY The touch Y.
     * @param pOutDistanceSq Receives the squared touch distance on a hit.
     * @return @c true when the touch hits the note.
     * @ghidraAddress 0x135ee8
     */
    bool CheckTouchHit(float flX, float flY, float *pOutDistanceSq) const;

    /**
     * @brief Judges a touched note's timing accuracy and reports the resulting grade.
     *
     * Does nothing when the note is not the frame's touched note. Otherwise it grades the signed
     * time error against the timing windows (0 = just, 1 = early/late, 2 = far) and resolves the hit.
     * @ghidraAddress 0x133a48
     */
    void JudgeNoteTiming();

    /**
     * @brief Tests whether an untouched note has passed its hit window and, if so, misses it.
     *
     * Once the judge clock is inside the note's miss window and at or past its hit time, a tap-only
     * note (kind 3) plays its miss sound and is marked processed, while any other note snaps to its
     * lane target and resolves as a miss.
     * @ghidraAddress 0x133b1c
     */
    void CheckNoteMiss();

    /**
     * @brief The auto-play tap: fires the note's tap once the judge clock reaches its hit window.
     *
     * The window test matches @c CheckNoteMiss; a tap-only note (kind 3) plays its tap sound and is
     * marked processed, any other note snaps to its lane target and resolves its hit.
     * @ghidraAddress 0x133c8c
     */
    void UpdateNoteAutoTap();

    /**
     * @brief Plays the note's tap/hit sound: its keysound, or a default sound from the sound table.
     *
     * A CPU/ghost note (rival mode non-zero) that is excluded from scoring stays silent unless the
     * game is in the CPU full-combo mode; the dispatched judge event carries the resolved sound
     * index and the note's play side.
     * @param nSoundIndex The default sound index (0 to 2) for a note with no keysound.
     * @param bUseAlt Whether to select the alternate keysound path.
     * @ghidraAddress 0x133dfc
     */
    void PlayNoteTapSound(int nSoundIndex, bool bUseAlt);

    /**
     * @brief Records a note's judged grade and drives its post-hit effects and scoring.
     * Reconstruction pending.
     * @param nGrade The judged grade.
     * @ghidraAddress 0x133ec0
     */
    void ResolveNoteHit(unsigned int nGrade);

    /**
     * @brief Activates each of the note's chain path-point links, clearing the perfect-hit flag.
     *
     * For each of the record's path points, activates the note at that path-point index through the
     * owning manager and clears the note's perfect-hit flag. Does nothing without a chart record or
     * an owning sheet.
     * @ghidraAddress 0x133578
     */
    void UpdateNotePathLinks();

    /** @brief The note's index in its sheet. */
    int GetNoteIndex() const {
        return m_nNoteIndex;
    }

    /** @brief The note-state-machine state. */
    int GetState() const {
        return m_nState;
    }

    /** @brief The note's rival-play mode (0 = player, 1 = CPU, 2 = ghost). */
    int GetRivalMode() const {
        return m_nRivalMode;
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
    /**
     * @brief Returns the current play-field judge clock: the play time scaled to the chart's
     * millisecond range and offset by the lead-in.
     */
    float GetCurrentJudgeTime() const;

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
    bool m_bShotActive = {};        // +0x4c: whether the note is in its shot (reflect) phase.
    unsigned char m_aReserved4d[3] = {};    // +0x4d
    float m_flShotDecayTimer = {};          // +0x50: the shot phase's decaying lifetime timer.
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
        int nSlidePointJudge = {}; // +0x3c: the slide point's judge result (0 until judged).
        int nSeedC = {};           // +0x40: a seed value (constructed to 0).
        int nSeedD = {};           // +0x44: a seed value (constructed to 5).
    };
    // +0x74..+0x4f3: the 16 per-note sub-entry slots.
    SubEntry m_aSubEntries[kSubEntryCount] = {}; // +0x74
    int m_nField4f4 = {};                   // +0x4f4: post-table state, still being worked out.
    int m_nField4f8 = {};                   // +0x4f8: post-table state, still being worked out.
    unsigned char m_aReserved4fc[0xc] = {}; // +0x4fc
    void *m_pField508 = {};                 // +0x508: cleared on construction.
    unsigned char m_aReserved510[4] = {};   // +0x510
    int m_nDirectionSign = {};              // +0x514: the shot direction, clamped to [-2, 2].
    int m_nWaypointCount = {};              // +0x518: the shot's waypoint count (abs of direction).
    unsigned char m_aReserved51c[4] = {};   // +0x51c
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
    unsigned char m_aReserved5da = {}; // +0x5da
    bool m_bJustHit =
        {}; // +0x5db: the perfect-hit flag, cleared when the note's path links notify.
    bool m_bShotDecaying = {};         // +0x5dc: whether the shot phase runs its decay timer.
    unsigned char m_aReserved5dd = {}; // +0x5dd
    bool m_bMissProcessed = {}; // +0x5de: whether a passed/missed tap note was already handled.
    bool m_bTouched = {};       // +0x5df: the frame's nearest-hit winner flag.
    bool m_bOwnSide = {};       // +0x5e0: the note's own side flag, used when it has no record.
    bool m_bIsPad = {};         // +0x5e1: whether the device is an iPad, set at construction.
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
