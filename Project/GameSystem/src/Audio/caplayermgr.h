/**
 * @file
 * The one-shot voice-player subsystem, @c caPlayerMgr.
 */

#pragma once

#import <Foundation/Foundation.h>

class caCAMixer;
class caSource;

/**
 * The one-shot voice-player subsystem, reached through @c AudioManager's @c sePlayer ivar. The
 * former free engine functions that took the @c caPlayerMgr as their first argument are its
 * instance methods. Only the members the reconstructed methods touch are modelled; the 32-bit
 * offset comments are documentation only.
 */
class caPlayerMgr {
public:
    /**
     * @brief Constructs the audio context: the graph, the name-to-id dictionary, and the buffer
     * array.
     * @ghidraAddress 0x4b580
     */
    void InitializeAudioContext(int channelCount);
    /**
     * @brief Tears down the audio context.
     * @ghidraAddress 0x4b4a8
     */
    void DestroyAudioContext();
    /**
     * @brief Tears down the audio context (wrapper entry point).
     * @ghidraAddress 0x4b57c
     */
    void DestroyAudioContextWrapper();
    /**
     * @brief Starts the audio graph.
     * @ghidraAddress 0x4b61c
     */
    void StartAudioGraph();
    /**
     * @brief Stops the audio graph.
     * @ghidraAddress 0x4b60c
     */
    void StopAudioGraph();
    /**
     * @brief Creates a sound buffer, loads PCM from a path, and registers it, returning its id.
     * @ghidraAddress 0x4b62c
     */
    int CreateAndLoadSound(const char *szPath, bool bLoop);
    /**
     * @brief Loads a sound and caches its id keyed by a call name, returning whether it was loaded.
     * @ghidraAddress 0x4b718
     */
    int LoadAndCacheSoundForKey(const char *szPath, NSString *callName, bool bLoop);
    /**
     * @brief Frees the sound buffer at the given index.
     * @ghidraAddress 0x4b870
     */
    void FreeSoundDataByIndex(unsigned int index);
    /**
     * @brief Frees the sound buffer registered under a call name.
     * @ghidraAddress 0x4b8cc
     */
    void FreeSoundForKey(NSString *callName);
    /**
     * @brief Plays the sound at the given index on the first free voice, returning its handle.
     * @param index The registered sound id.
     * @param volume The gain-table index forwarded to the chosen voice.
     * @ghidraAddress 0x4b998
     */
    unsigned int PlaySoundByIndex(int index, int volume);
    /**
     * @brief Plays the sound registered under a call name, returning its handle.
     * @ghidraAddress 0x4ba1c
     */
    unsigned int PlaySoundForKey(NSString *callName);
    /**
     * @brief Plays the sound at the given index on a specific voice, returning its handle.
     * @ghidraAddress 0x4b9d4
     */
    unsigned int PlaySoundOnVoice(int resourceId, int busId, int volume);
    /**
     * @brief Plays the sound under a call name on a specific voice, returning its handle.
     * @ghidraAddress 0x4bac0
     */
    unsigned int PlaySoundForKeyOnBus(NSString *callName, int busId, int volume);
    /**
     * @brief Resumes or starts the voice identified by a handle.
     * @ghidraAddress 0x4bb6c
     */
    void ResumeVoiceByHandle(unsigned int handle);
    /**
     * @brief Pauses the voice identified by a handle.
     * @ghidraAddress 0x4bb9c
     */
    void PauseVoiceByHandle(unsigned int handle);
    /**
     * @brief Stops the voice identified by a handle.
     * @ghidraAddress 0x4bb84
     */
    void StopVoiceByHandle(unsigned int handle);
    /**
     * @brief Releases the voice identified by a handle.
     * @ghidraAddress 0x4bcac
     */
    void ReleaseVoiceByHandle(unsigned int handle);
    /**
     * @brief Returns the playback state of the voice identified by a handle.
     * @ghidraAddress 0x4bbb4
     */
    int GetVoiceStateByHandle(unsigned int handle);
    /**
     * @brief Sets the mixer's master voice gain.
     * @ghidraAddress 0x4bbcc
     */
    void SetMasterVoiceParameter();

private:
    caCAMixer *m_pMixer = {};            // +0x00 the Core Audio voice mixer
    unsigned char m_aReserved08[8] = {}; // +0x08 the name-to-id dictionary (not yet modelled)
    caSource **m_pSourceArray = {};      // +0x10 the registered sound buffers, indexed by id
    int m_nSourceCount = {};             // +0x18 the number of registered sounds
};

// code: language=Objective-C++
// kate: hl Objective-C++;
// vim: set ft=objcpp :
