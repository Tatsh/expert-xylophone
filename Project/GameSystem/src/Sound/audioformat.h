/**
 * @file
 * @brief Shared audio-format descriptor builders for the sound engine.
 */

#ifndef AUDIOFORMAT_H
#define AUDIOFORMAT_H

#include <AudioToolbox/AudioToolbox.h>

#ifdef __cplusplus
extern "C" {
#endif

/**
 * @brief Fill an @c AudioStreamBasicDescription for the AudioUnit canonical 32-bit sample format.
 *
 * Produces the non-interleaved 8.24 fixed-point ("type 4", four bytes per frame) format the mixer
 * output unit is configured with, at the given sample rate and channel count.
 * @param pAsbd The descriptor to fill.
 * @param dSampleRate The sample rate, in hertz.
 * @param nChannelCount The number of channels.
 * @ghidraAddress 0x33e9c
 */
void InitFloatPcmFormatDescriptor(AudioStreamBasicDescription *pAsbd,
                                  double dSampleRate,
                                  int nChannelCount);

/**
 * @brief Fill an @c AudioStreamBasicDescription for signed 16-bit interleaved linear PCM.
 * @param pAsbd The descriptor to fill.
 * @param dSampleRate The sample rate, in hertz.
 * @param nChannelCount The number of channels.
 * @ghidraAddress 0x33ec8
 */
void InitPcmFormatDescriptor(AudioStreamBasicDescription *pAsbd,
                             double dSampleRate,
                             int nChannelCount);

#ifdef __cplusplus
}
#endif

#endif // AUDIOFORMAT_H
