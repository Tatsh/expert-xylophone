/**
 * @file
 * The shot (tap) sound sub-manager, @c ShotSoundManager.
 */

#pragma once

/**
 * The shot (tap) sound sub-manager. It holds thirty-three shot slots keyed by resource id and a
 * shared loaded flag; the application preloads the whole bank through @c LoadAll before a picker is
 * shown.
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
     * @brief Loads every shot sound slot from the bundle, no-op once the shared loaded flag is set.
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
     * @brief Auditions a shot sound slot, returning its play handle.
     * @param uChannel The mixer channel to play on.
     * @param iSlot The shot resource id to play.
     * @param iVariant The slot variant.
     * @ghidraAddress 0x1cd364
     */
    unsigned int PlaySlot(unsigned long uChannel, int iSlot, int iVariant);
};

// code: language=C++
// kate: hl C++;
// vim: set ft=cpp :
