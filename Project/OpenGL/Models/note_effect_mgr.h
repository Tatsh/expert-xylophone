/**
 * @file
 * The note manager / note-effect manager, @c NoteEffectMgr.
 */

#pragma once

#include "s_vector2.h"

class NoteModel;
class RbffNoteRecord;

namespace rb {
class CMusicSheet2;
}

/**
 * @brief The process-wide note manager: it owns the active chart, the live note render/effect
 * objects, and the running play counters.
 *
 * A lazily-created singleton (see @c shared). Only the fields the reconstructed methods touch are
 * modelled; the spans between them are the note-object pools and per-note render state, reserved to
 * preserve the 360-byte layout. The trailing @c // +0xNN comments document the original offsets for
 * reference only. The class is non-polymorphic, so the name is inferred from its methods rather
 * than confirmed from RTTI.
 * @ghidraAddress NoteEffectMgr (engine note manager, 360 bytes)
 */
class NoteEffectMgr {
public:
    /**
     * @brief The process-wide note manager, created on first use.
     * @return The shared note manager.
     * @ghidraAddress 0x136b9c
     */
    static NoteEffectMgr *shared();

    /**
     * @brief The chart's note-density tier (0, 1, or 2), which selects the per-grade gauge-gain
     * row.
     * @return The density tier.
     */
    int GetDensityTier() const {
        return m_nDensityTier;
    }

    /**
     * @brief Resets the per-note position cache: sets every render entry's cached position to the
     *        -1 empty marker.
     * @ghidraAddress 0x1373a0
     */
    void ClearNotePositionCache();

    /**
     * @brief Returns a touch's projected note-field position, computing and caching it on first use
     * this frame.
     *
     * Returns the cached position when the touch id is already cached; otherwise claims the first
     * empty cache slot, finds the live touch, normalises its position by the view size it began in,
     * projects it into note-field space, and caches it. Returns @c nullptr when the cache is full
     * or no live touch matches.
     * @param nTouchId The touch id to resolve.
     * @ghidraAddress 0x136e38
     */
    const S_VECTOR2 *GetOrCacheNotePosition(int nTouchId);

    /**
     * @brief Returns the note object for a chart note index, or @c nullptr when none matches.
     *
     * A valid in-range index returns the pooled object directly; otherwise (or for a negative
     * index) the pool is scanned for an object whose note index matches.
     * @param nIndex The chart note index.
     * @return The matching note object, or @c nullptr.
     * @ghidraAddress 0x137018
     */
    NoteModel *FindNoteByIndex(int nIndex);

    /**
     * @brief Returns the active chart's note record at @p nIndex, or @c nullptr when no chart is
     *        bound.
     * @param nIndex The note-record index.
     * @return The note record, or @c nullptr.
     * @ghidraAddress 0x137004
     */
    RbffNoteRecord *GetActiveNoteRecord(int nIndex);

    /**
     * @brief Whether the note at @p nIndex is excluded from scoring (flag bit 2 of its record).
     * @param nIndex The note-record index.
     * @return @c true when the note is excluded from scoring; @c false when it is not or has no
     *         record.
     * @ghidraAddress 0x137a88
     */
    bool IsNoteScoreExcluded(int nIndex);

    /**
     * @brief Whether the note at @p nIndex has record flag bit 6 (mask 0x40) set.
     * @param nIndex The note-record index.
     * @return @c true when the flag is set; @c false otherwise.
     * @ghidraAddress 0x137ab8
     */
    bool IsNoteFlag40Set(int nIndex);

    /**
     * @brief Grows the note-object pool and active-list arrays to hold at least @p nCount objects.
     *
     * A no-op when the current capacity already covers @p nCount. Otherwise it allocates new pool
     * and active-list arrays, copies the existing pooled objects across, constructs a fresh
     * @c NoteModel for each added slot, frees the old arrays, and records the new capacity.
     * @param nCount The required object count.
     * @ghidraAddress 0x1371a4
     */
    void EnsureNoteObjectCapacity(int nCount);

    /**
     * @brief Prepares the note objects for the bound chart: ensures pool capacity for the chart's
     *        note count, assigns each note its index, and clears the active list.
     *
     * A no-op when no chart is bound.
     * @ghidraAddress 0x137934
     */
    void InitNoteObjects();

