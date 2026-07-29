/**
 * @file
 * The parsed chart note record, @c RbffNoteRecord.
 */

#pragma once

#include "note_chain_link.h"

/**
 * @brief One slide sub-record: a slide point's note index, timing selector, and value pair.
 *
 * The chart parser fills an array of these; @c CalculateChartTiming and the slide renderers index
 * it. The trailing @c // +0xNN comments document the original 24-byte layout.
 */
struct RbffSlideRecord {
    short nNoteIndex = {}; /*!< The owning note's index in the record pool. +0x00 */
    /** @brief Copied from the chart sub-record's second short and never read back. +0x02 */
    short nField2 = {};
    int nTimingSel = {};    /*!< The timing selector. +0x04 */
    int nValueA = {};       /*!< The primary slide value. +0x08 */
    int nValueB = {};       /*!< The secondary slide value. +0x0c */
    int nValueAScaled = {}; /*!< The primary value in scaled units. +0x10 */
    int nValueBScaled = {}; /*!< The secondary value in scaled units. +0x14 */
};

/**
 * @brief One parsed note from the chart: its timing, geometry, lane, and colour data.
 *
 * Populated when the chart is decoded and referenced by a live @c NoteModel through its record
 * pointer. The trailing @c // +0xNN comments document the original member offsets for reference
 * only; the gaps are the record's less-used fields, reserved to preserve the 184-byte layout. The
 * array and chain-link accessors return a reference or pointer so element writes stay direct.
 * @ghidraAddress RbffNoteRecord (engine chart-note struct, 184 bytes)
 */
class RbffNoteRecord {
public:
    /**
     * @brief Constructs a note record in its default per-note state before the chart parser fills
     * it: zeroes the timing, geometry, and link fields; seeds the empty chain-link block; and sets
     * the default lane and lane-slot (3), the timing-selector sentinel (-2), and the colour/link
     * sentinels (-1).
     * @ghidraAddress 0x12f780
     */
    RbffNoteRecord();

    int GetTimeA() const {
        return m_nTimeA;
    }
    void SetTimeA(int nTimeA) {
        m_nTimeA = nTimeA;
    }

    int GetTimeB() const {
        return m_nTimeB;
    }
    void SetTimeB(int nTimeB) {
        m_nTimeB = nTimeB;
    }

    int GetNoteId() const {
        return m_nNoteId;
    }
    void SetNoteId(int nNoteId) {
        m_nNoteId = nNoteId;
    }

    int GetStartTime() const {
        return m_nStartTime;
    }
    void SetStartTime(int nStartTime) {
        m_nStartTime = nStartTime;
    }

    int GetPointCount() const {
        return m_nPointCount;
    }
    void SetPointCount(int nPointCount) {
        m_nPointCount = nPointCount;
    }

    short *GetPathPoints() const {
        return m_pPathPoints;
    }
    void SetPathPoints(short *pPathPoints) {
        m_pPathPoints = pPathPoints;
    }

    int GetKind() const {
        return m_nKind;
    }
    void SetKind(int nKind) {
        m_nKind = nKind;
    }

    int GetSide() const {
        return m_nSide;
    }
    void SetSide(int nSide) {
        m_nSide = nSide;
    }

    int GetHoldKind() const {
        return m_nHoldKind;
    }
    void SetHoldKind(int nHoldKind) {
        m_nHoldKind = nHoldKind;
    }

    int GetType() const {
        return m_nType;
    }
    void SetType(int nType) {
        m_nType = nType;
    }

    short *GetTargetCoords() {
        return m_aTargetCoords;
    }
    const short *GetTargetCoords() const {
        return m_aTargetCoords;
    }

    short GetTargetPad() const {
        return m_nTargetPad;
    }
    void SetTargetPad(short nTargetPad) {
        m_nTargetPad = nTargetPad;
    }

    unsigned int GetFlags() const {
        return m_dwFlags;
    }
    void SetFlags(unsigned int dwFlags) {
        m_dwFlags = dwFlags;
    }

