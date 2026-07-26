//
//  listener_list.mm
//  REFLEC BEAT plus
//
//  The engine's global priority-sorted listener list. Reconstructed from Ghidra project rb458,
//  program rb458. @ghidraAddress values are relative to the program image base.
//

#include "listener_list.h"

#include "engineruntime.h"

// The list's sentinel node (also its head/tail terminator), a namespace-scope object whose static
// constructor seeds an empty self-linked list at priority 9. Defined in its owning translation unit.
extern SortedListenerNode g_listenerListSentinel;

/** @ghidraAddress 0x365e4 */
void InsertSortedListenerNode(SortedListenerNode *pNode, int nPriority) {
    // Unlink the node from wherever it currently sits.
    SortedListenerNode *pNext = pNode->m_pNext;
    pNext->m_pPrev = pNode->m_pPrev;
    pNode->m_pPrev->m_pNext = pNext;
    // Walk from the sentinel to the first node whose priority is not below the requested one.
    SortedListenerNode *pBefore = &g_listenerListSentinel;
    SortedListenerNode *pAfter = pBefore->m_pNext;
    while (pAfter->m_nPriority < nPriority) {
        pBefore = pAfter;
        pAfter = pBefore->m_pNext;
    }
    // Splice the node in between pBefore and pAfter.
    pNode->m_pPrev = pBefore;
    pNode->m_pNext = pAfter;
    pBefore->m_pNext = pNode;
    pNode->m_pNext->m_pPrev = pNode;
    pNode->m_nPriority = nPriority;
}

/** @ghidraAddress 0x36628 */
void DispatchListenerList(void *pFrameArg) {
    // Walk the list from the head. A live node gets its per-frame callback and the walk advances to
    // its successor; a dead node is unlinked-and-destroyed (its successor is captured first, since
    // the destructor splices the node out of the list).
    for (SortedListenerNode *pNode = g_listenerListSentinel.GetNext();
         pNode != &g_listenerListSentinel;) {
        if (!pNode->IsDead()) {
            pNode->OnFrame(pFrameArg);
            pNode = pNode->GetNext();
        } else {
            SortedListenerNode *pNext = pNode->GetNext();
            pNode->Destroy();
            pNode = pNext;
        }
    }
}