    /**
     * @brief Detaches every pooled note from its chart binding and clears the active list (a
     * lighter reset than a full re-init).
     * @ghidraAddress 0x1379cc
     */
    void ResetAllNoteSubEntries();

    /**
     * @brief Binds a parsed chart and prepares its note objects, choosing a density tier by the
     *        chart's note count; a null chart clears the note bindings instead.
     * @param pMusicSheet The parsed chart, or @c nullptr to clear.
     * @ghidraAddress 0x137a4c
     */
    void SetActiveMusicSheet(rb::CMusicSheet2 *pMusicSheet);

    /**
     * @brief Evaluates the chart's scroll position at a target time by integrating the speed-change
     *        path.
     *
     * Walks the bound chart's speed-change path nodes, accumulating each segment's speed times its
     * duration (scaled to the per-millisecond scroll rate) up to @p nTargetTime, then adds the
     * partial final segment. Returns zero when no chart is bound or it has no path nodes.
     * @param nTargetTime The target time to evaluate the scroll position at.
     * @return The integrated scroll position.
     * @ghidraAddress 0x137664
     */
    float EvaluateNotePathAtTime(int nTargetTime) const;

    /**
     * @brief Appends a newly-activated note to the active list and insertion-sorts it into hit-time
     *        order.
     * @param pNote The note to insert.
     * @ghidraAddress 0x137080
     */
    void InsertActiveNoteSorted(NoteModel *pNote);

    /**
     * @brief Activates the chart note at @p nChartIndex: spawns its @c NoteModel and sorts it into
     * the active list, unless it has no record or is already active.
     *
     * A no-op without a bound chart, when the index has no record, when no pooled object matches,
     * or when the note is already active (its state is non-zero).
     * @param nChartIndex The chart note index.
     * @ghidraAddress 0x136f98
     */
    void ActivateNoteByIndex(int nChartIndex);

    /**
     * @brief Applies the current theme to the manager: caches the player theme from the user
     * settings and the game system's shot type, then preloads that shot type's sound variants.
     * @ghidraAddress 0x136c50
     */
    void ApplyTheme();

    /**
     * @brief Resets every pooled note's play state and clears the active list and counters (a full
     * replay reset).
     * @ghidraAddress 0x137124
     */
    void ResetAllNoteModels();

    /**
     * @brief Dispatches a note judge/tap event to the shot-sound manager, queuing the manager's
     * shot-sound slot at the event's priority.
     * @param nPlaySide The note's play side (the binary computes and passes it, but the sound
     * manager discards it).
     * @param nPriority The judge-event priority (a lower number wins).
     * @ghidraAddress 0x1372b8
     */
    void DispatchNoteJudgeEvent(int nPlaySide, unsigned int nPriority);

    /**
     * @brief Removes finished notes from the active list, compacting the survivors to the front.
     *
     * A note survives while its state has any bit set other than the finished bit (bit 3).
     * @ghidraAddress 0x136f38
     */
    void CompactActiveNotes();

    /**
     * @brief Processes the active-note list for one frame: touch-hit testing, step update, render,
     * and compaction.
     *
     * Unless input is locked, it resolves each live touch's play-field position and, for each
     * touch, finds the nearest active note it hits (within the sheet's touch radius) and marks that
     * note touched. It then advances every active note's state machine, renders the active notes in
     * reverse order, compacts the finished notes out of the list, and clears the per-frame
     * touch-scratch field.
     * @ghidraAddress 0x136ccc
     */
    void ProcessActiveNotes();

    /**
     * @brief Walks every note record of the attached chart (a bounds/validation pass).
     *
     * Fetches each record by index from the bound chart; the fetched pointers are not consumed (the
     * body that used them was inlined away), so this only exercises the record lookup.
     * @ghidraAddress 0x1378e4
     */
    void IterateNoteRecords();

    /**
     * @brief Assigns each active note a randomised colour, then locks the full-combo colours.
     *
     * A per-combo probability picks the proportion of the four colours; each unlocked note draws
     * its colour from that distribution. When the user or CPU achieved a full combo, every note on
     * the matching side is then forced to colour zero.
     * @ghidraAddress 0x1373c0
     */
    void AssignNoteColors();

