/**
 * @file
 * The engine play-timing singleton, @c PlayTimer.
 */

#pragma once

/**
 * The engine play-timing singleton. It is created lazily by @c PlayTimer::shared and read directly
 * through the @c g_pPlayTimer global; only the delay-frame offset the customize picker writes is
 * modelled here.
 * @ghidraAddress g_pPlayTimer (engine singleton, 0x40 bytes)
 */
class PlayTimer {
public:
    /**
     * @brief The device OS-version tier applied to play timing, distinguishing the timing
     * behaviour changes across iOS 8.0 and 8.1.
     */
    enum OsVersionTier {
        kOsVersionTierPre80 = 0,     /*!< The device OS is older than iOS 8.0. */
        kOsVersionTier80To81 = 1,    /*!< The device OS is iOS 8.0 up to (not including) 8.1. */
        kOsVersionTier81OrLater = 2, /*!< The device OS is iOS 8.1 or later. */
    };

    /**
     * @brief Records the device OS-version timing tier.
     * @param tier The OS-version tier.
     */
    void SetOsVersionTier(OsVersionTier tier) {
        m_nOsVersionTier = tier;
    }

    /**
     * @brief Stores the delay-frame-derived timing offset applied to note judging.
     * @param value The offset in seconds.
     */
    void SetDelayFrameOffset(float value) {
        m_flDelayFrameOffset = value;
    }

private:
    double m_dBaseTime = {};   // +0x00: the timing origin; a resume adds the paused interval to it.
    char m_reserved08[8] = {}; // +0x08: further timing state, still being worked out.
    float m_flPlayTime = {};   // +0x10: the current play time, in scaled units.
    float m_flFrameDelta = {}; // +0x14: the per-frame time step.
    int m_nOsVersionTier = {}; // +0x1c
    float m_flDelayFrameOffset = {}; // +0x20
    // +0x24..+0x2f: further timing state, still being worked out.
    char m_reserved24[0xc] = {}; // +0x24
    bool m_bPaused = {};         // +0x30: set while the play timer is paused.
    // +0x31..+0x37 is alignment padding before the pause timestamp.
    char m_reserved31[7] = {};     // +0x31
    double m_dPauseMediaTime = {}; // +0x38: the media time captured when the timer paused.

public:
    /** @brief Marks the timer paused and records the media time it paused at. */
    void MarkPaused(double dMediaTime) {
        m_dPauseMediaTime = dMediaTime;
        m_bPaused = true;
    }

    /** @brief Whether the timer is currently paused. */
    bool IsPaused() const {
        return m_bPaused;
    }

    /** @brief The current play time, in scaled units. */
    float GetPlayTime() const {
        return m_flPlayTime;
    }

    /** @brief The per-frame time step. */
    float GetFrameDelta() const {
        return m_flFrameDelta;
    }

    /**
     * @brief Resumes the timer, shifting its origin forward by the interval it spent paused.
     * @param dMediaTime The current media time.
     */
    void Resume(double dMediaTime) {
        m_bPaused = false;
        m_dBaseTime += dMediaTime - m_dPauseMediaTime;
    }

    /**
     * @brief Returns the engine play-timing singleton (@c g_pPlayTimer), constructing it on first
     * use.
     * @return The singleton timer (also stored in @c g_pPlayTimer).
     * @ghidraAddress 0x131868
     */
    static PlayTimer *shared();
};

/** @brief The engine play-timing singleton, constructed by @c PlayTimer::shared. */
extern PlayTimer *g_pPlayTimer;

/**
 * @brief The per-frame time step (about 16.667, one 60th of a second expressed in milliseconds)
 * used to scale a delay-frame count into the play-timing offset.
 * @ghidraAddress 0x2ef178
 */
extern const float g_flDelayFrameToSeconds;

// code: language=C++
// kate: hl C++;
// vim: set ft=cpp :
