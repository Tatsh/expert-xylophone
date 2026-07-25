//
//  music_sheet.mm
//  REFLEC BEAT plus
//
//  The note-chart reader/parser (MusicSheet). Reconstructed from Ghidra project rb458, program
//  rb458. @ghidraAddress values are relative to the program image base.
//

#include "music_sheet.h"

#include <cassert>
#include <cstdlib>
#include <cstring>

#include "rbff_chart_note.h"
#include "rbffnoterecord.h"

namespace {

// Reads one little-endian value of type T from the byte cursor and advances it.
template <typename T>
T ReadStream(const unsigned char *&pCursor) {
    T value;
    std::memcpy(&value, pCursor, sizeof(T));
    pCursor += sizeof(T);
    return value;
}

} // namespace

/** @ghidraAddress 0x12e944 */
int DeserializeNoteRecord(RbffChartNote *pRecord, const unsigned char **ppCursor) {
    const unsigned char *pCursor = *ppCursor;
    pRecord->nTimeA = ReadStream<int>(pCursor);
    pRecord->nTimeB = ReadStream<int>(pCursor);
    pRecord->nNoteId = ReadStream<short>(pCursor);
    pRecord->nStartTime = ReadStream<short>(pCursor);
    pRecord->nKind = ReadStream<signed char>(pCursor);
    pRecord->nPointCount = ReadStream<signed char>(pCursor);
    // The first eight path-point coordinates.
    for (int i = 0; i < 8; ++i) {
        pRecord->pathPoints[i] = ReadStream<short>(pCursor);
    }
    pRecord->nSide = ReadStream<signed char>(pCursor);
    pRecord->nType = ReadStream<signed char>(pCursor);
    pRecord->nHoldFlag = ReadStream<signed char>(pCursor);
    pRecord->reserved1 = ReadStream<signed char>(pCursor);
    // The chain-link ids and trailing reserved short (stored contiguously after the path points).
    pRecord->nChainLink = ReadStream<short>(pCursor);
    pRecord->nChainPartner = ReadStream<short>(pCursor);
    pRecord->reserved2 = ReadStream<short>(pCursor);
    *ppCursor = pCursor;
    return 1;
}

/** @ghidraAddress 0x12ea68 */
void InitPathPoint(RbffPathPoint *pPoint) {
    std::memset(pPoint->aData, 0, sizeof(pPoint->aData));
}

/** @ghidraAddress 0x12ea78 */
void InitNoteChainData(RbffNoteReadRecord *pRecord) {
    *pRecord = RbffNoteReadRecord{};
    // The chain-link ids start at the unset sentinel.
    pRecord->nChainLink = static_cast<short>(0xffff);
    pRecord->nChainPartner = static_cast<short>(0xffff);
}

/** @ghidraAddress 0x12eaac */
RbffNoteReadRecord *FreeNotePathArray(RbffNoteReadRecord *pRecord) {
    if (pRecord->pPathPoints != nullptr) {
        delete[] pRecord->pPathPoints;
        pRecord->pPathPoints = nullptr;
    }
    return pRecord;
}

