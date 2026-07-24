//
//  caplayermgr.mm
//  REFLEC BEAT plus
//
//  The one-shot voice-player subsystem (the caplayer engine's caPlayerMgr). Reconstructed from
//  Ghidra project rb458, program rb458. @ghidraAddress values are relative to the program image
//  base.
//

#include "caplayermgr.h"

#include "cacamixer.h"
#include "casound.h"

namespace {

// The source-category tag OR'd into every play handle returned from this one-shot entry point, so
// callers can tell which subsystem produced the handle.
constexpr unsigned int kOneShotSourceTag = 0x20000000;

// The sentinel returned when the sound index is out of range or unregistered.
constexpr unsigned int kInvalidHandle = 0xffffffff;

} // namespace

/** @ghidraAddress 0x4b998 */
unsigned int caPlayerMgr::PlaySoundByIndex(int index, int volume) {
    if (index >= m_nSourceCount || m_pSourceArray[index] == nullptr) {
        return kInvalidHandle;
    }
    return m_pMixer->FindFreeVoiceAndEnqueue(m_pSourceArray[index], volume) | kOneShotSourceTag;
}

/** @ghidraAddress 0x4b9d4 */
unsigned int caPlayerMgr::PlaySoundOnVoice(int resourceId, int busId, int volume) {
    if (resourceId < 0 || resourceId >= m_nSourceCount) {
        return kInvalidHandle;
    }
    caSource *pSource = m_pSourceArray[resourceId];
    if (pSource == nullptr) {
        return kInvalidHandle;
    }
    return m_pMixer->EnqueueVoiceBuffer(pSource, busId, volume) | kOneShotSourceTag;
}
