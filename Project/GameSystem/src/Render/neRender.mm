#include "neRender.h"

#import "engineruntime.h"
#import "matrixmath.h"
#include "neDebugLog.h"

namespace ne {

/** @ghidraAddress 0x29ee0 */
C_RENDER g_globalSceneRoot;

/** @ghidraAddress 0x29b3c */
C_RENDER::C_RENDER() {
    SetMatrixIdentity(m_mLocalMatrix);
    SetMatrixIdentity(m_mWorldMatrix);
    m_bVisible = true;

    // Both intrusive rings begin empty, self-linked: the link ring at +0x08/+0x10 and the
    // sibling ring at +0x30/+0x38.
    m_pLinkPrev = this;
    m_pLinkNext = this;
    m_pSiblingPrev = this;
    m_pSiblingNext = this;
}

/** @ghidraAddress 0x29edc */
void C_RENDER::Render() {
    // The base node is not drawable; drawable subclasses override this.
}

/**
 * @ghidraAddress 0x29c10
 * @ghidraAddress 0x29ce0 (the deleting-destructor thunk)
 */
C_RENDER::~C_RENDER() {
    m_pLinkNext->m_pLinkPrev = m_pLinkPrev;
    m_pLinkPrev->m_pLinkNext = m_pLinkNext;

    if (m_pParent != nullptr) {
        Detach();
    }

    // Detach advances m_pChildHead and resets the sibling link, so save the link first.
    C_RENDER *pChild = m_pChildHead;
    while (m_pChildHead != nullptr) {
        C_RENDER *pNext = pChild->m_pSiblingNext;
        pChild->Detach();
        pChild = pNext;
    }

    delete[] m_pBuffer;
    m_pBuffer = nullptr;
}

/** @ghidraAddress 0x29c8c */
void C_RENDER::Detach() {
    if (m_pParent == nullptr) {
        return;
    }

    C_RENDER *pNext = m_pSiblingNext;
    C_RENDER *pRelinkFrom = pNext;
    if (m_pParent->m_pChildHead == this) {
        if (pNext == this) {
            m_pParent->m_pChildHead = nullptr;
            pRelinkFrom = this;
        } else {
            m_pParent->m_pChildHead = pNext;
        }
    }

    pRelinkFrom->m_pSiblingPrev = m_pSiblingPrev;
    m_pSiblingPrev->m_pSiblingNext = pNext;
    m_pParent = nullptr;
    m_pSiblingPrev = this;
    m_pSiblingNext = this;
}

/** @ghidraAddress 0x29d08 */
void C_RENDER::AttachChild(C_RENDER *pChild) {
    pChild->Detach();
    pChild->m_pParent = this;

    C_RENDER *pChildHead = m_pChildHead;
    if (pChildHead == nullptr) {
        m_pChildHead = pChild;
    } else {
        C_RENDER *pTail = pChildHead->m_pSiblingPrev;
        pChild->m_pSiblingPrev = pTail;
        pChild->m_pSiblingNext = pChildHead;
        pTail->m_pSiblingNext = pChild;
        pChild->m_pSiblingNext->m_pSiblingPrev = pChild;
    }
}

/** @ghidraAddress 0x29cf4 */
void C_RENDER::RegisterGlobal() {
    g_globalSceneRoot.AttachChild(this);
}

/** @ghidraAddress 0x29d78 */
void C_RENDER::TraverseChildren() {
    C_RENDER *pChild = m_pChildHead;
    if (pChild == nullptr) {
        return;
    }

    C_RENDER *pNext;
    do {
        pNext = pChild->m_pSiblingNext;
        if (!pChild->m_bDeleteRequest) {
            if (pChild->m_bVisible) {
                pChild->Render();
                if (pChild->m_pChildHead != nullptr) {
                    pChild->TraverseChildren();
                }
            }
            break;
        }
        delete pChild;
        pChild = pNext;
    } while (pNext == m_pChildHead);

    if (m_pChildHead != nullptr && pNext != m_pChildHead) {
        do {
            C_RENDER *pAfter = pNext->m_pSiblingNext;
            if (!pNext->m_bDeleteRequest) {
                if (pNext->m_bVisible) {
                    pNext->Render();
                    if (pNext->m_pChildHead != nullptr) {
                        pNext->TraverseChildren();
                    }
                }
            } else {
                delete pNext;
            }
            pNext = pAfter;
        } while (m_pChildHead != nullptr && pNext != m_pChildHead);
    }
}

} // namespace ne

#if RBPDBG
int g_nDebugFrameCounter = 0;
// The frame to dump, or zero for none. The layer that owns the targets arms it on the first frame
// it emits a real position, so the dump lands once the play field has settled.
int g_nDebugSnapshotFrame = 0;
#endif

/** @ghidraAddress 0x29d58 */
void RenderGlobalSceneTree() {
    NE_DBG(++g_nDebugFrameCounter);
    // The binary's child-head guard is dropped here: TraverseChildren already returns early.
    ne::g_globalSceneRoot.TraverseChildren();
}
