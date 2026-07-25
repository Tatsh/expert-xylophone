/**
 * @file
 * The AVFoundation sound-effect voice mixer, @c AVSeMixer.
 */

#pragma once

#import <Foundation/Foundation.h>

@class AVBus;

/**
 * The AVFoundation sound-effect voice mixer: a fixed pool of @c AVBus voices held in an
 * @c NSMutableArray. Play handles pack a voice index in bits 16 and up and the voice's current id in
 * the low 16 bits, so a handle resolves back to a voice by bounds-checking the index and matching
 * the id. The former free engine functions that took the mixer as their first argument are its
 * instance methods. Only the members those methods touch are modelled; the trailing @c // +0xNN
 * offset comments are documentation only.
 * @ghidraAddress AVSeMixer (engine sound mixer)
 */
class AVSeMixer {
public:
    /**
     * @brief Builds the voice pool: allocates the array and fills it with @p nVoiceCount voices.
     * @param nVoiceCount The number of @c AVBus voices to create.
     * @ghidraAddress 0x47c7c
     */
    void InitializeBusArray(int nVoiceCount);

    /**
     * @brief Finds the index of the first free voice (one whose status is not playing).
     * @return The index of a free voice, or @c -1 when every voice is playing.
     * @ghidraAddress 0x47f88
     */
    int FindFreeBusIndex();

    /**
     * @brief Acquires a free voice, binds @p dwSource to it, prepares it, and returns a play handle.
     *
     * Packs the chosen voice index into bits 16 and up and the voice's current id into the low half,
     * then applies the initial volume through the handle.
     * @param dwSource The source id to bind.
     * @param nVolume The initial volume on a 0..127 scale.
     * @return The play handle, or @c 0xffffffff when no voice is free.
     * @ghidraAddress 0x47eb4
     */
    unsigned int AcquireBusForSource(unsigned int dwSource, unsigned int nVolume);

    /**
     * @brief Resolves a play handle back to its voice, validating the packed id.
     * @param dwHandle The play handle (voice index in bits 16 and up, current id in the low half).
     * @return The matching voice, or @c nil when the index is out of range or the id does not match.
     * @ghidraAddress 0x480c0
     */
    AVBus *BusForHandle(unsigned int dwHandle);

    /**
     * @brief Whether the voice at @p nIndex is free (its status is not playing).
     * @param nIndex The voice index.
     * @return @c true when the voice's status is not @c AVBusStatusPlaying.
     * @ghidraAddress 0x4836c
     */
    bool IsBusFree(int nIndex);

    /**
     * @brief Detaches @p source from every voice currently bound to it.
     * @param source The source id to remove.
     * @ghidraAddress 0x483d8
     */
    void RemoveSourceFromBuses(unsigned int source);

    /**
     * @brief Starts playback on the voice resolved from @p dwHandle.
     * @return @c true when a voice matched the handle.
     * @ghidraAddress 0x48058
     */
    bool PlayBusByHandle(unsigned int dwHandle);
    /**
     * @brief Stops the voice resolved from @p dwHandle.
     * @return @c true when a voice matched the handle.
     * @ghidraAddress 0x48158
     */
    bool StopBusByHandle(unsigned int dwHandle);
    /**
     * @brief Pauses the voice resolved from @p dwHandle.
     * @return @c true when a voice matched the handle.
     * @ghidraAddress 0x481c0
     */
    bool PauseBusByHandle(unsigned int dwHandle);
    /**
     * @brief Stops the voice resolved from @p dwHandle and unbinds its source.
     * @ghidraAddress 0x4849c
     */
    void StopAndClearBusByHandle(unsigned int dwHandle);
    /**
     * @brief The playback status of the voice resolved from @p dwHandle.
     * @return The voice's status, or @c -1 when no voice matched the handle.
     * @ghidraAddress 0x48228
     */
    int GetBusStatusByHandle(unsigned int dwHandle);
    /**
     * @brief Sets the volume of the voice resolved from @p dwHandle.
     * @param dwHandle The play handle.
     * @param nVolume The volume on a 0..127 scale.
     * @return @c true when a voice matched the handle.
     * @ghidraAddress 0x47fdc
     */
    bool SetBusVolumeByHandle(unsigned int dwHandle, int nVolume);
    /**
     * @brief Sets the volume of every voice in the pool.
     * @param nVolume The volume on a 0..127 scale.
     * @ghidraAddress 0x48290
     */
    void SetAllBusVolume(int nVolume);

private:
    unsigned char m_bReady = {};            // +0x00: whether the pool has been built.
    unsigned char m_aReserved01[3] = {};    // +0x01: alignment before the voice count.
    int m_nVoiceCount = {};                 // +0x04: the number of voices in the pool.
    NSMutableArray<AVBus *> *m_pBuses = {}; // +0x08: the voice pool.
};

// code: language=Objective-C++
// kate: hl Objective-C++;
// vim: set ft=objcpp :
