//
//  AudioManager.mm
//  REFLEC BEAT plus
//
//  Reconstructed from Ghidra project rb458, program rb458 (class AudioManager). Verified against the
//  arm64 disassembly (the soft-float -setVolume:/-playBgm: fade comparisons, the flat C-array ivar
//  arithmetic over the instance and manage-id tables, and the tagged sound-effect handle bit fields
//  are dropped or garbled by the decompiler).
//

#import "AudioManager.h"

#include <new>

#import <Foundation/Foundation.h>

#import "neEngineBridge.h"

namespace {

// The number of concurrent sound-effect instances tracked for the cached voice subsystem.
constexpr int kInstanceSlotCount = 4;
// The head slot of an instance table, holding the oldest tracked instance; it is the one dropped
// first when the table is full.
constexpr int kOldestInstanceSlot = 0;
// The number of mixer groups whose per-group instance tables and volumes are tracked.
constexpr int kGroupCount = 2;

// The number of engine channels the cached voice subsystem is initialised with.
constexpr int kVoiceChannelCount = 4;

// The sentinel stored in an instance slot's handle field to mark it free.
constexpr unsigned int kInvalidHandle = 0xffffffff;

// The instance-slot state values kept alongside each handle.
enum InstanceSlotState {
    kInstanceSlotStatePlaying = 0,
    kInstanceSlotStateFree = 2,
};

// The engine playback-status values returned for a handle.
enum PlaybackStatus {
    kPlaybackStatusStopped = -1,
    kPlaybackStatusPlaying = 2,
    kPlaybackStatusFinished = 4,
};

// The bit mask isolating the raw engine index from a tagged sound-effect resource handle.
constexpr unsigned int kResourceIndexMask = 0x0fffffff;
// The tag set on a resource handle registered by index in the cached voice subsystem.
constexpr unsigned int kResourceTagVoiceIndex = 0x10000000;
// The tag set on a resource handle registered by index in the mixer-bus subsystem.
constexpr unsigned int kResourceTagBusIndex = 0x60000000;

// The exclusive upper bound on an accepted group volume.
constexpr int kMaxVolume = 0x80;
// The default per-group sound-effect volume, one step below the maximum.
constexpr int kDefaultSeVolume = kMaxVolume - 1;

// The mixer group whose sound effects route to the cached @c caPlayer voice backend
// (@c sePlayer). Any other group value routes to the @c AVFoundation bus mixer (@c seAVPlayer).
constexpr int kSeGroupCaPlayer = 0;

// The sentinel returned by the register-by-key backends (@c RegisterSourceForKey,
// @c LoadAndCacheSoundForKey) when registration fails; any non-zero value means the source was
// registered.
constexpr int kRegisterFailed = 0;

// The @c AVAudioPlayer loop count that repeats a clip indefinitely.
constexpr int kLoopForever = -1;
// The @c AVAudioPlayer loop count that plays a clip exactly once.
constexpr int kPlayOnce = 0;

// The fade duration, in seconds, that requests an immediate (non-faded) start or stop.
constexpr double kNoFadeTime = 0.0;

// The full-scale @c AVAudioPlayer volume.
constexpr float kFullVolume = 1.0f;
// The silent @c AVAudioPlayer volume.
constexpr float kSilentVolume = 0.0f;

// The player selector passed to the interruption helpers: index @c 0 is the music player, index
// @c 1 the voice player.
enum PlayerIndex {
    kPlayerIndexBgm = 0,
    kPlayerIndexVoice = 1,
};

// One tracked sound-effect instance: its play handle and its owning mixer group.
struct SeManageId {
    unsigned int instanceId; // +0x0
    int busId;               // +0x4
    int group;               // +0x8
};

} // namespace

// The step interval of the background-music fade timers, in seconds; a fade shorter than this plays
// or stops immediately.
// @ghidraAddress 0x2eef30 (g_dAudioManagerFadeStepInterval)
constexpr double kFadeStepInterval = 0.05;

// The background-music fade-in duration applied when resuming after an interruption, in seconds.
// @ghidraAddress 0x2ec718 (g_dAudioManagerResumeFadeInTime)
constexpr double kResumeFadeInTime = 0.3;

@interface AudioManager () {
    // Engine-side subsystems and the instance-tracking tables, laid out to match the binary's ivar
    // block. The 32-bit offsets are documentation only; access always goes through these named
    // fields.
    caPlayerMgr *sePlayer;                                  // +0x08
    AudioSourceSlot *seAVPlayer;                            // +0x10
    BOOL isSuspend;                                         // +0x18
    float unitVolume;                                       // +0x48
    SeManageId seManageId[kGroupCount][kInstanceSlotCount]; // +0xb8
    SeManageId seList[kInstanceSlotCount];                  // +0xc0
    BOOL isInterruption[kGroupCount];                       // +0x49
    BOOL isPlaying[kGroupCount];                            // +0x4b
    BOOL isOnPause;                                         // +0x55
    BOOL isOnPauseVoice;                                    // +0x54
    int seVolume[kGroupCount];                              // +0x58
    BOOL _isStart;                                          // +0x50
}
@end

