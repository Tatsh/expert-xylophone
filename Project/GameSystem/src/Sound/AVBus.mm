//
//  AVBus.m
//  REFLEC BEAT plus
//
//  Reconstructed from Ghidra project rb458, program rb458 (class AVBus). @ghidraAddress values are
//  relative to the program image base.
//

#import "AVBus.h"

#import <AVFoundation/AVFoundation.h>

// The loop counts handed to AVAudioPlayer: a negative count repeats forever, zero plays once.
static const NSInteger kLoopForever = -1;
static const NSInteger kLoopOnce = 0;

// The gain reported for a voice that holds no player.
static const float kUnboundVoiceVolume = 1.0f;

@interface AVBus () <AVAudioPlayerDelegate> {
    // The bound source record. The binary compares it by identity in isSameSource: and clears it
    // on unbind.
    AudioSourceSlot::SourceRecord *mSource;
    // Bumped on every unbind, so a play handle minted against an older binding stops resolving to
    // this voice.
    unsigned short mCurrentID;
    // The playback state reported by status.
    AVBusStatus mStatus;
}

/**
 * @brief The voice's audio player, rebuilt each time a source is bound and released on unbind.
 * @ghidraAddress 0x41f48 (getter)
 * @ghidraAddress 0x41f58 (setter)
 */
@property(nonatomic, strong) AVAudioPlayer *player;

// The two source-binding constructors setSource: dispatches between. They are spelled "init..." in
// the binary but return a success flag rather than an object, so they are held out of the init
// method family.
- (BOOL)initWithContentsOfURL:(NSURL *)url
                       isLoop:(BOOL)isLoop __attribute__((objc_method_family(none)));
- (BOOL)initWithContentsOfData:(NSData *)data
                        isLoop:(BOOL)isLoop __attribute__((objc_method_family(none)));

@end

@implementation AVBus

#pragma mark - Lifecycle

/** @ghidraAddress 0x41308 */
- (instancetype)init {
    self = [super init];
    if (self) {
        mStatus = AVBusStatusNone;
        mCurrentID = 0;
    }
    return self;
}

/** @ghidraAddress 0x41e98 */
- (void)dealloc {
    self.player = nil;
}

#pragma mark - Source binding

/** @ghidraAddress 0x4135c */
- (BOOL)initWithContentsOfURL:(NSURL *)url
                       isLoop:(BOOL)isLoop __attribute__((objc_method_family(none))) {
    self.player = nil;
    NSError *error = nil;
    AVAudioPlayer *player = [[AVAudioPlayer alloc] initWithContentsOfURL:url error:&error];
    // The binary gates on the error slot rather than on the returned player.
    if (error != nil) {
        return NO;
    }
    self.player = player;
    self.player.numberOfLoops = isLoop ? kLoopForever : kLoopOnce;
    self.player.delegate = self;
    mStatus = AVBusStatusNone;
    return YES;
}

/** @ghidraAddress 0x414fc */
- (BOOL)initWithContentsOfData:(NSData *)data
                        isLoop:(BOOL)isLoop __attribute__((objc_method_family(none))) {
    self.player = nil;
    NSError *error = nil;
    AVAudioPlayer *player = [[AVAudioPlayer alloc] initWithData:data error:&error];
    if (error != nil) {
        return NO;
    }
    self.player = player;
    self.player.numberOfLoops = isLoop ? kLoopForever : kLoopOnce;
    self.player.delegate = self;
    mStatus = AVBusStatusNone;
    return YES;
}

/** @ghidraAddress 0x4169c */
- (unsigned short)setSource:(AudioSourceSlot::SourceRecord *)source {
    mSource = source;
    // A record carries the sound either as a URL or as a data buffer; the URL wins when both are
    // set, matching the binary's null test on the first field.
    if (source->source != nil) {
        [self initWithContentsOfURL:source->source isLoop:source->bLoop];
    } else {
        [self initWithContentsOfData:source->companion isLoop:source->bLoop];
    }
    return mCurrentID;
}

