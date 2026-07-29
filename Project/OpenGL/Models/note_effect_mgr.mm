//
//  note_effect_mgr.mm
//  REFLEC BEAT plus
//
//  The process-wide note manager (NoteEffectMgr). Reconstructed from Ghidra project rb458, program
//  rb458. @ghidraAddress values are relative to the program image base.
//

#include "note_effect_mgr.h"

#include <cstdlib>
#include <cstring>

#import "RBUserSettingData.h"
#include "ScoreTracker.h"
#include "deviceenvironment.h"
#include "full_combo_classic_layer.h"
#include "full_combo_colette_layer.h"
#include "full_combo_limelight_layer.h"
#include "gamesystem.h"
#include "music_sheet.h"
#include "note_model.h"
#include "rbffnoterecord.h"
#include "shotsoundmanager.h"
#include "touch_point.h"
#include "touchmanager.h"

// The process-wide note manager, created lazily by shared().
static NoteEffectMgr *g_pNoteEffectMgr = nullptr; // @ghidraAddress 0x3de050

namespace {

// The play-record grade cells summed to detect chart completion (the four judged grades), and the
// theme identifiers selecting the full-combo layer.
constexpr unsigned int kGradeMiss = 3;
constexpr unsigned int kGradeGood = 4;
constexpr unsigned int kGradeGreat = 5;
constexpr unsigned int kGradeJust = 6;
constexpr int kThemaClassic = 0;
constexpr int kThemaLimelight = 1;

// The final judged grade values (the last note's grade) selecting the completion handler.
constexpr int kFinalGradeFullCombo = 0;
constexpr int kFinalGradeClear = 1;
constexpr int kFinalGradeMiss = 2;

} // namespace

/** @ghidraAddress 0x136bec */
NoteEffectMgr::NoteEffectMgr() {
    // The header, combo, tier, and render sub-table are zeroed by the member initialisers; the
    // binary clears them explicitly. Only the active-slot indices start at the -1 empty marker.
    for (long &nSlot : m_aActiveSlot) {
        nSlot = kActiveSlotNone;
    }
    m_bIsPad = IsPad();
}

/** @ghidraAddress 0x137790 */
void NoteEffectMgr::HandleNoteScored(int nUnused, int nSide) {
    (void)nUnused; // The caller passes a note index the binary does not read here.

    // The score-record side is the tracker row for whether the scored side is the active play side.
    const unsigned int nRecordSide = GameSystem::GetGameSystem()->GetPlayColor() == nSide ? 1 : 0;
    ScoreTracker *pTracker = ScoreTracker::shared();

    // Sum the four judged-grade tallies (grades 3 through 6); the chart is complete once they reach
    // the total note count.
    const int nJudged = pTracker->GetPlayRecordCell(nRecordSide, kGradeMiss) +
                        pTracker->GetPlayRecordCell(nRecordSide, kGradeGood) +
                        pTracker->GetPlayRecordCell(nRecordSide, kGradeGreat) +
                        pTracker->GetPlayRecordCell(nRecordSide, kGradeJust);
    if (pTracker->GetTotalNotes() != nJudged) {
        return;
    }

    // Finalise by the final judged grade: grade 2 and grade 1 set their judge scores; grade 0 is a
    // full combo, which triggers the current theme's full-combo layer before setting judge score 0.
    const int nFinalGrade = pTracker->GetPlayRecordCell(nRecordSide, kGradeJust);
    if (nFinalGrade == kFinalGradeMiss) {
        pTracker->SetJudgeScore3(nRecordSide);
    } else if (nFinalGrade == kFinalGradeClear) {
        pTracker->SetJudgeScore2(nRecordSide);
    } else if (nFinalGrade == kFinalGradeFullCombo) {
        const auto nColor = static_cast<unsigned int>(nSide);
        if (m_nThema == kThemaLimelight) {
            FullComboLimelightLayer::shared()->CreateFullComboLimelight(nColor);
        } else if (m_nThema == kThemaClassic) {
            FullComboClassicLayer::shared()->CreateFullComboClassic(nColor);
        } else {
            FullComboColetteLayer::shared()->CreateFullComboColette(nColor);
        }
        pTracker->SetJudgeScore0(nRecordSide);
    }
}

