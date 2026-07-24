/**
 * @file
 * The grouped mixer-bus source subsystem, @c AudioSourceSlot.
 */

#pragma once

#import <Foundation/Foundation.h>

/**
 * The grouped mixer-bus source subsystem, reached through @c AudioManager's @c seAVPlayer ivar.
 * The former free engine functions that took the @c AudioSourceSlot as their first argument are
 * its instance methods.
 */
class AudioSourceSlot {
public:
    /**
     * @brief Constructs and initialises the mixer, name map, and source table.
     * @ghidraAddress 0x4a5d4
     */
    void InitAudioSourceSlot();
    /**
     * @brief Adds a source from a URL, returning its index.
     * @ghidraAddress 0x4a690
     */
    unsigned int AddSourceToManager(NSURL *url, bool bLoop);
    /**
     * @brief Registers a source from a URL under a call name, returning whether it was added.
     * @ghidraAddress 0x4a728
     */
    int RegisterSourceForKey(NSURL *url, NSString *callName, bool bLoop);
    /**
     * @brief Removes the source at the given index.
     * @ghidraAddress 0x4a870
     */
    void RemoveAudioSourceByIndex(unsigned int index);
    /**
     * @brief Removes the source registered under a call name.
     * @ghidraAddress 0x4a8c0
     */
    void RemoveAudioSourceByKey(NSString *callName);
    /**
     * @brief Acquires a playback bus for the source at the given index, returning its handle.
     * @ghidraAddress 0x4a954
     */
    unsigned int AcquireAudioBusForSourceIndex(unsigned int index);
    /**
     * @brief Acquires a playback bus for the source under a call name, returning its handle.
     * @ghidraAddress 0x4a990
     */
    unsigned int AcquireAudioBusForSourceKey(NSString *callName, int volume);
    /**
     * @brief Starts playback of the bus identified by a handle.
     * @ghidraAddress 0x4aa34
     */
    void PlaySourceByHandle(unsigned int handle);
    /**
     * @brief Pauses the bus identified by a play handle.
     * @ghidraAddress 0x4aa64
     */
    void PauseAudioBusByPlayHandle(unsigned int handle);
    /**
     * @brief Stops the bus identified by a play handle.
     * @ghidraAddress 0x4ab74
     */
    void StopAudioBusByPlayHandle(unsigned int handle);
    /**
     * @brief Stops the bus identified by a handle, returning whether it was playing.
     * @ghidraAddress 0x4aa4c
     */
    bool StopAudioBusByHandleWrapper(unsigned int handle);
    /**
     * @brief Returns the playback status of the bus identified by a handle.
     * @ghidraAddress 0x4aa7c
     */
    int QueryAudioBusPlaybackStatus(unsigned int handle);
    /**
     * @brief Pauses every audio bus.
     * @ghidraAddress 0x4a670
     */
    void PauseAllAudioBuses();
    /**
     * @brief Resumes every audio bus.
     * @ghidraAddress 0x4a680
     */
    void ResumeAllAudioBuses();
    /**
     * @brief Sets the volume of every audio bus.
     * @ghidraAddress 0x4aa94
     */
    void SetAllAudioBusVolumeWrapper(int volume);
};

// code: language=Objective-C++
// kate: hl Objective-C++;
// vim: set ft=objcpp :
