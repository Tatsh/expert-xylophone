/**
 * @file
 * The shot (tap) sound sub-manager, @c ShotSoundManager.
 */

#pragma once

/**
 * The shot (tap) sound sub-manager. It holds thirty-three shot slots, each with four judgement
 * variants, keyed by resource id and a shared loaded flag; the application preloads the whole bank
 * through @c LoadAll before a picker is shown, and plays a slot through @c PlaySlot. The 32-bit
 * offset comments are documentation only.
 * @ghidraAddress ShotSoundManager (engine class, 0x24c bytes)
 */
class ShotSoundManager {
public:
    /**
     * @brief Returns the shared shot-sound manager, constructing and clearing its slots on first
     *        use.
     * @ghidraAddress 0x1ccf30
     */
    static ShotSoundManager *GetInstance();
    /**
     * @brief Loads the four judgement variants of one shot slot from the bundle (unless already
     *        loaded).
     * @param slot The shot slot index.
     * @ghidraAddress 0x1ccfac
     */
    void LoadSlotVariants(int slot);
    /**
     * @brief Loads every shot sound slot (variant zero) from the bundle, a no-op once the shared
     *        loaded flag is set.
     * @ghidraAddress 0x1cd190
     */
    void LoadAll();
    /**
     * @brief Stores the shot sound group volume (clamped to the unit interval) and applies it to the
     *        audio manager's shot bus.
     * @param flVolume The requested volume, clamped to the range zero to one.
     * @ghidraAddress 0x1cd4a4
     */
    void SetVolume(float flVolume);
    /**
     * @brief Auditions a shot sound slot on a channel, stopping any prior sound on that channel and
     *        applying the current volume, returning its play handle.
     * @param uChannel The mixer channel to play on.
     * @param iSlot The shot slot to play.
     * @param iVariant The judgement variant (zero to three).
     * @ghidraAddress 0x1cd364
     */
    unsigned int PlaySlot(unsigned long uChannel, int iSlot, int iVariant);

    /** @brief The number of shot slots. */
    static constexpr int kSlotCount = 33;
    /** @brief The number of judgement variants per slot. */
    static constexpr int kVariantCount = 4;
    /** @brief The number of audition channels. */
    static constexpr int kChannelCount = 2;

private:
    // Constructs the manager: clears the loaded flags and marks every resource id unloaded.
    // @ghidraAddress 0x1ccf30
    ShotSoundManager();

    bool m_aSlotLoaded[kSlotCount] = {};               // +0x00 per-slot loaded flags
    bool m_bSharedLoaded = {};                         // +0x21 whether the whole bank is loaded
    unsigned char m_aPad22[2] = {};                    // +0x22
    int m_aResourceId[kSlotCount][kVariantCount] = {}; // +0x24 per-slot per-variant resource ids
    unsigned int m_aChannelHandle[kChannelCount] = {}; // +0x234 per-channel active play handles
    int m_nCurrentPrioritySlot = {};                   // +0x23c currently-sounding slot
    int m_nMinPriority = {};                           // +0x240 minimum retrigger priority
    int m_nReserved244 = {};                           // +0x244
    float m_flVolume = {};                             // +0x248 shot group volume, zero to one
};

// code: language=Objective-C++
// kate: hl Objective-C++;
// vim: set ft=objcpp :
