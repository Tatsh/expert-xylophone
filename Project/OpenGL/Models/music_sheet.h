/**
 * @file
 * The note-chart reader/parser, @c MusicSheet.
 */

#pragma once

#include "note_path_point_array.h"

struct RbffNoteRecord;
struct RbffSlideRecord;
class GameSystem;

/**
 * @brief One sheet path node: a speed/scroll value and the chart time it takes effect.
 *
 * A speed-change node has the same two-int layout as a @c NotePathPoint, so the reader stores the
 * nodes in its growable path-point array: @c nSpeed occupies the @c x slot and @c nTime the @c y.
 */
using SheetPathNode = NotePathPoint;

/**
 * @brief The note-chart reader: parses an RBFF chart blob into a pool of note records and holds the
 * per-chart timing, lane, and free-note state the play field reads.
 *
 * A polymorphic engine object of 152 bytes. The field layout is taken from the Ghidra data type; the
 * trailing @c // +0xNN comments document the original offsets for reference only, and access is
 * always through the named members.
 */
class MusicSheet {
public:
    /**
     * @brief Constructs an empty note-chart reader: installs the vtable, marks the version unread,
     * allocates a one-node path buffer, and clears every count, timing, and buffer pointer.
     * @ghidraAddress 0x12f828
     */
    MusicSheet();

    /**
     * @brief Frees every buffer the chart owns: the two note-index arrays, the note-record pool
     * (each record's path-point sub-buffer first), the slide-record array, and the path nodes; then
     * clears the path-point count and capacity.
     *
     * The binary emits a non-deleting destructor body (@c 0x12f874) and a deleting variant
     * (@c 0x12f938) that runs it then frees the object; both are this destructor.
     * @ghidraAddress 0x12f874
     * @ghidraAddress 0x12f938
     */
    ~MusicSheet();

    /**
     * @brief Returns the note record at @p nIndex, or null when the index is out of range.
     * @param nIndex The note-record index.
     * @return The note record, or null.
     * @ghidraAddress 0x13183c
     */
    RbffNoteRecord *GetNoteRecordByIndex(int nIndex);

    /**
     * @brief Builds a default twelve-note free chart when no real chart is loaded.
     *
     * Only when the reader is empty: allocates twelve note records spaced at a regular time
     * interval, each a free (target -1) note of fixed duration, seeds the chart header counts, and
     * installs the runtime state.
     * @param pGameSystem The install argument forwarded to @c InstallParsedNotes.
     * @return The install result, or @c 0 when a chart was already loaded.
     * @ghidraAddress 0x130af8
     */
    unsigned long BuildDefaultNoteChart(GameSystem *pGameSystem);

    /**
     * @brief Parses an RBFF note-chart blob into the reader and installs its runtime state.
     *
     * Bails if a chart is already loaded, checks the @c 'RBFF' magic, reads the format version
     * (rejecting versions above 13), dispatches to the version-appropriate parser (versions 10 to
     * 14 or the legacy 6 and 7 path), then installs the parsed notes and resolves each note's scroll
     * speeds. A failure at any step still resolves scroll speeds before returning zero.
     * @param pBytes The raw chart bytes.
     * @param pGameSystem The game-system singleton the install path reads.
     * @return @c 1 on success, @c 0 on a bad magic, unsupported version, or parse failure.
     * @ghidraAddress 0x12f970
     */
    int ParseNoteChartFile(const void *pBytes, GameSystem *pGameSystem);

    /** @brief The number of note records in the chart's pool. */
    int GetNoteCount() const {
        return m_nNoteCount;
    }

    /** @brief The note count used to select the scroll-speed / density tier. */
    int GetChartNoteCount() const {
        return m_nChartNoteCount;
    }

    /**
     * @brief Returns the speed-change path node at @p nIndex.
     *
     * Asserts the index is within the path-node count.
     * @param nIndex The path-node index.
     * @return A pointer to the path node.
     * @ghidraAddress 0x12f604
     */
    SheetPathNode *GetSheetPathNode(int nIndex);

