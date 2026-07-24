//
//  note_model.mm
//  REFLEC BEAT plus
//
//  A live play-field note (NoteModel). Reconstructed from Ghidra project rb458, program rb458.
//  @ghidraAddress values are relative to the program image base.
//

#include "note_model.h"

#include "gamesystem.h"
#include "rbffnoterecord.h"

/** @ghidraAddress 0x135e84 */
int NoteModel::IsSideFlipped() const {
    int nSide;
    if (m_pRecord == nullptr) {
        // A synthetic note (no chart record) mirrors by its own side flag; an unset flag is the
        // no-side sentinel.
        if (!m_bOwnSide) {
            return kNoSideSentinel;
        }
        nSide = 0;
    } else {
        nSide = m_pRecord->nSide;
        // A record side outside the two play sides falls back to the own-side flag.
        if (nSide > 1) {
            return m_bOwnSide ? 0 : kNoSideSentinel;
        }
    }
    // The note is flipped when its side differs from the current play side.
    return GameSystem::GetGameSystem()->GetPlayColor() != nSide;
}
