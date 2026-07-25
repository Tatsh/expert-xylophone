/**
 * @file
 * The note-chart reader/parser, @c MusicSheet.
 */

#pragma once

struct RbffNoteRecord;

/**
 * @brief The note-chart reader: parses an RBFF chart blob into a pool of note records and holds the
 * per-chart timing and lane state the play field reads.
 *
 * A polymorphic engine object whose full field layout is still being worked out; only the note-pool
 * members the record accessor needs are modelled so far, and the surrounding state is kept as
 * reserved spans to preserve the object's layout. The constructor, destructor, and parse family are
 * not yet reconstructed. The trailing @c // +0xNN comments document the original offsets for
 * reference only.
 */
class MusicSheet {
public:
    /**
     * @brief Returns the note record at @p nIndex, or null when the index is out of range.
     * @param nIndex The note-record index.
     * @return The note record, or null.
     * @ghidraAddress 0x13183c
     */
    RbffNoteRecord *GetNoteRecordByIndex(int nIndex);

    /** @brief The byte stride between note records in the pool (@c sizeof(RbffNoteRecord)). */
    static constexpr int kNoteRecordStride = 0xb8;

private:
    // +0x00 is the vtable pointer, and +0x08..+0x27 is the embedded stream-reader sub-object, both
    // still being worked out.
    unsigned char m_aReserved00[0x28] = {}; // +0x00
    int m_nNoteCount = {};                  // +0x28: the number of note records in the pool.
    // +0x2c..+0x67: further chart state (version, timing, and lane fields), still being worked out.
    unsigned char m_aReserved2c[0x3c] = {}; // +0x2c
    RbffNoteRecord *m_pNotePool = {};       // +0x68: the note-record pool (kNoteRecordStride each).
};

// code: language=C++
// kate: hl C++;
// vim: set ft=cpp :