    /**
     * @brief Returns the first path node's speed value, or a default when there are no path nodes.
     * @return The first node's speed as a float, or the default speed.
     * @ghidraAddress 0x1316b4
     */
    float GetFirstPathSpeed();

    /**
     * @brief Counts the chart's late notes per side and computes its scroll timing.
     *
     * Walks the note records to find each side's side-object end time, counts the notes (and slide
     * records) whose end time is past it into the per-side counters, then selects a scroll-speed tier
     * from the chart note count and stores the scroll and remaining timings.
     * @return The computed remaining timing.
     * @ghidraAddress 0x131294
     */
    int CalculateChartTiming();

    /**
     * @brief Resolves each note's start and end scroll speed against the speed-change path nodes.
     *
     * For every note record, seeds the start and end scroll speeds from the first path node, then
     * walks the path nodes advancing the start speed while a node's time is at or before the note's
     * start time and the end speed while it is at or before the note's end time. Finally flags the
     * note visible when its start speed is below its end speed.
     * @ghidraAddress 0x1309a8
     */
    void ResolveNoteScrollSpeeds();

    /**
     * @brief Reports whether any note on a target lane falls within two ticks of a query time.
     *
     * Scans the note records for one on @p nTarget whose end time (and, for a hold note, its tail)
     * is within tolerance of @p nTime, stopping once past the query time; failing that, scans the
     * slide records keyed to their owning note's lane.
     * @param nTime The query time.
     * @param nTarget The target lane id.
     * @return @c true when a matching note is near.
     * @ghidraAddress 0x130d64
     */
    bool CheckNoteNearTime(int nTime, int nTarget);

    /**
     * @brief Finds a note on @p nLane whose active span overlaps the time range, from @p nStartIndex.
     * @return The first matching note record, or @c nullptr.
     * @ghidraAddress 0x131704
     */
    RbffNoteRecord *FindNoteInTimeRange(int nLane, int nTimeStart, int nTimeEnd, int nStartIndex);

    /**
     * @brief Finds the nearest chain-eligible note on @p nLane whose timing selector matches
     * @p nField, from @p nStartIndex.
     * @return The matching note record, or @c nullptr.
     * @ghidraAddress 0x131760
     */
    RbffNoteRecord *FindChainNote(int nLane, int nTime, int nField, int nStartIndex);

    /**
     * @brief Clears each eligible note's green-target availability bitmap of the slots blocked by
     * overlapping or chained notes, so a green note only offers reachable targets.
     * @ghidraAddress 0x131450
     */
    void AssignGreenTargets();

    /**
     * @brief Assigns every note its play-field display lane and resolves each free note's colour.
     *
     * Builds a lane tracker seeded from the game system, then for each note inherits the chain
     * head's lane, reserves a hold note's fixed lane, spreads a side note across its blocked lanes,
     * or assigns the least-conflicting lane. A second pass, driven by a default-seeded generator,
     * paints path-point colour indices and resolves each free note's display colour.
     * @param pGameSystem The game system (supplies the seed and note difficulty).
     * @ghidraAddress 0x130e68
     */
    void AssignChartLanes(GameSystem *pGameSystem);

    /**
     * @brief Returns the last note of the chain @p pNote belongs to.
     *
     * Asserts @p pNote is a chain note that is not already the tail, then follows the chain's
     * next-segment links until a note with no next segment is reached.
     * @param pNote A note in the chain.
     * @return The chain's last note record.
     * @ghidraAddress 0x130cbc
     */
    RbffNoteRecord *GetChainLastNote(const RbffNoteRecord *pNote);

    /** @brief The byte stride between note records in the pool (@c sizeof(RbffNoteRecord)). */
    static constexpr int kNoteRecordStride = 0xb8;

    /** @brief The number of play sides the timing counters track. */
    static constexpr int kSideCount = 2;

private:
    /**
     * @brief Parses a legacy (version 6 and 7) note-chart word stream into the record pool and links
     * long notes.
     *
     * Reads the note count and chart end time from the header, allocates and default-constructs the
     * record pool, deserialises each note (allocating its path-point sub-array), derives its flag
     * bits (long-note head, free note, path-carrying), and scales its target coordinate. A second
     * pass pairs notes sharing an absolute time (same or different side) and resolves each long
     * note's tail.
     * @param pStream The decoded chart word stream (a header followed by note records).
     * @return @c 1 on success, @c 0 when a note fails to deserialise.
     * @ghidraAddress 0x12fa34
     */
    int ParseNoteChartData(const unsigned int *pStream);

