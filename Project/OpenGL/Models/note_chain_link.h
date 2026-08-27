/**
 * @file
 * The note chain-link block, @c NoteChainLink.
 */

#pragma once

#include <cstring>

/**
 * @brief The 12-byte chain-link block embedded in each chart note record (at record +0x3c).
 *
 * A chain threads its notes through the previous- and next-segment indices; both hold the -1 marker
 * when the note is at an end. The trailing eight bytes are cleared spare space. The chart parser
 * seeds it and the chain walkers query its ends.
 * Reconstructed type @c NoteChainLink: engine chart chain-link block, 12 bytes.
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

    /**
     * @brief The next chain-segment index, or the -1 marker at the tail.
     * @return The next chain-segment index, or -1 at the tail.
     */
    short GetNext() const {
        return m_nNext;
    }

    /**
     * @brief The head-note chain id (the parser stores it here for a long-note head).
     * @return The head-note chain id.
     */
    short GetChainId() const {
        return m_nPrev;
    }

    /** @brief Marks this note a long-note head bound to @p nPartner, with both end markers unset.
     *
     * Used only by the legacy parser, which leaves the next index unset and fills it later in its
     * own resolve pass. The v10 parser takes an already-resolved block from the chart instead; see
     * @c SetFromChartPayload.
     * @param nChainId The head-note chain id.
     * @param nPartner The bound partner index.
     */
    void SetLongNoteHead(short nChainId, short nPartner) {
        m_nPrev = nChainId;
        m_nNext = kNone;
        m_nPartner = nPartner;
        m_nMarker = kNone;
    }

    /**
     * @brief Seeds the block from a v10 chart's already-resolved twelve-byte chain payload.
     *
     * The v10 parser has no resolve pass: the chart carries the whole block and the binary copies
     * it verbatim, so the next index arrives from the file rather than being left at the -1 marker.
     * @param nPrev The previous-segment index (the payload's first short).
     * @param nNext The next-segment index (the payload's second short).
     * @param nPartnerAndMarker The partner index and end marker, packed low half then high half.
     * @param nExtra The trailing four payload bytes.
     */
    void SetFromChartPayload(short nPrev, short nNext, int nPartnerAndMarker, int nExtra) {
        m_nPrev = nPrev;
        m_nNext = nNext;
        m_nPartner = static_cast<short>(nPartnerAndMarker & 0xffff);
        m_nMarker = static_cast<short>((nPartnerAndMarker >> 16) & 0xffff);
        std::memcpy(m_aReserved08, &nExtra, sizeof(nExtra));
    }

    /**
     * @brief Records the resolved long-note tail: its partner note id and time delta.
     * @param nPartnerNoteId The tail's partner note id.
     * @param nTimeDelta The tail's time delta.
     */
    void SetTail(short nPartnerNoteId, short nTimeDelta) {
        m_nNext = nPartnerNoteId;
        m_nMarker = nTimeDelta;
    }

    /**
     * @brief The bound partner index, when this note heads a long note.
     * @return The bound partner index.
     */
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