    NoteChainLink &GetChainLink() {
        return m_chainLink;
    }
    const NoteChainLink &GetChainLink() const {
        return m_chainLink;
    }

    int GetHitTime() const {
        return m_nHitTime;
    }
    void SetHitTime(int nHitTime) {
        m_nHitTime = nHitTime;
    }

    int GetHitWindow() const {
        return m_nHitWindow;
    }
    void SetHitWindow(int nHitWindow) {
        m_nHitWindow = nHitWindow;
    }

    int GetSideIndex() const {
        return m_nSideIndex;
    }
    void SetSideIndex(int nSideIndex) {
        m_nSideIndex = nSideIndex;
    }

    int GetLane() const {
        return m_nLane;
    }
    void SetLane(int nLane) {
        m_nLane = nLane;
    }

    int GetLaneSlot() const {
        return m_nLaneSlot;
    }
    void SetLaneSlot(int nLaneSlot) {
        m_nLaneSlot = nLaneSlot;
    }

    int GetRoute() const {
        return m_nRoute;
    }
    void SetRoute(int nRoute) {
        m_nRoute = nRoute;
    }

    int GetTargetCopy() const {
        return m_nTargetCopy;
    }
    void SetTargetCopy(int nTargetCopy) {
        m_nTargetCopy = nTargetCopy;
    }

    int GetChainOffset() const {
        return m_nChainOffset;
    }
    void SetChainOffset(int nChainOffset) {
        m_nChainOffset = nChainOffset;
    }

    int GetColorTone() const {
        return m_nColorTone;
    }
    void SetColorTone(int nColorTone) {
        m_nColorTone = nColorTone;
    }

    bool IsBasicNote() const {
        return m_bBasicNote;
    }
    void SetBasicNote(bool bBasicNote) {
        m_bBasicNote = bBasicNote;
    }

    int GetDisplayLane() const {
        return m_nDisplayLane;
    }
    void SetDisplayLane(int nDisplayLane) {
        m_nDisplayLane = nDisplayLane;
    }

    int GetColorIndex() const {
        return m_nColorIndex;
    }
    void SetColorIndex(int nColorIndex) {
        m_nColorIndex = nColorIndex;
    }

    int GetColor() const {
        return m_nColor;
    }
    void SetColor(int nColor) {
        m_nColor = nColor;
    }

    int GetLinkA() const {
        return m_nLinkA;
    }
    void SetLinkA(int nLinkA) {
        m_nLinkA = nLinkA;
    }

    int GetTimingSel() const {
        return m_nTimingSel;
    }
    void SetTimingSel(int nTimingSel) {
        m_nTimingSel = nTimingSel;
    }

    unsigned char *GetGreenTargets() {
        return m_aGreenTargets;
    }
    const unsigned char *GetGreenTargets() const {
        return m_aGreenTargets;
    }

    int GetChosenTarget() const {
        return m_nChosenTarget;
    }
    void SetChosenTarget(int nChosenTarget) {
        m_nChosenTarget = nChosenTarget;
    }

    bool IsScrollVisible() const {
        return m_bScrollVisible;
    }
    void SetScrollVisible(bool bScrollVisible) {
        m_bScrollVisible = bScrollVisible;
    }

    float GetScrollStartSpeed() const {
        return m_flScrollStartSpeed;
    }
    void SetScrollStartSpeed(float flScrollStartSpeed) {
        m_flScrollStartSpeed = flScrollStartSpeed;
    }

    float GetScrollEndSpeed() const {
        return m_flScrollEndSpeed;
    }
    void SetScrollEndSpeed(float flScrollEndSpeed) {
        m_flScrollEndSpeed = flScrollEndSpeed;
    }

    RbffSlideRecord *GetSlideRecord() const {
        return m_pSlideRecord;
    }
    void SetSlideRecord(RbffSlideRecord *pSlideRecord) {
        m_pSlideRecord = pSlideRecord;
    }

