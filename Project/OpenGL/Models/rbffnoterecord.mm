//
//  rbffnoterecord.mm
//  REFLEC BEAT plus
//
//  The parsed chart note record's constructor. Reconstructed from Ghidra project rb458, program
//  rb458. @ghidraAddress values are relative to the program image base.
//

#include "rbffnoterecord.h"

// The default field seeds a fresh record carries before the chart parser fills it in.
namespace {
// The lane and lane-slot default (mode 3 = none), the timing-selector sentinel, and the empty-link
// and empty-colour sentinels.
constexpr int kDefaultLane = 3;
constexpr int kDefaultLaneSlot = 3;
constexpr int kTimingSelNone = -2;
constexpr int kLinkNone = -1;
} // namespace

/** @ghidraAddress 0x12f780 */
RbffNoteRecord::RbffNoteRecord() {
    m_chainLink.InitEmpty();
    m_nLane = kDefaultLane;
    m_nLaneSlot = kDefaultLaneSlot;
    m_nColorTone = kLinkNone;
    m_nDisplayLane = kLinkNone;
    m_nColorIndex = kLinkNone;
    m_nColor = kLinkNone;
    m_nTimingSel = kTimingSelNone;
    m_nChosenTarget = kLinkNone;
    // Every other field is left at its zero default (the binary explicitly zeroes them).
}
