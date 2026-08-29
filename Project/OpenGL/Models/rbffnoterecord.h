/**
 * @file
 * The parsed chart note record, @c RbffNoteRecord.
 */

#pragma once

#include "note_chain_link.h"

/**
 * One slide sub-record: a slide point's note index, timing selector, and value pair.
 *
 * The chart parser fills an array of these; @c CalculateChartTiming and the slide renderers index
 * it. The trailing @c // +0xNN comments document the original 24-byte layout.
 */
struct RbffSlideRecord {
    short nNoteIndex = {}; /*!< The owning note's index in the record pool. +0x00 */
    /** Copied from the chart sub-record's second short and never read back. +0x02 */
    short nField2 = {};
    int nTimingSel = {};    /*!< The timing selector. +0x04 */
    int nValueA = {};       /*!< The primary slide value. +0x08 */
    int nValueB = {};       /*!< The secondary slide value. +0x0c */
    int nValueAScaled = {}; /*!< The primary value in scaled units. +0x10 */
    int nValueBScaled = {}; /*!< The secondary value in scaled units. +0x14 */
};

/**
 * One parsed note from the chart: its timing, geometry, lane, and colour data.
 *
 * Populated when the chart is decoded and referenced by a live @c NoteModel through its record
 * pointer. The trailing @c // +0xNN comments document the original member offsets for reference
 * only; the gaps are the record's less-used fields, reserved to preserve the 184-byte layout. The
 * array and chain-link accessors return a reference or pointer so element writes stay direct.
 * Reconstructed type @c RbffNoteRecord: engine chart-note struct, 184 bytes.
 */
class RbffNoteRecord {
public:
    /**
     * Constructs a note record in its default per-note state before the chart parser fills
     * it: zeroes the timing, geometry, and link fields; seeds the empty chain-link block; and sets
     * the default lane and lane-slot (3), the timing-selector sentinel (-2), and the colour/link
     * sentinels (-1).
     * @ghidraAddress 0x12f780
     */
    RbffNoteRecord();

    /**
     * Returns the note's primary time stamp.
     * @return The note's primary time stamp.
     */
    int GetTimeA() const {
        return m_nTimeA;
    }
    /**
     * Stores the note's primary time stamp.
     * @param nTimeA The note's primary time stamp.
     */
    void SetTimeA(int nTimeA) {
        m_nTimeA = nTimeA;
    }

    /**
     * Returns the note's secondary time stamp.
     * @return The note's secondary time stamp.
     */
    int GetTimeB() const {
        return m_nTimeB;
    }
    /**
     * Stores the note's secondary time stamp.
     * @param nTimeB The note's secondary time stamp.
     */
    void SetTimeB(int nTimeB) {
        m_nTimeB = nTimeB;
    }

    /**
     * Returns the note identifier.
     * @return The note identifier.
     */
    int GetNoteId() const {
        return m_nNoteId;
    }
    /**
     * Stores the note identifier.
     * @param nNoteId The note identifier.
     */
    void SetNoteId(int nNoteId) {
        m_nNoteId = nNoteId;
    }

    /**
     * Returns the note's start time.
     * @return The note's start time.
     */
    int GetStartTime() const {
        return m_nStartTime;
    }
    /**
     * Stores the note's start time.
     * @param nStartTime The note's start time.
     */
    void SetStartTime(int nStartTime) {
        m_nStartTime = nStartTime;
    }

    /**
     * Returns the number of path points.
     * @return The number of path points.
     */
    int GetPointCount() const {
        return m_nPointCount;
    }
    /**
     * Stores the number of path points.
     * @param nPointCount The number of path points.
     */
    void SetPointCount(int nPointCount) {
        m_nPointCount = nPointCount;
    }

    /**
     * Returns the packed path-point array.
     * @return The packed path-point array, or @c nullptr when the note has no path.
     */
    short *GetPathPoints() const {
        return m_pPathPoints;
    }
    /**
     * Stores the packed path-point array.
     * @param pPathPoints The packed path-point array.
     */
    void SetPathPoints(short *pPathPoints) {
        m_pPathPoints = pPathPoints;
    }

    /**
     * Returns the note kind.
     * @return The note kind.
     */
    int GetKind() const {
        return m_nKind;
    }
    /**
     * Stores the note kind.
     * @param nKind The note kind.
     */
    void SetKind(int nKind) {
        m_nKind = nKind;
    }

