//
//  note_replay.mm
//  REFLEC BEAT plus
//
//  The replay/ghost application helper for the note play field. Reconstructed from Ghidra project
//  rb458, program rb458. @ghidraAddress values are relative to the program image base.
//

#include "note_replay.h"

#import "AppDelegate.h"
#import "MusicData.h"
#import "ReplayData.h"
#import "ReplayNote.h"
#include "gamesystem.h"
#include "note_effect_mgr.h"
#include "note_model.h"

namespace {
// The replay note type marking a slide note (its per-point judges are copied too).
constexpr int kReplayTypeSlide = 3;
// The recorded judge value marking a skipped-but-just-reflec entry.
constexpr int kReplayJudgeSkip = 5;
// The note kind a back-filled just-reflec miss applies to.
constexpr int kNoteKindTap = 0;

// Applies the replay to the live notes for one ghost side. Walks the replay array in lockstep with
// the live note list: matching-side notes take the recorded judge, JR flag, long rate, and (for
// slide notes) each sub-point judge; a skipped just-reflec entry back-fills an unmatched tap head as
// a just-reflec miss.
void ApplyReplayForSide(ReplayData *pReplay, unsigned int nGhostSide) {
    NoteEffectMgr *pMgr = NoteEffectMgr::shared();
    int nLiveIndex = 0;
    int nPendingJustReflec = 0;
    const NSUInteger nReplayCount = pReplay.replay.count;

    for (NSUInteger nReplayIndex = 0; nReplayIndex < nReplayCount; ++nReplayIndex) {
        ReplayNote *pEvent = pReplay.replay[nReplayIndex];

        // A skipped just-reflec entry (non-slide, judge 5 with the JR flag) is deferred to back-fill
        // a later unmatched tap head.
        if (pEvent.type.intValue != kReplayTypeSlide && pEvent.judge.intValue == kReplayJudgeSkip &&
            pEvent.jr.boolValue) {
            ++nPendingJustReflec;
            continue;
        }

        // Advance the live note list to the next note on the ghost side, back-filling pending
        // just-reflec misses onto skipped tap heads along the way.
        while (nLiveIndex < pMgr->GetNoteCount()) {
            NoteModel *pNote = pMgr->FindNoteByIndex(nLiveIndex);
            if (pNote->GetSide() == nGhostSide) {
                break;
            }
            // A pending just-reflec back-fills a not-yet-judged tap head, then is consumed.
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

        // Stamp the matching live note with the recorded result.
        NoteModel *pNote = pMgr->FindNoteByIndex(nLiveIndex);
        pNote->SetReplayResult(
            pEvent.judge.intValue, pEvent.jr.boolValue, pEvent.longrate.floatValue);

        // A slide note copies each of its sub-point judges.
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
    // With no selected music, clear any stale replay and stop.
    if (pAppDelegate.musicData == nil) {
        [AppDelegate appDelegate].replayData = nil;
        return;
    }
    // With no notes loaded, there is nothing to stamp.
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

    // The ghost side is the human player's side when the first note matches it, otherwise the
    // opposite side.
    const int nPlayColor = pGameSystem->GetPlayColor();
    const int nFirstSide = NoteEffectMgr::shared()->FindNoteByIndex(0)->GetSide();
    const unsigned int nGhostSide =
        nFirstSide == nPlayColor ? nPlayColor : static_cast<unsigned int>(nPlayColor == 0 ? 1 : 0);
    ApplyReplayForSide(pReplay, nGhostSide);
}