/** @ghidraAddress 0x1373a0 */
void NoteEffectMgr::ClearNotePositionCache() {
    for (RenderEntry &entry : m_aRenderTable) {
        entry.nCachedKey = -1;
    }
}

/** @ghidraAddress 0x136e38 */
const S_VECTOR2 *NoteEffectMgr::GetOrCacheNotePosition(int nTouchId) {
    // Return the already-cached projected position for this touch id, if present.
    for (RenderEntry &entry : m_aRenderTable) {
        if (entry.nCachedKey == nTouchId) {
            return &entry.cachedPosition;
        }
    }

    // Otherwise claim the first empty slot; a full cache drops the request.
    int nSlot = -1;
    for (int i = 0; i < kRenderEntryCount; ++i) {
        if (m_aRenderTable[i].nCachedKey == -1) {
            nSlot = i;
            break;
        }
    }
    if (nSlot < 0 || nSlot >= kRenderEntryCount) {
        return nullptr;
    }

    // Find the live touch with this id, normalise its position by the view size it began in,
    // project it into note-field space, and cache it.
    TouchManager *pTouchManager = TouchManager::FetchSharedSingleton();
    const int nActive = pTouchManager->GetActiveTouchCount();
    for (int i = 0; i < nActive; ++i) {
        TouchPoint *pTouch = pTouchManager->GetActiveTouch(i);
        if (pTouch->nId != nTouchId) {
            continue;
        }
        RenderEntry &entry = m_aRenderTable[nSlot];
        entry.nCachedKey = nTouchId;
        entry.cachedPosition =
            S_VECTOR2{static_cast<float>(pTouch->nCurrentX) / static_cast<float>(pTouch->nKey1),
                      static_cast<float>(pTouch->nCurrentY) / static_cast<float>(pTouch->nKey2)};
        ProjectNoteHitPoint(&entry.cachedPosition);
        return &entry.cachedPosition;
    }
    return nullptr;
}

/** @ghidraAddress 0x137004 */
RbffNoteRecord *NoteEffectMgr::GetActiveNoteRecord(int nIndex) {
    if (m_pMusicSheet == nullptr) {
        return nullptr;
    }
    return m_pMusicSheet->GetNoteRecordByIndex(nIndex);
}

/** @ghidraAddress 0x1378e4 */
void NoteEffectMgr::IterateNoteRecords() {
    if (m_pMusicSheet == nullptr) {
        return;
    }
    for (int nIndex = 0; nIndex < m_pMusicSheet->GetNoteCount(); ++nIndex) {
        // The fetched record is deliberately discarded; only the lookup is exercised.
        (void)m_pMusicSheet->GetNoteRecordByIndex(nIndex);
    }
}

namespace {
// The note-record flag bits the effect manager queries.
constexpr unsigned int kNoteFlagScoreExcluded = 1u << 2;
constexpr unsigned int kNoteFlag40 = 1u << 6;
} // namespace

/** @ghidraAddress 0x137a88 */
bool NoteEffectMgr::IsNoteScoreExcluded(int nIndex) {
    if (m_pMusicSheet != nullptr) {
        RbffNoteRecord *pRecord = m_pMusicSheet->GetNoteRecordByIndex(nIndex);
        if (pRecord != nullptr) {
            return (pRecord->GetFlags() & kNoteFlagScoreExcluded) != 0;
        }
    }
    return false;
}

/** @ghidraAddress 0x137ab8 */
bool NoteEffectMgr::IsNoteFlag40Set(int nIndex) {
    if (m_pMusicSheet != nullptr) {
        RbffNoteRecord *pRecord = m_pMusicSheet->GetNoteRecordByIndex(nIndex);
        // The binary omits the record null-check here; the record is guarded anyway.
        if (pRecord != nullptr) {
            return (pRecord->GetFlags() & kNoteFlag40) != 0;
        }
    }
    return false;
}

