/**
 * @file
 * The engine's global priority-sorted listener list and its intrusive node, @c ne::C_TASK.
 */

#pragma once

//
//  listener_list.h
//  REFLEC BEAT plus
//
//  The engine keeps one process-wide, sentinel-headed, priority-sorted doubly-linked list of
//  per-frame listener nodes. Each frame the render loop dispatches the list, invoking every live
//  node's callback and destroying the ones flagged dead. Scene layers register themselves onto the
//  list at a priority; the list is walked in ascending priority order.
//
//  Reconstructed from Ghidra project rb458, program rb458. @ghidraAddress values are relative to
//  the program image base.
//

/**
 * @brief One intrusive node in the engine's priority-sorted listener list.
 *
 * A polymorphic base: the compiler emits its vtable at offset 0, whose slots are the per-frame
 * callback @c OnFrame (slot 0) and the two destructor variants the compiler generates for
 * @c ~C_TASK (the complete-object destructor at slot 1 and the deleting destructor at
 * slot 2). The prev/next links thread the circular list and the priority is its sort key. Concrete
 * listeners (the sentinel, the UI layers) derive from this and override @c OnFrame. The trailing
 * @c // +0xNN comments document the original member offsets for reference only.
 * @ghidraAddress C_TASK (engine listener-list node)
 */
namespace ne {

class C_TASK {
public:
    /**
     * @brief Constructs an unlinked node: self-links the node (its prev and next point to itself),
     * seeds the idle priority, and clears the owned buffer and dead flag. Every concrete listener
     * runs this base constructor before setting up its own state.
     * @ghidraAddress 0x36558
     */
    C_TASK();

    /**
     * @brief Unlinks the node from its list and frees its owned buffer.
     *
     * The compiler emits this destructor as three bodies — the complete-object variant at
     * @c 0x36580, the deleting variant at @c 0x365d0, and the out-of-line deleting thunks at
     * @c 0x14a260 and @c 0x18be00 — which all collapse to this one virtual destructor.
     * @ghidraAddress 0x36580
     * @ghidraAddress 0x365d0
     * @ghidraAddress 0x14a260
     * @ghidraAddress 0x18be00
     */
    virtual ~C_TASK();

    /**
     * @brief The node's per-frame callback (vtable slot 0). The base does nothing; concrete
     * listeners override it.
     * @param nElapsedMs The frame delta, in milliseconds, passed by the dispatcher.
     */
    virtual void OnFrame(int nElapsedMs);

    /** @brief The previous node in the list. */
    C_TASK *GetPrev() const {
        return m_pPrev;
    }
    /** @brief The next node in the list. */
    C_TASK *GetNext() const {
        return m_pNext;
    }
    /** @brief The node's priority (the list is kept ascending by this key). */
    int GetPriority() const {
        return m_nPriority;
    }
    /** @brief Whether the node has been flagged dead (to be destroyed on the next dispatch). */
    bool IsDead() const {
        return m_bDead;
    }
    /** @brief Flags the node dead, so the next dispatch destroys it. */
    void MarkDead() {
        m_bDead = true;
    }

    /**
     * @brief Inserts (or re-positions) this node in the global listener list, ascending by
     * @p nPriority: unlinks it from its current position, then splices it before the first node
     * whose priority is not below @p nPriority.
     * @param nPriority The node's sort priority.
     * @ghidraAddress 0x365e4
     */
    void InsertSorted(int nPriority);

    /**
     * @brief Seeds the global listener-list sentinel into an empty self-linked list at the sentinel
     * priority and registers its teardown with @c atexit. Run once at startup.
     * @ghidraAddress 0x366ac
     */
    static void InitializeGlobalContainer();

protected:
    // Unlinks the node from its circular list (shared by the destructor and re-insertion).
    void Unlink();

    // +0x00: the compiler-emitted vtable pointer (the class is polymorphic; see the virtual
    // methods).
    C_TASK *m_pPrev = {}; // +0x08: the previous node.
    C_TASK *m_pNext = {}; // +0x10: the next node.
    int m_nPriority = {}; // +0x18: the sort key (the task state field).
    // unsigned char m_aReserved1c[0x24] = {}; // +0x1c: node-specific state.
    unsigned char *m_pBuffer = {}; // +0x40: an owned heap buffer, freed on destruction.
    bool m_bDead = {};             // +0x48: set when the node should be destroyed.
};

} // namespace ne

// code: language=C++
// kate: hl C++;
// vim: set ft=cpp :