/** @ghidraAddress 0x4171c */
- (BOOL)removeSource {
    mSource = nullptr;
    ++mCurrentID;
    if (self.player == nil) {
        return NO;
    }
    self.player = nil;
    return YES;
}

/** @ghidraAddress 0x41f20 */
- (BOOL)isSameSource:(AudioSourceSlot::SourceRecord *)source {
    return mSource == source;
}

#pragma mark - Transport

/** @ghidraAddress 0x41798 */
- (BOOL)prepare {
    if (self.player == nil || self.player.playing) {
        return NO;
    }
    [self.player prepareToPlay];
    mStatus = AVBusStatusPrepared;
    return YES;
}

/** @ghidraAddress 0x41898 */
- (BOOL)play {
    // The binary's test is (status | 2) == 3, which admits exactly the prepared and paused states.
    if ((mStatus != AVBusStatusPrepared && mStatus != AVBusStatusPaused) || self.player == nil) {
        return NO;
    }
    mStatus = AVBusStatusPlaying;
    if (![self.player play]) {
        mStatus = AVBusStatusStopped;
    }
    return YES;
}

/** @ghidraAddress 0x41964 */
- (BOOL)stop {
    if (self.player == nil) {
        return NO;
    }
    [self.player stop];
    mStatus = AVBusStatusStopped;
    return YES;
}

/** @ghidraAddress 0x41a08 */
- (BOOL)pause {
    if (self.player == nil) {
        return NO;
    }
    if (self.player.playing) {
        [self.player stop]; // Yes, the binary stops the player rather than pausing it.
        mStatus = AVBusStatusPaused;
    } else {
        mStatus = AVBusStatusStopped;
    }
    return YES;
}

/** @ghidraAddress 0x41afc */
- (BOOL)offPause {
    if (self.player == nil || mStatus != AVBusStatusPaused) {
        return NO;
    }
    mStatus = AVBusStatusPlaying;
    if (![self.player play]) {
        mStatus = AVBusStatusStopped;
    }
    return YES;
}

#pragma mark - State

/** @ghidraAddress 0x41bc0 */
- (BOOL)setVolume:(float)volume {
    if (self.player == nil) {
        return NO;
    }
    self.player.volume = volume;
    return YES;
}

/** @ghidraAddress 0x41c64 */
- (float)volume {
    if (self.player == nil) {
        return kUnboundVoiceVolume;
    }
    return self.player.volume;
}

/** @ghidraAddress 0x41f38 */
- (unsigned short)currentID {
    return mCurrentID;
}

/** @ghidraAddress 0x41d04 */
- (AVBusStatus)status {
    return mStatus;
}

#pragma mark - AVAudioPlayerDelegate

/** @ghidraAddress 0x41d14 */
- (void)audioPlayerDidFinishPlaying:(AVAudioPlayer *)player successfully:(BOOL)flag {
    mStatus = AVBusStatusStopped;
}

/** @ghidraAddress 0x41d28 */
- (void)audioPlayerBeginInterruption:(AVAudioPlayer *)player {
    if (mStatus == AVBusStatusPlaying) {
        mStatus = player.playing ? AVBusStatusPlaying : AVBusStatusStopped;
    }
}

/** @ghidraAddress 0x41da8 */
- (void)audioPlayerEndInterruption:(AVAudioPlayer *)player {
    if (mStatus == AVBusStatusPlaying && ![player play]) {
        mStatus = AVBusStatusStopped;
    }
}

/** @ghidraAddress 0x41e20 */
- (void)audioPlayerEndInterruption:(AVAudioPlayer *)player withOptions:(NSUInteger)flags {
    if (mStatus == AVBusStatusPlaying && ![player play]) {
        mStatus = AVBusStatusStopped;
    }
}

@end
