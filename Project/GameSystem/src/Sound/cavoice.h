/**
 * @file
 * @brief One Core Audio mixer playback voice, @c caVoice.
 */

#pragma once

class caSource;

/**
 * One playback voice (mixer bus): the sound bound to it, its ring-read cursors, a rolling
 * generation counter, and its playback state. The 32-bit offset comments are documentation only.
 * Reconstructed type @c caVoice: engine mixer-voice struct, 0x20 bytes.
 */
class caVoice {
public:
    /** @brief The voice playback states stored in @c m_nState. */
    enum State {
        kStateFree = -1,    /*!< No sound is bound to the voice. */
        kStatePrepared = 1, /*!< A sound is bound and ready to render. */
        kStatePlaying = 2,  /*!< The voice is playing. */
        kStatePaused = 3,   /*!< The voice is paused. */
        kStateFinished = 4, /*!< Playback has finished; the voice may be reused. */
    };

    /**
     * @brief Fills @p nCount bytes at @p pDst with the voice's next PCM span while it is playing,
     *        marking the voice finished when its source runs dry.
     *
     * A no-op (returns 0) when the voice has no source or is not in the playing state; otherwise it
     * pulls from the bound source's ring buffer through the voice's own read cursors.
     * @param pDst The output buffer to fill.
     * @param nCount The number of bytes to fill.
     * @return The number of bytes produced, or 0 when the source has drained.
     * @ghidraAddress 0x4ac40
     */
    unsigned long FillPcm(void *pDst, int nCount);

    /**
     * @brief The sound bound to this voice, or @c nullptr when free.
     * @return The bound sound, or @c nullptr when the voice is free.
     */
    caSource *GetSource() const {
        return m_pSource;
    }
    /**
     * @brief Binds (or clears with @c nullptr) the sound this voice plays.
     * @param pSource The sound to bind, or @c nullptr to free the voice.
     */
    void SetSource(caSource *pSource) {
        m_pSource = pSource;
    }

    /**
     * @brief Whether the render callback has been installed on this voice.
     * @return @c true once the render callback is installed.
     */
    bool IsCallbackBound() const {
        return m_bCallbackBound;
    }
    /**
     * @brief Records whether the render callback has been installed.
     * @param bBound @c true once the render callback is installed.
     */
    void SetCallbackBound(bool bBound) {
        m_bCallbackBound = bBound;
    }

    /**
     * @brief The rolling generation, packed into the play handle's low 16 bits.
     * @return The rolling generation.
     */
    unsigned short GetGeneration() const {
        return m_wGeneration;
    }
    /**
     * @brief Sets the rolling generation.
     * @param wGeneration The rolling generation.
     */
    void SetGeneration(unsigned short wGeneration) {
        m_wGeneration = wGeneration;
    }

    /**
     * @brief The voice's current playback state, one of @c State.
     * @return The voice's playback state.
     */
    int GetState() const {
        return m_nState;
    }
    /**
     * @brief Sets the voice's playback state.
     * @param nState The playback state, one of @c State.
     */
    void SetState(int nState) {
        m_nState = nState;
    }

    /** @brief Resets both ring-read cursors to the start of the source data. */
    void ResetReadCursors() {
        m_nBytesRead = 0;
        m_nReadPos = 0;
    }

private:
    caSource *m_pSource = {};   // +0x00: the sound bound to this voice, or nullptr when free.
    bool m_bCallbackBound = {}; // +0x04: whether the render callback is installed.
    // unsigned char m_aReserved05[7] = {}; // +0x05
    int m_nBytesRead = {};             // +0x0c: running consumed-byte counter for the ring read.
    int m_nReadPos = {};               // +0x10: current read offset into the source PCM block.
    unsigned short m_wGeneration = {}; // +0x14: rolling generation, packed into the play handle.
    // unsigned char m_aReserved16[2] = {}; // +0x16
    int m_nState = {}; // +0x18: one of State.
    // unsigned char m_aReserved1c[4] = {}; // +0x1c
};

// code: language=Objective-C++
// kate: hl Objective-C++;
// vim: set ft=objcpp :
