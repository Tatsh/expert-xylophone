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
     * @brief Frees the PCM data of the sound at @p index, detaching it from any active voice first.
     * @param index The registered sound id.
     * @return @c 1 when a sound was freed, @c 0 when the index is out of range or the slot is empty.
     * @ghidraAddress 0x4b870
     */
    int FreeSoundDataByIndex(int index);
    /**
     * @brief Frees the sound registered under a call name and removes its dictionary entry.
     * @return @c 1 when a cached sound was found and freed, @c 0 otherwise.
     * @ghidraAddress 0x4b8cc
     */
    int FreeSoundForKey(NSString *callName);
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
    unsigned int PlaySoundForKey(NSString *callName, int volume);
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
     * @brief Sets the mixer's master voice gain to the given volume-table index.
     * @param volume The gain-table index applied to every voice.
     * @ghidraAddress 0x4bbcc
     */
    void SetMasterVoiceParameter(int volume);

private:
    // Registers @p pSource in a free slot of the sound array and returns its slot index (sound id).
    unsigned int RegisterSource(caSource *pSource);
    // Returns the index of a free slot in the sound array, growing it by a fixed step and returning
    // the first new index when none is free.
    unsigned int FindOrGrowFreeSlot();

    caCAMixer *m_pMixer = {};                // +0x00 the Core Audio voice mixer
    NSMutableDictionary *m_pSourceDict = {}; // +0x08 the call-name -> sound-id map
    caSource **m_pSourceArray = {};          // +0x10 the registered sound buffers, indexed by id
    int m_nSourceCount = {};                 // +0x18 the number of registered sounds
};

// code: language=Objective-C++
// kate: hl Objective-C++;
// vim: set ft=objcpp :
