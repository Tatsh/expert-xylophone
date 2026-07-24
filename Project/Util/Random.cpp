#include "Random.h"

#include <cassert>

// The canonical xorshift128 seed words the generator starts from; SetSeed replaces only the fourth.
constexpr unsigned int kDefaultSeed0 = 0x075BCD15;
constexpr unsigned int kDefaultSeed1 = 0x159A55E5;
constexpr unsigned int kDefaultSeed2 = 0x1F123BB5;
constexpr unsigned int kDefaultSeed3 = 0x05491333;

// The xorshift128 shift amounts.
constexpr int kXorShiftA = 11;
constexpr int kXorShiftB = 8;
constexpr int kXorShiftC = 19;

// Mask that drops the sign bit so the generated value is non-negative.
constexpr unsigned int kNonNegativeMask = 0x7fffffff;

Random::Random() {
    m_nState0 = kDefaultSeed0;
    m_nState1 = kDefaultSeed1;
    m_nState2 = kDefaultSeed2;
    m_nState3 = kDefaultSeed3;
}

Random::~Random() = default;

void Random::SetSeed(unsigned int dwSeed) {
    m_nState0 = kDefaultSeed0;
    m_nState1 = kDefaultSeed1;
    m_nState2 = kDefaultSeed2;
    m_nState3 = dwSeed;
}

int Random::GetRandRangeInt(int nMax) {
    assert(nMax >= 0);
    // xorshift128: advance the four state words, folding the outgoing first word and the incoming
    // last word into the new state word.
    unsigned int t = m_nState0;
    t ^= t << kXorShiftA;
    m_nState0 = m_nState1;
    m_nState1 = m_nState2;
    const unsigned int w = m_nState3;
    m_nState2 = w;
    t = t ^ (t >> kXorShiftB) ^ w ^ (w >> kXorShiftC);
    m_nState3 = t;
    // Reduce the non-negative value modulo (nMax + 1), computed as the binary does with a guarded
    // divisor rather than the % operator.
    const int nValue = static_cast<int>(t & kNonNegativeMask);
    const int nRange = nMax + 1;
    const int nQuotient = (nRange != 0) ? nValue / nRange : 0;
    return nValue - nQuotient * nRange;
}

int Random::GetRandRangeInt(int nMin, int nMax) {
    assert(nMin <= nMax);
    return GetRandRangeInt(nMax - nMin) + nMin;
}

int Random::GetRandomBelow(int nMaxExclusive) {
    return GetRandRangeInt(nMaxExclusive - 1);
}

int Random::GetRandomRangeExclusive(int nMin, int nMaxExclusive) {
    return GetRandRangeInt(nMin, nMaxExclusive - 1);
}
