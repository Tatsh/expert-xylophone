/**
 * @file
 * The per-touch slot record, @c TouchPoint, tracked by @c TouchManager.
 */

#pragma once

/**
 * One tracked touch inside the @c TouchManager slot array.
 *
 * It is a plain data record: @c TouchManager fills it in and callers that resolve a slot (through
 * @c TouchManager::FindTouchById) read its position and phase fields directly. The 32-bit offset
 * comments are documentation only; the 64-bit build goes through the named fields.
 * Reconstructed type @c TouchPoint: engine touch-slot struct.
 */
struct TouchPoint {
    int nId = {};     /*!< The rolling touch id, -1 in a fresh slot. +0x00 */
    int nBeginX = {}; /*!< The x coordinate at begin. +0x04 */
    int nBeginY = {}; /*!< The y coordinate at begin. +0x08 */
    /** The live x, the position UpdateTouchPoint and HandleTouchMoved match on. +0x0c */
    int nCurrentX = {};
    int nCurrentY = {};  /*!< The live y. +0x10 */
    int nPreviousX = {}; /*!< The previous x, saved before an update. +0x14 */
    int nPreviousY = {}; /*!< The previous y. +0x18 */
    /** The frame-committed x; CompactTouchList copies the live x here. +0x1c */
    int nCommittedX = {};
    int nCommittedY = {}; /*!< The frame-committed y. +0x20 */
    int nKey1 = {};       /*!< The owning-view key pair: the view frame width at begin. +0x24 */
    int nKey2 = {};       /*!< The owning-view key pair: the view frame height at begin. +0x28 */
    /** Added this frame; cleared once CompactTouchList commits the slot. +0x2c */
    bool bIsNew = {};
    bool bEnded = {};        /*!< Whether the slot is slated for removal on the next
                                  CompactTouchList pass. +0x2d */
    bool bEndedPending = {}; /*!< Whether the touch ended while still new; promoted to @c bEnded on
                                  the next commit. +0x2e */
    // unsigned char aPad2f[1] = {}; // +0x2f trailing pad to the 0x30-byte slot size
};