    /**
     * @brief The active note count (the loaded chart's note count).
     * @ghidraAddress 0x13719c
     */
    int GetNoteCount() const {
        return m_nNoteCount;
    }

    /** @brief The active player theme (0 classic, 1 limelight, otherwise colette). */
    int GetThema() const {
        return m_nThema;
    }

    /**
     * @brief Records a scored note and, when every note of the side is judged, fires the chart's
     * completion.
     *
     * Sums the side's per-grade tallies (grades 3 through 6) on the score tracker; when they reach
     * the total note count, the chart is complete. It then finalises by the final grade: grade 2
     * sets judge score 3, grade 1 sets judge score 2, and grade 0 (a full combo) triggers the
     * theme-specific full-combo layer before setting judge score 0.
     * @param nUnused An index carried by the caller but not used here.
     * @param nSide The scored note's side.
     * @ghidraAddress 0x137790
     */
    void HandleNoteScored(int nUnused, int nSide);

    /**
     * @brief The accumulated hit (judged-note) count.
     * @ghidraAddress 0x137ae4
     */
    int GetHitCount() const {
        return m_nHitCount;
    }
    /**
     * @brief Increments the hit count.
     * @ghidraAddress 0x137aec
     */
    void IncrementHitCount() {
        ++m_nHitCount;
    }
    /**
     * @brief Decrements the hit count (undo on a rewind or miss-revert).
     * @ghidraAddress 0x137afc
     */
    void DecrementHitCount() {
        --m_nHitCount;
    }

private:
    /**
     * @brief Constructs the manager: zeroes the header, clears the per-note render sub-table, sets
     * the six active-slot indices to the -1 empty marker, and seeds the is-pad flag.
     * @ghidraAddress 0x136bec
     */
    NoteEffectMgr();

    // The chart note-count thresholds that select the density tier (0, 1, or 2).
    static constexpr int kDensityTierThreshold1 = 201;
    static constexpr int kDensityTierThreshold2 = 401;
    // The per-note render sub-table entry count and byte stride.
    static constexpr int kRenderEntryCount = 20;
    static constexpr int kRenderEntryStride = 0xc;
    // The empty marker held by an unused active-slot index.
    static constexpr long kActiveSlotNone = -1;

    int m_nShotSoundSlot = {}; // +0x00: the shot-sound slot id dispatched on a note judge.
    // unsigned char m_aReserved04[4] = {};  // +0x04: header state, still being worked out.
    NoteModel **m_ppNotePool = {};   // +0x08: the pooled NoteModel-object array.
    NoteModel **m_ppActiveList = {}; // +0x10: the active-note pointer array.
    int m_nNoteCount = {};           // +0x18: the active note count (the chart's note count).
    int m_nPoolCapacity = {};        // +0x1c: the note-object pool/array capacity.
    int m_nActiveCount = {};         // +0x20: the number of active notes.
    // unsigned char m_aReserved24[4] = {};  // +0x24
    rb::CMusicSheet2 *m_pMusicSheet = {}; // +0x28: the bound active chart, or null.
    int m_nDensityTier = {};              // +0x30: the note-density tier (0, 1, or 2).
    int m_nFrameTouchScratch =
        {}; // +0x34: per-frame touch-scratch, cleared at the end of a process pass.
    // +0x38..+0x60: the six active-slot note indices, seeded to the -1 empty marker.
    long m_aActiveSlot[6] = {}; // +0x38

    // One per-note render entry: the cached note position (-1 when empty) and its render state.
    struct RenderEntry {
        int nCachedKey = {};      // +0x00: the touch id this slot caches, or -1 when empty.
        S_VECTOR2 cachedPosition; // +0x04: the touch's projected note-field position.
    };
    // +0x68..+0x157: the 20-entry per-note render sub-table (each kRenderEntryStride bytes).
    RenderEntry m_aRenderTable[kRenderEntryCount] = {}; // +0x68
    bool m_bIsPad = {};                                 // +0x158: whether the device is an iPad.
    // unsigned char m_aReserved159[3] = {};               // +0x159
    int m_nThema = {};    // +0x15c: the active player theme, from the user settings.
    int m_nHitCount = {}; // +0x160: the accumulated hit (judged-note) count.
    // unsigned char m_aReserved164[4] = {}; // +0x164
};

// code: language=C++
// kate: hl C++;
// vim: set ft=cpp :