    /**
     * Returns the note's play side.
     * @return The note's play side.
     */
    int GetSide() const {
        return m_nSide;
    }
    /**
     * Stores the note's play side.
     * @param nSide The note's play side.
     */
    void SetSide(int nSide) {
        m_nSide = nSide;
    }

    /**
     * Returns the hold-note kind.
     * @return The hold-note kind.
     */
    int GetHoldKind() const {
        return m_nHoldKind;
    }
    /**
     * Stores the hold-note kind.
     * @param nHoldKind The hold-note kind.
     */
    void SetHoldKind(int nHoldKind) {
        m_nHoldKind = nHoldKind;
    }

    /**
     * Returns the note type.
     * @return The note type.
     */
    int GetType() const {
        return m_nType;
    }
    /**
     * Stores the note type.
     * @param nType The note type.
     */
    void SetType(int nType) {
        m_nType = nType;
    }

    /**
     * Returns the note's target coordinates for direct element writes.
     * @return The three-element target-coordinate array; the first element is scaled.
     */
    short *GetTargetCoords() {
        return m_aTargetCoords;
    }
    /**
     * Returns the note's target coordinates.
     * @return The three-element target-coordinate array; the first element is scaled.
     */
    const short *GetTargetCoords() const {
        return m_aTargetCoords;
    }

    /**
     * Returns the target pad, cleared alongside the target coordinates.
     * @return The target pad.
     */
    short GetTargetPad() const {
        return m_nTargetPad;
    }
    /**
     * Stores the target pad.
     * @param nTargetPad The target pad.
     */
    void SetTargetPad(short nTargetPad) {
        m_nTargetPad = nTargetPad;
    }

    /**
     * Returns the note flag bits.
     * @return The note flag bits.
     */
    unsigned int GetFlags() const {
        return m_dwFlags;
    }
    /**
     * Stores the note flag bits.
     * @param dwFlags The note flag bits.
     */
    void SetFlags(unsigned int dwFlags) {
        m_dwFlags = dwFlags;
    }

    /**
     * Returns the chain-link block threading chain notes, for direct writes.
     * @return The note's chain-link block.
     */
    NoteChainLink &GetChainLink() {
        return m_chainLink;
    }
    /**
     * Returns the chain-link block threading chain notes.
     * @return The note's chain-link block.
     */
    const NoteChainLink &GetChainLink() const {
        return m_chainLink;
    }

    /**
     * Returns the scheduled hit time.
     * @return The scheduled hit time.
     */
    int GetHitTime() const {
        return m_nHitTime;
    }
    /**
     * Stores the scheduled hit time.
     * @param nHitTime The scheduled hit time.
     */
    void SetHitTime(int nHitTime) {
        m_nHitTime = nHitTime;
    }

    /**
     * Returns the hit-window width.
     * @return The hit-window width.
     */
    int GetHitWindow() const {
        return m_nHitWindow;
    }
    /**
     * Stores the hit-window width.
     * @param nHitWindow The hit-window width.
     */
    void SetHitWindow(int nHitWindow) {
        m_nHitWindow = nHitWindow;
    }

    /**
     * Returns the note's index within its side, assigned on install.
     * @return The note's index within its side.
     */
    int GetSideIndex() const {
        return m_nSideIndex;
    }
    /**
     * Stores the note's index within its side.
     * @param nSideIndex The note's index within its side.
     */
    void SetSideIndex(int nSideIndex) {
        m_nSideIndex = nSideIndex;
    }

    /**
     * Returns the note's lane.
     * @return The note's lane.
     */
    int GetLane() const {
        return m_nLane;
    }
    /**
     * Stores the note's lane.
     * @param nLane The note's lane.
     */
    void SetLane(int nLane) {
        m_nLane = nLane;
    }

    /**
     * Returns the lane slot.
     * @return The lane slot.
     */
    int GetLaneSlot() const {
        return m_nLaneSlot;
    }
    /**
     * Stores the lane slot.
     * @param nLaneSlot The lane slot.
     */
    void SetLaneSlot(int nLaneSlot) {
        m_nLaneSlot = nLaneSlot;
    }

    /**
     * Returns the note's route.
     * @return The note's route.
     */
    int GetRoute() const {
        return m_nRoute;
    }
    /**
     * Stores the note's route.
     * @param nRoute The note's route.
     */
    void SetRoute(int nRoute) {
        m_nRoute = nRoute;
    }

