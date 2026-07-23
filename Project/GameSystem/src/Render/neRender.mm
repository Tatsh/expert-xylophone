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

/** @ghidraAddress 0x29c8c */
void DetachSceneNode(C_RENDER *pNode) {
    C_RENDER *pParent = pNode->m_pParent;
    if (pParent == nullptr) {
        return;
    }

    C_RENDER *pNext = pNode->m_pSiblingNext;
    C_RENDER *pRelinkFrom = pNext;
    if (pParent->m_pChildHead == pNode) {
        if (pNext == pNode) {
            // The node was the parent's only child, so the child list becomes empty.
            pParent->m_pChildHead = nullptr;
            pRelinkFrom = pNode;
        } else {
            // Advance the child-list head past the node being removed.
            pParent->m_pChildHead = pNext;
        }
    }

    pRelinkFrom->m_pSiblingPrev = pNode->m_pSiblingPrev;
    pNode->m_pSiblingPrev->m_pSiblingNext = pNext;
    pNode->m_pParent = nullptr;
    pNode->m_pSiblingPrev = pNode;
    pNode->m_pSiblingNext = pNode;
}

/** @ghidraAddress 0x29d08 */
void AttachSceneNode(C_RENDER *pParent, C_RENDER *pChild) {
    DetachSceneNode(pChild);
    pChild->m_pParent = pParent;

    C_RENDER *pChildHead = pParent->m_pChildHead;
    if (pChildHead == nullptr) {
        pParent->m_pChildHead = pChild;
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
