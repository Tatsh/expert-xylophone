/**
 * @file
 * The engine play-timing singleton, @c PlayTimer.
 */

#pragma once

/**
 * The engine play-timing singleton.
 *
 * It is created lazily by @c PlayTimer::shared and read directly through the @c g_pPlayTimer
 * global; only the delay-frame offset the customize picker writes is modelled here.
 * Reconstructed global @c g_pPlayTimer: engine singleton, 0x40 bytes.
 */
class PlayTimer {
public:
    /**
     * The device OS-version tier applied to play timing, distinguishing the timing
     * behaviour changes across iOS 8.0 and 8.1.
     */
    enum OsVersionTier {
        kOsVersionTierPre80 = 0,     /*!< The device OS is older than iOS 8.0. */
        kOsVersionTier80To81 = 1,    /*!< The device OS is iOS 8.0 up to (not including) 8.1. */
        kOsVersionTier81OrLater = 2, /*!< The device OS is iOS 8.1 or later. */
    };

    /**
     * Records the device OS-version timing tier.
     * @param tier The OS-version tier.
     */
    void SetOsVersionTier(OsVersionTier tier) {
        m_nOsVersionTier = tier;
    }

    /**
     * Stores the delay-frame-derived timing offset applied to note judging.
     * @param value The offset in seconds.
     */
    void SetDelayFrameOffset(float value) {
        m_flDelayFrameOffset = value;
    }

private:
    double m_dBaseTime = {};         // +0x00: a resume adds the paused interval to it.
    double m_dLastTime = {};         // +0x08: media time, seeded at playback start.
    float m_flPlayTime = {};         // +0x10: in scaled units.
    float m_flFrameDelta = {};       // +0x14
    bool m_bRunning = {};            // +0x18: cleared when paused.
    char m_reserved19[3] = {};       // +0x19
    int m_nOsVersionTier = {};       // +0x1c
    float m_flDelayFrameOffset = {}; // +0x20
    char m_reserved24[4] = {};       // +0x24: further timing state, still being worked out.
    double m_dAccumulated = {};      // +0x28: cleared at playback start.
    bool m_bPaused = {};             // +0x30
    char m_reserved31[7] = {};       // +0x31
    double m_dPauseMediaTime = {};   // +0x38

public:
    /**
     * Marks the timer paused and records the media time it paused at.
     * @param dMediaTime The media time the timer paused at.
     */
    void MarkPaused(double dMediaTime) {
        m_dPauseMediaTime = dMediaTime;
        m_bPaused = true;
    }

    /**
     * Whether the timer is currently paused.
     * @return @c true while the timer is paused.
     */
    bool IsPaused() const {
        return m_bPaused;
    }

    /**
     * The current play time, in scaled units.
     * @return The current play time, in scaled units.
     */
    float GetPlayTime() const {
        return m_flPlayTime;
    }

    /**
     * The per-frame time step.
     * @return The per-frame time step.
     */
    float GetFrameDelta() const {
        return m_flFrameDelta;
    }

    /**
     * Resumes the timer, shifting its origin forward by the interval it spent paused.
     * @param dMediaTime The current media time.
     */
    void Resume(double dMediaTime) {
        m_bPaused = false;
        m_dBaseTime += dMediaTime - m_dPauseMediaTime;
    }

    /**
     * Starts (or restarts) playback timing from the given media time: seeds the timing
     * origin and last-update time, zeroes the play time, frame delta, and accumulated time, sets
     * the running flag, and clears the paused flag.
     * @param dMediaTime The current media time to time from.
     * @param bRunning Whether playback is actually running (a preview with no music leaves it
     * clear).
     */
    void StartPlayback(double dMediaTime, bool bRunning) {
        m_bRunning = bRunning;
        m_dAccumulated = 0.0;
        m_dBaseTime = dMediaTime;
        m_flPlayTime = 0.0f;
        m_dLastTime = dMediaTime;
        m_flFrameDelta = 0.0f;
        m_bPaused = false;
    }

    /**
     * Returns the engine play-timing singleton (@c g_pPlayTimer), constructing it on first
     * use.
     * @return The singleton timer (also stored in @c g_pPlayTimer).
     * @ghidraAddress 0x131868
     */
    static PlayTimer *shared();

    /**
     * Advances the play clock for this frame, syncing to the BGM playback time.
     *
     * A no-op that zeroes the frame delta while paused. Otherwise it measures the wall-clock
     * interval since the last update, and — when the timer is running (music-driven) — corrects the
     * timing origin for any drift between the wall clock and the BGM's reported position, biased by
     * an OS-version-tier latency offset. The per-frame step is the drift-corrected interval scaled
     * to milliseconds, clamped to non-negative.
     * @return This timer. The binary leaves the return register unspecified on the running path
     *         and neither caller reads it.
     * @ghidraAddress 0x1318a4
     */
    PlayTimer *Update();
};

/** The engine play-timing singleton, constructed by @c PlayTimer::shared. */
extern PlayTimer *g_pPlayTimer;

/**
 * The per-frame time step (about 16.667, one 60th of a second expressed in milliseconds)
 * used to scale a delay-frame count into the play-timing offset.
 * @ghidraAddress 0x2ef178
 */
extern const float g_flDelayFrameToSeconds;
