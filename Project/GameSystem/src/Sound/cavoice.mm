#include "cavoice.h"

#include "casource.h"

/** @ghidraAddress 0x4ac40 */
unsigned long caVoice::FillPcm(void *pDst, int nCount) {
    if (m_pSource == nullptr || m_nState != kStatePlaying) {
        return 0;
    }
    const int nRead = m_pSource->ReadRingBuffer(pDst, nCount, &m_nBytesRead, &m_nReadPos);
    if (nRead == 0) {
        m_nState = kStateFinished;
        return 0;
    }
    return static_cast<unsigned long>(nRead);
}
