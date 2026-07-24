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
    /** @brief The voice playback states stored in @c m_nState. */
    enum State {
        kStateFree = -1,    /*!< No sound is bound to the voice. */
        kStatePrepared = 1, /*!< A sound is bound and ready to render. */
        kStateFinished = 4, /*!< Playback has finished; the voice may be reused. */
    };

    /** @brief The sound bound to this voice, or @c nullptr when free. */
    caSource *m_pSource = {}; // +0x00
    /** @brief Whether the render callback has been installed on this voice. */
    bool m_bCallbackBound = {};          // +0x04
    unsigned char m_aReserved05[7] = {}; // +0x05
    unsigned int m_dwBytesRead = {};     // +0x0c running consumed-byte counter for the ring read
    unsigned int m_dwReadPos = {};       // +0x10 current read offset into the source PCM block
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

private:
    unsigned char m_aReserved00[0x18] = {}; // +0x00
    AudioUnit m_pMixerUnit = {};            // +0x18 the spatial-mixer AudioUnit
    unsigned char m_aReserved20[4] = {};    // +0x20
    int m_nVoiceCount = {};                 // +0x24 the number of voices/buses
    caVoice **m_pVoiceArray = {};           // +0x28 the per-bus voice slots
};

// code: language=Objective-C++
// kate: hl Objective-C++;
// vim: set ft=objcpp :
