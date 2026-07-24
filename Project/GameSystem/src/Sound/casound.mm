//
//  casound.mm
//  REFLEC BEAT plus
//
//  A decoded one-shot sound buffer (the caplayer engine's caSource). Reconstructed from Ghidra
//  project rb458, program rb458. @ghidraAddress values are relative to the program image base.
//

#include "casound.h"

#include <cstring>

#import <AudioToolbox/AudioToolbox.h>

namespace {

// The client PCM format the source is decoded to: 16-bit signed packed linear PCM, one frame per
// packet, so a frame is two bytes per channel.
constexpr int kClientBitsPerChannel = 16;
constexpr int kClientBytesPerChannel = kClientBitsPerChannel / 8;

// The largest signed allocation the decode buffer is clamped to, matching the binary's overflow
// guard.
constexpr long kMaxAllocation = 0x7fffffff;

} // namespace

/** @ghidraAddress 0x4d39c */
caSource::~caSource() {
    // Free the decoded PCM block; the binary clears the pointer and size afterwards, which the
    // object's destruction makes moot.
    delete[] static_cast<unsigned char *>(m_pBuffer);
}

/** @ghidraAddress 0x4d368 */
int caSource::FreeBuffer() {
    delete[] static_cast<unsigned char *>(m_pBuffer);
    m_pBuffer = nullptr;
    m_dwBufferSize = 0;
    return 1;
}

/** @ghidraAddress 0x4d3d0 */
int caSource::LoadFromPath(const char *szPath, bool bLoop) {
    // Build a file URL from the path and load through it; a path that does not form a URL fails.
    CFURLRef url =
        CFURLCreateFromFileSystemRepresentation(kCFAllocatorDefault,
                                                reinterpret_cast<const UInt8 *>(szPath),
                                                static_cast<CFIndex>(std::strlen(szPath)),
                                                false);
    if (url == nullptr) {
        return 0;
    }
    const int nResult = LoadFromUrl(url, bLoop);
    CFRelease(url);
    return nResult;
}

/** @ghidraAddress 0x4d450 */
int caSource::LoadFromUrl(CFURLRef url, bool bLoop) {
    m_bLoop = bLoop;
    ExtAudioFileRef hAudioFile = nullptr;
    ExtAudioFileOpenURL(url, &hAudioFile);
    AudioStreamBasicDescription asbd = {};
    int nResult = 0;
    if (ReadAudioFormat(hAudioFile, &asbd) != 0) {
        nResult = ReadAudioPcmData(hAudioFile, &asbd);
    }
    ExtAudioFileDispose(hAudioFile);
    return nResult;
}

/** @ghidraAddress 0x4d4c4 */
int caSource::ReadAudioFormat(ExtAudioFileRef hAudioFile, AudioStreamBasicDescription *pAsbd) {
    UInt32 nPropertySize = sizeof(AudioStreamBasicDescription);
    if (ExtAudioFileGetProperty(
            hAudioFile, kExtAudioFileProperty_FileDataFormat, &nPropertySize, pAsbd) != noErr) {
        return 0;
    }
    SInt64 nFileLengthFrames = 0;
    nPropertySize = sizeof(nFileLengthFrames);
    if (ExtAudioFileGetProperty(hAudioFile,
                                kExtAudioFileProperty_FileLengthFrames,
                                &nPropertySize,
                                &nFileLengthFrames) != noErr) {
        return 0;
    }

    // Set the client format to 16-bit signed packed linear PCM, keeping the file's sample rate and
    // channel count.
    pAsbd->mFormatID = kAudioFormatLinearPCM;
    pAsbd->mFormatFlags = kLinearPCMFormatFlagIsSignedInteger | kLinearPCMFormatFlagIsPacked;
    pAsbd->mBitsPerChannel = kClientBitsPerChannel;
    const UInt32 nBytesPerFrame = pAsbd->mChannelsPerFrame * kClientBytesPerChannel;
    pAsbd->mFramesPerPacket = 1;
    pAsbd->mBytesPerFrame = nBytesPerFrame;
    pAsbd->mBytesPerPacket = nBytesPerFrame;

    m_dwBufferSize = static_cast<unsigned int>(nFileLengthFrames) * nBytesPerFrame;
    m_nChannelCount = static_cast<int>(pAsbd->mChannelsPerFrame);
    m_dSampleRate = pAsbd->mSampleRate;
    return 1;
}