@implementation AudioManager

#pragma mark - Singleton

+ (instancetype)sharedManager {
    /** @ghidraAddress 0x3d0c4 */
    static AudioManager *instance = nil;
    @synchronized(self) {
        if (instance == nil) {
            instance = [[AudioManager alloc] init];
        }
    }
    return instance;
}

#pragma mark - Lifecycle

- (instancetype)init {
    /** @ghidraAddress 0x3d154 */
    self = [super init];
    if (self) {
        sePlayer = new caPlayerMgr;
        seAVPlayer = new AudioSourceSlot;
        seAVPlayer->InitAudioSourceSlot();
        _isStart = NO;

        for (int slot = 0; slot < kInstanceSlotCount; ++slot) {
            seList[slot].instanceId = kInvalidHandle;
        }

        self.seNameList = [[NSMutableArray alloc] init];
        self.seRidList = [[NSMutableArray alloc] init];

        isInterruption[kPlayerIndexBgm] = NO;
        isInterruption[kPlayerIndexVoice] = NO;
        isPlaying[kPlayerIndexBgm] = NO;
        isPlaying[kPlayerIndexVoice] = NO;
        isSuspend = NO;
        isOnPauseVoice = NO;
        isOnPause = NO;

        for (int group = 0; group < kGroupCount; ++group) {
            seVolume[group] = kDefaultSeVolume;
            for (int slot = 0; slot < kInstanceSlotCount; ++slot) {
                seManageId[group][slot].instanceId = kInvalidHandle;
                seManageId[group][slot].busId = group * kInstanceSlotCount + slot;
            }
        }

        self.seType = [[NSMutableDictionary alloc] init];
    }
    return self;
}

- (void)dealloc {
    /** @ghidraAddress 0x40e90 */
    [self.fadeTimer invalidate];
    if (sePlayer) {
        sePlayer->DestroyAudioContext();
        sePlayer->DestroyAudioContextWrapper();
        delete sePlayer;
        sePlayer = nullptr;
    }
}

#pragma mark - System lifecycle

- (void)systemStart {
    /** @ghidraAddress 0x3d3ec */
    NSTimer *timer = [NSTimer timerWithTimeInterval:0
                                             target:self
                                           selector:@selector(onStartPlayer:)
                                           userInfo:nil
                                            repeats:NO];
    [[NSRunLoop currentRunLoop] addTimer:timer forMode:NSRunLoopCommonModes];
}

- (void)systemStartBlock {
    /** @ghidraAddress 0x3d4b4 */
    [self onStartPlayer:nil];
}

- (void)onStartPlayer:(nullable NSTimer *)timer {
    /** @ghidraAddress 0x3d50c */
    sePlayer->InitializeAudioContext(kVoiceChannelCount);
    InitializeSourceManager();
    _isStart = YES;
}

- (void)systemTerminate {
    /** @ghidraAddress 0x3d4c4 */
    sePlayer->DestroyAudioContext();
    [self releaseBgm];
    [self releaseVoice];
}

- (void)systemSuspend {
    /** @ghidraAddress 0x40d6c */
    if (_isStart && !isSuspend) {
        sePlayer->StopAudioGraph();
        seAVPlayer->PauseAllAudioBuses();
        [self suspendPlayer:kPlayerIndexBgm];
        [self suspendPlayer:kPlayerIndexVoice];
        isSuspend = YES;
    }
}

- (void)systemResume {
    /** @ghidraAddress 0x40e00 */
    if (_isStart && isSuspend) {
        sePlayer->StartAudioGraph();
        seAVPlayer->ResumeAllAudioBuses();
        [self resumePlayer:kPlayerIndexBgm];
        [self resumePlayer:kPlayerIndexVoice];
        isSuspend = NO;
    }
}

- (BOOL)isStart {
    /** @ghidraAddress 0x4101c */
    return _isStart;
}

#pragma mark - Background music

- (void)initBgm:(BOOL)loop {
    /** @ghidraAddress 0x3d560 */
    self.bgmPlayer.numberOfLoops = loop ? kLoopForever : kPlayOnce;
    self.bgmPlayer.delegate = self;
    [self.bgmPlayer prepareToPlay];
}

- (BOOL)loadBgmData:(nullable NSData *)data isLoop:(BOOL)loop {
    /** @ghidraAddress 0x3d638 */
    if (data == nil) {
        return NO;
    }
    [self releaseBgm];
    NSError *error = nil;
    self.bgmPlayer = [[AVAudioPlayer alloc] initWithData:data error:&error];
    if (error == nil) {
        [self initBgm:loop];
    }
    return error == nil;
}

- (BOOL)loadBgmDataWithBytes:(const void *)bytes length:(int)length isLoop:(BOOL)loop {
    /** @ghidraAddress 0x3d764 */
    return [self loadBgmData:[NSData dataWithBytes:bytes length:length] isLoop:loop];
}

