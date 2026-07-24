/**
 * @file
 * The Core Audio voice mixer, @c caCAMixer, and its per-voice slot, @c caVoice.
 */

#pragma once

#import <AudioToolbox/AudioToolbox.h>

class caSource;

/**
 * One playback voice (mixer bus): the sound bound to it, its ring-read cursors, a rolling
 * generation counter, and its playback state. The 32-bit offset comments are documentation only.
 * @ghidraAddress caVoice (engine mixer-voice struct, 0x20 bytes)
 */
class caVoice {
public:
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

    /** @brief The voice playback states stored in @c m_nState. */
    enum State {
        kStateFree = -1,    /*!< No sound is bound to the voice. */
        kStatePrepared = 1, /*!< A sound is bound and ready to render. */
        kStatePlaying = 2,  /*!< The voice is playing. */
        kStatePaused = 3,   /*!< The voice is paused. */
        kStateFinished = 4, /*!< Playback has finished; the voice may be reused. */
    };

    /** @brief The sound bound to this voice, or @c nullptr when free. */
    caSource *m_pSource = {}; // +0x00
    /** @brief Whether the render callback has been installed on this voice. */
    bool m_bCallbackBound = {};          // +0x04
    unsigned char m_aReserved05[7] = {}; // +0x05
    int m_nBytesRead = {};               // +0x0c running consumed-byte counter for the ring read
    int m_nReadPos = {};                 // +0x10 current read offset into the source PCM block
    unsigned short m_wGeneration = {};   // +0x14 rolling generation, packed into the play handle
    unsigned char m_aReserved16[2] = {}; // +0x16
    int m_nState = {};                   // +0x18 one of State
    unsigned char m_aReserved1c[4] = {}; // +0x1c
};

/**
 * The Core Audio voice mixer: a spatial-mixer AudioUnit and its array of playback voices. The
 * former free engine functions that took the mixer as their first argument are its instance
 * methods. Only the members those methods touch are modelled; the 32-bit offset comments are
 * documentation only.
 * @ghidraAddress caCAMixer (engine class)
 */
class caCAMixer {
public:
    /**
     * @brief Binds a sound to voice @p nBus and prepares it to play, returning its play handle.
     *
     * Reuses the voice only when it is free or finished: stores the source, bumps the generation,
     * builds the signed-16-bit LPCM stream format from the source's rate and channel count, applies
     * it to the mixer bus, installs the render callback, applies the volume gain, resets the read
     * cursors, and marks the voice prepared. The handle packs the generation in its low 16 bits and
     * the bus in bits 16 and up.
     * @param pSource The sound to bind.
     * @param nBus The voice/bus index.
     * @param nVolume The gain-table index.
     * @return The play handle, or @c 0xffffffff when the bus is busy or the AudioUnit config fails.
     * @ghidraAddress 0x4b084
     */
    unsigned int EnqueueVoiceBuffer(caSource *pSource, int nBus, int nVolume);

    /**
     * @brief Binds @p pSource to the first free or finished voice and prepares it, returning its
     *        play handle, or @c 0xffffffff when every voice is busy.
     * @param pSource The sound to bind.
     * @param nVolume The gain-table index.
     * @ghidraAddress 0x4b238
     */
    unsigned int FindFreeVoiceAndEnqueue(caSource *pSource, int nVolume);