namespace {
// Folds a rand() result into the unit interval (@ghidraAddress 0x3014d0 = 1 / RAND_MAX).
constexpr float kInverseRandMax = 1.0f / 2147483647.0f;

// The colour-spread lerp table, indexed by the combo count (@ghidraAddress 0x308c4c). Consecutive
// entries are the lo/hi endpoints a random factor interpolates between to pick the grey-note
// proportion; higher combos skew towards more grey (colour zero).
constexpr float kColorSpreadByCombo[] = {
    0.45f, 0.525f, 0.525f, 0.575f, 0.575f, 0.63f, 0.63f, 0.70f, 0.70f, 0.73f, 0.73f,
    0.77f, 0.77f,  0.80f,  0.80f,  0.83f,  0.83f, 0.85f, 0.85f, 0.91f, 1.0f,  1.0f,
};

// The four note colours the random assignment draws from.
constexpr int kNoteColorCount = 4;
// The number of player sides the full-combo colour-count pass walks.
constexpr int kSideCount = 2;
// The two-side versus game types: type zero or two.
constexpr int kGameTypeVersusA = 2;
constexpr int kGameTypeVersusB = 0;
// The colour full-combo notes are forced to.
constexpr int kFullComboColor = 0;
} // namespace

/** @ghidraAddress 0x1373c0 */
void NoteEffectMgr::AssignNoteColors() {
    if (m_pMusicSheet == nullptr) {
        return;
    }

    GameSystem *pGameSystem = GameSystem::GetGameSystem();
    const int nCombo = pGameSystem->GetComboCount();

    // Interpolate the grey-note proportion between the combo band's lo/hi endpoints by a random
    // factor, then clamp it to the unit interval.
    const int nSpreadIndex = nCombo < 0 ? 0 : nCombo;
    const float flLo = kColorSpreadByCombo[nSpreadIndex * 2];
    const float flHi = kColorSpreadByCombo[nSpreadIndex * 2 + 1];
    float flGreyProportion = flLo + (flHi - flLo) * static_cast<float>(rand()) * kInverseRandMax;
    if (flGreyProportion > 1.0f) {
        flGreyProportion = 1.0f;
    }
    if (flGreyProportion <= 0.0f) {
        flGreyProportion = 0.0f;
    }

    // The four colours partition the unit interval as {grey², up to grey, up to grey + remainder,
    // else the fourth}: grey² is colour 0, the next band colour 1, then 2, then 3.
    const float flThreshold0 = flGreyProportion * flGreyProportion;
    const float flThreshold1 = flThreshold0 + (flGreyProportion - flThreshold0);
    const float flThreshold2 = (flGreyProportion - flThreshold0) + flThreshold1;

    for (int nIndex = 0; nIndex < m_nNoteCount; ++nIndex) {
        NoteModel *pNote = FindNoteByIndex(nIndex);
        // A note carrying a locked colour keeps that colour; otherwise it draws a random one from
        // the colour bands. A missing note object still consumes no random draw only when locked.
        if (pNote != nullptr && pNote->IsColorLocked()) {
            pNote->SetColorKind(pNote->GetLockedColor());
            continue;
        }
        const float flRoll = static_cast<float>(rand()) * kInverseRandMax;
        int nColor;
        if (flRoll < flThreshold0) {
            nColor = 0;
        } else if (flRoll < flThreshold1) {
            nColor = 1;
        } else if (flRoll < flThreshold2) {
            nColor = 2;
        } else {
            nColor = 3;
        }
        if (pNote != nullptr) {
            pNote->SetColorKind(nColor);
        }
    }

    // When either player achieved a full combo, force every note on the matching side to colour
    // zero.
    const bool bUserFullCombo = pGameSystem->GetUserFullCombo();
    const bool bCpuFullCombo = pGameSystem->GetCpuFullCombo();
    if (bUserFullCombo || bCpuFullCombo) {
        const int nPlayColor = pGameSystem->GetPlayColor();
        const int nGameType = pGameSystem->GetGameType();
        for (int nIndex = 0; nIndex < m_nNoteCount; ++nIndex) {
            RbffNoteRecord *pRecord = m_pMusicSheet->GetNoteRecordByIndex(nIndex);
            NoteModel *pNote = FindNoteByIndex(nIndex);
            if (pRecord == nullptr || pNote == nullptr) {
                continue;
            }
            if (nGameType != kGameTypeVersusA && nGameType != kGameTypeVersusB) {
                continue;
            }
            const int nSide = pRecord->GetSide();
            if (nPlayColor == nSide && bUserFullCombo) {
                pNote->SetColorKind(kFullComboColor);
            }
            if ((nPlayColor == 0 ? 1 : 0) == nSide && bCpuFullCombo) {
                pNote->SetColorKind(kFullComboColor);
            }
        }
    }

    // The binary then re-tallies the per-colour counts for each side, but discards the totals; the
    // pass is kept only for its record and note lookups.
    for (int nSide = 0; nSide < kSideCount; ++nSide) {
        int aColorCount[kNoteColorCount] = {};
        for (int nIndex = 0; nIndex < m_nNoteCount; ++nIndex) {
            RbffNoteRecord *pRecord = m_pMusicSheet->GetNoteRecordByIndex(nIndex);
            NoteModel *pNote = FindNoteByIndex(nIndex);
            if (pRecord != nullptr && pNote != nullptr && nSide == pRecord->GetSide()) {
                ++aColorCount[pNote->GetColorKind()];
            }
        }
        (void)aColorCount; // The tallies are computed but discarded, matching the binary.
    }
}

