/**
 * @file
 * The xorshift128 pseudo-random number generator, @c Random.
 */

#pragma once

/**
 * A xorshift128 pseudo-random number generator.
 *
 * Holds four 32-bit state words advanced by the xorshift128 algorithm. Construct it for the
 * canonical default seed, or call @c SetSeed to reseed the fourth state word.
 */
class Random {
public:
    /**
     * Constructs the generator with the canonical default xorshift128 seed.
     * @ghidraAddress 0x85824
     */
    Random();
    /**
     * Destroys the generator. The class is polymorphic, so the destructor is virtual (the
     * binary keeps a one-slot vtable whose entry is a no-op).
     * @ghidraAddress 0x8584c
     */
    virtual ~Random();

    /**
     * Reseed the generator, fixing the first three state words and taking the fourth from
     * @p dwSeed.
     * @param dwSeed The seed value stored as the fourth state word.
     * @ghidraAddress 0x85854
     */
    void SetSeed(unsigned int dwSeed);

    /**
     * Advance the generator and return a value in the inclusive range @c [0, nMax].
     * @param nMax The inclusive upper bound; must be non-negative.
     * @return A pseudo-random value in @c [0, nMax].
     * @ghidraAddress 0x8587c
     */
    int GetRandRangeInt(int nMax);
    /**
     * Advance the generator and return a value in the inclusive range @c [nMin, nMax].
     * @param nMin The inclusive lower bound.
     * @param nMax The inclusive upper bound; must be at least @p nMin.
     * @return A pseudo-random value in @c [nMin, nMax].
     * @ghidraAddress 0x858f0
     */
    int GetRandRangeInt(int nMin, int nMax);
    /**
     * Return a value in the half-open range @c [0, nMaxExclusive).
     * @param nMaxExclusive The exclusive upper bound.
     * @return A pseudo-random value in @c [0, nMaxExclusive).
     * @ghidraAddress 0x858e8
     */
    int GetRandomBelow(int nMaxExclusive);
    /**
     * Return a value in the half-open range @c [nMin, nMaxExclusive).
     * @param nMin The inclusive lower bound.
     * @param nMaxExclusive The exclusive upper bound.
     * @return A pseudo-random value in @c [nMin, nMaxExclusive).
     * @ghidraAddress 0x8593c
     */
    int GetRandomRangeExclusive(int nMin, int nMaxExclusive);

private:
    unsigned int m_nState0 = {};
    unsigned int m_nState1 = {};
    unsigned int m_nState2 = {};
    unsigned int m_nState3 = {};
};