    /**
     * Returns the copy of the first target coordinate.
     * @return The copy of the first target coordinate.
     */
    int GetTargetCopy() const {
        return m_nTargetCopy;
    }
    /**
     * Stores the copy of the first target coordinate.
     * @param nTargetCopy The copy of the first target coordinate.
     */
    void SetTargetCopy(int nTargetCopy) {
        m_nTargetCopy = nTargetCopy;
    }

    /**
     * Returns the chain offset.
     * @return The chain offset.
     */
    int GetChainOffset() const {
        return m_nChainOffset;
    }
    /**
     * Stores the chain offset.
     * @param nChainOffset The chain offset.
     */
    void SetChainOffset(int nChainOffset) {
        m_nChainOffset = nChainOffset;
    }

    /**
     * Returns the colour tone.
     * @return The colour tone.
     */
    int GetColorTone() const {
        return m_nColorTone;
    }
    /**
     * Stores the colour tone.
     * @param nColorTone The colour tone.
     */
    void SetColorTone(int nColorTone) {
        m_nColorTone = nColorTone;
    }

    /**
     * Reports whether the note is a basic note.
     * @return @c true when the note is a basic note.
     */
    bool IsBasicNote() const {
        return m_bBasicNote;
    }
    /**
     * Records whether the note is a basic note.
     * @param bBasicNote @c true when the note is a basic note.
     */
    void SetBasicNote(bool bBasicNote) {
        m_bBasicNote = bBasicNote;
    }

    /**
     * Returns the display lane.
     * @return The display lane.
     */
    int GetDisplayLane() const {
        return m_nDisplayLane;
    }
    /**
     * Stores the display lane.
     * @param nDisplayLane The display lane.
     */
    void SetDisplayLane(int nDisplayLane) {
        m_nDisplayLane = nDisplayLane;
    }

    /**
     * Returns the colour index.
     * @return The colour index.
     */
    int GetColorIndex() const {
        return m_nColorIndex;
    }
    /**
     * Stores the colour index.
     * @param nColorIndex The colour index.
     */
    void SetColorIndex(int nColorIndex) {
        m_nColorIndex = nColorIndex;
    }

    /**
     * Returns the packed colour.
     * @return The packed colour.
     */
    int GetColor() const {
        return m_nColor;
    }
    /**
     * Stores the packed colour.
     * @param nColor The packed colour.
     */
    void SetColor(int nColor) {
        m_nColor = nColor;
    }

    /**
     * Returns the primary link.
     * @return The primary link.
     */
    int GetLinkA() const {
        return m_nLinkA;
    }
    /**
     * Stores the primary link.
     * @param nLinkA The primary link.
     */
    void SetLinkA(int nLinkA) {
        m_nLinkA = nLinkA;
    }

    /**
     * Returns the timing selector.
     * @return The timing selector.
     */
    int GetTimingSel() const {
        return m_nTimingSel;
    }
    /**
     * Stores the timing selector.
     * @param nTimingSel The timing selector.
     */
    void SetTimingSel(int nTimingSel) {
        m_nTimingSel = nTimingSel;
    }

    /**
     * Returns the per-slot green-target availability bitmap, for direct element writes.
     * @return The eleven-element green-target bitmap, a byte per reachable target.
     */
    unsigned char *GetGreenTargets() {
        return m_aGreenTargets;
    }
    /**
     * Returns the per-slot green-target availability bitmap.
     * @return The eleven-element green-target bitmap, a byte per reachable target.
     */
    const unsigned char *GetGreenTargets() const {
        return m_aGreenTargets;
    }

    /**
     * Returns the note's chosen green target.
     * @return The note's chosen green target.
     */
    int GetChosenTarget() const {
        return m_nChosenTarget;
    }
    /**
     * Stores the note's chosen green target.
     * @param nChosenTarget The note's chosen green target.
     */
    void SetChosenTarget(int nChosenTarget) {
        m_nChosenTarget = nChosenTarget;
    }

    /**
     * Reports whether the note is on-screen, that is its start speed is below its end speed.
     * @return @c true while the note is on-screen.
     */
    bool IsScrollVisible() const {
        return m_bScrollVisible;
    }
    /**
     * Records whether the note is on-screen.
     * @param bScrollVisible @c true while the note is on-screen.
     */
    void SetScrollVisible(bool bScrollVisible) {
        m_bScrollVisible = bScrollVisible;
    }