- (BOOL)loadBgmDataWithBytesNoCopy:(void *)bytes length:(int)length isLoop:(BOOL)loop {
    /** @ghidraAddress 0x3d7ec */
    return [self loadBgmData:[NSData dataWithBytesNoCopy:bytes length:length] isLoop:loop];
}

- (BOOL)loadBgmDataWithBytesNoCopy:(void *)bytes
                            length:(int)length
                      freeWhenDone:(BOOL)freeWhenDone
                            isLoop:(BOOL)loop {
    /** @ghidraAddress 0x3d874 */
    return [self loadBgmData:[NSData dataWithBytesNoCopy:bytes
                                                  length:length
                                            freeWhenDone:freeWhenDone]
                      isLoop:loop];
}

- (void)releaseBgm {
    /** @ghidraAddress 0x3e868 */
    [self.bgmPlayer stop];
    self.bgmPlayer = nil;
}

- (BOOL)playBgm:(double)time {
    /** @ghidraAddress 0x3f994 */
    if (self.bgmPlayer == nil) {
        return NO;
    }
    if (!isInterruption[kPlayerIndexBgm]) {
        [self deleteFadeTimer];
        if (time <= kFadeStepInterval) {
            self.bgmPlayer.volume = kFullVolume;
            if (![self.bgmPlayer play]) {
                if (![self.bgmPlayer prepareToPlay]) {
                    return NO;
                }
                if (![self.bgmPlayer play]) {
                    return NO;
                }
            }
        } else {
            self.bgmPlayer.volume = kSilentVolume;
            if (![self.bgmPlayer play]) {
                if (![self.bgmPlayer prepareToPlay]) {
                    return NO;
                }
                if (![self.bgmPlayer play]) {
                    return NO;
                }
            }
            [self createBgmFadeInTimer:time];
        }
    }
    isOnPause = NO;
    isPlaying[kPlayerIndexBgm] = YES;
    return YES;
}

- (BOOL)stopBgm:(double)time {
    /** @ghidraAddress 0x3fc1c */
    if (self.bgmPlayer == nil) {
        return NO;
    }
    [self deleteFadeTimer];
    if (time <= kFadeStepInterval) {
        [self.bgmPlayer stop];
        self.bgmPlayer.currentTime = 0;
        isPlaying[kPlayerIndexBgm] = NO;
        isOnPause = NO;
    } else {
        [self createBgmFadeOutTimer:time];
    }
    return YES;
}

- (BOOL)onPauseBgm:(double)time {
    /** @ghidraAddress 0x3fd48 */
    if (self.bgmPlayer == nil) {
        return NO;
    }
    isOnPause = YES;
    [self deleteFadeTimer];
    if (time <= kFadeStepInterval) {
        [self.bgmPlayer pause];
    } else {
        [self createBgmFadeOutTimer:time];
    }
    return YES;
}

- (BOOL)isPlayingBgm {
    /** @ghidraAddress 0x40018 */
    if (self.bgmPlayer == nil) {
        return NO;
    }
    return self.bgmPlayer.isPlaying;
}

- (double)bgmCurrentTime {
    /** @ghidraAddress 0x3fe30 */
    if (self.bgmPlayer == nil) {
        return 0.0;
    }
    return self.bgmPlayer.currentTime;
}

- (double)bgmDeviceCurrentTime {
    /** @ghidraAddress 0x3fed0 */
    if (self.bgmPlayer == nil) {
        return 0.0;
    }
    return self.bgmPlayer.deviceCurrentTime;
}

- (void)setBgmCurrentTime:(double)bgmCurrentTime {
    /** @ghidraAddress 0x3ff70 */
    if (self.bgmPlayer != nil) {
        self.bgmPlayer.currentTime = bgmCurrentTime;
    }
}

- (void)seekBgmToTop {
    /** @ghidraAddress 0x40660 */
    self.bgmPlayer.currentTime = 0;
}

- (void)pushBgm {
    /** @ghidraAddress 0x4048c */
    [self onPauseBgm:kNoFadeTime];
    [self.stackBgm stop];
    self.stackBgm = nil;
    self.stackBgm = self.bgmPlayer;
    self.bgmPlayer.delegate = nil;
    self.bgmPlayer = nil;
}

- (void)popBgm {
    /** @ghidraAddress 0x405a4 */
    [self releaseBgm];
    self.bgmPlayer = self.stackBgm;
    self.bgmPlayer.delegate = self;
    self.stackBgm = nil;
}

#pragma mark - Voice

- (BOOL)loadVoiceData:(nullable NSData *)data isLoop:(BOOL)loop {
    /** @ghidraAddress 0x3d8fc */
    if (data == nil) {
        return NO;
    }
    self.voicePlayer = nil;
    NSError *error = nil;
    self.voicePlayer = [[AVAudioPlayer alloc] initWithData:data error:&error];
    if (error == nil) {
        self.voicePlayer.numberOfLoops = loop ? kLoopForever : kPlayOnce;
        self.voicePlayer.delegate = self;
        [self.voicePlayer prepareToPlay];
    }
    return error == nil;
}

