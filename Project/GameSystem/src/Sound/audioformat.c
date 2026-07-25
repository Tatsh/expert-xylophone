#include "audioformat.h"

// The bytes-per-frame and bits-per-channel of the AudioUnit canonical 32-bit sample format.
#define kCanonicalBytesPerFrame 4
#define kCanonicalBitsPerChannel 32

// The AudioUnit canonical format flags (signed integer, packed, non-interleaved) with 24 fraction
// bits, i.e. 8.24 fixed point. Spelled as the numeric value the binary embeds; it is
// kAudioFormatFlagsAudioUnitCanonical for a 32-bit sample.
#define kCanonicalFormatFlags                                                                      \
    (kAudioFormatFlagIsSignedInteger | kAudioFormatFlagIsPacked |                                  \
     kAudioFormatFlagIsNonInterleaved | (24 << kLinearPCMFormatFlagsSampleFractionShift))

// Signed 16-bit interleaved linear PCM parameters.
#define kPcm16BitsPerChannel 16
#define kPcm16BytesPerSample 2
#define kPcm16FormatFlags (kAudioFormatFlagIsPacked | kAudioFormatFlagIsSignedInteger)

/** @ghidraAddress 0x33e9c */
void InitFloatPcmFormatDescriptor(AudioStreamBasicDescription *pAsbd,
                                  double dSampleRate,
                                  int nChannelCount) {
    pAsbd->mSampleRate = dSampleRate;
    pAsbd->mFormatID = kAudioFormatLinearPCM;
    pAsbd->mFormatFlags = kCanonicalFormatFlags;
    pAsbd->mBytesPerPacket = kCanonicalBytesPerFrame;
    pAsbd->mFramesPerPacket = 1;
    pAsbd->mBytesPerFrame = kCanonicalBytesPerFrame;
    pAsbd->mChannelsPerFrame = nChannelCount;
    pAsbd->mBitsPerChannel = kCanonicalBitsPerChannel;
    pAsbd->mReserved = 0;
}

/** @ghidraAddress 0x33ec8 */
void InitPcmFormatDescriptor(AudioStreamBasicDescription *pAsbd,
                             double dSampleRate,
                             int nChannelCount) {
    pAsbd->mSampleRate = dSampleRate;
    pAsbd->mFormatID = kAudioFormatLinearPCM;
    pAsbd->mFormatFlags = kPcm16FormatFlags;
    pAsbd->mChannelsPerFrame = nChannelCount;
    pAsbd->mBitsPerChannel = kPcm16BitsPerChannel;
    pAsbd->mFramesPerPacket = 1;
    pAsbd->mBytesPerFrame = nChannelCount * kPcm16BytesPerSample;
    pAsbd->mBytesPerPacket = nChannelCount * kPcm16BytesPerSample;
}
