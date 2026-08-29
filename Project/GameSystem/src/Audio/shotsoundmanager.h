/**
 * @file
 * The shot (tap) sound sub-manager, @c ShotSoundManager.
 */

#pragma once

/**
 * The shot (tap) sound sub-manager.
 *
 * It holds thirty-three shot slots, each with four judgement variants, keyed by resource id and a
 * shared loaded flag; the application preloads the whole bank through @c LoadAll before a picker
 * is shown, and plays a slot through @c PlaySlot. The 32-bit offset comments are documentation
 * only.
 * Reconstructed type @c ShotSoundManager: engine class, 0x24c bytes.
 */
class ShotSoundManager {
public:
    /**
     * Returns the shared shot-sound manager, constructing and clearing its slots on first
     *        use.
     * @return The shared shot-sound manager.
     * @ghidraAddress 0x1ccf30
     */
    static ShotSoundManager *GetInstance();
    /**
     * Loads the four judgement variants of one shot slot from the bundle (unless already
     *        loaded).
     * @param slot The shot slot index.
     * @ghidraAddress 0x1ccfac
     */
    void LoadSlotVariants(int slot);
    /**
     * Loads every shot sound slot (variant zero) from the bundle, a no-op once the shared
     *        loaded flag is set.
     * @ghidraAddress 0x1cd190
     */
    void LoadAll();
    /**
     * Stores the shot sound group volume (clamped to the unit interval) and applies it to
     * the audio manager's shot bus.
     * @param flVolume The requested volume, clamped to the range zero to one.
     * @ghidraAddress 0x1cd4a4
     */
    void SetVolume(float flVolume);
    /**
     * Auditions a shot sound slot on a channel, stopping any prior sound on that channel and
     *        applying the current volume, returning its play handle.
     * @param uChannel The mixer channel to play on.
     * @param iSlot The shot slot to play.
     * @param iVariant The judgement variant (zero to three).
     * @return The play handle for the auditioned slot.
     * @ghidraAddress 0x1cd364
     */
    unsigned int PlaySlot(unsigned long uChannel, int iSlot, int iVariant);

    /**
     * Records the highest-priority (lowest value) pending shot retrigger for this frame.
     *
     * Keeps the request whose priority is below the current pending priority, storing its slot and
     * priority for the frame's timer update to play.
     * @param nSlot The slot requesting a retrigger.
     * @param nPriority The request's priority (lower wins).
     * @ghidraAddress 0x1cd48c
     */
    void SetPendingRetrigger(int nSlot, int nPriority);

    /**
     * Advances the shot retrigger cooldown and fires the pending shot when it elapses.
     *
     * While the cooldown timer is positive it is clamped to one frame and decremented; once it
     * reaches zero, and unless the pending state is already idle, the pending slot is played on
     * channel one and the timer is reset to one frame. The pending state is set idle at the end.
     * @param flDeltaTime The elapsed time since the last frame, in milliseconds.
     * @ghidraAddress 0x1cd538
     */
    void UpdateRetriggerTimer(float flDeltaTime);

    /** The number of shot slots. */
    static constexpr int kSlotCount = 33;
    /** The number of judgement variants per slot. */
    static constexpr int kVariantCount = 4;
    /** The number of audition channels. */
    static constexpr int kChannelCount = 2;

private:
    // @ghidraAddress 0x1ccf30
    ShotSoundManager();

    bool m_aSlotLoaded[kSlotCount] = {}; // +0x00 per-slot loaded flags
    bool m_bSharedLoaded = {};           // +0x21 whether the whole bank is loaded
    // unsigned char m_aPad22[2] = {};                    // +0x22
    int m_aResourceId[kSlotCount][kVariantCount] = {}; // +0x24 per-slot per-variant resource ids
    unsigned int m_aChannelHandle[kChannelCount] = {}; // +0x234 per-channel active play handles
    int m_nPendingSlot = {};                           // +0x23c the pending slot to retrigger
    // +0x240 the pending judgement variant (0 through 3), which doubles as the retrigger priority
    // (lower wins); 5 is the idle sentinel meaning no shot is pending.
    int m_nPendingVariant = {};
    float m_flRetriggerTimer = {}; // +0x244 the retrigger cooldown timer, in milliseconds
    float m_flVolume = {};         // +0x248 shot group volume, zero to one
};

// code: language=Objective-C++
// kate: hl Objective-C++;
// vim: set ft=objcpp :
