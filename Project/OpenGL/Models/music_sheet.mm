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

#include "Random.h"
#include "gamesystem.h"
#include "note_lane_tracker.h"
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

// The note flag bits the legacy parser derives.
constexpr unsigned int kNoteFlagSameLane = 1; // Paired with another note at the same time and side.
constexpr unsigned int kNoteFlagLongHead = 8; // Heads a long note.
constexpr unsigned int kNoteFlagDifferentLane =
    4;                                          // Paired with a note at the same time, other side.
constexpr unsigned int kNoteFlagFree = 0x10;    // A free (anywhere) note; start time is -1.
constexpr unsigned int kNoteFlagHasPath = 0x20; // Carries a path-point sub-array.

// The on-disk note kind marking a long-note head.
constexpr int kChartKindLongHead = 2;

// The target-coordinate scaling: a coordinate is divided by the field width and scaled to the hash
// range (@ghidraAddress 0x2f8578 = 60.0 field width, 0x2f8540 = 1000.0 hash scale).
constexpr float kFieldWidth = 60.0f;
constexpr float kTargetScale = 1000.0f;

// The slide-target lane remap table: an on-disk slide lane (0..9) maps to the internal lane
// (@ghidraAddress 0x308afc). Values at or above 0xfffe map to -2, 0xfffd to -4, and 0xfffc to -3.
constexpr int kSlideLaneRemap[] = {6, 5, 4, 3, 2, 1, 0, 9, 8, 7};

// The note-colour table indexed by the remapped timing selector (@ghidraAddress 0x308ac8).
constexpr int kNoteColorTable[] = {0, 1, 2, 3, 4, 5, 6, 3, 3, 3};

// The side-note lane-scan flag count.
constexpr int kSideScanSlotCount = 3;

// The side-object note flag bit.
constexpr unsigned int kNoteFlagSideObject = 0x40;

} // namespace

/** @ghidraAddress 0x12f828 */
MusicSheet::MusicSheet() {
    // The version starts unread; the parser fills it in. Every count, timing, and buffer pointer is
    // cleared by the member initialisers, matching the binary's field-by-field zeroing.
    m_nVersion = -1;
    // The path-node array starts with room for one node and none read.
    m_pathNodes.Reserve();
    m_pRecords = nullptr;
    m_pSlideRecords = nullptr;
    m_pSideIndexArray = nullptr;
    m_pIndexArrayB = nullptr;
    m_nFirstIndex = 0;
    m_nIndexCount = 0;
}

