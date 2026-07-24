#pragma once

//
//  linear_tween.h
//  REFLEC BEAT plus
//
//  A recurring engine idiom: a five-float linear-interpolation channel embedded in a UI layer
//  (a start value, an end value, a duration, the elapsed time, and the current interpolated value).
//  Many layers advance one such channel per frame; each binary function operates on the channel
//  embedded at its own offset within the owning layer.
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
     * @brief Advances the channel by @p flDelta and recomputes @c m_flCurrent, unless the channel
     * has already reached its duration.
     *
     * The elapsed time is clamped to the duration; a zero duration forces the progress to 1. This
     * matches the shared tween idiom used by the title, full-combo, grade-gauge, and number-effect
     * layers.
     * @param flDelta The time (or frame count) to advance by.
     */
    void Advance(float flDelta);
};

// The per-layer channel-advance functions. Each advances the @c LinearTween embedded at its own
// offset within the owning layer; the owning layer classes are not modelled yet, so each takes the
// layer as an opaque pointer.

/**
 * @brief Advances the title screen's fade channel by @p nDeltaFrames.
 * @ghidraAddress 0x149ff4
 */
void CalculateTitleFade(void *pLayer, int nDeltaFrames);
/**
 * @brief Advances the title screen's secondary fade/tween channel by @p nDeltaFrames.
 * @ghidraAddress 0x152548
 */
void AdvanceTitleFadeValue(void *pLayer, int nDeltaFrames);
/**
 * @brief Advances a classic-theme animation channel's eased progress by @p flDelta.
 * @ghidraAddress 0x10a5fc
 */
void AdvanceEasedProgress(void *pState, float flDelta);
/**
 * @brief Advances the full-combo layer's fade/scale channel by @p flDeltaTime.
 * @ghidraAddress 0x18795c
 */
void AdvanceFcFadeInterp(float flDeltaTime, void *pLayer);
/**
 * @brief Advances the grade-gauge display's interpolation channel by @p flDeltaTime.
 * @ghidraAddress 0x120a74
 */
void AdvanceGradeGaugeChannel(float flDeltaTime, void *pThis);
/**
 * @brief Advances the number-effect layer's fade channel by @p flDeltaTime and raises its active
 * flag.
 * @ghidraAddress 0x189ef0
 */
void AdvanceNumberFadeInterp(float flDeltaTime, void *pLayer);
/**
 * @brief Advances a score-counter roll-up animation, snapping to the end value once complete.
 * @ghidraAddress 0x18bd58
 */
void AdvanceScoreDigitInterp(float flDeltaTime, void *pAnim);

// code: language=C++
// kate: hl C++;
// vim: set ft=cpp :