- (void)releaseVoice {
    /** @ghidraAddress 0x3e8d4 */
    self.voicePlayer = nil;
}

- (BOOL)playVoice {
    /** @ghidraAddress 0x406b8 */
    if (self.voicePlayer == nil) {
        return NO;
    }
    if (isOnPauseVoice) {
        self.voicePlayer.currentTime = self.voicePlayTime;
    }
    [self.voicePlayer play];
    isPlaying[kPlayerIndexVoice] = YES;
    isOnPauseVoice = NO;
    return YES;
}

- (BOOL)stopVoice {
    /** @ghidraAddress 0x407bc */
    if (self.voicePlayer == nil) {
        return NO;
    }
    [self.voicePlayer stop];
    isPlaying[kPlayerIndexVoice] = NO;
    return YES;
}

- (BOOL)onPauseVoice {
    /** @ghidraAddress 0x40860 */
    if (self.voicePlayer == nil) {
        return NO;
    }
    self.voicePlayTime = self.voicePlayer.currentTime;
    [self.voicePlayer stop];
    isOnPauseVoice = YES;
    return YES;
}

- (BOOL)isPlayingVoice {
    /** @ghidraAddress 0x40948 */
    if (self.voicePlayer == nil) {
        return NO;
    }
    return self.voicePlayer.isPlaying;
}

#pragma mark - Sound effect loading

- (int)getGroupID:(nullable NSString *)callName resourceId:(int)resourceId {
    /** @ghidraAddress 0x3dac4 */
    if (callName == nil) {
        return [self.seType[[NSNumber numberWithInt:resourceId]] intValue];
    }
    return [self.seType[callName] intValue];
}

- (int)loadSe:(nullable NSString *)path
       isLoop:(BOOL)loop
     callName:(nullable NSString *)callName
        group:(int)group {
    /** @ghidraAddress 0x3dc48 */
    if (path == nil) {
        return kInvalidHandle;
    }

    if (group != kSeGroupCaPlayer) {
        NSURL *url = [NSURL fileURLWithPath:path];
        if (callName != nil) {
            int registered = seAVPlayer->RegisterSourceForKey(url, callName, loop);
            if (registered != kRegisterFailed) {
                [self.seNameList addObject:callName];
            }
            self.seType[callName] = [NSNumber numberWithInt:group];
            return kInvalidHandle;
        }
        unsigned int index = seAVPlayer->AddSourceToManager(url, loop);
        if (index != kInvalidHandle) {
            [self.seRidList addObject:[NSNumber numberWithInt:static_cast<int>(index)]];
        }
        unsigned int handle = index | kResourceTagBusIndex;
        self.seType[[NSNumber numberWithInt:static_cast<int>(handle)]] =
            [NSNumber numberWithInt:group];
        return static_cast<int>(handle);
    }

    const char *cPath = path.UTF8String;
    if (callName == nil) {
        unsigned int index = sePlayer->CreateAndLoadSound(cPath, loop);
        if (index != kInvalidHandle) {
            [self.seRidList addObject:[NSNumber numberWithInt:static_cast<int>(index)]];
        }
        unsigned int handle = index | kResourceTagVoiceIndex;
        self.seType[[NSNumber numberWithInt:static_cast<int>(handle)]] =
            [NSNumber numberWithInt:kSeGroupCaPlayer];
        return static_cast<int>(handle);
    }

    int registered = sePlayer->LoadAndCacheSoundForKey(cPath, callName, loop);
    if (registered != kRegisterFailed) {
        [self.seNameList addObject:callName];
    }
    self.seType[callName] = [NSNumber numberWithInt:kSeGroupCaPlayer];
    return kInvalidHandle;
}

- (void)releaseSe:(nullable NSString *)callName resourceId:(int)resourceId {
    /** @ghidraAddress 0x3e1a4 */
    int group = [self getGroupID:callName resourceId:resourceId];
    if (callName == nil) {
        if (group == kSeGroupCaPlayer) {
            sePlayer->FreeSoundDataByIndex(static_cast<unsigned int>(resourceId) &
                                           kResourceIndexMask);
        } else {
            seAVPlayer->RemoveAudioSourceByIndex(static_cast<unsigned int>(resourceId) &
                                                 kResourceIndexMask);
        }
        for (NSUInteger i = 0; i < self.seRidList.count; ++i) {
            if ([self.seRidList[i] intValue] == resourceId) {
                [self.seRidList removeObjectAtIndex:i];
                break;
            }
        }
        [self.seType removeObjectForKey:[NSNumber numberWithInt:resourceId]];
    } else {
        if (group == kSeGroupCaPlayer) {
            sePlayer->FreeSoundForKey(callName);
        } else {
            seAVPlayer->RemoveAudioSourceByKey(callName);
        }
        for (NSUInteger i = 0; i < self.seNameList.count; ++i) {
            if ([callName compare:self.seNameList[i]] == NSOrderedSame) {
                [self.seNameList removeObjectAtIndex:i];
                break;
            }
        }
        [self.seType removeObjectForKey:callName];
    }
}

