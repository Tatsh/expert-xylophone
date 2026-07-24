//
//  note_model.mm
//  REFLEC BEAT plus
//
//  A live play-field note (NoteModel). Reconstructed from Ghidra project rb458, program rb458.
//  @ghidraAddress values are relative to the program image base.
//

#include "note_model.h"

#include <cassert>

#include "engineglobals.h"
#include "gamesystem.h"
#include "rbffnoterecord.h"

// The play-field edge bounds, seeded by the play-field layout pass (ComputePlayfieldLayoutY) and
// read here and by the effect layers.
float g_flPlayfieldBoundTop = {};    // @ghidraAddress 0x3ce95c
float g_flPlayfieldBoundBottom = {}; // @ghidraAddress 0x3ce960

namespace {

// The band fractions of the play-field edge, indexed by band, and the count of bands. Band 4 is the
// centre line and produces no offset; bands 0 through 3 sit above it and 5 through 8 below.
constexpr float kBandFractions[] = {0.38f, 0.30f, 0.20f, 0.10f, 0.0f, 0.10f, 0.20f, 0.30f, 0.38f};
constexpr int kBandCount = 9;
constexpr int kCentreBand = 4;

} // namespace

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

/** @ghidraAddress 0x1360a8 */
float NoteModel::GetVirtualBoundY(int nBand) {
    assert(nBand >= 0 && nBand < kBandCount);
    if (nBand == kCentreBand) {
        return 0.0f;
    }
    // Bands above the centre take the top edge, bands below take the bottom edge.
    const float flEdge = nBand < kCentreBand ? g_flPlayfieldBoundTop : g_flPlayfieldBoundBottom;
    return (flEdge * kBandFractions[nBand]) + (flEdge * kBandFractions[nBand]);
}
