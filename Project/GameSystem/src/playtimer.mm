#import "playtimer.h"

#import <QuartzCore/QuartzCore.h>

#import "AudioManager.h"

PlayTimer *g_pPlayTimer = nullptr; // @ghidraAddress 0x3de020

// One 60th of a second in milliseconds. @ghidraAddress 0x2ef178
const float g_flDelayFrameToSeconds = 16.6666f;

namespace {

// @ghidraAddress 0x2eeea0, 0x2f8540, and 0x2ec6a8
constexpr double kMediaTimeMsScale = 1000.0;
constexpr float kLatencyOffsetScale = 1000.0f;
constexpr double kDriftCorrectionFactor = 0.1;

// @ghidraAddress 0x308b44 (49.9998) and 0x308b48 (33.3332)
constexpr float kLatencyOffset80To81 = 0.0f;
constexpr float kLatencyOffset81OrLater = 49.9998f;
constexpr float kLatencyOffsetPre80 = 33.3332f;

} // namespace

/** @ghidraAddress 0x131868 */
PlayTimer *PlayTimer::shared() {
    if (g_pPlayTimer == nullptr) {
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

    if (m_bRunning) {
        const double dBgmTime = [AudioManager.sharedManager bgmCurrentTime];
        // Only the drift correction is gated on the BGM having advanced; the frame step below
        // runs regardless. @ghidraAddress 0x1318dc, 0x131920
        if (dBgmTime > m_dAccumulated) {
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
                ((dBgmTime + static_cast<double>(flLatencyOffset / kLatencyOffsetScale)) -
                 dInterval) *
                kDriftCorrectionFactor);
            m_dBaseTime -= dDrift;
            dInterval += dDrift;
        }
    }

    float flStep =
        static_cast<float>((dInterval - static_cast<double>(m_flPlayTime)) * kMediaTimeMsScale);
    if (flStep <= 0.0f) {
        flStep = 0.0f;
    }
    m_flFrameDelta = flStep;
    m_flPlayTime = static_cast<float>(dInterval);
    return this;
}
