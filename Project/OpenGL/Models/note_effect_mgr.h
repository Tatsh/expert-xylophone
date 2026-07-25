/**
 * @file
 * The note manager / note-effect manager, @c NoteEffectMgr.
 */

#pragma once

class MusicSheet;
class NoteModel;
struct RbffNoteRecord;

/**
 * @brief The process-wide note manager: it owns the active chart, the live note render/effect
 * objects, and the running play counters.
 *
 * A lazily-created singleton (see @c shared). Only the fields the reconstructed methods touch are
 * modelled; the spans between them are the note-object pools and per-note render state, reserved to
 * preserve the 360-byte layout. The trailing @c // +0xNN comments document the original offsets for
 * reference only. The class is non-polymorphic, so the name is inferred from its methods rather than
 * confirmed from RTTI.
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
     * @brief Resets the per-note position cache: sets every render entry's cached position to the
     *        -1 empty marker.
     * @ghidraAddress 0x1373a0
     */
    void ClearNotePositionCache();

    /**
     * @brief Returns the note object for a chart note index, or @c nullptr when none matches.
     *
     * A valid in-range index returns the pooled object directly; otherwise (or for a negative index)
     * the pool is scanned for an object whose note index matches.
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
     * @brief Detaches every pooled note from its chart binding and clears the active list (a lighter
     *        reset than a full re-init).
     * @ghidraAddress 0x1379cc
     */
    void ResetAllNoteSubEntries();

    /**
     * @brief Binds a parsed chart and prepares its note objects, choosing a density tier by the
     *        chart's note count; a null chart clears the note bindings instead.
     * @param pMusicSheet The parsed chart, or @c nullptr to clear.
     * @ghidraAddress 0x137a4c
     */
    void SetActiveMusicSheet(MusicSheet *pMusicSheet);

    /**
     * @brief Appends a newly-activated note to the active list and insertion-sorts it into hit-time
     *        order.
     * @param pNote The note to insert.
     * @ghidraAddress 0x137080
     */
    void InsertActiveNoteSorted(NoteModel *pNote);

    /**
     * @brief Removes finished notes from the active list, compacting the survivors to the front.
     *
     * A note survives while its state has any bit set other than the finished bit (bit 3).
     * @ghidraAddress 0x136f38
     */
    void CompactActiveNotes();

    /**
     * @brief The active note count (the loaded chart's note count).
     * @ghidraAddress 0x13719c
     */
    int GetNoteCount() const {
        return m_nNoteCount;
    }

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
     * the six active-slot indices to the -1 empty marker, and seeds the font-variant flag.
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

    unsigned char m_aReserved00[8] = {}; // +0x00: header state, still being worked out.
    NoteModel **m_ppNotePool = {};       // +0x08: the pooled NoteModel-object array.
    NoteModel **m_ppActiveList = {};     // +0x10: the active-note pointer array.
    int m_nNoteCount = {};               // +0x18: the active note count (the chart's note count).
    int m_nPoolCapacity = {};            // +0x1c: the note-object pool/array capacity.
    int m_nActiveCount = {};             // +0x20: the number of active notes.
    unsigned char m_aReserved24[4] = {}; // +0x24
    MusicSheet *m_pMusicSheet = {};      // +0x28: the bound active chart, or null.
    int m_nDensityTier = {};             // +0x30: the note-density tier (0, 1, or 2).
    unsigned char m_aReserved34[4] = {}; // +0x34
    // +0x38..+0x60: the six active-slot note indices, seeded to the -1 empty marker.
    long m_aActiveSlot[6] = {}; // +0x38

    // One per-note render entry: the cached note position (-1 when empty) and its render state.
    struct RenderEntry {
        int nCachedPosition = {};          // +0x00: the cached note position, or -1 when empty.
        unsigned char aReserved04[8] = {}; // +0x04: per-note render state, still being worked out.
    };
    // +0x68..+0x157: the 20-entry per-note render sub-table (each kRenderEntryStride bytes).
    RenderEntry m_aRenderTable[kRenderEntryCount] = {}; // +0x68
    bool m_bFontVariant = {};                           // +0x158: the device font variant.
    unsigned char m_aReserved159[7] = {};               // +0x159
    int m_nHitCount = {};                 // +0x160: the accumulated hit (judged-note) count.
    unsigned char m_aReserved164[4] = {}; // +0x164
};

// code: language=C++
// kate: hl C++;
// vim: set ft=cpp :