- (void)releaseSeAll {
    /** @ghidraAddress 0x3e580 */
    for (NSUInteger i = 0; i < self.seNameList.count; ++i) {
        NSString *callName = self.seNameList[i];
        int group = [self getGroupID:callName resourceId:0];
        if (group == kSeGroupCaPlayer) {
            sePlayer->FreeSoundForKey(callName);
        } else {
            seAVPlayer->RemoveAudioSourceByKey(callName);
        }
    }
    [self.seNameList removeAllObjects];

    for (NSUInteger i = 0; i < self.seRidList.count; ++i) {
        NSNumber *rid = self.seRidList[i];
        int group = [self getGroupID:nil resourceId:rid.intValue];
        if (group == kSeGroupCaPlayer) {
            sePlayer->FreeSoundDataByIndex(static_cast<unsigned int>(rid.intValue) &
                                           kResourceIndexMask);
        } else {
            seAVPlayer->RemoveAudioSourceByIndex(static_cast<unsigned int>(rid.intValue) &
                                                 kResourceIndexMask);
        }
    }
    [self.seRidList removeAllObjects];
    [self.seType removeAllObjects];
}

#pragma mark - Sound effect playback

- (unsigned int)prepare:(nullable NSString *)callName
             resourceId:(int)resourceId
                 volume:(int)volume {
    /** @ghidraAddress 0x3e8e4 */
    [self orderInstanceList];
    int group = [self getGroupID:callName resourceId:resourceId];
    unsigned int handle = [self acquireInstance:callName
                                     resourceId:resourceId
                                          group:group
                                         volume:volume];
    if (handle == kInvalidHandle) {
        [self stopOldInstance];
        handle = [self acquireInstance:callName resourceId:resourceId group:group volume:volume];
    }
    [self addInstance:handle group:group];
    return handle;
}

- (unsigned int)acquireInstance:(nullable NSString *)callName
                     resourceId:(int)resourceId
                          group:(int)group
                         volume:(int)volume {
    // The four-way dispatch that -prepare:resourceId:volume: (0x3e8e4) runs twice, once before and
    // once after stopping the oldest instance. Extracted so the binary's duplicated block is
    // written only once.
    if (callName == nil) {
        if (group == kSeGroupCaPlayer) {
            return sePlayer->PlaySoundByIndex(static_cast<unsigned int>(resourceId) &
                                              kResourceIndexMask);
        }
        return seAVPlayer->AcquireAudioBusForSourceIndex(static_cast<unsigned int>(resourceId) &
                                                         kResourceIndexMask);
    }
    if (group == kSeGroupCaPlayer) {
        return sePlayer->PlaySoundForKey(callName);
    }
    return seAVPlayer->AcquireAudioBusForSourceKey(callName, volume);
}

- (unsigned int)playSe:(nullable NSString *)callName resourceId:(int)resourceId {
    /** @ghidraAddress 0x3ec00 */
    if (callName != nil || resourceId != static_cast<int>(kInvalidHandle)) {
        int group = [self getGroupID:callName resourceId:resourceId];
        unsigned int handle = [self prepare:callName resourceId:resourceId volume:seVolume[group]];
        if (handle != kInvalidHandle) {
            if (group != kSeGroupCaPlayer) {
                seAVPlayer->PlaySourceByHandle(handle);
            } else {
                sePlayer->ResumeVoiceByHandle(handle);
            }
            return handle;
        }
    }
    return kInvalidHandle;
}

- (unsigned int)playSe:(nullable NSString *)callName resourceId:(int)resourceId Volume:(int)volume {
    /** @ghidraAddress 0x3ece8 */
    if (callName != nil || resourceId != static_cast<int>(kInvalidHandle)) {
        int group = [self getGroupID:callName resourceId:resourceId];
        unsigned int handle = [self prepare:callName resourceId:resourceId volume:volume];
        if (handle != kInvalidHandle) {
            if (group != kSeGroupCaPlayer) {
                seAVPlayer->PlaySourceByHandle(handle);
            } else {
                sePlayer->ResumeVoiceByHandle(handle);
            }
            return handle;
        }
    }
    return kInvalidHandle;
}

- (unsigned int)playSeSetGroup:(nullable NSString *)callName
                    resourceId:(int)resourceId
                       groupId:(int)groupId {
    /** @ghidraAddress 0x3edd0 */
    if ((callName == nil && resourceId == static_cast<int>(kInvalidHandle))) {
        return kInvalidHandle;
    }
    unsigned int handle = [self prepareSetGroup:callName resourceId:resourceId groupId:groupId];
    if (handle == kInvalidHandle) {
        return kInvalidHandle;
    }
    sePlayer->ResumeVoiceByHandle(handle);
    return handle;
}

