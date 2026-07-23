#pragma once

namespace ne {

/**
 * @brief Base scene-graph render node (RTTI @c ne::C_RENDER).
 *
 * Every drawable in the engine is a @c C_RENDER: nodes form a parent/child/sibling tree that is
 * walked to compose local and world transforms and to emit draw calls. Concrete leaves such as
 * @c C_SPRITE_INSTANCING derive from it. The class is polymorphic (it carries a vtable), so it is
 * modelled with a virtual destructor.
 *
 * The trailing @c // +0xNN comments document the original 32-bit member offsets for reference only;
 * never read or write the object through those offsets. Members whose meaning has not yet been
 * recovered are kept as explicitly-named reserved storage rather than invented field names.
 */
class C_RENDER {
public:
    C_RENDER();
    virtual ~C_RENDER();

    /**
     * @brief Whether this node (and its subtree) is drawn.
     */
    bool IsVisible() const {
        return m_bVisible;
    }

    /**
     * @brief Show or hide this node.
     * @param bVisible @c true to draw the node, @c false to skip it.
     */
    void SetVisible(bool bVisible) {
        m_bVisible = bVisible;
    }

    /**
     * @brief Whether the node is flagged for deferred deletion by the scene walker.
     */
    bool IsDeleteRequested() const {
        return m_bDeleteRequest;
    }

    /**
     * @brief The node's parent in the scene graph, or @c nullptr when it is a root.
     */
    C_RENDER *GetParent() const {
        return m_pParent;
    }

private:
    // +0x00: implicit vtable pointer (from the virtual destructor above).
    unsigned char m_reserved08[24] = {};  // +0x08: node state not yet recovered.
    C_RENDER *m_pParent = {};             // +0x20
    C_RENDER *m_pChildHead = {};          // +0x28
    C_RENDER *m_pSiblingPrev = {};        // +0x30
    C_RENDER *m_pSiblingNext = {};        // +0x38
    unsigned char m_reserved40[16] = {};  // +0x40: node state not yet recovered.
    float m_mLocalMatrix[16] = {};        // +0x50: local transform.
    float m_mWorldMatrix[16] = {};        // +0x90: composed world transform.
    bool m_bDeleteRequest = {};           // +0xd0
    bool m_bVisible = {};                 // +0xd1
    unsigned char m_reservedTail[2] = {}; // +0xd2

    // The scene-graph link/unlink helpers reach the private sibling and parent links directly.
    friend void AttachSceneNode(C_RENDER *pParent, C_RENDER *pChild);
    friend void DetachSceneNode(C_RENDER *pNode);
};

/**
 * @brief Insert @p pChild as a child of @p pParent in the scene graph.
 *
 * The node is first detached from any current parent, then linked into @p pParent's child list.
 * @param pParent The node to receive the child.
 * @param pChild The node to attach.
 * @ghidraAddress 0x29d08
 */
void AttachSceneNode(C_RENDER *pParent, C_RENDER *pChild);

/**
 * @brief Unlink @p pNode from its parent's child list.
 *
 * Advances the parent's child-list head past @p pNode if it was the head, splices the node out of
 * its sibling ring, then clears its parent link and resets its sibling links to itself.
 * @param pNode The node to detach.
 * @ghidraAddress 0x29c8c
 */
void DetachSceneNode(C_RENDER *pNode);

} // namespace ne

// code: language=C++
// kate: hl C++;
// vim: set ft=cpp :
