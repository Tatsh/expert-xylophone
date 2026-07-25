/**
 * @file
 * The per-touch slot record, @c TouchPoint, tracked by @c TouchManager.
 */

#pragma once

/**
 * One tracked touch inside the @c TouchManager slot array. It is a plain data record: @c TouchManager
 * fills it in and callers that resolve a slot (through @c TouchManager::FindTouchById) read its
 * position and phase fields directly. The 32-bit offset comments are documentation only; the 64-bit
 * build goes through the named fields.
 * @ghidraAddress TouchPoint (engine touch-slot struct)
 */
struct TouchPoint {
    int nId = {};            // +0x00 rolling touch id (-1 in a fresh slot)
    int nBeginX = {};        // +0x04 x at begin
    int nBeginY = {};        // +0x08 y at begin
    int nCurrentX = {};      // +0x0c live x (the position UpdateTouchPoint/HandleTouchMoved match)
    int nCurrentY = {};      // +0x10 live y
    int nPreviousX = {};     // +0x14 previous x (saved before an update)
    int nPreviousY = {};     // +0x18 previous y
    int nCommittedX = {};    // +0x1c frame-committed x (CompactTouchList copies the live x here)
    int nCommittedY = {};    // +0x20 frame-committed y
    int nKey1 = {};          // +0x24 owning-view key pair (the view frame width at begin)
    int nKey2 = {};          // +0x28 owning-view key pair (the view frame height at begin)
    bool bIsNew = {};        // +0x2c added this frame; cleared once CompactTouchList commits it
    bool bEnded = {};        // +0x2d slated for removal on the next CompactTouchList pass
    bool bEndedPending = {}; // +0x2e ended while still new; promoted to bEnded on next commit
    // unsigned char aPad2f[1] = {}; // +0x2f trailing pad to the 0x30-byte slot size
};

// code: language=C++
// kate: hl C++;
// vim: set ft=cpp :
