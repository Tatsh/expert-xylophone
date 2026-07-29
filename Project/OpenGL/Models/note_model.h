/**
 * @file
 * A live play-field note, @c NoteModel.
 */

#pragma once

#include "s_vector2.h"

class NoteEffectMgr;
class RbffNoteRecord;

/**
 * @brief One path waypoint node: a start time, the two endpoints a note interpolates between, and
 * the segment's length.
 *
 * A 40-byte record. @c AdvanceAlongWaypoint interpolates the note position from @c startPos towards
 * @c endPos by the elapsed fraction since @c flStartTime. The route pass fills @c flLength with the
 * straight-line distance between the endpoints, then converts it into the segment's traversal time
 * and rescales @c endPos into a per-unit-time velocity.
 */
struct WaypointNode {
    float flStartTime = {};  /*!< The node's start time. +0x00 */
    S_VECTOR2 startPos = {}; /*!< The interpolation start position. +0x04 */
    /** @brief The interpolation end position (the per-fraction delta). +0x0c */
    S_VECTOR2 endPos = {};
    float flLength = {}; /*!< The segment's length, traded for its traversal time. +0x14 */
    /**
     * @brief The node's trailing four words. +0x18
     *
     * No routine in the binary reads or writes them — the route pass's block-wide clear is their
     * only writer — so they carry no recovered meaning and are named for their position rather
     * than a guessed role.
     */
    float aflSpare18[4] = {};
};