/** @ghidraAddress 0x137018 */
NoteModel *NoteEffectMgr::FindNoteByIndex(int nIndex) {
    // A valid in-range index maps straight to its pooled object (when the pool covers it).
    if (nIndex >= 0 && nIndex < m_nNoteCount) {
        if (m_nPoolCapacity <= nIndex) {
            return nullptr;
        }
        return m_ppNotePool[nIndex];
    }
    // Otherwise scan the pool for an object whose note index matches.
    for (int i = 0; i < m_nPoolCapacity; ++i) {
        NoteModel *pNote = m_ppNotePool[i];
        if (pNote != nullptr && pNote->GetNoteIndex() == nIndex) {
            return pNote;
        }
    }
    return nullptr;
}

// The note-state bit that marks a note finished; a note survives compaction while any other bit
// is set.
namespace {
constexpr unsigned int kNoteStateFinishedBit = 0x8;
} // namespace

/** @ghidraAddress 0x136f98 */
void NoteEffectMgr::ActivateNoteByIndex(int nChartIndex) {
    if (m_pMusicSheet == nullptr) {
        return;
    }
    if (m_pMusicSheet->GetNoteRecordByIndex(nChartIndex) == nullptr) {
        return;
    }
    NoteModel *pNote = FindNoteByIndex(nChartIndex);
    // Skip a note that is missing from the pool or already active (its state is non-zero).
    if (pNote == nullptr || pNote->GetState() != 0) {
        return;
    }
    pNote->Init();
    InsertActiveNoteSorted(pNote);
}

/** @ghidraAddress 0x136c50 */
void NoteEffectMgr::ApplyTheme() {
    m_nThema = static_cast<int>([RBUserSettingData sharedInstance].thema);
    m_nShotSoundSlot = GameSystem::GetGameSystem()->GetShotType();
    ShotSoundManager::GetInstance()->LoadSlotVariants(m_nShotSoundSlot);
}

/** @ghidraAddress 0x137124 */
void NoteEffectMgr::ResetAllNoteModels() {
    // Reset every pooled note to its pre-play defaults.
    for (int i = 0; i < m_nPoolCapacity; ++i) {
        NoteModel *pNote = m_ppNotePool[i];
        if (pNote != nullptr) {
            pNote->ResetPlayState();
        }
    }
    // Clear the active list and the running counters.
    for (int i = 0; i < m_nPoolCapacity; ++i) {
        m_ppActiveList[i] = nullptr;
    }
    m_nActiveCount = 0;
    m_nHitCount = 0;
}

/** @ghidraAddress 0x1372b8 */
void NoteEffectMgr::DispatchNoteJudgeEvent(int nPlaySide, unsigned int nPriority) {
    (void)
        nPlaySide; // The binary computes and passes the play side, but the sound manager drops it.
    ShotSoundManager::GetInstance()->SetPendingRetrigger(m_nShotSoundSlot, nPriority);
}

