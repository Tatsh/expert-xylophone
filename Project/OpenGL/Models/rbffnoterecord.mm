#include "rbffnoterecord.h"

namespace {
constexpr int kDefaultLane = 3;
constexpr int kDefaultLaneSlot = 3;
constexpr int kTimingSelNone = -2;
constexpr int kLinkNone = -1;
} // namespace

/** @ghidraAddress 0x12f780 */
RbffNoteRecord::RbffNoteRecord() {
    m_nLane = kDefaultLane;
    m_nLaneSlot = kDefaultLaneSlot;
    m_nColorTone = kLinkNone;
    m_nDisplayLane = kLinkNone;
    m_nColorIndex = kLinkNone;
    m_nColor = kLinkNone;
    m_nTimingSel = kTimingSelNone;
    m_nChosenTarget = kLinkNone;
}
