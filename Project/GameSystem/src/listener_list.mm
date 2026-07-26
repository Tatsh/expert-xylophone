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

// The idle priority a freshly-constructed node carries; it is also the sentinel's terminating
// priority, so an unlinked node sorts alongside the list terminator until it is inserted.
static constexpr int kIdlePriority = 9;

namespace {

// The list's sentinel (also its head and tail terminator): a node whose per-frame callback does
// nothing. Seeded by InitializeGlobalContainer.
class ListenerListSentinel : public SortedListenerNode {
public:
    void OnFrame(void *) override {
    }
};

ListenerListSentinel g_listenerListSentinel;

// Registers the sentinel's teardown at process exit, matching the binary's __cxa_atexit call.
void DestroyGlobalListenerContainer() {
    g_listenerListSentinel.~ListenerListSentinel();
}

} // namespace

/** @ghidraAddress 0x36558 */
SortedListenerNode::SortedListenerNode() {
    // The compiler installs the vtable; this constructor self-links the node, seeds the idle
    // priority, and clears the owned buffer and dead flag.
    m_pPrev = this;
    m_pNext = this;
    m_nPriority = kIdlePriority;
    m_pBuffer = nullptr;
    m_bDead = false;
}

/**
 * @ghidraAddress 0x36580
 * @ghidraAddress 0x365d0
 * @ghidraAddress 0x14a260
 * @ghidraAddress 0x18be00
 */
SortedListenerNode::~SortedListenerNode() {
    Unlink();
}

void SortedListenerNode::OnFrame(void *) {
}

void SortedListenerNode::Unlink() {
    m_pNext->m_pPrev = m_pPrev;
    m_pPrev->m_pNext = m_pNext;
    delete[] m_pBuffer;
    m_pBuffer = nullptr;
}

/** @ghidraAddress 0x366ac */
void SortedListenerNode::InitializeGlobalContainer() {
    g_listenerListSentinel.m_nPriority = kIdlePriority;
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
            delete pNode;
            pNode = pNext;
        }
    }
}
