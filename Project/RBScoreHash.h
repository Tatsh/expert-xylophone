#ifndef RBSCOREHASH_H
#define RBSCOREHASH_H

// Shared layout of the eight-word MD5 tamper-hash scramble buffer used by the score and history
// record integrity checks. Both ScoreData and History fold a tune identifier and a set of
// per-record figures into this same eight-word buffer and hash it, so the buffer geometry is
// declared once here.

/**
 * @brief The number of 32-bit words folded into a tamper-hash scramble buffer.
 */
enum { kHashWordCount = 8 };

/**
 * @brief The length in bytes of the MD5 digest a tamper-hash builder produces.
 */
enum { kHashDigestLength = 16 };

/**
 * @brief The word-buffer slot each figure occupies in a tamper hash.
 *
 * Slot 0 always holds the tune identifier in every builder. The remaining slots hold different
 * figures depending on the builder (per-difficulty score words in ScoreData, per-play statistic
 * words in History), so no single content name fits every caller and they are named positionally.
 */
enum {
    kHashWordTuneID = 0, /*!< The tune identifier (shared by every builder). */
    kHashWordSlot1 = 1,  /*!< The second scramble slot. */
    kHashWordSlot2 = 2,  /*!< The third scramble slot. */
    kHashWordSlot3 = 3,  /*!< The fourth scramble slot. */
    kHashWordSlot4 = 4,  /*!< The fifth scramble slot. */
    kHashWordSlot5 = 5,  /*!< The sixth scramble slot. */
    kHashWordSlot6 = 6,  /*!< The seventh scramble slot. */
    kHashWordSlot7 = 7,  /*!< The eighth scramble slot. */
};

#endif

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
