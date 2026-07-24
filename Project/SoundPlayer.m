//
//  SoundPlayer.m
//  REFLEC BEAT plus
//
//  Reconstructed from Ghidra project rb458, program rb458 (class SoundPlayer). This is the per-voice
//  player the SoundManager mixer graph drives: it holds a SoundData asset and a play cursor and
//  fills the render callback's buffer list on demand. The whole class is plain Objective-C messaging
//  over the SoundData asset, so it lives in a .m file.
//

#import "SoundPlayer.h"

#import "SoundData.h"

@interface SoundPlayer () {
    // The binary's own ivars, in declaration order. The 32-bit offsets are documentation only;
    // access always goes through these named fields.
    BOOL m_IsPlaying;         // +0x364
    SoundData *m_SoundData;   // +0x368
    long long m_CurrentFrame; // +0x36c
    BOOL m_IsLoop;            // +0x370
    BOOL m_IsStop;            // +0x374
}
@end

@implementation SoundPlayer

#pragma mark - Asset

- (SoundData *)getSoundData {
    /** @ghidraAddress 0x354fc */
    return m_SoundData;
}

- (void)setSoundData:(SoundData *)soundData {
    /** @ghidraAddress 0x35498 */
    if (!m_IsPlaying) {
        m_SoundData = soundData;
    }
}

#pragma mark - Play cursor

- (long long)currentFrame {
    /** @ghidraAddress 0x3557c */
    return m_CurrentFrame;
}

- (void)setCurrentFrame:(long long)currentFrame {
    /** @ghidraAddress 0x3550c */
    if ([m_SoundData totalFrames] < currentFrame) {
        currentFrame = [m_SoundData totalFrames];
    }
    if (currentFrame < 0) {
        currentFrame = 0;
    }
    m_CurrentFrame = currentFrame;
}

#pragma mark - Loop

- (BOOL)isLoop {
    /** @ghidraAddress 0x355ac */
    return m_IsLoop;
}

- (void)setLoop:(BOOL)loop {
    /** @ghidraAddress 0x3558c */
    if (!m_IsPlaying) {
        m_IsLoop = loop;
    }
}

#pragma mark - Playback state

- (void)play {
    /** @ghidraAddress 0x355bc */
    m_IsPlaying = YES;
    m_IsStop = NO;
}

- (BOOL)isPlaying {
    /** @ghidraAddress 0x355dc */
    return m_IsPlaying;
}

- (void)endPlay {
    /** @ghidraAddress 0x355ec */
    m_IsPlaying = NO;
}

- (void)stop {
    /** @ghidraAddress 0x355fc */
    m_IsStop = YES;
}

- (BOOL)isStop {
    /** @ghidraAddress 0x35610 */
    return m_IsStop;
}

#pragma mark - Streaming

- (void)loadData:(AudioBufferList *)buffer Frames:(unsigned int)frames {
    /** @ghidraAddress 0x35620 */
    if (m_SoundData != nil) {
        long long nextFrame = 0;
        BOOL exhausted = [m_SoundData getData:m_CurrentFrame
                                       Frames:frames
                                         Loop:m_IsLoop
                                       Buffer:buffer
                                          Out:&nextFrame];
        if (exhausted) {
            [self stop];
        }
        m_CurrentFrame = nextFrame;
    }
}

@end
