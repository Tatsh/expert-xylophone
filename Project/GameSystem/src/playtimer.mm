#import "playtimer.h"

#import <QuartzCore/QuartzCore.h>

#import "AudioManager.h"

// The engine play-timing singleton, created on first use by PlayTimer::shared.
PlayTimer *g_pPlayTimer = nullptr; // @ghidraAddress 0x3de020

// The per-frame time step, one 60th of a second in milliseconds, that scales a delay-frame count
// into the play-timing offset. @ghidraAddress 0x2ef178
const float g_flDelayFrameToSeconds = 16.66659927368164f;

namespace {

// The seconds-to-milliseconds scale applied to the per-frame interval (@ghidraAddress 0x2eeea0) and
// to the OS-tier latency offset (@ghidraAddress 0x2f8540); and the fraction of the wall/BGM drift
// folded back into the timing origin each correction (@ghidraAddress 0x2ec6a8).
constexpr double kMediaTimeMsScale = 1000.0;
constexpr float kLatencyOffsetScale = 1000.0f;
constexpr double kDriftCorrectionFactor = 0.1;

// The BGM-latency offset, in the offset's own units, added for each OS-version tier before the
// drift correction. The iOS-8.0-to-8.1 tier adds nothing; iOS 8.1 or later adds the larger offset;
// a pre- 8.0 device adds the smaller one (@ghidraAddress 0x308b44 = 49.9998, 0x308b48 = 33.3332).
constexpr float kLatencyOffset80To81 = 0.0f;
constexpr float kLatencyOffset81OrLater = 49.99980163574219f;
constexpr float kLatencyOffsetPre80 = 33.33319854736328f;

} // namespace

/** @ghidraAddress 0x131868 */
PlayTimer *PlayTimer::shared() {
    if (g_pPlayTimer == nullptr) {
        // The binary allocates the raw 0x40-byte object and zeroes the timing, OS-tier, and paused
        // fields; the zero-initialising members below reproduce that.
        g_pPlayTimer = new PlayTimer();
    }
    return g_pPlayTimer;
}

/** @ghidraAddress 0x1318a4 */
PlayTimer *PlayTimer::Update() {
    if (m_bPaused) {
        m_flFrameDelta = 0.0f;
        return this;
    }

    const double dNow = CACurrentMediaTime();
    m_dLastTime = dNow;
    double dInterval = dNow - m_dBaseTime;

    // While the music is driving playback, correct the timing origin for drift between the wall
    // clock and the BGM's reported position, once the BGM has advanced past the last sampled
    // position.
    if (m_bRunning) {
        const double dBgmTime = [AudioManager.sharedManager bgmCurrentTime];
        if (dBgmTime <= m_dAccumulated) {
            return nullptr;
        }
        m_dAccumulated = dBgmTime;

        float flLatencyOffset = m_flDelayFrameOffset;
        switch (m_nOsVersionTier) {
        case kOsVersionTier80To81:
            flLatencyOffset += kLatencyOffset80To81;
            break;
        case kOsVersionTier81OrLater:
            flLatencyOffset += kLatencyOffset81OrLater;
            break;
        default:
            flLatencyOffset += kLatencyOffsetPre80;
            break;
        }

        const double dDrift = static_cast<float>(
            ((dBgmTime + static_cast<double>(flLatencyOffset / kLatencyOffsetScale)) - dInterval) *
            kDriftCorrectionFactor);
        m_dBaseTime -= dDrift;
        dInterval += dDrift;
    }

    // The per-frame step is the drift-corrected interval since the last recorded play time, scaled
    // to milliseconds and clamped to non-negative.
    float flStep =
        static_cast<float>((dInterval - static_cast<double>(m_flPlayTime)) * kMediaTimeMsScale);
    if (flStep <= 0.0f) {
        flStep = 0.0f;
    }
    m_flFrameDelta = flStep;
    m_flPlayTime = static_cast<float>(dInterval);
    return this;
}
