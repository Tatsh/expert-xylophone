//
//  cavoice.mm
//  REFLEC BEAT plus
//
//  One Core Audio mixer playback voice (the caplayer engine's caVoice). Reconstructed from Ghidra
//  project rb458, program rb458. @ghidraAddress values are relative to the program image base.
//

#include "cavoice.h"

#include "casource.h"

/** @ghidraAddress 0x4ac40 */
unsigned long caVoice::FillPcm(void *pDst, int nCount) {
    // Only a playing voice with a bound source produces samples.
    if (m_pSource == nullptr || m_nState != kStatePlaying) {
        return 0;
    }
    // Pull the next span from the source's ring buffer through this voice's own read cursors; a
    // zero-byte read means the source has drained, so the voice is marked finished.
    const int nRead = m_pSource->ReadRingBuffer(pDst, nCount, &m_nBytesRead, &m_nReadPos);
    if (nRead == 0) {
        m_nState = kStateFinished;
        return 0;
    }
    return static_cast<unsigned long>(nRead);
}
