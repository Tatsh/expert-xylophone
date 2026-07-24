/**
 * @file
 * A decoded one-shot sound buffer, @c caSource.
 */

#pragma once

#import <AudioToolbox/AudioToolbox.h>

/**
 * A single decoded sound: the source file's sample rate and channel count, and the fully-decoded
 * 16-bit signed PCM data block. Populated from an @c ExtAudioFileRef by @c ReadAudioFormat (which
 * fills the format fields and computes the buffer size) and @c ReadAudioPcmData (which allocates
 * and decodes the PCM).
 * @ghidraAddress caSource (engine sound-buffer struct)
 */
class caSource {
public:
    /**
     * @brief Constructs an empty sound buffer with all fields zeroed.
     * @ghidraAddress 0x4d350
     */
    caSource() = default;
    /**
     * @brief Frees the decoded PCM data block.
     * @ghidraAddress 0x4d39c
     */
    ~caSource();

    /**
     * @brief Loads a sound file at a filesystem path into this buffer.
     * @param szPath The NUL-terminated file path.
     * @param bLoop Whether ring reads of the decoded data should loop.
     * @return Non-zero on success, 0 on failure or a path that does not form a URL.
     * @ghidraAddress 0x4d3d0
     */
    int LoadFromPath(const char *szPath, bool bLoop);

    /**
     * @brief Opens the sound file at @p url, reads its format, and decodes the whole PCM block.
     * @param url The source file URL.
     * @param bLoop Whether ring reads of the decoded data should loop.
     * @return The decoded byte count, or 0 when the format read fails.
     * @ghidraAddress 0x4d450
     */
    int LoadFromUrl(CFURLRef url, bool bLoop);

    /**
     * @brief Reads the source file's data format into @p pAsbd and derives the decoded PCM buffer
     *        size.
     *
     * Queries the file's data format and length, sets @p pAsbd to the client 16-bit signed packed
     * LPCM format, and records the sample rate, channel count, and total byte size to decode.
     * @param hAudioFile The opened source file.
     * @param pAsbd The stream description to fill with the client format.
     * @return @c 1 on success, @c 0 when a property query fails.
     * @ghidraAddress 0x4d4c4
     */
    int ReadAudioFormat(ExtAudioFileRef hAudioFile, AudioStreamBasicDescription *pAsbd);

    /**
     * @brief Decodes the whole source file into the PCM data block sized by @c ReadAudioFormat.
     *
     * Allocates and zeroes the PCM buffer, sets the client data format on the file, and reads frames
     * in a loop until the buffer is full.
     * @param hAudioFile The opened source file.
     * @param pAsbd The client stream description set by @c ReadAudioFormat.
     * @return @c 1 on success, @c 0 on an empty size or read error.
     * @ghidraAddress 0x4d58c
     */
    int ReadAudioPcmData(ExtAudioFileRef hAudioFile, AudioStreamBasicDescription *pAsbd);

    /**
     * @brief Copies @p nCount bytes out of the decoded PCM block as a ring buffer, wrapping at the
     *        end when the sound loops.
     *
     * Reads from @p pReadPos, advancing it and @p pTotalRead. When the read reaches the end of the
     * PCM block: a non-looping sound stops and returns the bytes read so far; a looping sound wraps
     * the read position to the start and continues.
     * @param pDst The destination buffer.
     * @param nCount The number of bytes requested.
     * @param pTotalRead The running consumed-byte counter (advanced, reset to 0 on a loop wrap).
     * @param pReadPos The current read offset into the PCM block (advanced, wrapped on loop).
     * @return The total number of bytes copied.
     * @ghidraAddress 0x4d698
     */
    int ReadRingBuffer(void *pDst, int nCount, int *pTotalRead, int *pReadPos);

    /** @brief The source sample rate, in hertz. */
    double GetSampleRate() const {
        return m_dSampleRate;
    }
    /** @brief The number of channels in the decoded PCM. */
    int GetChannelCount() const {
        return m_nChannelCount;
    }

private:
    double m_dSampleRate = {}; // +0x00 the source sample rate, in hertz
    int m_nChannelCount = {};  // +0x08 the number of channels
    bool m_bLoop = {};         // +0x0c whether ring reads wrap at the end of the PCM block
    unsigned char m_aReserved0d[3] = {}; // +0x0d
    void *m_pBuffer = {};                // +0x10 the decoded 16-bit PCM data block
    unsigned int m_dwBufferSize = {};    // +0x14 the PCM data block's byte size
};

// code: language=Objective-C++
// kate: hl Objective-C++;
// vim: set ft=objcpp :
