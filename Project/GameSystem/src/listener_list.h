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
 * @brief A listener node's virtual dispatch table.
 *
 * The engine uses a custom (non-Itanium) slot layout: slot 0 is the per-frame callback and slot 2
 * (vtable byte offset 0x10) is the destructor. Slot 1 is unused by the list dispatcher.
 */
struct SortedListenerNodeVtable {
    void (*pfnOnFrame)(SortedListenerNode *pNode, void *pFrameArg); // slot 0 (+0x00).
    void (*pfnReserved)();                                          // slot 1 (+0x08), unused here.
    void (*pfnDestroy)(SortedListenerNode *pNode);                  // slot 2 (+0x10).
};

/**
 * @brief One intrusive node in the engine's priority-sorted listener list.
 *
 * A polymorphic object: its first slot is the vtable, through which the dispatcher calls the
 * per-frame callback (slot 0) and, for a dead node, the destructor (slot 2, at vtable offset 0x10).
 * The prev/next links thread the circular list, and the priority is its sort key. The trailing
 * @c // +0xNN comments document the original member offsets for reference only.
 * @ghidraAddress SortedListenerNode (engine listener-list node)
 */
class SortedListenerNode {
public:
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
    /** @brief Invokes the node's per-frame callback (vtable slot 0). */
    void OnFrame(void *pFrameArg) {
        m_pVtable->pfnOnFrame(this, pFrameArg);
    }
    /** @brief Invokes the node's destructor (vtable slot 2). */
    void Destroy() {
        m_pVtable->pfnDestroy(this);
    }

private:
    SortedListenerNodeVtable *m_pVtable = {}; // +0x00: the node's dispatch table.
    SortedListenerNode *m_pPrev = {};         // +0x08: the previous node.
    SortedListenerNode *m_pNext = {};         // +0x10: the next node.
    int m_nPriority = {};                     // +0x18: the sort key.
    unsigned char m_aReserved1c[0x24] = {};   // +0x1c: node-specific state.
    void *m_pBuffer = {};                     // +0x40: an owned heap buffer, freed on destruction.
    bool m_bDead = {};                        // +0x48: set when the node should be destroyed.
    unsigned char m_aReserved49[7] = {};      // +0x49: trailing state.

    friend void InsertSortedListenerNode(SortedListenerNode *pNode, int nPriority);
};

/**
 * @brief Inserts (or re-positions) @p pNode in the global listener list, ascending by @p nPriority.
 *
 * The node is first unlinked from its current position, then spliced in before the first node whose
 * priority is greater than or equal to @p nPriority.
 * @param pNode The node to insert.
 * @param nPriority The node's sort priority.
 * @ghidraAddress 0x365e4
 */
void InsertSortedListenerNode(SortedListenerNode *pNode, int nPriority);

// code: language=C++
// kate: hl C++;
// vim: set ft=cpp :
