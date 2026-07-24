//
//  neTouchManager.cpp
//  REFLEC BEAT plus
//
//  Reconstructed from Ghidra project rb458, program rb458. The touch-input tracking manager the
//  engine reads each frame; the Objective-C GL view (neGLView) feeds it raw UIKit touch phases and
//  the render loop commits a frame through CompactTouchList. The class has no embedded __FILE__
//  path (its methods are tiny leaves), so this pure-C++ engine file sits at the GameSystem source
//  root. The initialiser's slot layout was recovered from the arm64 disassembly (the decompiler
//  renders its NEON stores as folded vector temporaries).
//

#include <new>

#include "engineruntime.h"
#include "gamesystem.h"
#include "touchmanager.h"

// The sentinel each fresh slot's position fields hold until a touch is registered: the bit pattern
// 0x80000000, i.e. INT_MIN, which is also the representation of -0.0f the binary stores through its
// NEON immediates.
static constexpr int kUninitialisedCoord = static_cast<int>(0x80000000);
// The sentinel each fresh slot's key pair holds: INT_MAX (0x7fffffff).
static constexpr int kUninitialisedKey = 0x7fffffff;
// The id stamped into a free (never-used) slot.
static constexpr int kFreeSlotId = -1;
// The largest rolling id before it wraps back to zero.
static constexpr int kMaxTouchId = 0x7fffffff;

/** @brief The global touch-manager singleton, constructed by @c EnsureTouchManagerSingleton. */
TouchManager *g_pTouchManager = nullptr;

/** @ghidraAddress 0x17c90 */
TouchManager::TouchManager() {
    m_nActiveCount = 0;
    m_nNextId = 0;
    // Pre-allocate every slot once; the active list is a prefix of this pointer array and slots are
    // recycled by CompactTouchList's swap-remove rather than freed.
    for (int i = 0; i < kSlotCount; ++i) {
        auto *pSlot = new TouchPoint;
        pSlot->m_nId = kFreeSlotId;
        pSlot->m_nBeginX = kUninitialisedCoord;
        pSlot->m_nBeginY = kUninitialisedCoord;
        pSlot->m_nCurrentX = kUninitialisedCoord;
        pSlot->m_nCurrentY = kUninitialisedCoord;
        pSlot->m_nPreviousX = kUninitialisedCoord;
        pSlot->m_nPreviousY = kUninitialisedCoord;
        pSlot->m_nCommittedX = kUninitialisedCoord;
        pSlot->m_nCommittedY = kUninitialisedCoord;
        pSlot->m_nKey1 = kUninitialisedKey;
        pSlot->m_nKey2 = kUninitialisedKey;
        pSlot->m_bIsNew = true;
        pSlot->m_bEnded = false;
        pSlot->m_bEndedPending = false;
        m_apSlots[i] = pSlot;
    }
}

/** @ghidraAddress 0x17c38 */
TouchManager *TouchManager::FetchSharedSingleton() {
    return g_pTouchManager;
}

/** @ghidraAddress 0x17dbc */
void TouchManager::AddTouchPoint(int nX, int nY, int nKey1, int nKey2) {
    // Claim the slot just past the active prefix and give it the next rolling id.
    TouchPoint *pSlot = m_apSlots[m_nActiveCount];
    pSlot->m_nId = m_nNextId;
    pSlot->m_nBeginX = nX;
    pSlot->m_nBeginY = nY;
    pSlot->m_nCurrentX = nX;
    pSlot->m_nCurrentY = nY;
    pSlot->m_nPreviousX = nX;
    pSlot->m_nPreviousY = nY;
    pSlot->m_nCommittedX = nX;
    pSlot->m_nCommittedY = nY;
    pSlot->m_nKey1 = nKey1;
    pSlot->m_nKey2 = nKey2;
    pSlot->m_bIsNew = true;
    pSlot->m_bEnded = false;
    pSlot->m_bEndedPending = false;
    m_nNextId = m_nNextId == kMaxTouchId ? 0 : m_nNextId + 1;
    ++m_nActiveCount;
}

