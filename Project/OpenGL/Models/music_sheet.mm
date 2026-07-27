//
//  music_sheet.mm
//  REFLEC BEAT plus
//
//  The note-chart reader/parser (CMusicSheet2). Reconstructed from Ghidra project rb458, program
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
#include "rbff_stream.h"
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

/** @ghidraAddress 0x12eb10 */
void ClearNoteChartHeader(RbffTempoEvent *pEvent) {
    std::memset(pEvent->aData, 0, sizeof(pEvent->aData));
}

/** @ghidraAddress 0x12eb20 */
void ClearNotePair(RbffChartHeaderRecord *pRecord) {
    *pRecord = RbffChartHeaderRecord{};
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

// The chart-format version ranges: 10 through 14 take the modern parser, 6 and 7 the legacy one.
constexpr int kMinModernVersion = 10;
constexpr unsigned int kModernVersionSpan = 5;
constexpr int kMinLegacyVersion = 6;

} // namespace

namespace rb {

/** @ghidraAddress 0x12f6f4 */
void CMusicSheet2::InitPathNodeRegion() {
    // The path-node array starts with room for one node and none read; the parse counter and timing
    // block that follows it is zeroed. The member initialisers already zero these fields, so this
    // reproduces the binary's explicit clears.
    m_pathNodes.Reserve();
    m_nChartEndTime = 0;
    m_nSeedA = 0;
    m_nNoteCount = 0;
    m_nTempoEventCount = 0;
    m_nFreeNoteCount = 0;
    m_nSlideRecordCount = 0;
    m_nChartEndTimeScaled = 0;
    m_nField3c = 0;
    m_nChartNoteCount = 0;
    m_nChartNoteCountSide1 = 0;
    for (int nSide = 0; nSide < kSideCount; ++nSide) {
        m_aSideObjectCounts[nSide] = 0;
        m_aPlayableCounts[nSide] = 0;
        m_aSideCount[nSide] = 0;
    }
    m_nScrollTiming = 0;
    m_nRemainTiming = 0;
}

/** @ghidraAddress 0x12f828 */
CMusicSheet2::CMusicSheet2() {
    // The version starts unread; the parser fills it in. Every count, timing, and buffer pointer is
    // cleared by the member initialisers, matching the binary's field-by-field zeroing.
    m_nVersion = -1;
    InitPathNodeRegion();
    m_pRecords = nullptr;
    m_pSlideRecords = nullptr;
    m_pSideIndexArray = nullptr;
    m_pIndexArrayB = nullptr;
    m_nFirstIndex = 0;
    m_nIndexCount = 0;
}

/** @ghidraAddress 0x12f970 */
int CMusicSheet2::ParseNoteChartFile(const void *pBytes, GameSystem *pGameSystem) {
    // Only parse into an empty reader.
    if (m_pRecords != nullptr) {
        return 0;
    }

    RbffStreamCursor cursor;
    InitRbffStreamCursor(&cursor);
    if (!CheckRbffMagic(pBytes)) {
        return 0;
    }

    // The format version follows the four-byte magic; the note stream begins after the 16-byte
    // header.
    const auto *pWords = static_cast<const unsigned int *>(pBytes);
    m_nVersion = static_cast<int>(pWords[1]);
    const auto *pStream = static_cast<const unsigned char *>(pBytes) + 16;

    bool bParsed;
    if (static_cast<unsigned int>(m_nVersion - kMinModernVersion) < kModernVersionSpan) {
        bParsed = ParseNotesV10(reinterpret_cast<const unsigned long *>(pStream)) != 0;
    } else if (static_cast<unsigned int>(m_nVersion - kMinLegacyVersion) <= 1) {
        bParsed = (ParseNoteChartData(reinterpret_cast<const unsigned int *>(pStream)) & 1) != 0;
    } else {
        bParsed = false;
    }

    if (bParsed && InstallParsedNotes(pGameSystem) != 0) {
        ResolveNoteScrollSpeeds();
        return 1;
    }
    // A parse or install failure still resolves scroll speeds before reporting failure.
    ResolveNoteScrollSpeeds();
    return 0;
}

namespace {
// The default-chart geometry: twelve free notes from a base time, one per step, each a fixed
// duration, with the chart end rounded up to a grid (@ghidraAddress 0x2fcff4/0x2feff4/0x453b8000/
// 0x2feff0).
constexpr int kDefaultNoteCount = 12;
constexpr float kDefaultBaseTime = 1500.0f;
constexpr float kDefaultStepTime = 500.0f;
constexpr int kDefaultNoteDuration = 3000;
constexpr float kDefaultEndRoundAdd = 3000.0f;
constexpr float kDefaultEndGrid = 2000.0f;
} // namespace

/** @ghidraAddress 0x130af8 */
unsigned long CMusicSheet2::BuildDefaultNoteChart(GameSystem *pGameSystem) {
    if (m_pRecords != nullptr) {
        return 0;
    }

    // The chart opens with a single start path node.
    m_pathNodes.Append(NotePathPoint{});
    m_pRecords = new RbffNoteRecord[kDefaultNoteCount];

    float flTime = kDefaultBaseTime;
    RbffNoteRecord *pLast = nullptr;
    for (int i = 0; i < kDefaultNoteCount; ++i) {
        RbffNoteRecord &record = m_pRecords[i];
        record.SetTimeA(static_cast<int>(flTime));
        record.SetTimeB(kDefaultNoteDuration);
        record.SetNoteId(i);
        record.SetStartTime(-1); // a free (anywhere) note
        record.SetPointCount(0);
        record.SetPathPoints(nullptr);
        record.SetKind(-1);
        record.SetSide(0);
        record.SetHoldKind(0);
        record.SetType(0);
        record.SetFlags(kNoteFlagFree);
        // Reset the chain link to the empty state (the binary's chain-link init).
        record.GetChainLink() = NoteChainLink();
        flTime += kDefaultStepTime;
        pLast = &record;
    }

    // Round the last note's end time up to the grid to get the chart length.
    const float flEnd = static_cast<float>(
        static_cast<int>(
            (static_cast<float>(pLast->GetTimeB() + pLast->GetTimeA()) + kDefaultEndRoundAdd) /
            kDefaultEndGrid) *
        kDefaultEndGrid);
    m_nChartEndTime = static_cast<int>(flEnd);
    m_nChartEndTimeScaled = static_cast<int>(flEnd * kFieldWidth);
    m_nField3c = 0;
    m_nSeedA = 0;
    m_nNoteCount = kDefaultNoteCount;
    m_nTempoEventCount = 0;
    m_nFreeNoteCount = kDefaultNoteCount;

    return InstallParsedNotes(pGameSystem);
}

namespace {
// The v<11 colour-tone lane table, indexed by a per-side alternator (@ghidraAddress 0x308ac0).
constexpr int kLegacyColorToneLane[] = {0, 2};
// The per-side colour-tone alternator that flips 0<->1 each legacy note (@ghidraAddress 0x3de018).
int g_aColorToneAlternator[2] = {};
// The difficulty value for the BASIC chart.
constexpr int kDifficultyBasic = 0;
// The initial minimum basic-note time.
constexpr int kBasicNoteTimeInit = 9999;
// The unset index-array sentinel.
constexpr int kIndexArraySentinel = 0x7fffffff;
} // namespace

/** @ghidraAddress 0x13029c */
unsigned long CMusicSheet2::InstallParsedNotes(GameSystem *pGameSystem) {
    // perSideCounters[side]: note index; [side+2]: playable+slide index count; [side+4]: side-object
    // count; [side+6]: non-slide-tail (playable) count.
    int perSideCounters[8] = {};
    const int nPlayColor = pGameSystem->GetPlayColor();
    const int nVersion = m_nVersion;

    for (int i = 0; i < m_nNoteCount; ++i) {
        RbffNoteRecord &record = m_pRecords[i];
        const int nSide = record.GetSide();
        record.SetTargetCopy(record.GetTargetCoords()[0]);
        record.SetLane((nPlayColor == nSide) ? 1 : 0);
        record.SetLaneSlot((nPlayColor != nSide) ? 1 : 0);
        record.SetHitTime(
            static_cast<int>((static_cast<float>(record.GetTimeA()) * kFieldWidth) / kTargetScale));
        record.SetHitWindow(
            static_cast<int>((static_cast<float>(record.GetTimeB()) * kFieldWidth) / kTargetScale));
        record.SetChainOffset(static_cast<int>(
            (static_cast<float>(record.GetTargetCoords()[0]) * kFieldWidth) / kTargetScale));
        const unsigned short nSel = static_cast<unsigned short>(record.GetTargetCoords()[1]);
        record.SetColorTone(static_cast<short>(nSel));
        record.SetLinkA(static_cast<short>(record.GetTargetPad()));

        // Derive the shot/route selector into nTimingSel.
        int nRoute = static_cast<short>(nSel);
        if (record.GetHoldKind() == 1) {
            nRoute += 7;
        } else if (nVersion > 0xc) {
            if (nSel < 0xfffe) {
                if (nRoute == -3) {
                    nRoute = -4;
                } else if (nRoute == -4) {
                    nRoute = -3;
                } else {
                    nRoute = kSlideLaneRemap[nRoute];
                }
            } else {
                nRoute = -2;
            }
        } else {
            nRoute = -2;
        }
        record.SetTimingSel(nRoute);

        // Legacy charts pick the colour tone from an alternating table.
        if (nVersion < 0xb) {
            const int nAlt = (nPlayColor == nSide) ? 1 : 0;
            const unsigned int nEntry = g_aColorToneAlternator[nAlt];
            record.SetColorTone(kLegacyColorToneLane[nEntry]);
            g_aColorToneAlternator[nAlt] = nEntry ^ 1;
        }

        record.SetSideIndex(perSideCounters[nSide]);
        ++perSideCounters[nSide];
        if (record.GetType() != kNoteTypeSlideTail) {
            ++perSideCounters[nSide + 6];
        }
        if ((record.GetFlags() & kSideObjectFlag) != 0) {
            ++perSideCounters[nSide + 4];
        }
    }

    // Fold each slide record's owning side into the playable and index counters.
    for (int i = 0; i < m_nSlideRecordCount; ++i) {
        const int nSide = m_pRecords[m_pSlideRecords[i].nNoteIndex].GetSide();
        ++perSideCounters[nSide + 6];
        ++perSideCounters[nSide + 2];
    }

    // Publish the per-side counts into the reader's count fields.
    m_nChartNoteCount = perSideCounters[6];
    m_nChartNoteCountSide1 = perSideCounters[7];
    m_aSideObjectCounts[0] = perSideCounters[4];
    m_aSideObjectCounts[1] = perSideCounters[5];
    m_aPlayableCounts[0] = perSideCounters[2];
    m_aPlayableCounts[1] = perSideCounters[3];

    // Build the free-note side-index array, sized to the free-note count.
    delete[] m_pSideIndexArray;
    m_pSideIndexArray = new int[m_nFreeNoteCount];
    const int nOwnSide = pGameSystem->GetPlayColor();
    m_nFirstIndex = (nOwnSide == 0) ? m_nChartNoteCountSide1 : m_nChartNoteCount;
    const int nOtherPlayable = (nOwnSide == 0) ? m_aPlayableCounts[1] : m_aPlayableCounts[0];
    m_nIndexCount = 0;

    // Count the own-side playable-index entries (a hold note contributes two).
    int nOwnPlayable = 0;
    for (int i = 0; i < m_nNoteCount; ++i) {
        RbffNoteRecord &record = m_pRecords[i];
        if ((record.GetLane() & 4) == 0 && record.GetSideIndex() == 0) {
            m_nIndexCount = nOwnPlayable + 1;
            nOwnPlayable = nOwnPlayable + 1;
            if (record.GetType() == 1) {
                m_nIndexCount = nOwnPlayable + 1;
                nOwnPlayable = nOwnPlayable + 1;
            }
        }
    }

    // Allocate the playable-index array and prefill the own-side slots with the sentinel.
    m_pIndexArrayB = new int[nOtherPlayable + nOwnPlayable];
    for (int i = 0; i < m_nIndexCount; ++i) {
        m_pIndexArrayB[i] = kIndexArraySentinel;
    }

    const int nDifficulty = pGameSystem->GetDifficulty();
    int nFreeIndex = 0;
    int nPlayableIndex = 0;
    int nBasicMinTime = kBasicNoteTimeInit;
    bool bBasicOpen = true;
    for (int i = 0; i < m_nNoteCount; ++i) {
        RbffNoteRecord &record = m_pRecords[i];

        // Mark the difficulty's basic notes: every own-side note on BASIC, otherwise the first
        // non-decreasing run of hit times.
        if (record.GetLane() == nOwnSide) {
            if (nDifficulty == kDifficultyBasic) {
                record.SetBasicNote(true);
            } else if (bBasicOpen && record.GetHitTime() + record.GetHitWindow() <= nBasicMinTime) {
                record.SetBasicNote(true);
                nBasicMinTime = record.GetHitTime() + record.GetHitWindow();
            } else {
                bBasicOpen = false;
            }
        }

        // Record each free note's id in the side-index array.
        if (nFreeIndex >= 0 && (record.GetFlags() & kNoteFlagFree) != 0 &&
            nFreeIndex < m_nFreeNoteCount) {
            m_pSideIndexArray[nFreeIndex] = record.GetNoteId();
            ++nFreeIndex;
        }

        // Derive the note's route by type.
        if (record.GetType() == kNoteTypeSlideTail) {
            record.SetRoute(7);
        } else if (record.GetType() == 1) {
            record.SetRoute(record.GetChainOffset() + (record.GetHoldKind() == 1 ? 7 : 9));
        } else if ((record.GetFlags() & kNoteFlagLongHead) != 0) {
            if (record.GetChainLink().IsHead()) {
                RbffNoteRecord *pLast = GetChainLastNote(&record);
                int nR = (pLast->GetHitTime() + pLast->GetHitWindow()) - record.GetHitTime() -
                         record.GetHitWindow();
                if (pLast->GetType() == 1) {
                    nR += pLast->GetChainOffset();
                    nR += (record.GetHoldKind() == 1) ? 7 : 9;
                } else {
                    nR += 7;
                }
                record.SetRoute(nR);
            } else {
                record.SetRoute(0);
            }
        } else {
            record.SetRoute(7);
        }

        // Populate the playable-index array for own-side, lane-0 notes and flag simultaneous
        // cross-side notes.
        const bool bPlayable = (record.GetFlags() & kNoteFlagFree) == 0 && record.GetLane() == 0;
        if (bPlayable) {
            m_pIndexArrayB[nPlayableIndex] = record.GetHitWindow() + record.GetHitTime();
            ++nPlayableIndex;
            if (record.GetType() == 1) {
                m_pIndexArrayB[nPlayableIndex] =
                    record.GetChainOffset() + record.GetHitTime() + record.GetHitWindow();
                ++nPlayableIndex;
            }
        }
        if (record.GetType() == 1) {
            // Flag a note as simultaneous when a cross-side note ends within two ticks of its tail.
            for (int j = 0; j < m_nNoteCount; ++j) {
                RbffNoteRecord &other = m_pRecords[j];
                if (other.GetSide() == record.GetSide()) {
                    continue;
                }
                const unsigned int nDelta =
                    (record.GetChainOffset() + record.GetHitTime() + record.GetHitWindow() + 1) -
                    (other.GetHitTime() + other.GetHitWindow());
                if (nDelta < 3 || nDelta - other.GetChainOffset() < 3) {
                    record.SetFlags(record.GetFlags() | (kNoteFlagSideObject));
                    break;
                }
            }
        }
    }

    // Append each non-1-lane slide's time to the playable-index array when no note is near it.
    for (int i = 0; i < m_nSlideRecordCount; ++i) {
        RbffSlideRecord &slide = m_pSlideRecords[i];
        if (m_pRecords[slide.nNoteIndex].GetLane() != 1 &&
            nPlayableIndex < nOtherPlayable + nOwnPlayable) {
            const int nTime = slide.nValueBScaled + slide.nValueAScaled;
            if (!CheckNoteNearTime(nTime, 1)) {
                m_pIndexArrayB[nPlayableIndex] = nTime;
                ++nPlayableIndex;
            }
        }
    }

    AssignChartLanes(pGameSystem);
    CalculateChartTiming();
    return static_cast<unsigned long>(perSideCounters[6] == perSideCounters[7]);
}

/** @ghidraAddress 0x12fa34 */
int CMusicSheet2::ParseNoteChartData(const unsigned int *pStream) {
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
        record.SetTimeA(chartNote.nTimeA);
        record.SetTimeB(chartNote.nTimeB);
        record.SetNoteId(chartNote.nNoteId);
        record.SetStartTime(chartNote.nStartTime);
        record.SetPointCount(chartNote.nPointCount);
        if (chartNote.nPointCount > 0) {
            record.SetPathPoints(new short[chartNote.nPointCount]);
            for (int j = 0; j < chartNote.nPointCount; ++j) {
                record.GetPathPoints()[j] = chartNote.pathPoints[j];
            }
        }
        record.SetKind(chartNote.nKind);
        record.SetSide(chartNote.nSide);
        // The three target coordinates follow the eight path-point shorts on disk.
        for (int j = 0; j < 3; ++j) {
            record.GetTargetCoords()[j] = chartNote.pathPoints[4 + j];
        }
        record.SetTargetPad(0);
        record.SetHoldKind(chartNote.nHoldFlag != 0 ? 1 : 0);
        record.SetType(chartNote.nType);

        unsigned int dwFlags = 0;
        // An on-disk note type of 2 marks a long-note head.
        if (chartNote.nType == kChartKindLongHead) {
            record.SetType(0);
            dwFlags = kNoteFlagLongHead;
            record.GetChainLink().SetLongNoteHead(chartNote.nChainLink, chartNote.nChainPartner);
        }
        if (record.GetStartTime() == -1) {
            dwFlags |= kNoteFlagFree;
        }
        if (record.GetPointCount() > 0) {
            dwFlags |= kNoteFlagHasPath;
        }
        record.SetFlags(dwFlags);
        // Scale the first target coordinate into the hash range.
        record.GetTargetCoords()[0] = static_cast<short>(static_cast<int>(
            (static_cast<float>(record.GetTargetCoords()[0]) / kFieldWidth) * kTargetScale));
    }

