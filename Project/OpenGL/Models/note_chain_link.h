/**
 * @file
 * The note chain-link block, @c NoteChainLink.
 */

#pragma once

/**
 * @brief The 12-byte chain-link block embedded in each chart note record (at record +0x3c).
 *
 * A chain threads its notes through the previous- and next-segment indices; both hold the -1 marker
 * when the note is at an end. The trailing eight bytes are cleared spare space. The chart parser
 * seeds it and the chain walkers query its ends.
 * @ghidraAddress NoteChainLink (engine chart chain-link block, 12 bytes)
 */
class NoteChainLink {
public:
    /**
     * @brief Constructs the block in the empty state: both indices to the -1 marker, the partner,
     * end marker, and trailing spare all cleared.
     * @ghidraAddress 0x12eadc
     */
    NoteChainLink();

    /**
     * @brief Whether this note heads its chain (no previous segment).
     * @return @c true when the previous-segment index is the -1 marker.
     * @ghidraAddress 0x12eaf0
     */
    bool IsHead() const {
        return m_nPrev == kNone;
    }

    /**
     * @brief Whether this note ends its chain (no next segment).
     * @return @c true when the next-segment index is the -1 marker.
     * @ghidraAddress 0x12eb00
     */
    bool IsTail() const {
        return m_nNext == kNone;
    }

    /** @brief The next chain-segment index, or the -1 marker at the tail. */
    short GetNext() const {
        return m_nNext;
    }

    /** @brief The head-note chain id (the parser stores it here for a long-note head). */
    short GetChainId() const {
        return m_nPrev;
    }

    /** @brief Marks this note a long-note head bound to @p nPartner, with both end markers unset. */
    void SetLongNoteHead(short nChainId, short nPartner) {
        m_nPrev = nChainId;
        m_nNext = kNone;
        m_nPartner = nPartner;
        m_nMarker = kNone;
    }

    /** @brief Records the resolved long-note tail: its partner note id and time delta. */
    void SetTail(short nPartnerNoteId, short nTimeDelta) {
        m_nNext = nPartnerNoteId;
        m_nMarker = nTimeDelta;
    }

    /** @brief The bound partner index, when this note heads a long note. */
    short GetPartner() const {
        return m_nPartner;
    }

private:
    // The chain-segment index marker for an absent (head or tail) link.
    static constexpr short kNone = -1;

    short m_nPrev = {};                  // +0x00: the previous chain-segment index / head chain id.
    short m_nNext = {};                  // +0x02: the next chain-segment index (-1 = tail).
    short m_nPartner = {};               // +0x04: the bound partner index for a long-note head.
    short m_nMarker = {};                // +0x06: an end marker / resolved tail time delta.
    unsigned char m_aReserved08[4] = {}; // +0x08: cleared spare space.
};

// code: language=C++
// kate: hl C++;
// vim: set ft=cpp :