    /**
     * @brief Moves the prepared or paused voice named by @p hVoice to playing.
     * @param hVoice The raw handle (voice index in bits 16+, generation in the low 16).
     * @return @c 1 when the voice matched and started, @c 0 otherwise.
     * @ghidraAddress 0x4b28c
     */
    unsigned int StartVoice(unsigned int hVoice);
    /**
     * @brief Marks the voice named by @p hVoice finished (stopped).
     * @return @c 1 when the voice matched, @c 0 otherwise.
     * @ghidraAddress 0x4b2e4
     */
    unsigned int StopVoice(unsigned int hVoice);
    /**
     * @brief Pauses the voice named by @p hVoice.
     * @return @c 1 when the voice matched, @c 0 otherwise.
     * @ghidraAddress 0x4b32c
     */
    unsigned int PauseVoice(unsigned int hVoice);
    /**
     * @brief Returns the playback state of the voice named by @p hVoice, or @c -1 when the handle
     *        does not resolve to a live voice.
     * @ghidraAddress 0x4b374
     */
    int GetVoiceState(unsigned int hVoice);
    /**
     * @brief Frees the voice named by @p hVoice (marks it finished and drops its source) so a later
     *        @c FindFreeVoiceAndEnqueue can recycle it. Always returns @c 1.
     * @ghidraAddress 0x4b42c
     */
    unsigned int StopAndClearVoice(unsigned int hVoice);

    /**
     * @brief Installs the per-voice render callback on the mixer AudioUnit for voice @p nBus, once.
     *
     * The callback (@c RenderVoiceAudioCallback) is bound with the voice as its reference so the
     * render loop can pull PCM for it; it is installed only once per voice.
     * @param nBus The voice/bus index.
     * @ghidraAddress 0x4b174
     */
    void InstallVoiceRenderCallback(int nBus);

    /**
     * @brief Applies the gain-table entry @p nVolume to voice @p nBus's mixer bus.
     *
     * Sets the spatial-mixer gain parameter (id 3, output scope) to the looked-up gain value. The
     * binary's "pan" naming is a misnomer: parameter 3 on the spatial mixer is the master gain.
     * @param nVolume The gain-table index.
     * @param nBus The voice/bus index.
     * @return @c true on success, @c false when the bus is out of range or the set fails.
     * @ghidraAddress 0x4b1e8
     */
    bool ApplyVoicePanParam(int nVolume, int nBus);

    /**
     * @brief Builds the AUGraph: a 3D spatial mixer feeding the RemoteIO output unit.
     * @return @c true when every Core Audio call succeeded.
     * @ghidraAddress 0x4acd0
     */
    bool BuildAudioUnitGraph();
    /**
     * @brief Sizes the mixer to @p nVoiceCount buses, allocates the voice slots, sets the output
     *        stream format, and initialises the graph.
     * @param nVoiceCount The number of mixer buses/voices (must be below 4096).
     * @return @c true on success, @c false on an oversized count or a Core Audio failure.
     * @ghidraAddress 0x4adb4
     */
    bool ConfigureAudioUnitGraph(int nVoiceCount);

    /**
     * @brief Starts the graph (once) and applies the default master gain.
     *
     * The compiler emits this both inlined at @c 0x4af6c and as an out-of-line thunk at @c 0x4aff8;
     * both collapse to this one method.
     * @ghidraAddress 0x4af6c
     * @ghidraAddress 0x4aff8
     */
    void Start();
    /**
     * @brief Stops the graph when it is running.
     * @ghidraAddress 0x4afc4
     */
    void Stop();

private:
    // Resolves a raw play handle to its live voice (index in the high bits, generation in the low
    // 16), or @c nullptr when the index is out of range or the generation is stale.
    caVoice *ResolveVoice(unsigned int hVoice);

    AUGraph m_pAUGraph = {};             // +0x00 the Core Audio processing graph
    AUNode m_nOutputNode = {};           // +0x08 the RemoteIO output node
    AUNode m_nMixerNode = {};            // +0x0c the 3D spatial-mixer node
    AudioUnit m_pOutputUnit = {};        // +0x10 the RemoteIO output AudioUnit
    AudioUnit m_pMixerUnit = {};         // +0x18 the spatial-mixer AudioUnit
    bool m_bIsRunning = {};              // +0x20 whether the graph is started
    unsigned char m_aReserved21[3] = {}; // +0x21
    int m_nVoiceCount = {};              // +0x24 the number of voices/buses
    caVoice **m_pVoiceArray = {};        // +0x28 the per-bus voice slots
};

// code: language=Objective-C++
// kate: hl Objective-C++;
// vim: set ft=objcpp :