/** @ghidraAddress 0x12eb28 */
int ReadRbffNoteRecord(RbffNoteReadRecord *pOut, const unsigned char **ppCursor) {
    const unsigned char *pCursor = *ppCursor;
    pOut->nTimeA = ReadStream<int>(pCursor);
    pOut->nTimeB = ReadStream<int>(pCursor);
    pOut->nNoteId = ReadStream<short>(pCursor);
    pOut->nStartTime = ReadStream<short>(pCursor);
    pOut->nPointCount = ReadStream<short>(pCursor);
    // A positive point count allocates the path-point array and reads that many coordinates.
    if (pOut->nPointCount > 0) {
        pOut->pPathPoints = new short[pOut->nPointCount];
        for (int i = 0; i < pOut->nPointCount; ++i) {
            pOut->pPathPoints[i] = ReadStream<short>(pCursor);
        }
    }
    pOut->nKind = ReadStream<signed char>(pCursor);
    pOut->nSide = ReadStream<signed char>(pCursor);
    pOut->nHoldKind = ReadStream<signed char>(pCursor);
    pOut->reserved1b = ReadStream<signed char>(pCursor);
    for (int i = 0; i < 4; ++i) {
        pOut->aTargetCoords[i] = ReadStream<short>(pCursor);
    }
    pOut->nFlags = ReadStream<unsigned int>(pCursor);
    pOut->nField28 = ReadStream<signed char>(pCursor);
    pOut->nField29 = ReadStream<signed char>(pCursor);
    pOut->nField2a = ReadStream<short>(pCursor);
    pOut->nType = ReadStream<int>(pCursor);
    // The chain payload is present only when flag bit 3 is set: the binary reads the eight bytes at
    // the cursor into the chain-link block (+0x30) and the four bytes at cursor+8 into the extra
    // field (+0x38), then advances the cursor twelve bytes past all of it.
    if ((pOut->nFlags & 8) != 0) {
        long chainBlock;
        std::memcpy(&chainBlock, pCursor, sizeof(chainBlock));
        std::memcpy(&pOut->nChainLink, &chainBlock, sizeof(chainBlock));
        std::memcpy(&pOut->nChainExtra, pCursor + sizeof(long), sizeof(int));
        pCursor += sizeof(long) + sizeof(int);
    }
    *ppCursor = pCursor;
    return 1;
}

/** @ghidraAddress 0x12ed14 */
int ReadRbffTempoEvent(RbffTempoEvent *pOut, const unsigned char **ppCursor) {
    // A tempo event is a verbatim 36-byte block.
    std::memcpy(pOut->aData, *ppCursor, sizeof(pOut->aData));
    *ppCursor += sizeof(pOut->aData);
    return 1;
}

/** @ghidraAddress 0x12ed44 */
int DeserializeChartHeaderRecord(RbffChartHeaderRecord *pRecord, const unsigned char **ppCursor) {
    const unsigned char *pCursor = *ppCursor;
    pRecord->nField0 = ReadStream<unsigned short>(pCursor);
    pRecord->nField2 = ReadStream<unsigned short>(pCursor);
    pRecord->nField4 = ReadStream<unsigned short>(pCursor);
    pRecord->nValueA = ReadStream<int>(pCursor);
    pRecord->nValueB = ReadStream<int>(pCursor);
    // The record is followed by four reserved bytes.
    pCursor += 4;
    *ppCursor = pCursor;
    return 1;
}

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

// The tolerance, in ticks, within which a note counts as near a query time.
constexpr int kNearTimeTolerance = 2;

// The chart-note-count thresholds selecting a scroll-speed tier, and the per-tier scroll speeds
// (@ghidraAddress 0x308af0).
constexpr int kSpeedTierMidThreshold = 200;
constexpr int kSpeedTierHighThreshold = 400;
constexpr float kScrollSpeeds[] = {0.05f, 0.04f, 0.03f};

} // namespace

/** @ghidraAddress 0x12f828 */
MusicSheet::MusicSheet() {
    // The version starts unread; the parser fills it in. Every count, timing, and buffer pointer is
    // cleared by the member initialisers, matching the binary's field-by-field zeroing.
    m_nVersion = -1;
    // The path buffer starts with room for one node and no nodes read.
    m_pPathNodes = new SheetPathNode[1]();
    m_nPathPointCount = 0;
    m_nPathPointCapacity = 1;
    m_pRecords = nullptr;
    m_pSlideRecords = nullptr;
    m_pSideIndexArray = nullptr;
    m_pIndexArrayB = nullptr;
    m_nFirstIndex = 0;
    m_nIndexCount = 0;
}

/**
 * @ghidraAddress 0x12f874
 * @ghidraAddress 0x12f938
 */
