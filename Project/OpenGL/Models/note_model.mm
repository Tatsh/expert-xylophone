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

// The note lane-position table (@ghidraAddress 0x3de000), seeded once by InitNoteLaneTable and read
// by GetNoteLaneFraction. It holds the six across-field lane fractions (symmetric about the centre),
// a lane spread span, and the two wide-lane fractions for the alternate lane kind. The leading span
// is unused padding preceding the seeded fields.
NoteLaneTable g_noteLaneTable = {}; // @ghidraAddress 0x3de000

namespace {

// The band fractions of the play-field edge, indexed by band, and the count of bands. Band 4 is the
// centre line and produces no offset; bands 0 through 3 sit above it and 5 through 8 below.
constexpr float kBandFractions[] = {0.38f, 0.30f, 0.20f, 0.10f, 0.0f, 0.10f, 0.20f, 0.30f, 0.38f};
constexpr int kBandCount = 9;
constexpr int kCenterBand = 4;

// The alternate lane kind whose two wide lanes use the wide-lane fractions, and its two lane indices.
constexpr int kWideLaneKind = 1;
constexpr int kWideLaneLeft = 1;
constexpr int kWideLaneRight = 2;

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

/** @ghidraAddress 0x133a24 */
int NoteModel::GetSide() const {
    if (m_pRecord != nullptr) {
        return m_pRecord->nSide;
    }
    // A synthetic note reports side 0 when its own-side flag is set, else the no-side sentinel.
    return m_bOwnSide ? 0 : kNoSideSentinel;
}

/** @ghidraAddress 0x1336c0 */
int NoteModel::GetType() const {
    if (m_pRecord != nullptr) {
        return m_pRecord->nType;
    }
    // A synthetic note reports type 0 when its own-side flag is set, else the idle-kind sentinel.
    return m_bOwnSide ? 0 : kIdleTypeSentinel;
}

/** @ghidraAddress 0x1352b8 */
float NoteModel::GetLaneX() const {
    int nKind;
    int nLane;
    if (m_pRecord != nullptr) {
        nKind = m_pRecord->nHoldKind;
        nLane = m_pRecord->nDisplayLane;
    } else {
        // A synthetic note (no record) derives its kind and lane from the own-side flag.
        nKind = m_bOwnSide ? 0 : kNoSideSentinel;
        nLane = m_bOwnSide ? -1 : kNoSideSentinel;
    }
    return GetNoteLaneFraction(nKind, nLane) * GameSystem::GetGameSystem()->GetSheetInsetHalfX();
}

/** @ghidraAddress 0x136afc */
void InitNoteLaneTable() {
    // The six across-field lane fractions are symmetric about the centre lane (which is zero).
    g_noteLaneTable.flLaneSpread = 288.0f;
    g_noteLaneTable.flWideLaneLeft = -0.888889f;
    g_noteLaneTable.flWideLaneRight = 0.888889f;
    g_noteLaneTable.flLaneFrac0 = -0.777778f;
    g_noteLaneTable.flLaneFrac1 = -0.518519f;
    g_noteLaneTable.flLaneFrac2 = -0.259259f;
    g_noteLaneTable.flLaneFrac4 = 0.259259f;
    g_noteLaneTable.flLaneFrac5 = -g_noteLaneTable.flLaneFrac1;
    g_noteLaneTable.flLaneFrac6 = -g_noteLaneTable.flLaneFrac0;
}

/** @ghidraAddress 0x136a38 */
float GetNoteLaneFraction(int nKind, int nLane) {
    // The alternate wide-lane kind places only its two wide lanes; every other lane is centred.
    if (nKind == kWideLaneKind) {
        if (nLane == kWideLaneLeft) {
            return 0.0f;
        }
        if (nLane == kWideLaneRight) {
            return g_noteLaneTable.flWideLaneRight;
        }
        return 0.0f;
    }

    // The ordinary kind maps each lane to its across-field fraction; the centre and any out-of-range
    // lane are zero.
    switch (nLane) {
    case 0:
        return g_noteLaneTable.flLaneFrac0;
    case 1:
        return g_noteLaneTable.flLaneFrac1;
    case 2:
        return g_noteLaneTable.flLaneFrac2;
    case 4:
        return g_noteLaneTable.flLaneFrac4;
    case 5:
        return g_noteLaneTable.flLaneFrac5;
    case 6:
        return g_noteLaneTable.flLaneFrac6;
    default:
        return 0.0f;
    }
}

/** @ghidraAddress 0x1360a8 */
float NoteModel::GetVirtualBoundY(int nBand) {
    assert(nBand >= 0 && nBand < kBandCount);
    if (nBand == kCenterBand) {
        return 0.0f;
    }
    // Bands above the centre take the top edge, bands below take the bottom edge.
    const float flEdge = nBand < kCenterBand ? g_flPlayfieldBoundTop : g_flPlayfieldBoundBottom;
    return (flEdge * kBandFractions[nBand]) + (flEdge * kBandFractions[nBand]);
}
