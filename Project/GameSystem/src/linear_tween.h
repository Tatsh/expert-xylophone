#pragma once

//
//  linear_tween.h
//  REFLEC BEAT plus
//
//  A recurring engine idiom: a five-float linear-interpolation channel embedded in a UI layer
//  (a start value, an end value, a duration, the elapsed time, and the current interpolated value).
//  Many layers advance one such channel per frame. Each advancer is an instance method of its
//  owning layer; the layers are not fully modelled yet, so only the channel (and, where a method
//  touches them, the sibling fields) is named, with reserved spans positioning it at its real
//  offset.
//
//  Reconstructed from Ghidra project rb458, program rb458. @ghidraAddress values are relative to
//  the program image base.
//

/**
 * @brief A five-float linear-interpolation channel: current = start + t*(end - start), where
 * t = elapsed / duration clamped to 1.
 * @ghidraAddress LinearTween (engine tween sub-struct)
 */
struct LinearTween {
    float m_flStart = {};    // +0x00 interpolation start value
    float m_flEnd = {};      // +0x04 interpolation end value
    float m_flDuration = {}; // +0x08 total duration
    float m_flElapsed = {};  // +0x0c elapsed time so far
    float m_flCurrent = {};  // +0x10 last computed interpolated value

    /**
     * @brief Advances the channel by @p flDelta and recomputes @c m_flCurrent, unless it has
     * already reached its duration. The elapsed time is clamped to the duration; a zero duration
     * forces the progress to 1.
     * @param flDelta The time (or frame count) to advance by.
     */
    void Advance(float flDelta);
};

/**
 * @brief The classic-theme animation state, as far as its eased-progress channel is concerned.
 * @ghidraAddress ClassicThemeAnimation (engine layer)
 */
class ClassicThemeAnimation {
public:
    /**
     * @brief Advances the eased-progress channel by @p flDelta.
     * @ghidraAddress 0x10a5fc
     */
    void AdvanceEasedProgress(float flDelta);

private:
    unsigned char m_aReserved00[0x44] = {}; // +0x00
    LinearTween m_easeChannel;              // +0x44
};

/**
 * @brief The full-combo effect layer, as far as its fade/scale channel is concerned.
 * @ghidraAddress FullComboEffectLayer (engine layer)
 */
class FullComboEffectLayer {
public:
    /**
     * @brief Advances the fade/scale channel by @p flDeltaTime.
     * @ghidraAddress 0x18795c
     */
    void AdvanceFadeInterp(float flDeltaTime);

private:
    unsigned char m_aReserved00[0x6c] = {}; // +0x00
    LinearTween m_fadeChannel;              // +0x6c
};

/**
 * @brief The grade-gauge display layer, as far as its interpolation channel is concerned.
 * @ghidraAddress GradeGaugeLayer (engine layer)
 */
class GradeGaugeLayer {
public:
    /**
     * @brief Advances the grade-gauge channel by @p flDeltaTime.
     * @ghidraAddress 0x120a74
     */
    void AdvanceChannel(float flDeltaTime);

private:
    unsigned char m_aReserved00[0x6c] = {}; // +0x00
    LinearTween m_gaugeChannel;             // +0x6c
};

/**
 * @brief The number-effect layer, as far as its fade channel and active flag are concerned.
 * @ghidraAddress NumberEffectLayer (engine layer)
 */
class NumberEffectLayer {
public:
    /**
     * @brief Advances the fade channel by @p flDeltaTime and raises the active flag.
     * @ghidraAddress 0x189ef0
     */
    void AdvanceFadeInterp(float flDeltaTime);

private:
    unsigned char m_aReserved00[0x30] = {}; // +0x00
    LinearTween m_fadeChannel;              // +0x30 (five floats, ending at +0x44)
    bool m_bFadeActive = {};                // +0x44 raised once the channel advances a frame
};

/**
 * @brief A score-counter roll-up record: a compact value/start/end/elapsed/duration tuple that
 * snaps to the end value once complete.
 * @ghidraAddress ScoreDigitAnim (engine 0x18-byte record)
 */
class ScoreDigitAnim {
public:
    /**
     * @brief Advances the roll-up by @p flDeltaTime, snapping the value to the end once complete.
     * @ghidraAddress 0x18bd58
     */
    void Advance(float flDeltaTime);

private:
    unsigned char m_aReserved00[0x04] = {}; // +0x00
    float m_flStart = {};                   // +0x04 start value
    float m_flEnd = {};                     // +0x08 end value
    float m_flValue = {};                   // +0x0c current displayed value
    float m_flElapsed = {};                 // +0x10 elapsed time so far
    float m_flDuration = {};                // +0x14 total duration
};

// code: language=C++
// kate: hl C++;
// vim: set ft=cpp :