/** @ghidraAddress 0x4d58c */
int caSource::ReadAudioPcmData(ExtAudioFileRef hAudioFile, AudioStreamBasicDescription *pAsbd) {
    if (m_dwBufferSize == 0) {
        return 0;
    }

    // Reallocate and zero the PCM buffer sized by ReadAudioFormat (the allocation is clamped to the
    // maximum signed size, matching the binary's overflow guard).
    if (m_pBuffer != nullptr) {
        delete[] static_cast<unsigned char *>(m_pBuffer);
        m_pBuffer = nullptr;
    }
    const auto nByteSize = static_cast<int>(m_dwBufferSize);
    const size_t nAllocation =
        static_cast<long>(nByteSize) < 0 ? static_cast<size_t>(kMaxAllocation) : nByteSize;
    m_pBuffer = new unsigned char[nAllocation];
    std::memset(m_pBuffer, 0, static_cast<size_t>(nByteSize));

    if (ExtAudioFileSetProperty(hAudioFile,
                                kExtAudioFileProperty_ClientDataFormat,
                                sizeof(AudioStreamBasicDescription),
                                pAsbd) != noErr) {
        return 0;
    }

    // Read frames into the buffer until it is full: each pass points a one-buffer AudioBufferList at
    // the next unfilled span and reads as many frames as remain.
    int nRemaining = static_cast<int>(m_dwBufferSize);
    if (nRemaining < 1) {
        return 1;
    }
    int nConsumed = 0;
    while (true) {
        const UInt32 nBytesPerFrame = pAsbd->mBytesPerFrame;
        UInt32 nFramesToRead = nBytesPerFrame != 0 ? nRemaining / nBytesPerFrame : 0;

        AudioBufferList bufferList;
        bufferList.mNumberBuffers = 1;
        bufferList.mBuffers[0].mNumberChannels = static_cast<UInt32>(m_nChannelCount);
        bufferList.mBuffers[0].mDataByteSize = static_cast<UInt32>(nRemaining);
        bufferList.mBuffers[0].mData = static_cast<unsigned char *>(m_pBuffer) + nConsumed;

        if (ExtAudioFileRead(hAudioFile, &nFramesToRead, &bufferList) != noErr) {
            return 0;
        }
        const int nBytesRead = static_cast<int>(pAsbd->mBytesPerFrame * nFramesToRead);
        nConsumed += nBytesRead;
        nRemaining -= nBytesRead;
        if (nRemaining < 1) {
            return 1;
        }
    }
}

/** @ghidraAddress 0x4d698 */
int caSource::ReadRingBuffer(void *pDst, int nCount, int *pTotalRead, int *pReadPos) {
    int nReadPos = *pReadPos;
    int nTotalCopied = 0;
    auto *pOut = static_cast<unsigned char *>(pDst);
    while (nCount != 0) {
        // Clamp this chunk so it does not run past the end of the PCM block.
        int nChunk = nCount;
        if (nReadPos + nChunk >= static_cast<int>(m_dwBufferSize)) {
            nChunk = static_cast<int>(m_dwBufferSize) - nReadPos;
        }
        if (nChunk != 0) {
            std::memcpy(pOut, static_cast<unsigned char *>(m_pBuffer) + nReadPos, nChunk);
        }
        nTotalCopied += nChunk;
        nReadPos += nChunk;
        *pReadPos = nReadPos;
        *pTotalRead += nChunk;
        pOut += nChunk;
        nCount -= nChunk;
        if (nCount == 0) {
            break;
        }
        // More was requested than remained: a non-looping sound stops here; a looping sound wraps
        // the read position (and its consumed counter) back to the start and continues.
        if (!m_bLoop) {
            break;
        }
        nReadPos = 0;
        *pReadPos = 0;
        *pTotalRead = 0;
    }
    return nTotalCopied;
}