- (unsigned int)prepareSetGroup:(nullable NSString *)callName
                     resourceId:(int)resourceId
                        groupId:(int)groupId {
    /** @ghidraAddress 0x3eab0 */
    int slot = [self orderInstanceList:groupId];
    if (slot == static_cast<int>(kInvalidHandle)) {
        [self stopSe:seManageId[groupId][kOldestInstanceSlot].instanceId];
        slot = [self orderInstanceList:groupId];
        if (slot == static_cast<int>(kInvalidHandle)) {
            return kInvalidHandle;
        }
    }
    int busId = seManageId[groupId][slot].busId;
    int volume = seVolume[groupId];
    unsigned int handle;
    if (callName == nil) {
        handle = sePlayer->PlaySoundOnVoice(resourceId, busId, volume);
    } else {
        handle = sePlayer->PlaySoundForKeyOnBus(callName, busId, volume);
    }
    seManageId[groupId][slot].instanceId = handle;
    return handle;
}

- (BOOL)stopSe:(unsigned int)handle {
    /** @ghidraAddress 0x3ee78 */
    for (int slot = 0; slot < kInstanceSlotCount; ++slot) {
        if (seList[slot].instanceId == handle) {
            if (seList[slot].group == kSeGroupCaPlayer) {
                sePlayer->StopVoiceByHandle(handle);
                return YES;
            }
            return seAVPlayer->StopAudioBusByHandleWrapper(handle);
        }
    }
    return NO;
}

- (BOOL)onPauseSe:(unsigned int)handle {
    /** @ghidraAddress 0x3eefc */
    for (int slot = 0; slot < kInstanceSlotCount; ++slot) {
        if (seList[slot].instanceId == handle) {
            if (seList[slot].group == kSeGroupCaPlayer) {
                sePlayer->PauseVoiceByHandle(handle);
                return YES;
            }
            seAVPlayer->PauseAudioBusByPlayHandle(handle);
            return YES;
        }
    }
    return NO;
}

- (BOOL)offPauseSe:(unsigned int)handle {
    /** @ghidraAddress 0x3ef80 */
    for (int slot = 0; slot < kInstanceSlotCount; ++slot) {
        if (seList[slot].instanceId == handle) {
            if (seList[slot].group == kSeGroupCaPlayer) {
                sePlayer->ResumeVoiceByHandle(handle);
                return YES;
            }
            seAVPlayer->PlaySourceByHandle(handle);
            return YES;
        }
    }
    return NO;
}

- (BOOL)isPlayingSe:(unsigned int)handle {
    /** @ghidraAddress 0x3f004 */
    for (int slot = 0; slot < kInstanceSlotCount; ++slot) {
        if (seList[slot].instanceId == handle) {
            int status;
            if (seList[slot].group == kSeGroupCaPlayer) {
                status = sePlayer->GetVoiceStateByHandle(handle);
            } else {
                status = seAVPlayer->QueryAudioBusPlaybackStatus(handle);
            }
            return status == kPlaybackStatusPlaying;
        }
    }
    return NO;
}

- (BOOL)onPauseSeAll {
    /** @ghidraAddress 0x3f090 */
    for (int slot = 0; slot < kInstanceSlotCount; ++slot) {
        if (seList[slot].group == kSeGroupCaPlayer) {
            sePlayer->PauseVoiceByHandle(seList[slot].instanceId);
        } else {
            seAVPlayer->PauseAudioBusByPlayHandle(seList[slot].instanceId);
        }
    }
    return YES;
}

- (BOOL)offPauseSeAll {
    /** @ghidraAddress 0x3f110 */
    for (int slot = 0; slot < kInstanceSlotCount; ++slot) {
        if (seList[slot].group == kSeGroupCaPlayer) {
            sePlayer->ResumeVoiceByHandle(seList[slot].instanceId);
        } else {
            seAVPlayer->PlaySourceByHandle(seList[slot].instanceId);
        }
    }
    return YES;
}

- (BOOL)stopSeAll {
    /** @ghidraAddress 0x3f190 */
    for (int slot = 0; slot < kInstanceSlotCount; ++slot) {
        if (seList[slot].group == kSeGroupCaPlayer) {
            sePlayer->StopVoiceByHandle(seList[slot].instanceId);
        } else {
            seAVPlayer->StopAudioBusByHandleWrapper(seList[slot].instanceId);
        }
    }
    return YES;
}

- (BOOL)stopAll {
    /** @ghidraAddress 0x3f210 */
    [self stopBgm:kNoFadeTime];
    [self stopVoice];
    [self stopSeAll];
    return YES;
}

#pragma mark - Instance tables

