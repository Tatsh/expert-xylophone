/**
 * @file
 * The themed sound-effect manager, @c SoundEffectManager.
 */

#pragma once

/**
 * The themed sound-effect manager.
 *
 * It holds three theme banks of twenty slots plus thirty-six shared slots, keyed by the current
 * theme; the application plays a slot through @c PlayThemedSoundEffect. The 32-bit offset comments
 * are documentation only.
 * Reconstructed type @c SoundEffectManager: engine class, 0x1e8 bytes.
 */
class SoundEffectManager {
public:
    /**
     * Returns the shared themed sound-effect manager, constructing it on first use.
     * @return The shared themed sound-effect manager.
     * @ghidraAddress 0x1cc514
     */
    static SoundEffectManager *GetInstance();

    /**
     * Loads every themed and shared sound effect into the manager.
     *
     * Preloads all three themes' twenty slots plus the thirty-six shared slots from the bundle.
     * @ghidraAddress 0x1cc75c
     */
    void LoadAll();

    /**
     * Plays the sound effect in the given slot for the current theme, returning its play
     *        handle, or @c 0xffffffff when the slot is not loaded.
     * @param slotID The themed sound-effect slot to play.
     * @return The play handle, or @c 0xffffffff when the slot is not loaded.
     * @ghidraAddress 0x1cc934
     */
    unsigned int PlayThemedSoundEffect(int slotID);
    /**
     * Plays the shared sound effect selected by the current game state (the BGM type).
     * @return The play handle, or @c 0xffffffff when the selected shared slot is not loaded.
     * @ghidraAddress 0x1ccb08
     */
    unsigned int PlayGameStateSoundEffect();
    /**
     * Plays the shared sound effect selected by the current theme.
     *
     * Maps the current theme to a shared slot (the Colette theme to slot 15, the Limelight theme to
     * slot 1, and the Classic theme to slot 0) and plays it.
     * @return The play handle, or @c 0xffffffff when the selected shared slot is not loaded.
     * @ghidraAddress 0x1cca20
     */
    unsigned int PlaySharedSoundEffect();
    /**
     * Plays the current theme's loaded voice for @p voiceID, when the requested state
     * matches (or is the always-play state).
     * @param voiceID The themed voice identifier.
     * @return @c true when a voice was played.
     * @ghidraAddress 0x1cceac
     */
    bool PlayThemedVoice(int voiceID);
    /**
     * Loads the themed voice for the given identifier and immediately plays it.
     *
     * A thin wrapper that loads the voice data through @c LoadThemedVoiceData and then plays it
     * through @c PlayThemedVoice.
     * @param voiceID The themed voice identifier.
     * @ghidraAddress 0x1ccc18
     */
    void LoadAndSetThemedVoice(int voiceID);
    /**
     * Loads the current theme's voice (CV) file for @p voiceID into the audio manager and
     *        records the requested voice state.
     * @param voiceID The themed voice identifier (also stored as the current voice state).
     * @return Always @c true.
     * @ghidraAddress 0x1ccc44
     */
    bool LoadThemedVoiceData(int voiceID);
    /**
     * Reports whether the sound effect with the given play handle is still playing.
     *
     * The manager receiver is unused; the query is forwarded to
     * @c -[AudioManager isPlayingSe:]. It is modelled as a member because the binary passes the
     * manager pointer as the first argument.
     * @param playHandle The play handle returned by @c PlayThemedSoundEffect.
     * @return @c true while the effect is still playing.
     * @ghidraAddress 0x1ccba8
     */
    bool IsPlaying(unsigned int playHandle);

    /** The number of theme banks. */
    static constexpr int kThemeCount = 3;
    /** The number of sound-effect slots per theme bank. */
    static constexpr int kThemedSlotCount = 20;
    /** The number of shared (theme-independent) sound-effect slots. */
    static constexpr int kSharedSlotCount = 36;

private:
    // @ghidraAddress 0x1cc4ac
    SoundEffectManager();

    // @ghidraAddress 0x1cc548
    void LoadThemedSoundEffect(int theme, int slot);

    long m_nCurrentVoiceState = {};                             // +0x00 last-requested voice state
    bool m_aThemeLoaded[kThemeCount][kThemedSlotCount] = {};    // +0x08 per-theme slot loaded flags
    int m_aThemeResourceId[kThemeCount][kThemedSlotCount] = {}; // +0x44 per-theme slot resource ids
    bool m_aSharedLoaded[kSharedSlotCount] = {};                // +0x134 shared slot loaded flags
    int m_aSharedResourceId[kSharedSlotCount] = {};             // +0x158 shared slot resource ids
};

// code: language=Objective-C++
// kate: hl Objective-C++;
// vim: set ft=objcpp :
