/**
 * @file
 * The AVFoundation sound-effect source manager, @c AudioSourceSlot.
 */

#pragma once

#import <Foundation/Foundation.h>

class AVSeMixer;

/**
 * The AVFoundation sound-effect source manager, reached through @c AudioManager's @c seAVPlayer
 * ivar. It owns the voice mixer (@c AVSeMixer), a call-name-to-index dictionary, and a growable
 * array of source records, and vends bus play handles for registered sources. The former free
 * engine functions that took the manager as their first argument are its instance methods. Only the
 * members those methods touch are modelled; the trailing @c // +0xNN offset comments are
 * documentation only.
 * Reconstructed type @c AudioSourceSlot: AVFoundation SE manager.
 */
class AudioSourceSlot {
public:
    /**
     * @brief One registered sound source: the bound source object, a companion object, and its loop
     * flag.
     */
    struct SourceRecord {
        id source = {};    /*!< The bound source object (a copy). +0x00 */
        id companion = {}; /*!< A companion object released with the record. +0x08 */
        bool bLoop = {};   /*!< Whether the source loops. +0x10 */
        // +0x11..+0x17 is trailing padding to the 0x18-byte record.

        /**
         * @brief Initialises the record: stores a copy of @p source and its loop flag.
         * @param sourceObject The source object to copy into the record.
         * @param bLoopValue Whether the source loops.
         * @return Always 1.
         * @ghidraAddress 0x4abcc
         */
        int Initialize(id sourceObject, bool bLoopValue);
        /**
         * @brief Clears the record, releasing its two object references.
         * @return Always 1.
         * @ghidraAddress 0x4ab8c
         */
        int Clear();
    };

    /**
     * @brief Zeroes the manager's fields to the empty state (its construction-time initialiser).
     * @ghidraAddress 0x4a5d4
     */
    void InitAudioSourceSlot();
    /**
     * @brief Builds the mixer voice pool, the call-name map, and the source table.
     * @param nVoiceCount The number of mixer voices to create.
     * @ghidraAddress 0x4a5e8
     */
    void InitializeSourceManager(int nVoiceCount);
    /**
     * @brief Adds a source, returning its slot index.
     * @param source The source object to register.
     * @param bLoop Whether the source loops.
     * @return The slot index the source was added at.
     * @ghidraAddress 0x4a690
     */
    unsigned int AddSource(id source, bool bLoop);
    /**
     * @brief Registers a source under a call name, returning whether it was added.
     * @param source The source object to register.
     * @param callName The call name the source is registered under.
     * @param bLoop Whether the source loops.
     * @return Non-zero when the source was added.
     * @ghidraAddress 0x4a728
     */
    int RegisterSourceForKey(id source, NSString *callName, bool bLoop);
    /**
     * @brief Removes the source at the given index.
     * @param index The slot index of the source to remove.
     * @return Non-zero when a source was removed.
     * @ghidraAddress 0x4a870
     */
    int RemoveSourceByIndex(int index);
    /**
     * @brief Removes the source registered under a call name.
     * @param callName The call name the source was registered under.
     * @return Non-zero when a source was removed.
     * @ghidraAddress 0x4a8c0
     */
    int RemoveSourceByKey(NSString *callName);
    /**
     * @brief Acquires a playback bus for the source at the given index, returning its handle.
     * @param index The slot index of the source to play.
     * @param volume The mixer gain, forwarded untouched to the mixer.
     * @return The play handle for the acquired bus.
     * @ghidraAddress 0x4a954
     */
    unsigned int AcquireBusForSourceIndex(int index, int volume);
    /**
     * @brief Acquires a playback bus for the source under a call name, returning its handle.
     * @param callName The call name the source was registered under.
     * @param volume The mixer gain, forwarded untouched to the mixer.
     * @return The play handle for the acquired bus.
     * @ghidraAddress 0x4a990
     */
    unsigned int AcquireBusForSourceKey(NSString *callName, int volume);
    /**
     * @brief Starts playback of the bus identified by a play handle.
     * @param handle The play handle of the bus to start.
     * @return Whether a bus was found for the handle.
     * @ghidraAddress 0x4aa34
     */
    bool PlayByHandle(unsigned int handle);
    /**
     * @brief Stops the bus identified by a play handle, returning whether it was playing.
     * @param handle The play handle of the bus to stop.
     * @return Whether the bus was playing.
     * @ghidraAddress 0x4aa4c
     */
    bool StopByHandle(unsigned int handle);
    /**
     * @brief Pauses the bus identified by a play handle.
     * @param handle The play handle of the bus to pause.
     * @return Whether a bus was found for the handle.
     * @ghidraAddress 0x4aa64
     */
    bool PauseByHandle(unsigned int handle);
    /**
     * @brief Returns the playback status of the bus identified by a play handle.
     * @param handle The play handle of the bus to query.
     * @return The bus's playback status.
     * @ghidraAddress 0x4aa7c
     */
    int GetStatusByHandle(unsigned int handle);
    /**
     * @brief Stops the bus identified by a play handle and detaches its source.
     * @param handle The play handle of the bus to stop and clear.
     * @ghidraAddress 0x4ab74
     */
    void StopAndClearByHandle(unsigned int handle);
    /**
     * @brief Pauses every audio bus.
     * @ghidraAddress 0x4a670
     */
    void PauseAllBuses();
    /**
     * @brief Resumes every audio bus.
     * @ghidraAddress 0x4a680
     */
    void ResumeAllBuses();
    /**
     * @brief Sets the volume of every audio bus.
     * @param volume The mixer gain applied to every bus.
     * @ghidraAddress 0x4aa94
     */
    void SetAllVolume(int volume);

private:
    // Returns the index of a free source slot, growing the array by a fixed step when none is free.
    int FindFreeSlotIndex();

    AVSeMixer *m_pMixer = {};            // +0x00: the voice mixer.
    NSMutableDictionary *m_pKeyMap = {}; // +0x08: the call-name -> slot-index map.
    SourceRecord **m_pSourceArray = {};  // +0x10: the registered source records, indexed by slot.
    int m_nSourceCount = {};             // +0x18: the source-array capacity.
};

// code: language=Objective-C++
// kate: hl Objective-C++;
// vim: set ft=objcpp :