/** @ghidraAddress 0x12fa34 */
int MusicSheet::ParseNoteChartData(const unsigned int *pStream) {
    // The header carries the note count and chart end time; the note records follow it.
    const unsigned int nNoteCount = pStream[1];
    m_nChartEndTime = static_cast<int>(pStream[2]);
    m_nSeedA = static_cast<int>(pStream[3]);
    m_nNoteCount = static_cast<int>(nNoteCount);
    m_nTempoEventCount = 0;
    m_nFreeNoteCount = 0;
    // The first path node is the chart's implicit start node.
    m_pathNodes.Append(NotePathPoint{static_cast<int>(pStream[0]), 0});

    const auto *pCursor = reinterpret_cast<const unsigned char *>(pStream + 4);
    m_pRecords = new RbffNoteRecord[nNoteCount];
    for (unsigned int i = 0; i < nNoteCount; ++i) {
        RbffChartNote chartNote;
        if (DeserializeNoteRecord(&chartNote, &pCursor) == 0) {
            return 0;
        }
        RbffNoteRecord &record = m_pRecords[i];
        record.nTimeA = chartNote.nTimeA;
        record.nTimeB = chartNote.nTimeB;
        record.nNoteId = chartNote.nNoteId;
        record.nStartTime = chartNote.nStartTime;
        record.nPointCount = chartNote.nPointCount;
        if (chartNote.nPointCount > 0) {
            record.pPathPoints = new short[chartNote.nPointCount];
            for (int j = 0; j < chartNote.nPointCount; ++j) {
                record.pPathPoints[j] = chartNote.pathPoints[j];
            }
        }
        record.nKind = chartNote.nKind;
        record.nSide = chartNote.nSide;
        // The three target coordinates follow the eight path-point shorts on disk.
        for (int j = 0; j < 3; ++j) {
            record.aTargetCoords[j] = chartNote.pathPoints[4 + j];
        }
        record.nTargetPad = 0;
        record.nHoldKind = chartNote.nHoldFlag != 0 ? 1 : 0;
        record.nType = chartNote.nType;

        unsigned int dwFlags = 0;
        // An on-disk note type of 2 marks a long-note head.
        if (chartNote.nType == kChartKindLongHead) {
            record.nType = 0;
            dwFlags = kNoteFlagLongHead;
            record.chainLink.SetLongNoteHead(chartNote.nChainLink, chartNote.nChainPartner);
        }
        if (record.nStartTime == -1) {
            dwFlags |= kNoteFlagFree;
        }
        if (record.nPointCount > 0) {
            dwFlags |= kNoteFlagHasPath;
        }
        record.dwFlags = dwFlags;
        // Scale the first target coordinate into the hash range.
        record.aTargetCoords[0] = static_cast<short>(static_cast<int>(
            (static_cast<float>(record.aTargetCoords[0]) / kFieldWidth) * kTargetScale));
    }

    // Second pass: pair notes sharing an absolute end time and resolve each long note's tail.
    for (int i = 0; i < m_nNoteCount; ++i) {
        RbffNoteRecord &head = m_pRecords[i];
        for (int j = 0; j < m_nNoteCount; ++j) {
            if (i == j) {
                continue;
            }
            RbffNoteRecord &other = m_pRecords[j];
            if (head.nTimeA + head.nTimeB == other.nTimeA + other.nTimeB) {
                head.dwFlags |=
                    (head.nSide == other.nSide) ? kNoteFlagSameLane : kNoteFlagDifferentLane;
            }
            // Resolve a long-note head's tail against the note whose id matches its chain link.
            if ((head.dwFlags & kNoteFlagLongHead) != 0 && head.chainLink.GetChainId() != -1 &&
                head.chainLink.GetChainId() == other.nNoteId) {
                other.dwFlags |= kNoteFlagLongHead;
                other.chainLink.SetTail(static_cast<short>(head.nNoteId),
                                        static_cast<short>(head.nTimeA - other.nTimeA));
            }
        }
        if ((head.dwFlags & kNoteFlagFree) != 0) {
            ++m_nFreeNoteCount;
        }
    }

    return 1;
}

