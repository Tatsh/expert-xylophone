/**
 * @file
 * The engine touch tracker, @c TouchManager, and its per-touch slot, @c TouchPoint.
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

/**
 * The global touch manager. The application obtains it through @c FetchSharedSingleton and commits
 * each frame through @c CompactTouchList. The Objective-C GL view feeds it raw touch phases through
 * @c AddTouchPoint, @c UpdateTouchPoint, @c HandleTouchMoved, and @c MarkAllTouchesEnded.
 * @ghidraAddress TouchManager (engine class, slot array at +0x0, count at +0x100)
 */
class TouchManager {
public:
    /** @brief The fixed number of pre-allocated touch slots the manager tracks. */
    static constexpr int kSlotCount = 32;

    /**
     * @brief Constructs the manager with an empty active list and @c kSlotCount pre-allocated
     * touch slots.
     * @ghidraAddress 0x17c90
     */
    TouchManager();
    /**
     * @brief Returns the global touch-manager singleton, or @c nullptr when not yet created.
     * @ghidraAddress 0x17c38
     */
    static TouchManager *FetchSharedSingleton();
    /**
     * @brief Registers a new touch in the next free slot, assigning it the next rolling id and the
     *        owning view's key pair.
     * @param nX The touch x in view coordinates.
     * @param nY The touch y in view coordinates.
     * @param nKey1 The owning-view key (its frame width at begin).
     * @param nKey2 The owning-view key (its frame height at begin).
     * @ghidraAddress 0x17dbc
     */
    void AddTouchPoint(int nX, int nY, int nKey1, int nKey2);
    /**
     * @brief Advances the tracked touch whose current position matches (@p nKey1, @p nKey2) to the
     *        new position, saving the old position as the previous one.
     * @param nX The new touch x.
     * @param nY The new touch y.
     * @param nKey1 The previous x used to locate the slot.
     * @param nKey2 The previous y used to locate the slot.
     * @ghidraAddress 0x17e10
     */
    void UpdateTouchPoint(int nX, int nY, int nKey1, int nKey2);
    /**
     * @brief Marks the tracked touch at (@p nOldX, @p nOldY) as moved to (@p nNewX, @p nNewY),
     *        preferring an exact old-position match and falling back to the new position.
     * @param nNewX The new touch x.
     * @param nNewY The new touch y.
     * @param nOldX The previous touch x to match.
     * @param nOldY The previous touch y to match.
     * @ghidraAddress 0x17e5c
     */
    void HandleTouchMoved(int nNewX, int nNewY, int nOldX, int nOldY);
    /**
     * @brief Marks every tracked touch as moved/ended for this frame (used when all touches end or
     *        cancel at once).
     * @ghidraAddress 0x17f14
     */
    void MarkAllTouchesEnded();
    /**
     * @brief Commits the current touch frame and swap-removes the touches that have ended.
     * @ghidraAddress 0x17f50
     */
    void CompactTouchList();

private:
    TouchPoint *m_apSlots[kSlotCount] = {}; // +0x00 the slot pointer array (active slots first)
    int m_nActiveCount = {};                // +0x100 number of active slots at the array head
    int m_nNextId = {};                     // +0x104 the next rolling id to assign
};

/** @brief The global touch-manager singleton, constructed by @c EnsureTouchManagerSingleton. */
extern TouchManager *g_pTouchManager;

// code: language=C++
// kate: hl C++;
// vim: set ft=cpp :