/** @brief The number of path nodes a note's waypoint block holds. */
constexpr int kWaypointBlockNodeCount = 4;

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
    explicit NoteModel(NoteEffectMgr *pSheet);

    /**
     * @brief Reports whether the note should be horizontally mirrored for the current play side.
     *
     * With no chart record, or a record whose side is out of range, the note's own side flag
     * decides (returning the no-partner sentinel when unset). Otherwise the note is flipped when
     * its side differs from the game system's current play side.
     * @return @c 1 when the note's X should be flipped, @c 0 when not, @c 3 as the no-side
     * sentinel.
     * @ghidraAddress 0x135e84
     */
    int IsSideFlipped() const;

    /**
     * @brief Reports whether the note is on the current play side.
     *
     * With no chart record, or a record whose side is out of range, the note's own-side flag
     * decides (returning the no-side sentinel when unset). Otherwise the note is on the play side
     * when its side matches the game system's current play side.
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
     * The travel-line fraction is chosen by the note's hold kind (the record's hold kind, or the
     * own- side flag for a synthetic note): kind 0 uses the near-lane slope, kind 1 uses the
     * far-lane slope, any other kind yields zero. The fraction is scaled by the game system's sheet
     * inset.
     * @return The target Y coordinate.
     * @ghidraAddress 0x135310
     */
    float GetTargetLineY() const;

    /**
     * @brief Marks this note as touched (the frame's nearest-hit winner).
     * @ghidraAddress 0x13609c
     */
    void MarkTouched();

    /** @brief Returns the note's assigned colour kind (0 through 3). */
    int GetColorKind() const {
        return m_nKind;
    }
    /** @brief Sets the note's assigned colour kind. */
    void SetColorKind(int nKind) {
        m_nKind = nKind;
    }
    /**
     * @brief Whether the note carries a pre-assigned (locked) colour, kept instead of a random one.
     *
     * A colour-lock state at or below @c kColorLockThreshold is itself the assigned colour.
     */
    bool IsColorLocked() const {
        return m_nColorLockState <= kColorLockThreshold;
    }
    /** @brief The pre-assigned colour a locked note carries (its colour-lock state value). */
    int GetLockedColor() const {
        return m_nColorLockState;
    }

    /** @brief Stamps the note with a replay's recorded judge, JR flag, and long-note rate. */
    void SetReplayResult(int nJudge, bool bJustReflec, float flLongRate) {
        m_nColorLockState = nJudge;
        m_bEmphasisFallback = bJustReflec;
        m_flLongRate = flLongRate;
    }
    /** @brief Sets slide sub-point @p nIndex's recorded judge result. */
    void SetSlidePointJudge(int nIndex, int nJudge) {
        m_aSubEntries[nIndex].nSlidePointJudge = nJudge;
    }
    /** @brief Sets slide sub-point @p nIndex's recorded replay judge (the +0x44 sub-entry slot). */
    void SetSlideReplayJudge(int nIndex, int nJudge) {
        m_aSubEntries[nIndex].nIncomingGrade = nJudge;
    }
    /** @brief The note's recorded judge result (from a replay). */
    int GetRecordedJudge() const {
        return m_nColorLockState;
    }
    /** @brief The note's judgement grade (the per-note COOL/GREAT/GOOD/MISS index). */
    int GetJudgeGrade() const {
        return m_nJudgeGrade;
    }
    /** @brief The note's shot travel progress (recorded as the replay long-note rate). */
    float GetShotProgress() const {
        return m_flShotProgress;
    }
    /** @brief Whether a CPU/ghost shot has been scored on this note (the replay just-reflec flag).
     */
    bool IsShotResolved() const {
        return m_bShotResolved;
    }

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
     * @brief Reflects the note at a play-field edge, or advances it to its next path waypoint.
     *
     * Computes the edge bound from the note-field half-width, mirrored by the travel direction and
     * the note's side flip. When the note still has waypoints left, it advances the waypoint index,
     * points the current-waypoint pointer at the next node, follows it, and takes the node's
     * velocity; otherwise (unless the record is a hold note) it bounces the note back by mirroring
     * its X about the edge and negating its X velocity. Either way it spawns a bounds effect at the
     * edge and clears the waypoint-active flag.
     * @param nDirection The travel direction sign selecting which edge to reflect off.
     * @ghidraAddress 0x133858
     */
    void HandleReflect(int nDirection);

    /**
     * @brief The state-machine fade-out step: advances the note's position and decays its fade
     * timer, transitioning to the finished state once the timer reaches zero.
     * @ghidraAddress 0x1334dc
     */
    void UpdateStepFadeOut();

    /**
     * @brief The state-machine shot step: advances the reflected note along its reversed velocity
     * by its speed and progress, stores the render position and draw flags, and finishes the note
     * once it flies below the play field.
     * @ghidraAddress 0x132b20
     */
    void UpdateStepShot();

    /**
     * @brief The state-machine approach step (state 1): eases the note in until it reaches the play
     * field, then hands it to its existing/slide state.
     *
     * Once the play clock passes the note's hit time, links its path and finishes it (state 8).
     * Otherwise it advances the appearance progress from the note's spawn epoch, scaled by the
     * record's resolved scroll speed. Below full progress it stores the eased appearance scale and
     * progress fraction; at full progress it snaps to full scale, clears the shot direction, and
     * enters the existing state (state 2) or, for a slide note, the slide state (state 5) after
     * computing each slide point's interpolation times and slopes.
     * @ghidraAddress 0x131bc0
     */
    void UpdateStepApproach();

    /**
     * @brief The state-machine existing step (state 2): advances the note, reflects it off the play
     * field, and either judges its timing (per rival mode) or, once it has passed its target line
     * without a hit, finalises it as a miss (scoring the miss, applying the gauge penalty, and
     * spawning the miss glow and bounds-damage effects). A hold note keeps its render endpoint
     * tracking the tail.
     * @ghidraAddress 0x131e3c
     */
    void UpdateStepExisted();

    /**
     * @brief The state-machine long-touched step (state 3): tracks a held long note.
     *
     * While the hold runs it moves the note's render endpoint along the reversed velocity by the
     * remaining fraction of the hold. It then decides whether the note is still touched (a CPU or
     * ghost note always is; a player note holds while an active touch stays within the sheet's
     * release radius, or unconditionally while paused). Once the note is released or its release
     * time passes, it either finishes as a hit at its stored grade (scoring the hit, spawning the
     * burst, adding the gauge gain, and playing the tap sound) or, on an early release, enters the
     * shot state and scores a miss with the hold-shortfall penalty.
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
     * @brief Emits this frame's sprites for the note into the per-kind note layers.
     *
     * Drops the note outright when it belongs to a hidden rival side or is not in a drawable state.
     * A slide note emits its body, its result burst once scored, and one segment per slide point
     * whose window contains the play clock; a long note emits its body, its trail once held and
     * graded, and a head particle; every other note emits a plain body. A chained note then draws
     * the connector to its partner, and a note whose shot has been resolved emits its charge.
     * Every position is mirrored for the play side.
     * @ghidraAddress 0x135388
     */
    void RenderNote();

    /**
     * @brief Initialises the note for activation: seeds its full play state from its chart record
     * before it enters the active list.
     *
     * Resolves the base position from the first of three sources that applies — a chain-mate's base
     * position, a mirrored partner's live position negated through the field centre, or the note's
     * own lane at the mid-lane row — and lays out the slide path's sub-entries when the record
     * names a chosen target. It then seeds the position, shot, render, and spawn-time state,
     * derives the shot direction and rival mode, clears the waypoint block and the per-play flags,
     * and (for a note with no mirrored partner) enters the pre-spawn state and emits its spawn
     * burst. Finally it routes the note and, when its hit time has already passed, snaps it onto
     * the target line in the passed state.
     * @ghidraAddress 0x134128
     */
    void Init();

    /**
     * @brief Lays out the note's path through the waypoint block for the coming play.
     *
     * Clears the block, then fills the start position of each live node. A note partway along a
     * chain copies its head note's route outright; any other note derives its own from its hold
     * kind, shot direction, display lane, and play side: the spawn point, one bounce point per unit
     * of shot direction, and the target line. The segment deltas, lengths, and node start times are
     * then resolved so the whole path is traversed at one speed between the spawn and hit times.
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
     * @brief The ghost (replay) shot handler.
     *
     * The replay counterpart of @c CheckShotCPU: it scores a filled-gauge note by emphasis or the
     * side's full-combo run, but a non-ghost note that fails those tests instead consumes a queued
     * hit from the note manager's hit count, and a resolved ghost note that scored none feeds the
     * hit count back. It then picks the bounce direction and leaves the shot phase.
     * @ghidraAddress 0x13663c
     */
    void CheckShotGhost();

    /**
     * @brief Picks a resolved shot's bounce direction: a hold note follows its display lane, any
     * other note flips a coin between the two outer directions.
     * @return The bounce direction sign.
     */
    int PickShotBounceDirection() const;

    /**
     * @brief Tests whether a touch point hits this note, reporting the squared touch distance.
     *
     * Only a player note in its existing or slide-existing state can be hit, and only once the
     * judge clock is inside its hit window or it is close enough below its target line. The note's
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
     * @brief Decides whether this note should be emphasised (highlighted).
     *
     * A per-combo random chance emphasises the note outright; otherwise, in versus mode, the note
     * is emphasised when its side matches the local side and that side achieved a full combo
     * (falling back to the per-note flag), and in non-versus mode when the user achieved a full
     * combo.
     * @return @c true when the note should be emphasised.
     * @ghidraAddress 0x136884
     */
    bool ShouldEmphasize() const;

    /**
     * @brief Judges a touched note's timing accuracy and reports the resulting grade.
     *
     * Does nothing when the note is not the frame's touched note. Otherwise it grades the signed
     * time error against the timing windows (0 = just, 1 = early/late, 2 = far) and resolves the
     * hit.
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
     *
     * A grade of zero latches the perfect-hit flag. A slide note (record type 3) stores the grade
     * and enters its slide state, returning early for a non-scoring grade. A long note (record type
     * 1) stores the grade, enters its held state, and clears the long-note-active flag. Every other
     * (normal) note is marked scored and finished, spawns the hit burst, and — unless it is a rival
     * note — adds its score, records the judged grade, and adds the per-grade gauge gain (from the
     * chart's density-tier row), then notifies its chain-path links and the scoring subsystem. All
     * paths finish by playing the note's tap sound. Screen positions are mirrored for a
     * side-flipped note.
     * @param nGrade The judged grade (0 = best/just).
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

    /**
     * @brief Resets the note's play state for a new play or retry.
     *
     * Clears the state and sub-state, marks the note index unassigned, sets the kind fields to the
     * none sentinel, re-seeds the first ten sub-entries to their empty defaults, and resets the
     * colour-lock and emphasis flags.
     * @ghidraAddress 0x131ae8
     */
    void ResetPlayState();

    /** @brief The no-side sentinel returned when the note has neither a record side nor own side.
     */
    static constexpr int kNoSideSentinel = 3;

    /** @brief The idle-type sentinel a synthetic note reports for its type when it has no own side.
     */
    static constexpr int kIdleTypeSentinel = 5;

    /** @brief The number of per-note sub-entry (hold/slide segment) slots. */
    static constexpr int kSubEntryCount = 16;

    /** @brief A colour-lock state at or below this leaves the note open to random colour
     * assignment. */
    static constexpr int kColorLockThreshold = 3;