    int GetSlidePointCount() const {
        return m_nSlidePointCount;
    }
    void SetSlidePointCount(int nSlidePointCount) {
        m_nSlidePointCount = nSlidePointCount;
    }

private:
    int m_nTimeA = {};      // +0x00: the note's primary time stamp.
    int m_nTimeB = {};      // +0x04: the note's secondary time stamp.
    int m_nNoteId = {};     // +0x08: the note identifier.
    int m_nStartTime = {};  // +0x0c: the note's start time.
    int m_nPointCount = {}; // +0x10: the number of path points.
    // unsigned char m_aPad14[4]; // +0x14 (alignment padding, compiler-inserted)
    short *m_pPathPoints = {};      // +0x18: the packed path-point array.
    int m_nKind = {};               // +0x20: the note kind.
    int m_nSide = {};               // +0x24: the note's play side.
    int m_nHoldKind = {};           // +0x28: the hold-note kind.
    int m_nType = {};               // +0x2c: the note type.
    short m_aTargetCoords[3] = {};  // +0x30: the note's target coordinates (the first is scaled).
    short m_nTargetPad = {};        // +0x36: cleared alongside the target coordinates.
    unsigned int m_dwFlags = {};    // +0x38: the note flag bits.
    NoteChainLink m_chainLink = {}; // +0x3c: the 12-byte chain-link block threading chain notes.
    int m_nHitTime = {};            // +0x48: the scheduled hit time.
    int m_nHitWindow = {};          // +0x4c: the hit-window width.
    int m_nSideIndex = {}; // +0x50: the note's index within its side (assigned on install).
    int m_nLane = {};      // +0x54: the note's lane.
    int m_nLaneSlot = {};  // +0x58: the lane slot.
    unsigned char m_aReserved5c[4] = {}; // +0x5c: an unused four-byte gap.
    int m_nRoute = {};                   // +0x60: the note's route.
    int m_nTargetCopy = {};              // +0x64: a copy of the first target coordinate.
    int m_nChainOffset = {};             // +0x68: the chain offset.
    int m_nColorTone = {};               // +0x6c: the colour tone.
    bool m_bBasicNote = {};              // +0x70: whether the note is a basic note.
    // unsigned char m_aPad71[3]; // +0x71 (alignment padding, compiler-inserted)
    int m_nDisplayLane = {};          // +0x74: the display lane.
    int m_nColorIndex = {};           // +0x78: the colour index.
    int m_nColor = {};                // +0x7c: the packed colour.
    int m_nLinkA = {};                // +0x80: the primary link.
    int m_nTimingSel = {};            // +0x84: the timing selector.
    unsigned char m_aReserved88 = {}; // +0x88: a one-byte gap before the green-target bitmap.
    // +0x89: the per-slot green-target availability bitmap (a byte per reachable target); the chart
    // lane pass clears the slots blocked by overlapping or chained notes.
    unsigned char m_aGreenTargets[11] = {};
    int m_nChosenTarget = {};   // +0x94: the note's chosen green target.
    bool m_bScrollVisible = {}; // +0x98: whether the note is on-screen (startSpeed < endSpeed).
    // unsigned char m_aPad99[3]; // +0x99 (alignment padding, compiler-inserted)
    float m_flScrollStartSpeed = {}; // +0x9c: the resolved scroll speed at the note's start.
    float m_flScrollEndSpeed = {};   // +0xa0: the resolved scroll speed at the note's end.
    // unsigned char m_aPadA4[4]; // +0xa4 (alignment padding, compiler-inserted)
    RbffSlideRecord *m_pSlideRecord = {}; // +0xa8: the slide sub-record, when present.
    int m_nSlidePointCount = {};          // +0xb0: the number of slide points.
    // unsigned char m_aPadB4[4]; // +0xb4 (trailing alignment padding, compiler-inserted)
};

// code: language=C++
// kate: hl C++;
// vim: set ft=cpp :