/** @ghidraAddress 0x17e10 */
void TouchManager::UpdateTouchPoint(int nX, int nY, int nKey1, int nKey2) {
    // Locate the active slot whose live position equals the given key (the touch's previous point)
    // and advance it, saving the old position as the previous one.
    for (int i = 0; i < m_nActiveCount; ++i) {
        TouchPoint *pSlot = m_apSlots[i];
        if (pSlot->m_nCurrentX == nKey1 && pSlot->m_nCurrentY == nKey2) {
            pSlot->m_nPreviousX = pSlot->m_nCurrentX;
            pSlot->m_nPreviousY = pSlot->m_nCurrentY;
            pSlot->m_nCurrentX = nX;
            pSlot->m_nCurrentY = nY;
            return;
        }
    }
}

/** @ghidraAddress 0x17e5c */
void TouchManager::HandleTouchMoved(int nNewX, int nNewY, int nOldX, int nOldY) {
    // Prefer a not-yet-ended slot whose live position matches the old point; fall back to one that
    // already sits at the new point. On a match, save the previous position, move to the new point,
    // and raise the moved flag (m_bIsNew slots use m_bEnded, older ones m_bEndedPending).
    TouchPoint *pMatch = nullptr;
    for (int i = 0; i < m_nActiveCount; ++i) {
        TouchPoint *pSlot = m_apSlots[i];
        if (!pSlot->m_bEnded && pSlot->m_nCurrentX == nOldX && pSlot->m_nCurrentY == nOldY) {
            pMatch = pSlot;
            break;
        }
    }
    if (pMatch == nullptr) {
        for (int i = 0; i < m_nActiveCount; ++i) {
            TouchPoint *pSlot = m_apSlots[i];
            if (!pSlot->m_bEnded && pSlot->m_nCurrentX == nNewX && pSlot->m_nCurrentY == nNewY) {
                pMatch = pSlot;
                break;
            }
        }
    }
    if (pMatch == nullptr) {
        return;
    }
    pMatch->m_nPreviousX = pMatch->m_nCurrentX;
    pMatch->m_nPreviousY = pMatch->m_nCurrentY;
    pMatch->m_nCurrentX = nNewX;
    pMatch->m_nCurrentY = nNewY;
    if (!pMatch->m_bIsNew) {
        pMatch->m_bEnded = true;
    } else {
        pMatch->m_bEndedPending = true;
    }
}

/** @ghidraAddress 0x17f14 */
void TouchManager::MarkAllTouchesEnded() {
    // Flag every active slot as moved/ended for this frame, unconditionally.
    for (int i = 0; i < m_nActiveCount; ++i) {
        TouchPoint *pSlot = m_apSlots[i];
        if (!pSlot->m_bIsNew) {
            pSlot->m_bEnded = true;
        } else {
            pSlot->m_bEndedPending = true;
        }
    }
}

/** @ghidraAddress 0x17f50 */
void TouchManager::CompactTouchList() {
    int count = m_nActiveCount;
    int i = 0;
    while (i < count) {
        TouchPoint *pSlot = m_apSlots[i];
        if (!pSlot->m_bEnded) {
            // Still live: commit the current position and promote a pending end to a real one.
            pSlot->m_bIsNew = false;
            pSlot->m_nCommittedX = pSlot->m_nCurrentX;
            pSlot->m_nCommittedY = pSlot->m_nCurrentY;
            if (pSlot->m_bEndedPending) {
                pSlot->m_bEnded = true;
            }
            ++i;
        } else {
            // Ended: swap the last active slot into this index and park the freed slot at the tail
            // for reuse, without advancing i so the swapped-in slot is re-examined.
            --count;
            if (i != count) {
                m_apSlots[i] = m_apSlots[count];
                m_apSlots[m_nActiveCount - 1] = pSlot;
                count = m_nActiveCount - 1;
            }
            m_nActiveCount = count;
        }
    }
}

/** @ghidraAddress 0x17c44 */
void EnsureTouchManagerSingleton(void) {
    if (g_pTouchManager == nullptr) {
        g_pTouchManager = new TouchManager;
    }
}
