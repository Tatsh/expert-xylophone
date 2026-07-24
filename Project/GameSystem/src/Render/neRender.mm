#import "neRender.h"

#import "../../../neEngineBridge.h"

namespace ne {

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

} // namespace ne