    // Second pass: pair notes sharing an absolute end time and resolve each long note's tail.
    for (int i = 0; i < m_nNoteCount; ++i) {
        RbffNoteRecord &head = m_pRecords[i];
        for (int j = 0; j < m_nNoteCount; ++j) {
            if (i == j) {
                continue;
            }
            RbffNoteRecord &other = m_pRecords[j];
            if (head.GetTimeA() + head.GetTimeB() == other.GetTimeA() + other.GetTimeB()) {
                head.SetFlags(head.GetFlags() |
                              ((head.GetSide() == other.GetSide()) ? kNoteFlagSameLane :
                                                                     kNoteFlagDifferentLane));
            }
            // Resolve a long-note head's tail against the note whose id matches its chain link.
            if ((head.GetFlags() & kNoteFlagLongHead) != 0 &&
                head.GetChainLink().GetChainId() != -1 &&
                head.GetChainLink().GetChainId() == other.GetNoteId()) {
                other.SetFlags(other.GetFlags() | (kNoteFlagLongHead));
                other.GetChainLink().SetTail(
                    static_cast<short>(head.GetNoteId()),
                    static_cast<short>(head.GetTimeA() - other.GetTimeA()));
            }
        }
        if ((head.GetFlags() & kNoteFlagFree) != 0) {
            ++m_nFreeNoteCount;
        }
    }