/** @ghidraAddress 0x12fdf4 */
int MusicSheet::ParseNotesV10(const unsigned long *pStream) {
    const auto *pHeader = reinterpret_cast<const unsigned char *>(pStream);
    const auto readHeaderInt = [pHeader](int nOffset) {
        int value;
        std::memcpy(&value, pHeader + nOffset, sizeof(value));
        return value;
    };
    const auto readHeaderShort = [pHeader](int nOffset) {
        short value;
        std::memcpy(&value, pHeader + nOffset, sizeof(value));
        return value;
    };

    // The first path node is the chart's implicit start node (speed at +0x00).
    m_pathNodes.Append(NotePathPoint{readHeaderInt(0x00), 0});
    m_nChartEndTime = readHeaderInt(0x04);
    m_nSeedA = readHeaderInt(0x08);
    m_nNoteCount = readHeaderShort(0x0c);
    m_nTempoEventCount = readHeaderShort(0x0e);
    m_nFreeNoteCount = readHeaderShort(0x10);
    m_nSlideRecordCount = readHeaderInt(0x14);

    const unsigned char *pCursor = pHeader + 0x1c;
    m_pRecords = new RbffNoteRecord[m_nNoteCount];
    for (int i = 0; i < m_nNoteCount; ++i) {
        RbffNoteReadRecord staging;
        InitNoteChainData(&staging);
        if (ReadRbffNoteRecord(&staging, &pCursor) == 0) {
            FreeNotePathArray(&staging);
            return 0;
        }
        RbffNoteRecord &record = m_pRecords[i];
        record.nTimeA = staging.nTimeA;
        record.nTimeB = staging.nTimeB;
        record.nNoteId = staging.nNoteId;
        record.nStartTime = staging.nStartTime;
        record.nPointCount = staging.nPointCount;
        if (staging.nPointCount > 0) {
            record.pPathPoints = new short[staging.nPointCount];
            for (int j = 0; j < staging.nPointCount; ++j) {
                record.pPathPoints[j] = staging.pPathPoints[j];
            }
        }
        record.nKind = staging.nKind;
        record.nSide = staging.nSide;
        record.nHoldKind = staging.nHoldKind;
        // The on-disk type of 2 is remapped to 0; any other value passes through.
        record.nType = staging.nType == kChartKindLongHead ? 0 : staging.nType;
        for (int j = 0; j < 3; ++j) {
            record.aTargetCoords[j] = staging.aTargetCoords[j];
        }
        record.dwFlags = staging.nFlags;
        if ((staging.nFlags & kNoteFlagLongHead) != 0) {
            record.chainLink.SetLongNoteHead(staging.nChainLink, staging.nChainPartner);
        }
        FreeNotePathArray(&staging);
    }

    // The tempo events follow the notes; a speed-change event (kind 3) appends a path node.
    for (int i = 0; i < m_nTempoEventCount; ++i) {
        RbffTempoEvent event;
        std::memset(&event, 0, sizeof(event));
        if (ReadRbffTempoEvent(&event, &pCursor) == 0) {
            return 0;
        }
        short nEventKind;
        std::memcpy(&nEventKind, event.aData, sizeof(nEventKind));
        if (nEventKind == 3) {
            int aNode[2];
            std::memcpy(aNode, event.aData + sizeof(int), sizeof(aNode));
            m_pathNodes.Append(NotePathPoint{aNode[0], aNode[1]});
        }
    }

    // The slide records follow the tempo events.
    if (m_nSlideRecordCount > 0) {
        m_pSlideRecords = new RbffSlideRecord[m_nSlideRecordCount]();
        for (int i = 0; i < m_nSlideRecordCount; ++i) {
            RbffChartHeaderRecord header;
            std::memset(&header, 0, sizeof(header));
            if (DeserializeChartHeaderRecord(&header, &pCursor) == 0) {
                return 0;
            }
            RbffSlideRecord &slide = m_pSlideRecords[i];
            slide.nNoteIndex = static_cast<short>(header.nField0);
            slide.nField2 = static_cast<short>(header.nField2);
            // Remap the slide's target lane; the high sentinels map to negative markers.
            const unsigned short nLane = header.nField4;
            if (nLane >= 0xfffe) {
                slide.nTimingSel = -2;
            } else if (nLane == 0xfffd) {
                slide.nTimingSel = -4;
            } else if (static_cast<short>(nLane) == -4) {
                slide.nTimingSel = -3;
            } else {
                slide.nTimingSel = kSlideLaneRemap[static_cast<short>(nLane)];
            }
            slide.nValueA = header.nValueA;
            slide.nValueB = header.nValueB;
            slide.nValueAScaled =
                static_cast<int>((static_cast<float>(header.nValueA) * kFieldWidth) / kTargetScale);
            slide.nValueBScaled =
                static_cast<int>((static_cast<float>(header.nValueB) * kFieldWidth) / kTargetScale);
        }

        // Link each run of slides to its owning note, counting the run into the note's slide count.
        RbffNoteRecord *pOwner = nullptr;
        int nLastIndex = -1;
        for (int i = 0; i < m_nSlideRecordCount; ++i) {
            const int nIndex = m_pSlideRecords[i].nNoteIndex;
            if (pOwner == nullptr || nIndex != nLastIndex) {
                pOwner = &m_pRecords[nIndex];
                pOwner->pSlideRecord = &m_pSlideRecords[i];
                nLastIndex = nIndex;
            }
            ++pOwner->nSlidePointCount;
        }
    }

    return 1;
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
    m_pathNodes.Free();
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
        for (int nNode = 1; nNode < m_pathNodes.GetCount(); ++nNode) {
            // A node's time is its y coordinate and its speed its x coordinate.
            if (GetSheetPathNode(nNode)->y <= nStartTime) {
                record.flScrollStartSpeed = static_cast<float>(GetSheetPathNode(nNode)->x);
            }
            if (GetSheetPathNode(nNode)->y <= nEndTime) {
                record.flScrollEndSpeed = static_cast<float>(GetSheetPathNode(nNode)->x);
            }
            if (GetSheetPathNode(nNode)->y > nEndTime) {
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
    assert(nIndex >= 0 && nIndex < m_pathNodes.GetCount());
    return &m_pathNodes[nIndex];
}

/** @ghidraAddress 0x1316b4 */
float MusicSheet::GetFirstPathSpeed() {
    if (m_pathNodes.GetCount() == 0) {
        return kDefaultPathSpeed;
    }
    assert(m_pathNodes.GetCount() > 0);
    // The node's speed occupies the path point's x slot.
    return static_cast<float>(m_pathNodes[0].x);
}

/** @ghidraAddress 0x131704 */
RbffNoteRecord *
MusicSheet::FindNoteInTimeRange(int nLane, int nTimeStart, int nTimeEnd, int nStartIndex) {
    for (int i = nStartIndex; i < m_nNoteCount; ++i) {
        RbffNoteRecord &record = m_pRecords[i];
        if (record.nLane != nLane) {
            continue;
        }
        const int nEndTime = record.nHitWindow + record.nHitTime;
        const int nTailTime = nEndTime + record.nRoute;
        if (nTimeEnd > nEndTime && nTailTime != nTimeStart &&
            (nTimeEnd <= nEndTime || nTimeStart <= nTailTime)) {
            return &record;
        }
    }
    return nullptr;
}

/** @ghidraAddress 0x131760 */
RbffNoteRecord *MusicSheet::FindChainNote(int nLane, int nTime, int nField, int nStartIndex) {
    int nBestEndTime = -1;
    for (int i = nStartIndex; i < m_nNoteCount; ++i) {
        RbffNoteRecord &record = m_pRecords[i];
        // Only notes on the lane that are either not chain notes or a chain head, with a distinct
        // hit time, are candidates.
        if (record.nLane != nLane) {
            continue;
        }
        const bool bEligible =
            (record.dwFlags & kNoteFlagLongHead) == 0 || record.chainLink.IsHead();
        const int nEndTime = record.nHitWindow + record.nHitTime;
        if (bEligible && nEndTime != nTime) {
            // The candidates must be non-decreasing in end time; a smaller one ends the search.
            if (nBestEndTime != -1 && nEndTime <= nBestEndTime) {
                return nullptr;
            }
            nBestEndTime = nTime;
            if (record.nTimingSel == nField) {
                return &record;
            }
        }
    }
    return nullptr;
}

/** @ghidraAddress 0x130e68 */
void MusicSheet::AssignChartLanes(GameSystem *pGameSystem) {
    AssignGreenTargets();

    const unsigned int dwSeed = pGameSystem->GetRandSeed();
    NoteLaneTracker tracker;
    tracker.SetNoteData(dwSeed);

    // First pass: assign each note its display lane.
    for (int i = 0; i < m_nNoteCount; ++i) {
        RbffNoteRecord &record = m_pRecords[i];
        int nLane;
        if ((record.dwFlags & kNoteFlagLongHead) != 0 && !record.chainLink.IsHead()) {
            // A chain note that is not the head inherits its previous segment's display lane.
            nLane = m_pRecords[record.chainLink.GetChainId()].nDisplayLane;
        } else if (record.nHoldKind == 1) {
            // A hold note reserves its fixed colour-tone lane.
            tracker.ReserveNoteLane(record.nHitTime + record.nHitWindow,
                                    record.nRoute,
                                    record.nLane,
                                    record.nColorTone,
                                    false);
            nLane = record.nColorTone;
        } else {
            bool bSpread = false;
            if ((record.dwFlags & kNoteFlagSideObject) != 0) {
                // A side note first marks the colour-tone slots of overlapping same-lane hold notes,
                // then spreads onto them.
                unsigned char aScanFlags[kSideScanSlotCount] = {};
                int nMarked = -1;
                for (int j = i; j < m_nNoteCount; ++j) {
                    RbffNoteRecord &other = m_pRecords[j];
                    if (other.nLane != record.nLane) {
                        continue;
                    }
                    const int nEnd = record.nHitTime + record.nHitWindow;
                    if (other.nHitTime + other.nHitWindow >= nEnd &&
                        other.nHitTime + other.nHitWindow <= nEnd + record.nChainOffset &&
                        other.nHoldKind == 1) {
                        if (nMarked == -1) {
                            nMarked = other.nColorTone;
                        }
                        aScanFlags[other.nColorTone] = 1;
                    }
                }
                // Spread only when the first two slots are marked; the third gates the chosen slot.
                const bool bBothMarked = aScanFlags[0] != 0 && aScanFlags[1] != 0;
                const bool bThirdMarked = bBothMarked && aScanFlags[2] != 0;
                for (int nSlot = 0; nSlot < kSideScanSlotCount; ++nSlot) {
                    const bool bSkip = bThirdMarked && nMarked == nSlot;
                    if (!bSkip && aScanFlags[nSlot] != 0) {
                        tracker.ReserveNoteLane(record.nHitTime + record.nHitWindow,
                                                record.nRoute,
                                                record.nLane,
                                                nSlot,
                                                true);
                    }
                }
                bSpread = true;
            }
            nLane = tracker.AssignNoteLane(record.nHitTime + record.nHitWindow,
                                           record.nRoute,
                                           record.nLane,
                                           bSpread ? 1 : 0,
                                           record.aGreenTargets);
        }
        record.nDisplayLane = nLane;
    }

    // Second pass: resolve each free note's display colour, driven by a default-seeded generator.
    Random colourRng;
    colourRng.SetSeed(dwSeed);
    for (int i = 0; i < m_nNoteCount; ++i) {
        RbffNoteRecord &record = m_pRecords[i];
        const int nColourIndex = colourRng.GetRandomRangeExclusive(0, 2);
        // Paint each of the note's path-point targets with the shared colour index.
        for (int j = 0; j < record.nPointCount; ++j) {
            const int nTarget = record.pPathPoints != nullptr ? record.pPathPoints[j] : -1;
            m_pRecords[nTarget].nColorIndex = nColourIndex;
        }
        if (record.nStartTime != -1) {
            continue;
        }
        int nColour = colourRng.GetRandomBelow(7);
        if (((static_cast<unsigned int>(record.nLinkA) >> 1 & 1) == 0 &&
             static_cast<unsigned int>(record.nTimingSel) < 10) ||
            record.nHoldKind == 1) {
            // Map the timing selector through the slide-lane remap, then the note-colour table, and
            // mirror it into the 0..6 colour range.
            int nRemapped;
            const unsigned int nSel = static_cast<unsigned int>(record.nTimingSel);
            if (nSel < 0xfffffffe) {
                if (nSel == 0xfffffffd) {
                    nRemapped = -4;
                } else if (nSel == 0xfffffffc) {
                    nRemapped = -3;
                } else {
                    nRemapped = kSlideLaneRemap[record.nTimingSel];
                }
            } else {
                nRemapped = -2;
            }
            // The binary indexes the colour table with the remapped selector even when it is
            // negative (-2..-4), reading the words just before the table; reproduced faithfully.
            const int nTableColour = kNoteColorTable[nRemapped];
            nColour = static_cast<unsigned int>(nTableColour - 1) < 6 ? 6 - nTableColour : 6;
        }
        record.nColor = nColour;
    }
}

/** @ghidraAddress 0x131450 */
void MusicSheet::AssignGreenTargets() {
    // First pass: record each hold note's or colour-resolved note's chosen target and mark its slot.
    for (int i = 0; i < m_nNoteCount; ++i) {
        RbffNoteRecord &record = m_pRecords[i];
        int nTarget = -1;
        if (record.nHoldKind == 1) {
            if (record.nColorTone != -1) {
                nTarget = record.nColorTone;
            }
        } else if (static_cast<unsigned int>(record.nTimingSel) < 10) {
            nTarget = record.nTimingSel;
        }
        if (nTarget != -1) {
            record.nChosenTarget = nTarget;
            record.aGreenTargets[nTarget] = 1;
        }
    }

    // Second pass: for eligible green notes, initialise the availability bitmap then clear the slots
    // blocked by overlapping and chained notes.
    for (int i = 0; i < m_nNoteCount; ++i) {
        RbffNoteRecord &record = m_pRecords[i];
        const bool bEligible =
            record.nHoldKind != 1 && static_cast<unsigned int>(record.nTimingSel) >= 10 &&
            ((record.dwFlags & kNoteFlagLongHead) == 0 || record.chainLink.IsHead());
        if (!bEligible) {
            continue;
        }

        // The seven reachable targets start available; the three beyond are not.
        for (int nSlot = 0; nSlot < 7; ++nSlot) {
            record.aGreenTargets[nSlot] = 1;
        }
        for (int nSlot = 7; nSlot < 11; ++nSlot) {
            record.aGreenTargets[nSlot] = 0;
        }

        const int nHitEnd = record.nHitTime + record.nHitWindow;
        // Clear the slots taken by notes overlapping this one's span; each search resumes past the
        // note it found.
        int nSearchStart = 0;
        for (RbffNoteRecord *pOther =
                 FindNoteInTimeRange(record.nLane, nHitEnd, nHitEnd + record.nRoute, nSearchStart);
             pOther != nullptr;
             pOther = FindNoteInTimeRange(
                 record.nLane, nHitEnd, nHitEnd + record.nRoute, nSearchStart)) {
            nSearchStart = pOther->nNoteId + 1;
            if (pOther != &record && pOther->nChosenTarget != -1) {
                record.aGreenTargets[pOther->nChosenTarget] = 0;
                // A hold note also blocks its colour-tone slot.
                if (pOther->nType == 1 && pOther->nHoldKind == 1) {
                    record.aGreenTargets[pOther->nColorTone] = 0;
                }
            }
        }

        // Walk the chain forward (field -3) and backward (field -4); each step re-derives the search
        // from the note just found, and each side trims the bitmap from one end.
        int nForward = 0;
        for (RbffNoteRecord *pChain = &record;
             (pChain = FindChainNote(
                  pChain->nLane, pChain->nHitTime + pChain->nHitWindow, -3, pChain->nNoteId)) !=
             nullptr;) {
            ++nForward;
        }
        int nBackward = 0;
        for (RbffNoteRecord *pChain = &record;
             (pChain = FindChainNote(
                  pChain->nLane, pChain->nHitTime + pChain->nHitWindow, -4, pChain->nNoteId)) !=
             nullptr;) {
            ++nBackward;
        }
        if (nForward > 0) {
            std::memset(record.aGreenTargets, 0, nForward);
        }
        if (nBackward > 0) {
            std::memset(&record.aGreenTargets[7 - nBackward], 0, nBackward);
        }
    }
}

/** @ghidraAddress 0x130cbc */
RbffNoteRecord *MusicSheet::GetChainLastNote(const RbffNoteRecord *pNote) {
    // The start note must be a chain note and must not already be the chain's tail.
    assert((pNote->dwFlags & kNoteFlagLongHead) != 0);
    assert(!pNote->chainLink.IsTail());
    // Follow the next-segment links until a note has no next segment.
    int nIndex = pNote->chainLink.GetNext();
    while (m_pRecords[nIndex].chainLink.GetNext() >= 0) {
        nIndex = m_pRecords[nIndex].chainLink.GetNext();
    }
    return &m_pRecords[nIndex];
}

/** @ghidraAddress 0x13183c */
RbffNoteRecord *MusicSheet::GetNoteRecordByIndex(int nIndex) {
    if (nIndex < 0 || nIndex >= m_nNoteCount) {
        return nullptr;
    }
    // The pool is a contiguous array of records; kNoteRecordStride equals sizeof(RbffNoteRecord).
    return &m_pRecords[nIndex];
}