- (void)orderInstanceList {
    /** @ghidraAddress 0x3f260 */
    for (int slot = 0; slot < kInstanceSlotCount; ++slot) {
        if (seList[slot].instanceId == kInvalidHandle) {
            break;
        }
        int status;
        if (seList[slot].group == kSeGroupCaPlayer) {
            status = sePlayer->GetVoiceStateByHandle(seList[slot].instanceId);
        } else {
            status = seAVPlayer->QueryAudioBusPlaybackStatus(seList[slot].instanceId);
        }
        if (status == kPlaybackStatusFinished || status == kPlaybackStatusStopped) {
            if (seList[slot].group == kSeGroupCaPlayer) {
                sePlayer->ReleaseVoiceByHandle(seList[slot].instanceId);
            } else {
                seAVPlayer->StopAudioBusByPlayHandle(seList[slot].instanceId);
            }
            seList[slot].instanceId = kInvalidHandle;
            seList[slot].group = kInstanceSlotStateFree;
        }
    }

    // Compact the freed slots by pulling later live entries forward.
    for (int slot = 0; slot < kInstanceSlotCount - 1; ++slot) {
        if (seList[slot].instanceId != kInvalidHandle) {
            continue;
        }
        int next = slot + 1;
        while (next < kInstanceSlotCount && seList[next].instanceId == kInvalidHandle) {
            ++next;
        }
        if (next >= kInstanceSlotCount) {
            return;
        }
        seList[slot].instanceId = seList[next].instanceId;
        seList[slot].group = seList[next].group;
        seList[next].instanceId = kInvalidHandle;
        seList[next].group = kInstanceSlotStateFree;
        if (seList[slot].instanceId == kInvalidHandle) {
            return;
        }
    }
}

- (int)orderInstanceList:(int)groupId {
    /** @ghidraAddress 0x3f3c0 */
    for (int slot = 0; slot < kInstanceSlotCount; ++slot) {
        if (seManageId[groupId][slot].instanceId == kInvalidHandle) {
            break;
        }
        int status = sePlayer->GetVoiceStateByHandle(seManageId[groupId][slot].instanceId);
        if (status == kPlaybackStatusFinished || status == kPlaybackStatusStopped) {
            sePlayer->ReleaseVoiceByHandle(seManageId[groupId][slot].instanceId);
            seManageId[groupId][slot].instanceId = kInvalidHandle;
        }
    }

    for (int slot = 0; slot < kInstanceSlotCount - 1; ++slot) {
        if (seManageId[groupId][slot].instanceId != kInvalidHandle) {
            continue;
        }
        int next = slot + 1;
        while (next < kInstanceSlotCount &&
               seManageId[groupId][next].instanceId == kInvalidHandle) {
            ++next;
        }
        if (next >= kInstanceSlotCount) {
            break;
        }
        seManageId[groupId][slot].instanceId = seManageId[groupId][next].instanceId;
        int savedBus = seManageId[groupId][slot].busId;
        seManageId[groupId][slot].busId = seManageId[groupId][next].busId;
        seManageId[groupId][next].instanceId = kInvalidHandle;
        seManageId[groupId][next].busId = savedBus;
        if (seManageId[groupId][slot].instanceId == kInvalidHandle) {
            break;
        }
    }

    for (int slot = 0; slot < kInstanceSlotCount; ++slot) {
        if (seManageId[groupId][slot].instanceId == kInvalidHandle) {
            return slot;
        }
    }
    return kInvalidHandle;
}

- (void)stopOldInstance {
    /** @ghidraAddress 0x3f544 */
    if (seList[kOldestInstanceSlot].group == kSeGroupCaPlayer) {
        sePlayer->ReleaseVoiceByHandle(seList[kOldestInstanceSlot].instanceId);
    } else {
        seAVPlayer->StopAudioBusByPlayHandle(seList[kOldestInstanceSlot].instanceId);
    }
    for (int slot = 0; slot < kInstanceSlotCount - 1; ++slot) {
        seList[slot].instanceId = seList[slot + 1].instanceId;
        seList[slot].group = seList[slot + 1].group;
    }
    seList[kInstanceSlotCount - 1].instanceId = kInvalidHandle;
    seList[kInstanceSlotCount - 1].group = kInstanceSlotStateFree;
}

- (void)addInstance:(unsigned int)handle group:(int)group {
    /** @ghidraAddress 0x3f5e4 */
    for (int slot = 0; slot < kInstanceSlotCount; ++slot) {
        if (seList[slot].instanceId == kInvalidHandle) {
            seList[slot].instanceId = handle;
            seList[slot].group = group;
            return;
        }
    }
}

#pragma mark - Volume

- (void)setSeVolume:(int)seVolumeValue groupId:(int)groupId {
    /** @ghidraAddress 0x3f624 */
    if (seVolumeValue >= kMaxVolume) {
        return;
    }
    seVolume[groupId] = seVolumeValue;
    if (groupId != kSeGroupCaPlayer) {
        seAVPlayer->SetAllAudioBusVolumeWrapper(seVolumeValue);
        return;
    }
    for (int channel = 0; channel < kVoiceChannelCount; ++channel) {
        sePlayer->SetMasterVoiceParameter();
    }
}

