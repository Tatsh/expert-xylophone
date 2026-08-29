#include "note_replay.h"

#import "AppDelegate.h"
#import "MusicData.h"
#import "ReplayData.h"
#import "ReplayNote.h"
#include "gamesystem.h"
#include "note_effect_mgr.h"
#include "note_model.h"

namespace {
constexpr int kReplayTypeSlide = 3;
constexpr int kReplayJudgeSkip = 5;
constexpr int kNoteKindTap = 0;

void ApplyReplayForSide(ReplayData *pReplay, int nGhostSide) {
    NoteEffectMgr *pMgr = NoteEffectMgr::shared();
    int nLiveIndex = 0;
    int nPendingJustReflec = 0;
    const NSUInteger nReplayCount = pReplay.replay.count;

    for (NSUInteger nReplayIndex = 0; nReplayIndex < nReplayCount; ++nReplayIndex) {
        ReplayNote *pEvent = pReplay.replay[nReplayIndex];

        // A skipped just-reflec entry is deferred to back-fill a later unmatched tap head.
        if (pEvent.type.intValue != kReplayTypeSlide && pEvent.judge.intValue == kReplayJudgeSkip &&
            pEvent.jr.boolValue) {
            ++nPendingJustReflec;
            continue;
        }

        while (nLiveIndex < pMgr->GetNoteCount()) {
            NoteModel *pNote = pMgr->FindNoteByIndex(nLiveIndex);
            if (pNote->GetSide() == nGhostSide) {
                break;
            }
            if (nPendingJustReflec > 0 && pNote->GetStartTime() != -1 &&
                pNote->GetKind() == kNoteKindTap) {
                NoteModel *pHead = pMgr->FindNoteByIndex(pNote->GetStartTime());
                if (pHead->GetRecordedJudge() == 0) {
                    pNote->SetReplayResult(kReplayJudgeSkip, true, 0.0f);
                    --nPendingJustReflec;
                }
            }
            ++nLiveIndex;
        }
        if (nLiveIndex >= pMgr->GetNoteCount()) {
            break;
        }

        NoteModel *pNote = pMgr->FindNoteByIndex(nLiveIndex);
        pNote->SetReplayResult(
            pEvent.judge.intValue, pEvent.jr.boolValue, pEvent.longrate.floatValue);

        if (pNote->GetType() == kReplayTypeSlide && pEvent.type.intValue == kReplayTypeSlide) {
            const NSUInteger nSlideCount = pEvent.slide.count;
            for (NSUInteger nSlide = 0; nSlide < nSlideCount; ++nSlide) {
                pNote->SetSlideReplayJudge(static_cast<int>(nSlide),
                                           pEvent.slide[nSlide].judge.intValue);
            }
        }
        ++nLiveIndex;
    }
}
} // namespace

/** @ghidraAddress 0x14fd30 */
void ApplyReplayGhostToNotes() {
    AppDelegate *pAppDelegate = [AppDelegate appDelegate];
    if (pAppDelegate.musicData == nil) {
        [AppDelegate appDelegate].replayData = nil;
        return;
    }
    if (NoteEffectMgr::shared()->GetNoteCount() == 0) {
        return;
    }

    GameSystem *pGameSystem = GameSystem::GetGameSystem();
    MusicData *pMusicData = [AppDelegate appDelegate].musicData;
    ReplayData *pReplay = [ReplayData loadReplayData:pMusicData.MusicID
                                          difficulty:pGameSystem->GetDifficulty()];
    if (pReplay == nil) {
        return;
    }
    [AppDelegate appDelegate].replayData = pReplay;

    const int nPlayColor = pGameSystem->GetPlayColor();
    const int nFirstSide = NoteEffectMgr::shared()->FindNoteByIndex(0)->GetSide();
    const int nGhostSide = nFirstSide == nPlayColor ? nPlayColor : (nPlayColor == 0 ? 1 : 0);
    ApplyReplayForSide(pReplay, nGhostSide);
}