/** @ghidraAddress 0x136f38 */
void NoteEffectMgr::CompactActiveNotes() {
    int nSurvivors = 0;
    for (int i = 0; i < m_nActiveCount; ++i) {
        NoteModel *pNote = m_ppActiveList[i];
        if ((static_cast<unsigned int>(pNote->GetState()) & ~kNoteStateFinishedBit) != 0) {
            // Keep the note, swapping it down to the survivor prefix.
            m_ppActiveList[i] = m_ppActiveList[nSurvivors];
            m_ppActiveList[nSurvivors] = pNote;
            ++nSurvivors;
        }
    }
    m_nActiveCount = nSurvivors;
}

/** @ghidraAddress 0x136ccc */
void NoteEffectMgr::ProcessActiveNotes() {
    // Touch-hit pass: skipped while input is locked (paused).
    if (!GameSystem::GetGameSystem()->GetPaused()) {
        const float flTouchRadiusSq = GameSystem::GetGameSystem()->GetSheetDiameterSq();
        TouchManager *pTouchManager = TouchManager::FetchSharedSingleton();
        for (int nTouch = 0; nTouch < pTouchManager->GetActiveTouchCount(); ++nTouch) {
            TouchPoint *pTouch = pTouchManager->GetActiveTouch(nTouch);
            if (!pTouch->bIsNew) {
                continue;
            }
            const S_VECTOR2 *pPoint = GetOrCacheNotePosition(pTouch->nId);
            if (pPoint == nullptr || m_nActiveCount <= 0) {
                continue;
            }

            // Find the nearest active note this touch hits, within the sheet's touch radius.
            int nNearest = -1;
            float flNearestDistSq = flTouchRadiusSq;
            for (int i = 0; i < m_nActiveCount; ++i) {
                float flDistSq = -1.0f;
                if (m_ppActiveList[i]->CheckTouchHit(pPoint->x, pPoint->y, &flDistSq) &&
                    flDistSq < flNearestDistSq) {
                    nNearest = i;
                    flNearestDistSq = flDistSq;
                }
            }
            if (nNearest != -1) {
                m_ppActiveList[nNearest]->MarkTouched();
            }
        }
    }

    // Advance every active note's state machine, then render them in reverse order.
    if (m_nActiveCount > 0) {
        for (int i = 0; i < m_nActiveCount; ++i) {
            m_ppActiveList[i]->UpdateStep();
        }
        for (int i = m_nActiveCount - 1; i >= 0; --i) {
            m_ppActiveList[i]->RenderNote();
        }
    }

    CompactActiveNotes();
    m_nFrameTouchScratch = 0;
}

/** @ghidraAddress 0x137080 */
void NoteEffectMgr::InsertActiveNoteSorted(NoteModel *pNote) {
    // Append at the tail, then bubble it earlier while its hit time precedes its predecessor's.
    const int nInserted = m_nActiveCount;
    m_ppActiveList[nInserted] = pNote;
    m_nActiveCount = nInserted + 1;
    for (int i = nInserted; i > 0; --i) {
        if (m_ppActiveList[i - 1]->GetHitTime() <= m_ppActiveList[i]->GetHitTime()) {
            break;
        }
        NoteModel *pTmp = m_ppActiveList[i - 1];
        m_ppActiveList[i - 1] = m_ppActiveList[i];
        m_ppActiveList[i] = pTmp;
    }
}

/** @ghidraAddress 0x137a4c */
void NoteEffectMgr::SetActiveMusicSheet(rb::CMusicSheet2 *pMusicSheet) {
    m_pMusicSheet = pMusicSheet;
    if (pMusicSheet == nullptr) {
        ResetAllNoteSubEntries();
        return;
    }
    // Pick the density tier from the chart's note count.
    const int nChartNotes = pMusicSheet->GetChartNoteCount(0);
    if (nChartNotes < kDensityTierThreshold1) {
        m_nDensityTier = 0;
    } else if (nChartNotes < kDensityTierThreshold2) {
        m_nDensityTier = 1;
    } else {
        m_nDensityTier = 2;
    }
    InitNoteObjects();
}