    return 1;
}

/** @ghidraAddress 0x12fdf4 */
int CMusicSheet2::ParseNotesV10(const unsigned long *pStream) {
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
        record.SetTimeA(staging.nTimeA);
        record.SetTimeB(staging.nTimeB);
        record.SetNoteId(staging.nNoteId);
        record.SetStartTime(staging.nStartTime);
        record.SetPointCount(staging.nPointCount);
        if (staging.nPointCount > 0) {
            record.SetPathPoints(new short[staging.nPointCount]);
            for (int j = 0; j < staging.nPointCount; ++j) {
                record.GetPathPoints()[j] = staging.pPathPoints[j];
            }
        }
        record.SetKind(staging.nKind);
        record.SetSide(staging.nSide);
        record.SetHoldKind(staging.nHoldKind);
        // The on-disk type of 2 is remapped to 0; any other value passes through.
        record.SetType(staging.nType == kChartKindLongHead ? 0 : staging.nType);
        for (int j = 0; j < 3; ++j) {
            record.GetTargetCoords()[j] = staging.aTargetCoords[j];
        }
        record.SetFlags(staging.nFlags);
        if ((staging.nFlags & kNoteFlagLongHead) != 0) {
            record.GetChainLink().SetLongNoteHead(staging.nChainLink, staging.nChainPartner);
        }
        FreeNotePathArray(&staging);
    }

    // The tempo events follow the notes; a speed-change event (kind 3) appends a path node.
    for (int i = 0; i < m_nTempoEventCount; ++i) {
        RbffTempoEvent event;
        ClearNoteChartHeader(&event);
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
            ClearNotePair(&header);
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
                pOwner->SetSlideRecord(&m_pSlideRecords[i]);
                nLastIndex = nIndex;
            }
            ++pOwner->GetSlidePointCount();
        }
    }

    return 1;
}

