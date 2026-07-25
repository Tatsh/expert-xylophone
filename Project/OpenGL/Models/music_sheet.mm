//
//  music_sheet.mm
//  REFLEC BEAT plus
//
//  The note-chart reader/parser (MusicSheet). Reconstructed from Ghidra project rb458, program
//  rb458. @ghidraAddress values are relative to the program image base.
//

#include "music_sheet.h"

#include <cassert>

#include "rbffnoterecord.h"

namespace {

// The default first-path speed used when the chart carries no speed-change nodes (@ghidraAddress
// 0x2ec6b0, a shared read-only 100.0 constant).
constexpr float kDefaultPathSpeed = 100.0f;

// The side-object flag bit in a note record's flags.
constexpr unsigned int kSideObjectFlag = 1u << 5;
// The note type of a slide-tail (excluded from the late-note count), and the hold type (whose end
// time includes the chain offset).
constexpr int kNoteTypeSlideTail = 3;
constexpr int kNoteTypeHold = 1;

// The chart-note-count thresholds selecting a scroll-speed tier, and the per-tier scroll speeds
// (@ghidraAddress 0x308af0).
constexpr int kSpeedTierMidThreshold = 200;
constexpr int kSpeedTierHighThreshold = 400;
constexpr float kScrollSpeeds[] = {0.05f, 0.04f, 0.03f};

} // namespace

/** @ghidraAddress 0x131294 */
int MusicSheet::CalculateChartTiming() {
    int aPerSideEndTime[kSideCount] = {};
    bool aSideSeen[kSideCount] = {};

    // Walk the records backward: for each side, record the end time of its last side-object note.
    for (int i = m_nNoteCount - 1; i >= 0; --i) {
        const RbffNoteRecord &record = m_pRecords[i];
        const int nSide = record.nSide;
        if (!aSideSeen[nSide] && (record.dwFlags & kSideObjectFlag) != 0) {
            aPerSideEndTime[nSide] = record.nHitTime + record.nHitWindow;
            aSideSeen[nSide] = true;
        }
        if (aSideSeen[0] && aSideSeen[1]) {
            break;
        }
    }

    // Count the notes whose end time runs past their side's side-object end time.
    for (int i = 0; i < m_nNoteCount; ++i) {
        const RbffNoteRecord &record = m_pRecords[i];
        if (record.nType == kNoteTypeSlideTail) {
            continue;
        }
        int nEndTime = record.nHitTime + record.nHitWindow;
        if (record.nType == kNoteTypeHold) {
            nEndTime += record.nChainOffset;
        }
        if (aPerSideEndTime[record.nSide] < nEndTime) {
            ++m_aSideCount[record.nSide];
        }
    }

    // Count the slide records likewise, keyed to their owning note's side.
    for (int i = 0; i < m_nSlideRecordCount; ++i) {
        const RbffSlideRecord &slide = m_pSlideRecords[i];
        const int nSide = m_pRecords[slide.nNoteIndex].nSide;
        if (aPerSideEndTime[nSide] < slide.nValueAScaled + slide.nValueBScaled) {
            ++m_aSideCount[nSide];
        }
    }

    // Select a scroll-speed tier from the chart note count and compute the timings.
    int nTier = 0;
    if (m_nChartNoteCount > kSpeedTierHighThreshold) {
        nTier = 2;
    } else if (m_nChartNoteCount > kSpeedTierMidThreshold) {
        nTier = 1;
    }
    const float flSpeed = kScrollSpeeds[nTier];
    m_nScrollTiming = static_cast<int>(static_cast<float>(m_nChartNoteCount) * flSpeed);
    m_nRemainTiming =
        static_cast<int>(flSpeed * static_cast<float>(m_nChartNoteCount - m_aSideCount[0]));
    return m_nRemainTiming;
}

/** @ghidraAddress 0x12f604 */
SheetPathNode *MusicSheet::GetSheetPathNode(int nIndex) {
    assert(nIndex >= 0 && nIndex < m_nPathPointCount);
    return &m_pPathNodes[nIndex];
}

/** @ghidraAddress 0x1316b4 */
float MusicSheet::GetFirstPathSpeed() {
    if (m_nPathPointCount == 0) {
        return kDefaultPathSpeed;
    }
    assert(m_nPathPointCount > 0);
    return static_cast<float>(m_pPathNodes[0].nSpeed);
}

/** @ghidraAddress 0x13183c */
RbffNoteRecord *MusicSheet::GetNoteRecordByIndex(int nIndex) {
    if (nIndex < 0 || nIndex >= m_nNoteCount) {
        return nullptr;
    }
    // The pool is a contiguous array of records; kNoteRecordStride equals sizeof(RbffNoteRecord).
    return &m_pRecords[nIndex];
}
