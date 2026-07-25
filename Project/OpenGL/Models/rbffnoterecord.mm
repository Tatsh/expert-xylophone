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
    chainLink.InitEmpty();
    nLane = kDefaultLane;
    nLaneSlot = kDefaultLaneSlot;
    nColorTone = kLinkNone;
    nDisplayLane = kLinkNone;
    nColorIndex = kLinkNone;
    nColor = kLinkNone;
    nTimingSel = kTimingSelNone;
    nChosenTarget = kLinkNone;
    // Every other field is left at its zero default (the binary explicitly zeroes them).
}