/**
 * @ghidraAddress 0x12f874
 * @ghidraAddress 0x12f938
 */
CMusicSheet2::~CMusicSheet2() {
    delete[] m_pIndexArrayB;
    m_pIndexArrayB = nullptr;
    delete[] m_pSideIndexArray;
    m_pSideIndexArray = nullptr;
    if (m_pRecords != nullptr) {
        // Free each note's path-point sub-buffer before releasing the record pool itself.
        for (int i = 0; i < m_nNoteCount; ++i) {
            delete[] m_pRecords[i].GetPathPoints();
            m_pRecords[i].SetPathPoints(nullptr);
        }
        delete[] m_pRecords;
        m_pRecords = nullptr;
    }
    delete[] m_pSlideRecords;
    m_pSlideRecords = nullptr;
    m_pathNodes.Free();
}

/** @ghidraAddress 0x130d64 */
bool CMusicSheet2::CheckNoteNearTime(int nTime, int nTarget) {
    // Scan the note records for one on the target lane whose end time is near the query time.
    for (int i = 0; i < m_nNoteCount; ++i) {
        const RbffNoteRecord &record = m_pRecords[i];
        if (record.GetLane() != nTarget) {
            continue;
        }
        int nEndTime = record.GetHitTime() + record.GetHitWindow();
        if (std::abs(nEndTime - nTime) < kNearTimeTolerance) {
            return true;
        }
        // A hold note also matches on its tail end.
        if (record.GetType() == kNoteTypeHold) {
            const int nTailTime = nEndTime + record.GetChainOffset();
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
        if (m_pRecords[slide.nNoteIndex].GetLane() != nTarget) {
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
void CMusicSheet2::ResolveNoteScrollSpeeds() {
    for (int i = 0; i < m_nNoteCount; ++i) {
        RbffNoteRecord &record = m_pRecords[i];
        // Seed both speeds from the first path node.
        record.SetScrollStartSpeed(GetFirstPathSpeed());
        record.SetScrollEndSpeed(GetFirstPathSpeed());

        const int nStartTime = record.GetTimeA();
        const int nEndTime = record.GetTimeA() + record.GetTimeB();
        // Walk the path nodes, advancing the start speed up to the note's start time and the end
        // speed up to its end time, until a node lies past the note's end.
        for (int nNode = 1; nNode < m_pathNodes.GetCount(); ++nNode) {
            // A node's time is its y coordinate and its speed its x coordinate.
            if (GetSheetPathNode(nNode)->y <= nStartTime) {
                record.SetScrollStartSpeed(static_cast<float>(GetSheetPathNode(nNode)->x));
            }
            if (GetSheetPathNode(nNode)->y <= nEndTime) {
                record.SetScrollEndSpeed(static_cast<float>(GetSheetPathNode(nNode)->x));
            }
            if (GetSheetPathNode(nNode)->y > nEndTime) {
                break;
            }
        }

        record.SetScrollVisible(record.GetScrollStartSpeed() < record.GetScrollEndSpeed());
    }
}

/** @ghidraAddress 0x131294 */
int CMusicSheet2::CalculateChartTiming() {
    int aPerSideEndTime[kSideCount] = {};
    bool aSideSeen[kSideCount] = {};

    // Walk the records backward: for each side, record the end time of its last side-object note.
    for (int i = m_nNoteCount - 1; i >= 0; --i) {
        const RbffNoteRecord &record = m_pRecords[i];
        const int nSide = record.GetSide();
        if (!aSideSeen[nSide] && (record.GetFlags() & kSideObjectFlag) != 0) {
            aPerSideEndTime[nSide] = record.GetHitTime() + record.GetHitWindow();
            aSideSeen[nSide] = true;
        }
        if (aSideSeen[0] && aSideSeen[1]) {
            break;
        }
    }

    // Count the notes whose end time runs past their side's side-object end time.
    for (int i = 0; i < m_nNoteCount; ++i) {
        const RbffNoteRecord &record = m_pRecords[i];
        if (record.GetType() == kNoteTypeSlideTail) {
            continue;
        }
        int nEndTime = record.GetHitTime() + record.GetHitWindow();
        if (record.GetType() == kNoteTypeHold) {
            nEndTime += record.GetChainOffset();
        }
        if (aPerSideEndTime[record.GetSide()] < nEndTime) {
            ++m_aSideCount[record.GetSide()];
        }
    }

    // Count the slide records likewise, keyed to their owning note's side.
    for (int i = 0; i < m_nSlideRecordCount; ++i) {
        const RbffSlideRecord &slide = m_pSlideRecords[i];
        const int nSide = m_pRecords[slide.nNoteIndex].GetSide();
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
SheetPathNode *CMusicSheet2::GetSheetPathNode(int nIndex) {
    assert(nIndex >= 0 && nIndex < m_pathNodes.GetCount());
    return &m_pathNodes[nIndex];
}

/** @ghidraAddress 0x1316b4 */
float CMusicSheet2::GetFirstPathSpeed() {
    if (m_pathNodes.GetCount() == 0) {
        return kDefaultPathSpeed;
    }
    assert(m_pathNodes.GetCount() > 0);
    // The node's speed occupies the path point's x slot.
    return static_cast<float>(m_pathNodes[0].x);
}

/** @ghidraAddress 0x131704 */
RbffNoteRecord *
CMusicSheet2::FindNoteInTimeRange(int nLane, int nTimeStart, int nTimeEnd, int nStartIndex) {
    for (int i = nStartIndex; i < m_nNoteCount; ++i) {
        RbffNoteRecord &record = m_pRecords[i];
        if (record.GetLane() != nLane) {
            continue;
        }
        const int nEndTime = record.GetHitWindow() + record.GetHitTime();
        const int nTailTime = nEndTime + record.GetRoute();
        if (nTimeEnd > nEndTime && nTailTime != nTimeStart &&
            (nTimeEnd <= nEndTime || nTimeStart <= nTailTime)) {
            return &record;
        }
    }
    return nullptr;
}

/** @ghidraAddress 0x131760 */
RbffNoteRecord *CMusicSheet2::FindChainNote(int nLane, int nTime, int nField, int nStartIndex) {
    int nBestEndTime = -1;
    for (int i = nStartIndex; i < m_nNoteCount; ++i) {
        RbffNoteRecord &record = m_pRecords[i];
        // Only notes on the lane that are either not chain notes or a chain head, with a distinct
        // hit time, are candidates.
        if (record.GetLane() != nLane) {
            continue;
        }
        const bool bEligible =
            (record.GetFlags() & kNoteFlagLongHead) == 0 || record.GetChainLink().IsHead();
        const int nEndTime = record.GetHitWindow() + record.GetHitTime();
        if (bEligible && nEndTime != nTime) {
            // The candidates must be non-decreasing in end time; a smaller one ends the search.
            if (nBestEndTime != -1 && nEndTime <= nBestEndTime) {
                return nullptr;
            }
            nBestEndTime = nTime;
            if (record.GetTimingSel() == nField) {
                return &record;
            }
        }
    }
    return nullptr;
}

/** @ghidraAddress 0x130e68 */
void CMusicSheet2::AssignChartLanes(GameSystem *pGameSystem) {
    AssignGreenTargets();

    const unsigned int dwSeed = pGameSystem->GetRandSeed();
    NoteLaneTracker tracker;
    tracker.SetNoteData(dwSeed);

    // First pass: assign each note its display lane.
    for (int i = 0; i < m_nNoteCount; ++i) {
        RbffNoteRecord &record = m_pRecords[i];
        int nLane;
        if ((record.GetFlags() & kNoteFlagLongHead) != 0 && !record.GetChainLink().IsHead()) {
            // A chain note that is not the head inherits its previous segment's display lane.
            nLane = m_pRecords[record.GetChainLink().GetChainId()].GetDisplayLane();
        } else if (record.GetHoldKind() == 1) {
            // A hold note reserves its fixed colour-tone lane.
            tracker.ReserveNoteLane(record.GetHitTime() + record.GetHitWindow(),
                                    record.GetRoute(),
                                    record.GetLane(),
                                    record.GetColorTone(),
                                    false);
            nLane = record.GetColorTone();
        } else {
            bool bSpread = false;
            if ((record.GetFlags() & kNoteFlagSideObject) != 0) {
                // A side note first marks the colour-tone slots of overlapping same-lane hold notes,
                // then spreads onto them.
                unsigned char aScanFlags[kSideScanSlotCount] = {};
                int nMarked = -1;
                for (int j = i; j < m_nNoteCount; ++j) {
                    RbffNoteRecord &other = m_pRecords[j];
                    if (other.GetLane() != record.GetLane()) {
                        continue;
                    }
                    const int nEnd = record.GetHitTime() + record.GetHitWindow();
                    if (other.GetHitTime() + other.GetHitWindow() >= nEnd &&
                        other.GetHitTime() + other.GetHitWindow() <=
                            nEnd + record.GetChainOffset() &&
                        other.GetHoldKind() == 1) {
                        if (nMarked == -1) {
                            nMarked = other.GetColorTone();
                        }
                        aScanFlags[other.GetColorTone()] = 1;
                    }
                }
                // Spread only when the first two slots are marked; the third gates the chosen slot.
                const bool bBothMarked = aScanFlags[0] != 0 && aScanFlags[1] != 0;
                const bool bThirdMarked = bBothMarked && aScanFlags[2] != 0;
                for (int nSlot = 0; nSlot < kSideScanSlotCount; ++nSlot) {
                    const bool bSkip = bThirdMarked && nMarked == nSlot;
                    if (!bSkip && aScanFlags[nSlot] != 0) {
                        tracker.ReserveNoteLane(record.GetHitTime() + record.GetHitWindow(),
                                                record.GetRoute(),
                                                record.GetLane(),
                                                nSlot,
                                                true);
                    }
                }
                bSpread = true;
            }
            nLane = tracker.AssignNoteLane(record.GetHitTime() + record.GetHitWindow(),
                                           record.GetRoute(),
                                           record.GetLane(),
                                           bSpread ? 1 : 0,
                                           record.GetGreenTargets());
        }
        record.SetDisplayLane(nLane);
    }

    // Second pass: resolve each free note's display colour, driven by a default-seeded generator.
    Random colourRng;
    colourRng.SetSeed(dwSeed);
    for (int i = 0; i < m_nNoteCount; ++i) {
        RbffNoteRecord &record = m_pRecords[i];
        const int nColourIndex = colourRng.GetRandomRangeExclusive(0, 2);
        // Paint each of the note's path-point targets with the shared colour index.
        for (int j = 0; j < record.GetPointCount(); ++j) {
            const int nTarget = record.GetPathPoints() != nullptr ? record.GetPathPoints()[j] : -1;
            m_pRecords[nTarget].SetColorIndex(nColourIndex);
        }
        if (record.GetStartTime() != -1) {
            continue;
        }
        int nColour = colourRng.GetRandomBelow(7);
        if (((static_cast<unsigned int>(record.GetLinkA()) >> 1 & 1) == 0 &&
             static_cast<unsigned int>(record.GetTimingSel()) < 10) ||
            record.GetHoldKind() == 1) {
            // Map the timing selector through the slide-lane remap, then the note-colour table, and
            // mirror it into the 0..6 colour range.
            int nRemapped;
            const unsigned int nSel = static_cast<unsigned int>(record.GetTimingSel());
            if (nSel < 0xfffffffe) {
                if (nSel == 0xfffffffd) {
                    nRemapped = -4;
                } else if (nSel == 0xfffffffc) {
                    nRemapped = -3;
                } else {
                    nRemapped = kSlideLaneRemap[record.GetTimingSel()];
                }
            } else {
                nRemapped = -2;
            }
            // The binary indexes the colour table with the remapped selector even when it is
            // negative (-2..-4), reading the words just before the table; reproduced faithfully.
            const int nTableColour = kNoteColorTable[nRemapped];
            nColour = static_cast<unsigned int>(nTableColour - 1) < 6 ? 6 - nTableColour : 6;
        }
        record.SetColor(nColour);
    }
}

/** @ghidraAddress 0x131450 */
void CMusicSheet2::AssignGreenTargets() {
    // First pass: record each hold note's or colour-resolved note's chosen target and mark its slot.
    for (int i = 0; i < m_nNoteCount; ++i) {
        RbffNoteRecord &record = m_pRecords[i];
        int nTarget = -1;
        if (record.GetHoldKind() == 1) {
            if (record.GetColorTone() != -1) {
                nTarget = record.GetColorTone();
            }
        } else if (static_cast<unsigned int>(record.GetTimingSel()) < 10) {
            nTarget = record.GetTimingSel();
        }
        if (nTarget != -1) {
            record.SetChosenTarget(nTarget);
            record.GetGreenTargets()[nTarget] = 1;
        }
    }

    // Second pass: for eligible green notes, initialise the availability bitmap then clear the slots
    // blocked by overlapping and chained notes.
    for (int i = 0; i < m_nNoteCount; ++i) {
        RbffNoteRecord &record = m_pRecords[i];
        const bool bEligible =
            record.GetHoldKind() != 1 && static_cast<unsigned int>(record.GetTimingSel()) >= 10 &&
            ((record.GetFlags() & kNoteFlagLongHead) == 0 || record.GetChainLink().IsHead());
        if (!bEligible) {
            continue;
        }

        // The seven reachable targets start available; the three beyond are not.
        for (int nSlot = 0; nSlot < 7; ++nSlot) {
            record.GetGreenTargets()[nSlot] = 1;
        }
        for (int nSlot = 7; nSlot < 11; ++nSlot) {
            record.GetGreenTargets()[nSlot] = 0;
        }

        const int nHitEnd = record.GetHitTime() + record.GetHitWindow();
        // Clear the slots taken by notes overlapping this one's span; each search resumes past the
        // note it found.
        int nSearchStart = 0;
        for (RbffNoteRecord *pOther = FindNoteInTimeRange(
                 record.GetLane(), nHitEnd, nHitEnd + record.GetRoute(), nSearchStart);
             pOther != nullptr;
             pOther = FindNoteInTimeRange(
                 record.GetLane(), nHitEnd, nHitEnd + record.GetRoute(), nSearchStart)) {
            nSearchStart = pOther->GetNoteId() + 1;
            if (pOther != &record && pOther->GetChosenTarget() != -1) {
                record.GetGreenTargets()[pOther->GetChosenTarget()] = 0;
                // A hold note also blocks its colour-tone slot.
                if (pOther->GetType() == 1 && pOther->GetHoldKind() == 1) {
                    record.GetGreenTargets()[pOther->GetColorTone()] = 0;
                }
            }
        }

        // Walk the chain forward (field -3) and backward (field -4); each step re-derives the search
        // from the note just found, and each side trims the bitmap from one end.
        int nForward = 0;
        for (RbffNoteRecord *pChain = &record;
             (pChain = FindChainNote(pChain->GetLane(),
                                     pChain->GetHitTime() + pChain->GetHitWindow(),
                                     -3,
                                     pChain->GetNoteId())) != nullptr;) {
            ++nForward;
        }
        int nBackward = 0;
        for (RbffNoteRecord *pChain = &record;
             (pChain = FindChainNote(pChain->GetLane(),
                                     pChain->GetHitTime() + pChain->GetHitWindow(),
                                     -4,
                                     pChain->GetNoteId())) != nullptr;) {
            ++nBackward;
        }
        if (nForward > 0) {
            std::memset(record.GetGreenTargets(), 0, nForward);
        }
        if (nBackward > 0) {
            std::memset(&record.GetGreenTargets()[7 - nBackward], 0, nBackward);
        }
    }
}

/** @ghidraAddress 0x130cbc */
RbffNoteRecord *CMusicSheet2::GetChainLastNote(const RbffNoteRecord *pNote) {
    // The start note must be a chain note and must not already be the chain's tail.
    assert((pNote->GetFlags() & kNoteFlagLongHead) != 0);
    assert(!pNote->GetChainLink().IsTail());
    // Follow the next-segment links until a note has no next segment.
    int nIndex = pNote->GetChainLink().GetNext();
    while (m_pRecords[nIndex].GetChainLink().GetNext() >= 0) {
        nIndex = m_pRecords[nIndex].GetChainLink().GetNext();
    }
    return &m_pRecords[nIndex];
}

/** @ghidraAddress 0x13183c */
RbffNoteRecord *CMusicSheet2::GetNoteRecordByIndex(int nIndex) {
    if (nIndex < 0 || nIndex >= m_nNoteCount) {
        return nullptr;
    }
    // The pool is a contiguous array of records; kNoteRecordStride equals sizeof(RbffNoteRecord).
    return &m_pRecords[nIndex];
}

} // namespace rb
