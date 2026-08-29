#import "SoundPlayer.h"

#import "SoundData.h"

@interface SoundPlayer () {
    BOOL m_IsPlaying;
    SoundData *m_SoundData;
    NSInteger m_CurrentFrame;
    BOOL m_IsLoop;
    BOOL m_IsStop;
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

- (NSInteger)currentFrame {
    /** @ghidraAddress 0x3557c */
    return m_CurrentFrame;
}

- (void)setCurrentFrame:(NSInteger)currentFrame {
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
        NSInteger nextFrame = 0;
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