    /**
     * @brief Converts the parsed note records into runtime play state.
     *
     * BPM-scales each note's times into its runtime hit time and window, resolves its owning side
     * against the game system's play colour, derives its shot/route value, counts the notes per
     * side, builds the free-note and playable index arrays, marks the difficulty's basic notes,
     * links each long note through its chain, and flags simultaneous cross-side notes. Finishes by
     * assigning lanes and computing the chart timing.
     * @param pGameSystem The game system (play colour and difficulty).
     * @return Non-zero when the two sides carry an equal playable-note count.
     * @ghidraAddress 0x13029c
     */
    unsigned long InstallParsedNotes(GameSystem *pGameSystem);

    /**
     * @brief Parses a version 10-to-14 note-chart stream into the record pool, tempo events, and
     * slide records.
     *
     * Reads the header counts, allocates and default-constructs the record pool, and per note
     * initialises a staging record, reads it from the stream, and unpacks it into the pool record
     * (path points, kind/side/hold/type, target coordinates, flags, and the optional chain block).
     * Then reads the tempo events (appending a path node for speed-change events) and the slide
     * records, scaling their times and linking each to its owning note.
     * @param pStream The decoded chart stream.
     * @return @c 1 on success, @c 0 when a record fails to read.
     * @ghidraAddress 0x12fdf4
     */
    int ParseNotesV10(const unsigned long *pStream);

    void *m_pVtable = {}; // +0x00: the virtual-function table.
    int m_nVersion = {};  // +0x08: the parsed chart format version.
    // +0x10: the speed-change path nodes in the reader's growable array (entry pointer at +0x10, the
    // live count at +0x18, and the capacity at +0x1c).
    NotePathPointArray m_pathNodes = {};
    int m_nChartEndTime = {};       // +0x20: the chart's end time.
    int m_nSeedA = {};              // +0x24: a parse seed/scratch value.
    int m_nNoteCount = {};          // +0x28: the number of note records in the pool.
    int m_nTempoEventCount = {};    // +0x2c: the number of tempo events.
    int m_nFreeNoteCount = {};      // +0x30: the number of free (synthetic) notes.
    int m_nSlideRecordCount = {};   // +0x34: the number of slide records.
    int m_nChartEndTimeScaled = {}; // +0x38: the chart end time in scaled units.
    int m_nField3c = {};            // +0x3c: chart-parse scratch, still being worked out.
    // +0x40: side 0's playable-note count (drives the scroll-speed tier); +0x44 is side 1's.
    int m_nChartNoteCount = {};
    int m_nChartNoteCountSide1 = {};          // +0x44
    int m_aSideObjectCounts[kSideCount] = {}; // +0x48: the per-side side-object note counts.
    int m_aPlayableCounts[kSideCount] = {};   // +0x50: the per-side playable (slide-index) counts.
    int m_aSideCount[kSideCount] = {};        // +0x58: the per-side late-note counts.
    int m_nScrollTiming = {};                 // +0x60: the computed scroll timing.
    int m_nRemainTiming = {};                 // +0x64: the computed remaining timing.
    RbffNoteRecord *m_pRecords = {};       // +0x68: the note-record pool (kNoteRecordStride each).
    RbffSlideRecord *m_pSlideRecords = {}; // +0x70: the slide-record array.
    int *m_pSideIndexArray = {};           // +0x78: the per-side note-index array.
    int *m_pIndexArrayB = {};              // +0x80: a second note-index array.
    int m_nFirstIndex = {};                // +0x88: the first active note index.
    int m_nIndexCount = {};                // +0x90: the active note-index count.
    unsigned char m_aTailPad[4] = {};      // +0x94: trailing padding.
};

// code: language=C++
// kate: hl C++;
// vim: set ft=cpp :