MusicSheet::~MusicSheet() {
    delete[] m_pIndexArrayB;
    m_pIndexArrayB = nullptr;
    delete[] m_pSideIndexArray;
    m_pSideIndexArray = nullptr;
    if (m_pRecords != nullptr) {
        // Free each note's path-point sub-buffer before releasing the record pool itself.
        for (int i = 0; i < m_nNoteCount; ++i) {
            delete[] m_pRecords[i].pPathPoints;
            m_pRecords[i].pPathPoints = nullptr;
        }
        delete[] m_pRecords;
        m_pRecords = nullptr;
    }
    delete[] m_pSlideRecords;
    m_pSlideRecords = nullptr;
    delete[] m_pPathNodes;
    m_pPathNodes = nullptr;
    m_nPathPointCount = 0;
    m_nPathPointCapacity = 0;
}

/** @ghidraAddress 0x130d64 */
bool MusicSheet::CheckNoteNearTime(int nTime, int nTarget) {
    // Scan the note records for one on the target lane whose end time is near the query time.
    for (int i = 0; i < m_nNoteCount; ++i) {
        const RbffNoteRecord &record = m_pRecords[i];
        if (record.nLane != nTarget) {
            continue;
        }
        int nEndTime = record.nHitTime + record.nHitWindow;
        if (std::abs(nEndTime - nTime) < kNearTimeTolerance) {
            return true;
        }
        // A hold note also matches on its tail end.
        if (record.nType == kNoteTypeHold) {
            const int nTailTime = nEndTime + record.nChainOffset;
            if (std::abs(nTailTime - nTime) < kNearTimeTolerance) {
                return true;
            }
            nEndTime = nTailTime;
        }
        if (nTime < nEndTime) {
            break;
        }
    }

    // Otherwise scan the slide records, keyed to their owning note's lane. A slide matches when it
    // is within one tick of the query time, or still lies ahead of it.
    for (int i = 0; i < m_nSlideRecordCount; ++i) {
        const RbffSlideRecord &slide = m_pSlideRecords[i];
        if (m_pRecords[slide.nNoteIndex].nLane != nTarget) {
            continue;
        }
        const int nSlideTime = slide.nValueBScaled + slide.nValueAScaled;
        const int nDelta = nSlideTime - nTime;
        const bool bAhead = nDelta != 0 && nSlideTime >= nTime;
        const bool bNear = std::abs(nDelta) <= 1 ? true : bAhead;
        if (bNear) {
            return true;
        }
    }

    return false;
}

/** @ghidraAddress 0x1309a8 */
void MusicSheet::ResolveNoteScrollSpeeds() {
    for (int i = 0; i < m_nNoteCount; ++i) {
        RbffNoteRecord &record = m_pRecords[i];
        // Seed both speeds from the first path node.
        record.flScrollStartSpeed = GetFirstPathSpeed();
        record.flScrollEndSpeed = GetFirstPathSpeed();

        const int nStartTime = record.nTimeA;
        const int nEndTime = record.nTimeA + record.nTimeB;
        // Walk the path nodes, advancing the start speed up to the note's start time and the end
        // speed up to its end time, until a node lies past the note's end.
        for (int nNode = 1; nNode < m_nPathPointCount; ++nNode) {
            if (GetSheetPathNode(nNode)->nTime <= nStartTime) {
                record.flScrollStartSpeed = static_cast<float>(GetSheetPathNode(nNode)->nSpeed);
            }
            if (GetSheetPathNode(nNode)->nTime <= nEndTime) {
                record.flScrollEndSpeed = static_cast<float>(GetSheetPathNode(nNode)->nSpeed);
            }
            if (GetSheetPathNode(nNode)->nTime > nEndTime) {
                break;
            }
        }

        record.bScrollVisible = record.flScrollStartSpeed < record.flScrollEndSpeed;
    }
}

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
