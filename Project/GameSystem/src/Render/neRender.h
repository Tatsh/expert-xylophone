/**
 * @file
 * The base scene-graph render node, @c ne::C_RENDER, and its scene-tree links.
 */

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
    /**
     * @brief Constructs an unparented node: identity local and world transforms, visible, with both
     * intrusive rings empty (self-linked).
     * @ghidraAddress 0x29b3c
     */
    C_RENDER();
    /**
     * @brief Render this node.
     *
     * The base node is not drawable and does nothing; drawable subclasses such as
     * @c C_SPRITE_INSTANCING override this to emit their draw calls. Invoked by the scene-tree
     * render walk. This is the first virtual slot, before the destructor.
     * @ghidraAddress 0x29edc
     */
    virtual void Render();
    /**
     * @brief Destroys the node: unlinks it from the render-list ring, detaches it from its parent
     * and detaches all of its children, then frees its buffer.
     * @ghidraAddress 0x29c10
     */
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

    /**
     * @brief Attach @p pChild as a child of this node.
     *
     * @p pChild is first detached from any current parent, then linked into this node's child list.
     * @param pChild The node to attach.
     * @ghidraAddress 0x29d08
     */
    void AttachChild(C_RENDER *pChild);

    /**
     * @brief Unlink this node from its parent's child list.
     *
     * Advances the parent's child-list head past this node if it was the head, splices the node out
     * of its sibling ring, then clears its parent link and resets its sibling links to itself.
     * @ghidraAddress 0x29c8c
     */
    void Detach();

    /**
     * @brief Register this node in the global scene tree so it is drawn each frame.
     *
     * Attaches the node as a child of the process-wide scene root, @c g_globalSceneRoot, whose
     * children @c RenderGlobalSceneTree traverses.
     * @ghidraAddress 0x29cf4
     */
    void RegisterGlobal();

    /**
     * @brief Traverse this node's children for the frame.
     *
     * Draws each visible child (via @c Render) and recurses into its subtree, and destroys each
     * child flagged for deletion. The child list is an intrusive circular ring, so deletions that
     * remove the head are handled as the walk proceeds.
     * @ghidraAddress 0x29d78
     */
    void TraverseChildren();

private:
    // +0x00: implicit vtable pointer (from the virtual destructor above).
    // +0x08/+0x10: this node's slot in a self-linked ring whose owning list is not yet identified;
    // it is distinct from the parent/child/sibling tree below, which the link helpers manage.
    C_RENDER *m_pLinkPrev = {};    // +0x08
    C_RENDER *m_pLinkNext = {};    // +0x10
    int m_nField18 = {};           // +0x18: node state not yet recovered.
    C_RENDER *m_pParent = {};      // +0x20
    C_RENDER *m_pChildHead = {};   // +0x28
    C_RENDER *m_pSiblingPrev = {}; // +0x30
    C_RENDER *m_pSiblingNext = {}; // +0x38
    // +0x40: lazily-allocated buffer freed with delete[] in the destructor; the element type is not
    // yet recovered, so it is modelled as a raw byte buffer.
    unsigned char *m_pBuffer = {};      // +0x40
    unsigned char m_reserved48[8] = {}; // +0x48: node state not yet recovered.
    float m_mLocalMatrix[16] = {};      // +0x50: local transform.
    float m_mWorldMatrix[16] = {};      // +0x90: composed world transform.
    bool m_bDeleteRequest = {};         // +0xd0
    bool m_bVisible = {};               // +0xd1
    // +0xd2..+0xd7 is compiler alignment padding to the 0xd8-byte object size (no member there).
};

/**
 * @brief The process-wide scene-graph root.
 *
 * Nodes registered with @c C_RENDER::RegisterGlobal become its children and are traversed for
 * drawing each frame by @c RenderGlobalSceneTree. It is a namespace-scope @c C_RENDER, so the
 * compiler emits its static constructor and atexit destructor registration (the binary's
 * @c InitializeGlobalSceneRoot at 0x29ee0).
 * @ghidraAddress 0x3cfe20
 */
extern C_RENDER g_globalSceneRoot;

} // namespace ne

// code: language=C++
// kate: hl C++;
// vim: set ft=cpp :
