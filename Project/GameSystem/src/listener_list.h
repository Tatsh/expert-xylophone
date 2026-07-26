/**
 * @file
 * The engine's global priority-sorted listener list and its intrusive node, @c SortedListenerNode.
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
//  Reconstructed from Ghidra project rb458, program rb458. @ghidraAddress values are relative to the
//  program image base.
//

class SortedListenerNode;

/**
 * @brief A listener node's dispatch table.
 *
 * The engine uses a custom slot layout: slot 0 is the per-frame callback, slot 1 the non-deleting
 * destructor, and slot 2 the deleting destructor.
 */
struct SortedListenerNodeVtable {
    void (*pfnOnFrame)(SortedListenerNode *pNode, void *pFrameArg); // slot 0 (+0x00): per-frame.
    void (*pfnDestroyNode)(SortedListenerNode *pNode);              // slot 1 (+0x08): non-deleting.
    void (*pfnDestroy)(SortedListenerNode *pNode);                  // slot 2 (+0x10): deleting.
};

/**
 * @brief One intrusive node in the engine's priority-sorted listener list.
 *
 * Its first slot is the dispatch table, through which the list invokes the per-frame callback and
 * the destructors. The prev/next links thread the circular list, and the priority is its sort key.
 * The trailing @c // +0xNN comments document the original member offsets for reference only.
 * @ghidraAddress SortedListenerNode (engine listener-list node)
 */
class SortedListenerNode {
public:
    /**
     * @brief Constructs an unlinked node: installs the base dispatch table, self-links the node
     * (its prev and next point to itself), seeds the idle priority, and clears the owner and dead
     * flag. Every concrete listener/task runs this base constructor before setting up its own state.
     * @ghidraAddress 0x36558
     */
    SortedListenerNode();

    /** @brief The previous node in the list. */
    SortedListenerNode *GetPrev() const {
        return m_pPrev;
    }
    /** @brief The next node in the list. */
    SortedListenerNode *GetNext() const {
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
    /** @brief Invokes the node's per-frame callback (dispatch-table slot 0). */
    void OnFrame(void *pFrameArg) {
        m_pVtable->pfnOnFrame(this, pFrameArg);
    }
    /** @brief Invokes the node's deleting destructor (dispatch-table slot 2). */
    void Destroy() {
        m_pVtable->pfnDestroy(this);
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
     * @brief Unlinks this node from its list and frees its owned buffer (the non-deleting
     * destructor body).
     * @ghidraAddress 0x36580
     */
    void Unlink();

    /**
     * @brief The deleting destructor: unlinks and frees the buffer, then frees the node itself.
     * @ghidraAddress 0x365d0
     */
    void DestroyAndFree();

    /**
     * @brief Seeds the global listener-list sentinel into an empty self-linked list at the sentinel
     * priority and registers its teardown with @c atexit. Run once at startup.
     * @ghidraAddress 0x366ac
     */
    static void InitializeGlobalContainer();

private:
    SortedListenerNodeVtable *m_pVtable = {}; // +0x00: the node's dispatch table.
    SortedListenerNode *m_pPrev = {};         // +0x08: the previous node.
    SortedListenerNode *m_pNext = {};         // +0x10: the next node.
    int m_nPriority = {};                     // +0x18: the sort key.
    unsigned char m_aReserved1c[0x24] = {};   // +0x1c: node-specific state.
    unsigned char *m_pBuffer = {};            // +0x40: an owned heap buffer, freed on destruction.
    bool m_bDead = {};                        // +0x48: set when the node should be destroyed.
    unsigned char m_aReserved49[7] = {};      // +0x49: trailing state.
};

// code: language=C++
// kate: hl C++;
// vim: set ft=cpp :