#pragma mark - Fade timers

- (void)deleteFadeTimer {
    /** @ghidraAddress 0x3f6a8 */
    [self.fadeTimer invalidate];
    self.fadeTimer = nil;
}

- (void)createBgmFadeInTimer:(double)time {
    /** @ghidraAddress 0x3f714 */
    [self deleteFadeTimer];
    unitVolume = static_cast<float>((kFullVolume / time) * kFadeStepInterval);
    self.fadeTimer = [NSTimer timerWithTimeInterval:kFadeStepInterval
                                             target:self
                                           selector:@selector(onFadeInTimer:)
                                           userInfo:nil
                                            repeats:YES];
    [[NSRunLoop currentRunLoop] addTimer:self.fadeTimer forMode:NSRunLoopCommonModes];
}

- (void)createBgmFadeOutTimer:(double)time {
    /** @ghidraAddress 0x3f854 */
    [self deleteFadeTimer];
    unitVolume = static_cast<float>((-kFullVolume / time) * kFadeStepInterval);
    self.fadeTimer = [NSTimer timerWithTimeInterval:kFadeStepInterval
                                             target:self
                                           selector:@selector(onFadeOutTimer:)
                                           userInfo:nil
                                            repeats:YES];
    [[NSRunLoop currentRunLoop] addTimer:self.fadeTimer forMode:NSRunLoopCommonModes];
}

- (void)onFadeInTimer:(NSTimer *)timer {
    /** @ghidraAddress 0x400c4 */
    if (self.fadeTimer != timer) {
        return;
    }
    float volume = self.bgmPlayer.volume + unitVolume;
    if (volume >= kFullVolume) {
        self.bgmPlayer.volume = kFullVolume;
        [self.fadeTimer invalidate];
        self.fadeTimer = nil;
    }
    self.bgmPlayer.volume = volume;
}

- (void)onFadeOutTimer:(NSTimer *)timer {
    /** @ghidraAddress 0x40268 */
    if (self.fadeTimer != timer) {
        return;
    }
    float volume = self.bgmPlayer.volume + unitVolume;
    if (volume >= kSilentVolume) {
        self.bgmPlayer.volume = volume;
        return;
    }
    self.bgmPlayer.volume = kSilentVolume;
    [self.fadeTimer invalidate];
    self.fadeTimer = nil;
    if (!isOnPause) {
        [self.bgmPlayer stop];
        isPlaying[kPlayerIndexBgm] = NO;
    } else {
        [self.bgmPlayer pause];
    }
}

#pragma mark - AVAudioPlayerDelegate

- (void)audioPlayerDidFinishPlaying:(AVAudioPlayer *)player successfully:(BOOL)flag {
    /** @ghidraAddress 0x409f4 */
    if (self.bgmPlayer == player) {
        isPlaying[kPlayerIndexBgm] = NO;
    }
    if (self.voicePlayer == player) {
        isPlaying[kPlayerIndexVoice] = NO;
    }
}

- (void)audioPlayerBeginInterruption:(AVAudioPlayer *)player {
    /** @ghidraAddress 0x40aa8 */
    if (self.bgmPlayer == player) {
        isInterruption[kPlayerIndexBgm] = YES;
    } else {
        isInterruption[kPlayerIndexVoice] = YES;
    }
}

- (void)audioPlayerEndInterruption:(AVAudioPlayer *)player {
    /** @ghidraAddress 0x40b2c */
    [self resumePlayer:(self.bgmPlayer != player) ? kPlayerIndexVoice : kPlayerIndexBgm];
}

- (void)audioPlayerEndInterruption:(AVAudioPlayer *)player withOptions:(NSUInteger)flags {
    /** @ghidraAddress 0x40bac */
    [self resumePlayer:(self.bgmPlayer != player) ? kPlayerIndexVoice : kPlayerIndexBgm];
}

#pragma mark - Suspend and resume

- (void)suspendPlayer:(int)playerIndex {
    /** @ghidraAddress 0x40c2c */
    if (playerIndex > kPlayerIndexVoice) {
        return;
    }
    isInterruption[playerIndex] = YES;
    if (playerIndex == kPlayerIndexVoice) {
        [self.voicePlayer stop];
    } else if (playerIndex == kPlayerIndexBgm) {
        [self.bgmPlayer stop];
    }
}

- (void)resumePlayer:(int)playerIndex {
    /** @ghidraAddress 0x40ce4 */
    if (playerIndex >= kGroupCount || !isInterruption[playerIndex]) {
        return;
    }
    isInterruption[playerIndex] = NO;
    if (!isPlaying[playerIndex]) {
        return;
    }
    if (playerIndex == kPlayerIndexVoice) {
        if (!isOnPauseVoice) {
            [self playVoice];
        }
    } else if (playerIndex == kPlayerIndexBgm && !isOnPause) {
        [self playBgm:kResumeFadeInTime];
    }
}

@end
