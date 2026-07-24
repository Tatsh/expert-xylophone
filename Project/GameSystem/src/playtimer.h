/**
 * @file
 * The engine play-timing singleton, @c PlayTimer.
 */

#pragma once

/**
 * The engine play-timing singleton. It is created lazily by @c EnsurePlayTimer and read directly
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
    char m_reserved[0x1c] = {};      // +0x00
    int m_nOsVersionTier = {};       // +0x1c
    float m_flDelayFrameOffset = {}; // +0x20
};

/**
 * @brief Constructs the engine play-timing singleton (@c g_pPlayTimer) on first use.
 * @ghidraAddress 0x131868
 */
void EnsurePlayTimer(void);

/** @brief The engine play-timing singleton, constructed by @c EnsurePlayTimer. */
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
