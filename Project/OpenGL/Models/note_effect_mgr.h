/**
 * @file
 * The note manager / note-effect manager, @c NoteEffectMgr.
 */

#pragma once

class MusicSheet;

/**
 * @brief The process-wide note manager: it owns the active chart, the live note render/effect
 * objects, and the running play counters.
 *
 * A lazily-created singleton (see @c shared). Only the fields the reconstructed methods touch are
 * modelled; the spans between them are the note-object pools and per-note render state, reserved to
 * preserve the 360-byte layout. The trailing @c // +0xNN comments document the original offsets for
 * reference only. The class is non-polymorphic, so the name is inferred from its methods rather than
 * confirmed from RTTI.
 * @ghidraAddress NoteEffectMgr (engine note manager, 360 bytes)
 */
class NoteEffectMgr {
public:
    /**
     * @brief The process-wide note manager, created on first use.
     * @return The shared note manager.
     * @ghidraAddress 0x136b9c
     */
    static NoteEffectMgr *shared();

    /**
     * @brief The current lane/combo field.
     * @ghidraAddress 0x13719c
     */
    int GetComboField() const {
        return m_nComboField;
    }

    /**
     * @brief The accumulated hit (judged-note) count.
     * @ghidraAddress 0x137ae4
     */
    int GetHitCount() const {
        return m_nHitCount;
    }
    /**
     * @brief Increments the hit count.
     * @ghidraAddress 0x137aec
     */
    void IncrementHitCount() {
        ++m_nHitCount;
    }
    /**
     * @brief Decrements the hit count (undo on a rewind or miss-revert).
     * @ghidraAddress 0x137afc
     */
    void DecrementHitCount() {
        --m_nHitCount;
    }

private:
    /**
     * @brief Constructs the manager: zeroes the header, clears the per-note render sub-table, sets
     * the six active-slot indices to the -1 empty marker, and seeds the font-variant flag.
     * @ghidraAddress 0x136bec
     */
    NoteEffectMgr();

    // The per-note render sub-table entry count and byte stride.
    static constexpr int kRenderEntryCount = 20;
    static constexpr int kRenderEntryStride = 0xc;
    // The empty marker held by an unused active-slot index.
    static constexpr long kActiveSlotNone = -1;

    unsigned char m_aReserved00[0x18] = {}; // +0x00: header state, still being worked out.
    int m_nComboField = {};                 // +0x18: the current lane/combo field.
    unsigned char m_aReserved1c[0xc] = {};  // +0x1c
    MusicSheet *m_pMusicSheet = {};         // +0x28: the bound active chart, or null.
    int m_nDensityTier = {};                // +0x30: the note-density tier (0, 1, or 2).
    unsigned char m_aReserved34[4] = {};    // +0x34
    // +0x38..+0x60: the six active-slot note indices, seeded to the -1 empty marker.
    long m_aActiveSlot[6] = {};          // +0x38
    unsigned char m_aReserved68[4] = {}; // +0x68
    // +0x6c..+0x157: the 20-entry per-note render sub-table (stride kRenderEntryStride).
    unsigned char m_aRenderTable[0xec] = {}; // +0x6c
    bool m_bFontVariant = {};                // +0x158: the device font variant.
    unsigned char m_aReserved159[7] = {};    // +0x159
    int m_nHitCount = {};                    // +0x160: the accumulated hit (judged-note) count.
    unsigned char m_aReserved164[4] = {};    // +0x164
};

// code: language=C++
// kate: hl C++;
// vim: set ft=cpp :
