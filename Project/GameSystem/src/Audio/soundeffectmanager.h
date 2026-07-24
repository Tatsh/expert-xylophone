/**
 * @file
 * The themed sound-effect manager, @c SoundEffectManager.
 */

#pragma once

/**
 * The themed sound-effect manager. It holds three theme banks of twenty slots plus thirty-six
 * shared slots, keyed by the current theme; the application plays a slot through
 * @c PlayThemedSoundEffect.
 * @ghidraAddress SoundEffectManager (engine class, 0x1e8 bytes)
 */
class SoundEffectManager {
public:
    /**
     * @brief Returns the shared themed sound-effect manager, constructing it on first use.
     * @ghidraAddress 0x1cc514
     */
    static SoundEffectManager *GetInstance();
    /**
     * @brief Plays the sound effect in the given slot for the current theme, returning its play
     *        handle, or @c 0xffffffff when the slot is not loaded.
     * @ghidraAddress 0x1cc934
     */
    unsigned int PlayThemedSoundEffect(int slotID);
    /**
     * @brief Loads the themed voice for the given identifier and immediately plays it.
     *
     * A thin wrapper that loads the voice data through @c LoadThemedVoiceData and then plays it
     * through @c PlayThemedVoice.
     * @param voiceID The themed voice identifier.
     * @ghidraAddress 0x1ccc18
     */
    void LoadAndSetThemedVoice(int voiceID);
    /**
     * @brief Reports whether the sound effect with the given play handle is still playing.
     *
     * The manager receiver is unused; the query is forwarded to
     * @c -[AudioManager isPlayingSe:]. It is modelled as a member because the binary passes the
     * manager pointer as the first argument.
     * @param playHandle The play handle returned by @c PlayThemedSoundEffect.
     * @return @c true while the effect is still playing.
     * @ghidraAddress 0x1ccba8
     */
    bool IsPlaying(unsigned int playHandle);
};

// code: language=C++
// kate: hl C++;
// vim: set ft=cpp :
