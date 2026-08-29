#include "ctask.h"

#include <cstdlib>

#include "engineruntime.h"

// Also the sentinel's terminating priority, so an unlinked node sorts with the terminator.
static constexpr int kIdlePriority = 9;

namespace {

// The list's sentinel, serving as both its head and its tail terminator.
class ListenerListSentinel : public ne::C_TASK {
public:
    void OnFrame(int) override {
    }
};

ListenerListSentinel g_listenerListSentinel;

void DestroyGlobalListenerContainer() {
    g_listenerListSentinel.~ListenerListSentinel();
}

} // namespace

namespace ne {

/** @ghidraAddress 0x36558 */
C_TASK::C_TASK() {
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
C_TASK::~C_TASK() {
    Unlink();
}

void C_TASK::OnFrame(int) {
}

void C_TASK::Unlink() {
    m_pNext->m_pPrev = m_pPrev;
    m_pPrev->m_pNext = m_pNext;
    delete[] m_pBuffer;
    m_pBuffer = nullptr;
}

/** @ghidraAddress 0x366ac */
void C_TASK::InitializeGlobalContainer() {
    g_listenerListSentinel.m_nPriority = kIdlePriority;
    g_listenerListSentinel.m_pPrev = &g_listenerListSentinel;
    g_listenerListSentinel.m_pNext = &g_listenerListSentinel;
    g_listenerListSentinel.m_pBuffer = nullptr;
    g_listenerListSentinel.m_bDead = false;
    atexit(DestroyGlobalListenerContainer);
}

// Run the container initialiser at load, as the binary's __mod_init_func entry does.
__attribute__((constructor)) static void RunListenerContainerInit() {
    C_TASK::InitializeGlobalContainer();
}

/** @ghidraAddress 0x365e4 */
void C_TASK::InsertSorted(int nPriority) {
    m_pNext->m_pPrev = m_pPrev;
    m_pPrev->m_pNext = m_pNext;
    C_TASK *pBefore = &g_listenerListSentinel;
    C_TASK *pAfter = pBefore->m_pNext;
    while (pAfter->m_nPriority < nPriority) {
        pBefore = pAfter;
        pAfter = pBefore->m_pNext;
    }
    m_pPrev = pBefore;
    m_pNext = pAfter;
    pBefore->m_pNext = this;
    m_pNext->m_pPrev = this;
    m_nPriority = nPriority;
}

} // namespace ne

/** @ghidraAddress 0x36628 */
void DispatchListenerList(int nElapsedMs) {
    // A dead node's successor is captured first, since destruction splices it out of the list.
    for (ne::C_TASK *pNode = g_listenerListSentinel.GetNext(); pNode != &g_listenerListSentinel;) {
        if (!pNode->IsDead()) {
            pNode->OnFrame(nElapsedMs);
            pNode = pNode->GetNext();
        } else {
            ne::C_TASK *pNext = pNode->GetNext();
            delete pNode;
            pNode = pNext;
        }
    }
}
