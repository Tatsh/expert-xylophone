/**
 * @file
 * The Core Audio voice mixer, @c caCAMixer.
 */

#pragma once

#import <AudioToolbox/AudioToolbox.h>

#include "cavoice.h"

class caSource;

/**
 * The Core Audio voice mixer: a spatial-mixer AudioUnit and its array of playback voices.
 *
 * The former free engine functions that took the mixer as their first argument are its instance
 * methods. Only the members those methods touch are modelled; the 32-bit offset comments are
 * documentation only.
 * Reconstructed type @c caCAMixer: engine class.
 */
class caCAMixer {
public:
    /**
     * Binds a sound to voice @p nBus and prepares it to play, returning its play handle.
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
     * Binds @p pSource to the first free or finished voice and prepares it, returning its
     *        play handle, or @c 0xffffffff when every voice is busy.
     * @param pSource The sound to bind.
     * @param nVolume The gain-table index.
     * @return The play handle, or @c 0xffffffff when every voice is busy.
     * @ghidraAddress 0x4b238
     */
    unsigned int FindFreeVoiceAndEnqueue(caSource *pSource, int nVolume);

    /**
     * Moves the prepared or paused voice named by @p hVoice to playing.
     * @param hVoice The raw handle (voice index in bits 16+, generation in the low 16).
     * @return @c 1 when the voice matched and started, @c 0 otherwise.
     * @ghidraAddress 0x4b28c
     */
    unsigned int StartVoice(unsigned int hVoice);
    /**
     * Marks the voice named by @p hVoice finished (stopped).
     * @param hVoice The play handle of the voice to stop.
     * @return @c 1 when the voice matched, @c 0 otherwise.
     * @ghidraAddress 0x4b2e4
     */
    unsigned int StopVoice(unsigned int hVoice);
    /**
     * Pauses the voice named by @p hVoice.
     * @param hVoice The play handle of the voice to pause.
     * @return @c 1 when the voice matched, @c 0 otherwise.
     * @ghidraAddress 0x4b32c
     */
    unsigned int PauseVoice(unsigned int hVoice);
    /**
     * Returns the playback state of the voice named by @p hVoice, or @c -1 when the handle
     *        does not resolve to a live voice.
     * @param hVoice The play handle of the voice to query.
     * @return The voice's playback state, or @c -1 when the handle does not resolve.
     * @ghidraAddress 0x4b374
     */
    int GetVoiceState(unsigned int hVoice);
    /**
     * Frees the voice named by @p hVoice (marks it finished and drops its source) so a later
     *        @c FindFreeVoiceAndEnqueue can recycle it. Always returns @c 1.
     * @param hVoice The play handle of the voice to free.
     * @return Always @c 1.
     * @ghidraAddress 0x4b42c
     */
    unsigned int StopAndClearVoice(unsigned int hVoice);

    /**
     * Detaches @p pSource from every voice that currently references it.
     *
     * Clears the bound-source pointer (leaving the voice state untouched) so no active voice reads
     * the buffer's PCM data after it is freed. Called before a sound's data is released.
     * @param pSource The sound being freed.
     * @ghidraAddress 0x4b3b0
     */
    void ClearVoicesUsingBuffer(caSource *pSource);

    /**
     * Installs the per-voice render callback on the mixer AudioUnit for voice @p nBus, once.
     *
     * The callback (@c RenderVoiceAudioCallback) is bound with the voice as its reference so the
     * render loop can pull PCM for it; it is installed only once per voice.
     * @param nBus The voice/bus index.
     * @ghidraAddress 0x4b174
     */
    void InstallVoiceRenderCallback(int nBus);

    /**
     * Applies the gain-table entry @p nVolume to voice @p nBus's mixer bus.
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
     * Sets the master output gain to the volume-table entry @p nVolume.
     *
     * A thin forwarder to @c ApplyVoicePanParam on bus 0, which the spatial mixer treats as the
     * master output-scope gain.
     * @param nVolume The gain-table index.
     * @ghidraAddress 0x4afbc
     */
    void SetAllVolume(int nVolume);

    /**
     * Builds the AUGraph: a 3D spatial mixer feeding the RemoteIO output unit.
     * @return @c true when every Core Audio call succeeded.
     * @ghidraAddress 0x4acd0
     */
    bool BuildAudioUnitGraph();
    /**
     * Builds the graph and, if that succeeds, configures it for @p nVoiceCount buses.
     * @param nVoiceCount The number of mixer buses/voices.
     * @return @c true when the graph both built and configured, @c false otherwise.
     * @ghidraAddress 0x4ac94
     */
    bool GraphSetup(int nVoiceCount);

    /**
     * Tears the mixer down: stops and disposes the AUGraph, then deletes every voice slot
     * and the voice array.
     * @ghidraAddress 0x4affc
     */
    void Terminate();

    /**
     * Sizes the mixer to @p nVoiceCount buses, allocates the voice slots, sets the output
     *        stream format, and initialises the graph.
     * @param nVoiceCount The number of mixer buses/voices (must be below 4096).
     * @return @c true on success, @c false on an oversized count or a Core Audio failure.
     * @ghidraAddress 0x4adb4
     */
    bool ConfigureAudioUnitGraph(int nVoiceCount);

    /**
     * Starts the graph (once) and applies the default master gain.
     *
     * The compiler emits this both inlined at @c 0x4af6c and as an out-of-line thunk at @c 0x4aff8;
     * both collapse to this one method.
     * @ghidraAddress 0x4af6c
     * @ghidraAddress 0x4aff8
     */
    void Start();
    /**
     * Stops the graph when it is running.
     * @ghidraAddress 0x4afc4
     */
    void Stop();

private:
    // Resolves a raw play handle to its live voice (index in the high bits, generation in the low
    // 16), or @c nullptr when the index is out of range or the generation is stale.
    caVoice *ResolveVoice(unsigned int hVoice);

    AUGraph m_pAUGraph = {};      // +0x00 the Core Audio processing graph
    AUNode m_nOutputNode = {};    // +0x08 the RemoteIO output node
    AUNode m_nMixerNode = {};     // +0x0c the 3D spatial-mixer node
    AudioUnit m_pOutputUnit = {}; // +0x10 the RemoteIO output AudioUnit
    AudioUnit m_pMixerUnit = {};  // +0x18 the spatial-mixer AudioUnit
    bool m_bIsRunning = {};       // +0x20 whether the graph is started
    // unsigned char m_aReserved21[3] = {}; // +0x21
    int m_nVoiceCount = {};       // +0x24 the number of voices/buses
    caVoice **m_pVoiceArray = {}; // +0x28 the per-bus voice slots
};

// code: language=Objective-C++
// kate: hl Objective-C++;
// vim: set ft=objcpp :
