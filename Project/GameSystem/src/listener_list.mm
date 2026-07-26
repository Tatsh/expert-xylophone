//
//  listener_list.mm
//  REFLEC BEAT plus
//
//  The engine's global priority-sorted listener list. Reconstructed from Ghidra project rb458,
//  program rb458. @ghidraAddress values are relative to the program image base.
//

#include "listener_list.h"

#include <cstdlib>

#include "engineruntime.h"

// The sentinel priority; every real listener sorts below it, so it always terminates the list.
static constexpr int kSentinelPriority = 9;

namespace {
// The sentinel's per-frame callback is a no-op (the list terminator carries no behaviour).
void SentinelOnFrame(SortedListenerNode *, void *) {
}

// Dispatch-table adapters that forward the plain node-pointer vtable slots to the node's methods:
// the no-op callback (slot 0), the non-deleting destructor (slot 1), and the deleting one (slot 2).
void SentinelDestroyNode(SortedListenerNode *pNode) {
    pNode->Unlink();
}
void SentinelDeleteNode(SortedListenerNode *pNode) {
    pNode->DestroyAndFree();
}
SortedListenerNodeVtable g_sentinelVtable = {
    SentinelOnFrame, SentinelDestroyNode, SentinelDeleteNode};
} // namespace

// The list's sentinel node (also its head/tail terminator), seeded by InitializeGlobalContainer.
SortedListenerNode g_listenerListSentinel;

// Registers the sentinel's teardown at process exit, matching the binary's __cxa_atexit call.
static void DestroyGlobalListenerContainer() {
    g_listenerListSentinel.Destroy();
}

/** @ghidraAddress 0x366ac */
void SortedListenerNode::InitializeGlobalContainer() {
    g_listenerListSentinel.m_pVtable = &g_sentinelVtable;
    g_listenerListSentinel.m_nPriority = kSentinelPriority;
    g_listenerListSentinel.m_pPrev = &g_listenerListSentinel;
    g_listenerListSentinel.m_pNext = &g_listenerListSentinel;
    g_listenerListSentinel.m_pBuffer = nullptr;
    g_listenerListSentinel.m_bDead = false;
    atexit(DestroyGlobalListenerContainer);
}

// Run the container initialiser at load, as the binary's __mod_init_func entry does.
__attribute__((constructor)) static void RunListenerContainerInit() {
    SortedListenerNode::InitializeGlobalContainer();
}

/** @ghidraAddress 0x365e4 */
void SortedListenerNode::InsertSorted(int nPriority) {
    // Unlink from the current position.
    m_pNext->m_pPrev = m_pPrev;
    m_pPrev->m_pNext = m_pNext;
    // Walk from the sentinel to the first node whose priority is not below the requested one.
    SortedListenerNode *pBefore = &g_listenerListSentinel;
    SortedListenerNode *pAfter = pBefore->m_pNext;
    while (pAfter->m_nPriority < nPriority) {
        pBefore = pAfter;
        pAfter = pBefore->m_pNext;
    }
    // Splice this node in between pBefore and pAfter.
    m_pPrev = pBefore;
    m_pNext = pAfter;
    pBefore->m_pNext = this;
    m_pNext->m_pPrev = this;
    m_nPriority = nPriority;
}

/** @ghidraAddress 0x36580 */
void SortedListenerNode::Unlink() {
    m_pNext->m_pPrev = m_pPrev;
    m_pPrev->m_pNext = m_pNext;
    delete[] m_pBuffer;
    m_pBuffer = nullptr;
}

/** @ghidraAddress 0x365d0 */
void SortedListenerNode::DestroyAndFree() {
    Unlink();
    delete this;
}

/** @ghidraAddress 0x36628 */
void DispatchListenerList(void *pFrameArg) {
    // Walk the list from the head. A live node gets its per-frame callback and the walk advances to
    // its successor; a dead node is destroyed (its successor is captured first, since destruction
    // splices the node out of the list).
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