    /**
     * Returns the resolved scroll speed at the note's start.
     * @return The resolved scroll speed at the note's start.
     */
    float GetScrollStartSpeed() const {
        return m_flScrollStartSpeed;
    }
    /**
     * Stores the resolved scroll speed at the note's start.
     * @param flScrollStartSpeed The resolved scroll speed at the note's start.
     */
    void SetScrollStartSpeed(float flScrollStartSpeed) {
        m_flScrollStartSpeed = flScrollStartSpeed;
    }

    /**
     * Returns the resolved scroll speed at the note's end.
     * @return The resolved scroll speed at the note's end.
     */
    float GetScrollEndSpeed() const {
        return m_flScrollEndSpeed;
    }
    /**
     * Stores the resolved scroll speed at the note's end.
     * @param flScrollEndSpeed The resolved scroll speed at the note's end.
     */
    void SetScrollEndSpeed(float flScrollEndSpeed) {
        m_flScrollEndSpeed = flScrollEndSpeed;
    }

    /**
     * Returns the slide sub-record.
     * @return The slide sub-record, or @c nullptr when the note has none.
     */
    RbffSlideRecord *GetSlideRecord() const {
        return m_pSlideRecord;
    }
    /**
     * Stores the slide sub-record.
     * @param pSlideRecord The slide sub-record, or @c nullptr when the note has none.
     */
    void SetSlideRecord(RbffSlideRecord *pSlideRecord) {
        m_pSlideRecord = pSlideRecord;
    }

    /**
     * Returns the number of slide points.
     * @return The number of slide points.
     */
    int GetSlidePointCount() const {
        return m_nSlidePointCount;
    }
    /**
     * Stores the number of slide points.
     * @param nSlidePointCount The number of slide points.
     */
    void SetSlidePointCount(int nSlidePointCount) {
        m_nSlidePointCount = nSlidePointCount;
    }

private:
    int m_nTimeA = {};      // +0x00
    int m_nTimeB = {};      // +0x04
    int m_nNoteId = {};     // +0x08
    int m_nStartTime = {};  // +0x0c
    int m_nPointCount = {}; // +0x10
    // unsigned char m_aPad14[4]; // +0x14
    short *m_pPathPoints = {};      // +0x18
    int m_nKind = {};               // +0x20
    int m_nSide = {};               // +0x24
    int m_nHoldKind = {};           // +0x28
    int m_nType = {};               // +0x2c
    short m_aTargetCoords[3] = {};  // +0x30: the first element is scaled.
    short m_nTargetPad = {};        // +0x36: cleared alongside the target coordinates.
    unsigned int m_dwFlags = {};    // +0x38
    NoteChainLink m_chainLink = {}; // +0x3c
    int m_nHitTime = {};            // +0x48
    int m_nHitWindow = {};          // +0x4c
    int m_nSideIndex = {};          // +0x50: assigned on install.
    int m_nLane = {};               // +0x54
    int m_nLaneSlot = {};           // +0x58
    // unsigned char m_aReserved5c[4] = {}; // +0x5c
    int m_nRoute = {};       // +0x60
    int m_nTargetCopy = {};  // +0x64: a copy of the first target coordinate.
    int m_nChainOffset = {}; // +0x68
    int m_nColorTone = {};   // +0x6c
    bool m_bBasicNote = {};  // +0x70
    // unsigned char m_aPad71[3]; // +0x71
    int m_nDisplayLane = {};          // +0x74
    int m_nColorIndex = {};           // +0x78
    int m_nColor = {};                // +0x7c
    int m_nLinkA = {};                // +0x80
    int m_nTimingSel = {};            // +0x84
    unsigned char m_aReserved88 = {}; // +0x88
    // +0x89: the chart lane pass clears the slots blocked by overlapping or chained notes.
    unsigned char m_aGreenTargets[11] = {};
    int m_nChosenTarget = {};   // +0x94
    bool m_bScrollVisible = {}; // +0x98: startSpeed < endSpeed.
    // unsigned char m_aPad99[3]; // +0x99
    float m_flScrollStartSpeed = {}; // +0x9c
    float m_flScrollEndSpeed = {};   // +0xa0
    // unsigned char m_aPadA4[4]; // +0xa4
    RbffSlideRecord *m_pSlideRecord = {}; // +0xa8
    int m_nSlidePointCount = {};          // +0xb0
    // unsigned char m_aPadB4[4]; // +0xb4
};
