/**
 * @file
 * The xorshift128 pseudo-random number generator, @c Random.
 */

#pragma once

/**
 * @brief A xorshift128 pseudo-random number generator.
 *
 * Holds four 32-bit state words advanced by the xorshift128 algorithm. Construct it for the
 * canonical default seed, or call @c SetSeed to reseed the fourth state word. The trailing
 * @c // +0xNN comments document the original 32-bit member offsets for reference only.
 */
class Random {
public:
    /**
     * @brief Constructs the generator with the canonical default xorshift128 seed.
     * @ghidraAddress 0x85824
     */
    Random();
    /**
     * @brief Destroys the generator. The class is polymorphic, so the destructor is virtual (the
     * binary keeps a one-slot vtable whose entry is a no-op).
     * @ghidraAddress 0x8584c
     */
    virtual ~Random();

    /**
     * @brief Reseed the generator, fixing the first three state words and taking the fourth from
     * @p dwSeed.
     * @param dwSeed The seed value stored as the fourth state word.
     * @ghidraAddress 0x85854
     */
    void SetSeed(unsigned int dwSeed);

    /**
     * @brief Advance the generator and return a value in the inclusive range @c [0, nMax].
     * @param nMax The inclusive upper bound; must be non-negative.
     * @return A pseudo-random value in @c [0, nMax].
     * @ghidraAddress 0x8587c
     */
    int GetRandRangeInt(int nMax);
    /**
     * @brief Advance the generator and return a value in the inclusive range @c [nMin, nMax].
     * @param nMin The inclusive lower bound.
     * @param nMax The inclusive upper bound; must be at least @p nMin.
     * @return A pseudo-random value in @c [nMin, nMax].
     * @ghidraAddress 0x858f0
     */
    int GetRandRangeInt(int nMin, int nMax);
    /**
     * @brief Return a value in the half-open range @c [0, nMaxExclusive).
     * @param nMaxExclusive The exclusive upper bound.
     * @return A pseudo-random value in @c [0, nMaxExclusive).
     * @ghidraAddress 0x858e8
     */
    int GetRandomBelow(int nMaxExclusive);
    /**
     * @brief Return a value in the half-open range @c [nMin, nMaxExclusive).
     * @param nMin The inclusive lower bound.
     * @param nMaxExclusive The exclusive upper bound.
     * @return A pseudo-random value in @c [nMin, nMaxExclusive).
     * @ghidraAddress 0x8593c
     */
    int GetRandomRangeExclusive(int nMin, int nMaxExclusive);

private:
    // +0x00: implicit vtable pointer (from the virtual destructor above).
    unsigned int m_nState0 = {}; // +0x08
    unsigned int m_nState1 = {}; // +0x0c
    unsigned int m_nState2 = {}; // +0x10
    unsigned int m_nState3 = {}; // +0x14
};

// code: language=C++
// kate: hl C++;
// vim: set ft=cpp :