private:
    /**
     * @brief Mirrors a render X coordinate for the play side: negated unless the note is flipped.
     * @param flX The X before mirroring.
     * @return The mirrored X.
     * @ghidraAddress 0x135388
     */
    float MirrorRenderX(float flX) const;

    /**
     * @brief Mirrors a render Y coordinate for the play side: negated when the note is flipped.
     * @param flY The Y before mirroring.
     * @return The mirrored Y.
     * @ghidraAddress 0x135388
     */
    float MirrorRenderY(float flY) const;

    /**
     * @brief Returns the colour the render pass draws the note in: its record's side, or (for a
     * note with no record) its own side, else the no-side sentinel.
     * @return The render side.
     * @ghidraAddress 0x135388
     */
    int GetRenderSide() const;

    /**
     * @brief Whether the note draws its end cap: its link's second bit is clear and its timing
     * selector is under the bound.
     * @return @c true when the end cap is drawn.
     * @ghidraAddress 0x135388
     */
    bool HasRenderEndCap() const;

    /**
     * @brief Emits the plain note body. The binary inlines this into @c RenderNote.
     * @ghidraAddress 0x135388
     */
    void RenderPlainNote();

    /**
     * @brief Emits a slide note's body, its result burst once scored, and one segment per live
     * slide point. The binary inlines this into @c RenderNote.
     * @ghidraAddress 0x135388
     */
    void RenderSlideNote();

    /**
     * @brief Emits a long note's body, its trail once held and graded, and its head particle.
     * @param bAtRenderPoint Whether the note still sits on its render endpoint, which angles the
     *                       body along the travel direction rather than drawing it flat.
     * @ghidraAddress 0x135388
     */
    void RenderLongNote(bool bAtRenderPoint);

    /**
     * @brief Emits the connector from this note to its chain partner, when it has a live one.
     * @ghidraAddress 0x135388
     */
    void RenderChainConnector();

    /**
     * @brief Fills the live waypoint nodes' start positions for a note that derives its own route.
     *
     * The Y pass places the spawn point, the bounce points (whose play-field bands come from the
     * note's display lane and play side) and the target line; the X pass then places the same nodes
     * across the field, alternating field edges for each bounce. The binary inlines this into
     * @c SetRoute; it is split out only to keep the two passes legible.
     * @param nRouteKind The route kind: the plain note or the reflect note.
     * @ghidraAddress 0x13498c
     */
    void BuildRouteWaypoints(int nRouteKind);

    /**
     * @brief Resolves the laid-out route into per-segment deltas, lengths, and node start times.
     *
     * Each node's end position becomes the offset to the next node and its length that offset's
     * magnitude; the path is then traversed at one speed between the spawn and hit times, which
     * turns each end position into a velocity and gives each node its start time. The binary
     * inlines this into @c SetRoute.
     * @ghidraAddress 0x13498c
     */
    void FinishRoute();

    /**
     * @brief Returns the current play-field judge clock: the play time scaled to the chart's
     * millisecond range and offset by the lead-in.
     */
    float GetCurrentJudgeTime() const;

    NoteEffectMgr *m_pSheet = {};   // +0x00: the owning note manager.
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
    // unsigned char m_aReserved4d[3] = {}; // +0x4d
    float m_flShotDecayTimer = {}; // +0x50: the shot phase's decaying lifetime timer.
    float m_flShotSpeed = {};      // +0x54: the shot step's travel speed.
    float m_flShotProgress = {};   // +0x58: the shot step's travel progress.
    float m_flRenderX = {};        // +0x5c: the note's render X coordinate.
    float m_flRenderY = {};        // +0x60: the note's render Y coordinate.
    int m_nLongGrade = {}; // +0x64: a held long note's stored timing grade (set when it is hit).
    int m_nActiveKind =
        {}; // +0x68: the active segment kind (5 = none); a resolved slide note stores
            //        its timing grade here.
    int m_nActiveIndex = {}; // +0x6c: the active segment index (-1 = none).
    int m_nActiveKind2 = {}; // +0x70: a second active segment kind (5 = none).

    // One per-note sub-entry (a hold/slide segment slot): its kind, source note index, and seeded
    // state, filled by the constructor. The 0x48-byte stride and field roles are from the ctor.
    struct SubEntry {
        int nKind = {};  // +0x00: the segment kind (5 = none).
        int nIndex = {}; // +0x04: the source note index (-1 = none).
        // +0x08..+0x20: this slide point's three interpolation times and its start/end control
        // positions, set by the approach step's slide-path setup (UpdateStepApproach).
        float flTime0 = {};  // +0x08: the point's first interpolation time.
        float flTime1 = {};  // +0x0c: the point's second interpolation time.
        float flTime2 = {};  // +0x10: the point's third interpolation time (the pre-seeded time).
        float flStartX = {}; // +0x14: the point's start X.
        float flStartY = {}; // +0x18: the point's start Y.
        float flEndX = {};   // +0x1c: the point's end X.
        float flEndY = {};   // +0x20: the point's end Y.
        // +0x24..+0x28: the point's live interpolated position, advanced each frame by the slide
        // step (UpdateStepSlideExisted) along the two axis slopes.
        float flCurX = {};    // +0x24: the point's current interpolated X.
        float flCurY = {};    // +0x28: the point's current interpolated Y.
        float flSlopeX = {};  // +0x2c: the X slope over the first time span (endX-startX)/(t1-t0).
        float flSlopeY = {};  // +0x30: the Y slope over the second time span (endY-startY)/(t2-t1).
        bool bLastPoint = {}; // +0x34: set on the slide path's final point by the activation pass.
        // unsigned char aReserved35[3] = {}; // +0x35
        int nResolvedGrade =
            {}; // +0x38: the slide point's resolved judge grade (constructed to 5).
        int nSlidePointJudge = {}; // +0x3c: the slide point's judge result / per-point hit tally.
        int nMissCount = {};       // +0x40: the point's miss/combo tally (constructed to 0).
        int nIncomingGrade = {};   // +0x44: the incoming grade/kind, 5 while unresolved.
    };
    // +0x74..+0x4f3: the 16 per-note sub-entry slots.
    SubEntry m_aSubEntries[kSubEntryCount] = {}; // +0x74
    // +0x4f4 and +0x4f8: two words the constructor zeroes (str wzr at 0x131a70 and 0x131a74) and
    // that no other method of the class reads or writes, so their role is not recovered.
    int m_nField4f4 = {};
    int m_nField4f8 = {};
    // +0x4fc..+0x507: twelve bytes no method of the class touches at all, not even to clear them.
    // unsigned char m_aReserved4fc[0xc] = {};
    // +0x508: eight bytes the constructor zeroes in one store (str xzr at 0x131a7c) and that
    // nothing reads. Their type is unknown, so they are modelled as raw storage rather than a
    // pointer.
    // unsigned char m_aReserved508[8] = {};
    bool m_bPlayStateFlag510 = {}; // +0x510: a play-state flag cleared on a play reset.
    // unsigned char m_aReserved511[3] = {}; // +0x511
    int m_nDirectionSign = {}; // +0x514: the shot direction, clamped to [-2, 2].
    int m_nWaypointCount = {}; // +0x518: the shot's waypoint count (abs of direction).
    int m_nWaypointIndex = {}; // +0x51c: the current waypoint's index into the block.
    // +0x520..+0x5bf: the waypoint/path block, zeroed on construction and re-laid-out by SetRoute.
    // The route fills the first m_nWaypointCount + 2 nodes: the spawn point, one node per bounce,
    // and the target line.
    WaypointNode m_aWaypointBlock[kWaypointBlockNodeCount] = {}; // +0x520
    WaypointNode *m_pCurrentWaypoint = {}; // +0x5c0: the current path waypoint node, or null.
    bool m_bLongNoteActive = {};           // +0x5c8: set while a long note is held, cleared when
                                           //         the note is hit and finalised.
    // unsigned char m_aReserved5c9[3] = {};  // +0x5c9
    float m_flAppearScale = {}; // +0x5cc: the approach step's appearance scale, eased in.
    float m_flFadeTimer =
        {};                  // +0x5d0: the fade-out step's decaying timer, also the approach step's
                             //         appearance progress fraction.
    float m_flBornTime = {}; // +0x5d4: the note's spawn epoch, the approach progress's start time.
    bool m_bRenderReflectPath =
        {};                      // +0x5d8: set while the note's held/shot render endpoint is live.
    bool m_bRenderShotTail = {}; // +0x5d9: set by the shot step to draw the reflected tail.
    bool m_bScored = {}; // +0x5da: set once a normal (non-held) note has been scored and finalised.
    bool m_bJustHit =
        {}; // +0x5db: the perfect-hit flag, cleared when the note's path links notify.
    bool m_bShotDecaying = {};  // +0x5dc: whether the shot phase runs its decay timer.
    bool m_bShotResolved = {};  // +0x5dd: set once a CPU/ghost shot has been scored and its gauge
                                //         penalty applied, gating the shot-direction pick.
    bool m_bMissProcessed = {}; // +0x5de: whether a passed/missed tap note was already handled.
    bool m_bTouched = {};       // +0x5df: the frame's nearest-hit winner flag.
    bool m_bOwnSide = {};       // +0x5e0: the note's own side flag, used when it has no record.
    bool m_bIsPad = {};         // +0x5e1: whether the device is an iPad, set at construction.
    // unsigned char m_aReserved5e2[2] = {}; // +0x5e2
    int m_nAutoShotMode = {}; // +0x5e4: the shot's auto-play mode (0 user-driven, 1 CPU, else off).
    int m_nColorLockState =
        {}; // +0x5e8: the recorded/assigned note result: the replay ghost stores the recorded judge
    //         here, and the random colour pass leaves it open when it is above the threshold.
    bool m_bEmphasisFallback = {}; // +0x5ec: the versus-mode emphasis fallback / JR flag.
    // unsigned char m_aReserved5ed[3] = {}; // +0x5ed
    float m_flLongRate = {}; // +0x5f0: the recorded long-note rate (from the replay).
    // unsigned char m_aReserved5f4[4] = {}; // +0x5f4: trailing state to the 0x5f8-byte size.
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
    // unsigned char m_aReserved00[0x28] = {}; /*!< Unused padding before the seeded fields. +0x00
    // */
    float flLaneFrac0 = {};     /*!< Lane 0 fraction (leftmost). +0x28 */
    float flLaneFrac1 = {};     /*!< Lane 1 fraction. +0x2c */
    float flLaneFrac2 = {};     /*!< Lane 2 fraction. +0x30 */
    float flLaneFrac4 = {};     /*!< Lane 4 fraction (lane 3 is the zero centre). +0x34 */
    float flLaneFrac5 = {};     /*!< Lane 5 fraction. +0x38 */
    float flLaneFrac6 = {};     /*!< Lane 6 fraction (rightmost). +0x3c */
    float flLaneSpread = {};    /*!< The lane spread span. +0x40 */
    float flWideLaneLeft = {};  /*!< The alternate kind's left wide-lane fraction. +0x44 */
    float flWideLaneRight = {}; /*!< The alternate kind's right wide-lane fraction. +0x48 */
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
 * For the ordinary lane kind, returns the lane's fraction (the centre lane is zero, and
 * out-of-range lanes are zero). For the alternate wide-lane kind, the two wide lanes use the
 * wide-lane fractions and every other lane is zero.
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
