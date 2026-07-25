/**
 * @file
 * The per-touch slot record, @c TouchPoint, tracked by @c TouchManager.
 */

#pragma once

/**
 * One tracked touch inside the @c TouchManager slot array. The 32-bit offset comments are
 * documentation only; the 64-bit build goes through the named fields.
 * @ghidraAddress TouchPoint (engine touch-slot struct)
 */
struct TouchPoint {
    int m_nId = {};         // +0x00 rolling touch id (-1 in a fresh slot)
    int m_nBeginX = {};     // +0x04 x at begin
    int m_nBeginY = {};     // +0x08 y at begin
    int m_nCurrentX = {};   // +0x0c live x (the position UpdateTouchPoint/HandleTouchMoved match)
    int m_nCurrentY = {};   // +0x10 live y
    int m_nPreviousX = {};  // +0x14 previous x (saved before an update)
    int m_nPreviousY = {};  // +0x18 previous y
    int m_nCommittedX = {}; // +0x1c frame-committed x (CompactTouchList copies the live x here)
    int m_nCommittedY = {}; // +0x20 frame-committed y
    int m_nKey1 = {};       // +0x24 owning-view key pair (the view frame width at begin)
    int m_nKey2 = {};       // +0x28 owning-view key pair (the view frame height at begin)
    bool m_bIsNew = {};     // +0x2c added this frame; cleared once CompactTouchList commits it
    bool m_bEnded = {};     // +0x2d slated for removal on the next CompactTouchList pass
    bool m_bEndedPending = {}; // +0x2e ended while still new; promoted to m_bEnded on next commit
    // unsigned char m_aPad2f[1] = {}; // +0x2f trailing pad to the 0x30-byte slot size
};

// code: language=C++
// kate: hl C++;
// vim: set ft=cpp :
