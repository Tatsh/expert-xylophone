#include "neRender.h"

#import "engineruntime.h"
#import "matrixmath.h"

namespace ne {

// The process-wide scene-graph root. Its static constructor and atexit destructor registration are
// the binary's InitializeGlobalSceneRoot (0x29ee0), emitted by the compiler for this global.
C_RENDER g_globalSceneRoot;

/** @ghidraAddress 0x29b3c */
C_RENDER::C_RENDER() {
    // The two transforms start at identity. In the binary the matrix members are also pre-filled
    // inline by their default construction before these calls; the explicit calls set the final
    // identity value, and every other field is zero or nullptr from the member initialisers.
    SetMatrixIdentity(m_mLocalMatrix);
    SetMatrixIdentity(m_mWorldMatrix);
    m_bVisible = true;

    // Both intrusive rings begin empty (self-linked): the link ring at +0x08/+0x10 and the sibling
    // ring at +0x30/+0x38.
    m_pLinkPrev = this;
    m_pLinkNext = this;
    m_pSiblingPrev = this;
    m_pSiblingNext = this;
}

/** @ghidraAddress 0x29edc */
void C_RENDER::Render() {
    // The base render node is not drawable; drawable subclasses override this.
}

/** @ghidraAddress 0x29c10 */
C_RENDER::~C_RENDER() {
    // Unlink from the render-list ring.
    m_pLinkNext->m_pLinkPrev = m_pLinkPrev;
    m_pLinkPrev->m_pLinkNext = m_pLinkNext;

    // Detach from the parent's child list, if attached.
    if (m_pParent != nullptr) {
        Detach();
    }

    // Detach every child. Each Detach advances m_pChildHead, so re-reading it walks the whole list;
    // the sibling link is saved first because Detach resets it.
    C_RENDER *pChild = m_pChildHead;
    while (m_pChildHead != nullptr) {
        C_RENDER *pNext = pChild->m_pSiblingNext;
        pChild->Detach();
        pChild = pNext;
    }

    // Free the lazily-allocated buffer.
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
            // This was the parent's only child, so the child list becomes empty.
            m_pParent->m_pChildHead = nullptr;
            pRelinkFrom = this;
        } else {
            // Advance the child-list head past this node.
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
        // Splice the child in just before the head, at the tail of the sibling ring.
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

    // First pass: destroy any delete-requested children at the head, each of which advances the
    // circular list's head, then draw the first live child (recursing into its subtree) and stop.
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

    // Second pass: walk the remaining siblings, drawing the visible ones (and recursing) and
    // destroying the delete-requested ones, until the ring returns to the head.
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

/** @ghidraAddress 0x29d58 */
void RenderGlobalSceneTree() {
    // The binary guards this with a child-head check, but TraverseChildren already returns early
    // when the root has no children, so the guard is redundant.
    ne::g_globalSceneRoot.TraverseChildren();
}