/** @ghidraAddress 0x137664 */
float NoteEffectMgr::EvaluateNotePathAtTime(int nTargetTime) const {
    // The per-millisecond scroll-rate scale (@ghidraAddress 0x308c48 = 1/60000).
    constexpr float kScrollRatePerMs = 1.0f / 60000.0f;

    if (m_pMusicSheet == nullptr) {
        return 0.0f;
    }
    const int nCount = m_pMusicSheet->GetSheetPathNodeCount();
    if (nCount == 0) {
        return 0.0f;
    }

    // Each path node stores its speed as a float in the value slot (read raw, not converted) and
    // its time in the following int slot.
    const auto nodeSpeed = [this](int nIndex) {
        float flSpeed;
        const int nRaw = m_pMusicSheet->GetSheetPathNode(nIndex)->x;
        std::memcpy(&flSpeed, &nRaw, sizeof(flSpeed));
        return flSpeed;
    };

    float flSpeed = nodeSpeed(0);
    float flPosition = 0.0f;
    int nRemaining = nTargetTime;
    for (int nIndex = 1; nIndex < nCount; ++nIndex) {
        const int nNodeTime = m_pMusicSheet->GetSheetPathNode(nIndex)->y;
        if (nNodeTime >= nTargetTime) {
            break;
        }
        // Integrate the segment from the previous node to this one at the current speed.
        const float flSegment =
            static_cast<float>(nNodeTime - m_pMusicSheet->GetSheetPathNode(nIndex - 1)->y);
        flPosition += flSpeed * flSegment * kScrollRatePerMs;
        nRemaining = static_cast<int>(static_cast<float>(nRemaining) - flSegment);
        flSpeed = nodeSpeed(nIndex);
    }
    // Add the partial final segment up to the target time.
    return flPosition + static_cast<float>(nRemaining) * flSpeed * kScrollRatePerMs;
}

/** @ghidraAddress 0x1379cc */
void NoteEffectMgr::ResetAllNoteSubEntries() {
    // Detach every pooled note from its chart binding.
    for (int i = 0; i < m_nPoolCapacity; ++i) {
        NoteModel *pNote = m_ppNotePool[i];
        if (pNote != nullptr) {
            pNote->ResetBinding();
        }
    }
    m_nNoteCount = 0;
    // Clear the active list and reset the active count.
    for (int i = 0; i < m_nPoolCapacity; ++i) {
        m_ppActiveList[i] = nullptr;
    }
    m_nActiveCount = 0;
}

/** @ghidraAddress 0x137934 */
void NoteEffectMgr::InitNoteObjects() {
    if (m_pMusicSheet == nullptr) {
        return;
    }
    const int nCount = m_pMusicSheet->GetNoteCount();
    EnsureNoteObjectCapacity(nCount);
    m_nNoteCount = nCount;
    // Bind each chart note to its pooled object.
    for (int i = 0; i < nCount; ++i) {
        NoteModel *pNote = FindNoteByIndex(i);
        if (pNote != nullptr) {
            pNote->SetNoteIndex(i);
        }
    }
    // Clear the active list and reset the active count.
    for (int i = 0; i < m_nPoolCapacity; ++i) {
        m_ppActiveList[i] = nullptr;
    }
    m_nActiveCount = 0;
}

/** @ghidraAddress 0x1371a4 */
void NoteEffectMgr::EnsureNoteObjectCapacity(int nCount) {
    if (m_nPoolCapacity >= nCount) {
        return;
    }
    // Grow both arrays; the active list is reallocated but left for InitNoteObjects to populate.
    auto **ppNewPool = new NoteModel *[nCount];
    auto **ppNewActive = new NoteModel *[nCount];
    // Carry the existing pooled objects across, then construct a fresh note for each added slot.
    int i = 0;
    for (; i < m_nPoolCapacity; ++i) {
        ppNewPool[i] = m_ppNotePool[i];
    }
    for (; i < nCount; ++i) {
        ppNewPool[i] = new NoteModel(this);
    }
    delete[] m_ppNotePool;
    delete[] m_ppActiveList;
    m_ppNotePool = ppNewPool;
    m_nPoolCapacity = nCount;
    m_ppActiveList = ppNewActive;
}

/** @ghidraAddress 0x136b9c */
NoteEffectMgr *NoteEffectMgr::shared() {
    if (g_pNoteEffectMgr == nullptr) {
        // The binary allocates the raw 0x168-byte object and runs the constructor.
        g_pNoteEffectMgr = new NoteEffectMgr();
    }
    return g_pNoteEffectMgr;
}
