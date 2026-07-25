/**
 * @file
 * An AVFoundation sound-effect voice, @c AVBus.
 */

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * @brief The playback state of an @c AVBus voice, returned by @c status.
 */
typedef NS_ENUM(NSInteger, AVBusStatus) {
    AVBusStatusNone = -1,    /*!< No source is bound. */
    AVBusStatusPrepared = 1, /*!< A source is bound and prepared but not playing. */
    AVBusStatusPlaying = 2,  /*!< The voice is playing. */
    AVBusStatusPaused = 3,   /*!< The voice is paused. */
    AVBusStatusStopped = 4,  /*!< The voice has stopped or finished. */
};

/**
 * @brief One AVFoundation sound-effect voice in the SE mixer's bus pool.
 *
 * A voice binds one sound source and plays, pauses, resumes, stops, and adjusts its own volume. The
 * SE mixer (@c AVSeMixer) keeps an array of these and resolves play handles back to a voice by
 * matching its @c currentID. The method set is recovered from the mixer's bus-management routines,
 * which are the only callers; the class's own ivars and method bodies are reconstructed separately.
 */
@interface AVBus : NSObject

/**
 * @brief Prepares the bound source for playback (loads and readies its buffer).
 */
- (void)prepare;
/**
 * @brief Binds a sound source to this voice and returns the voice's new current id.
 * @param source The source identifier to bind.
 * @return The voice's current id, packed into the low half of a play handle by the mixer.
 */
- (unsigned int)setSource:(unsigned int)source;
/**
 * @brief Unbinds the voice's current source.
 */
- (void)removeSource;
/**
 * @brief Whether the voice is currently bound to @p source.
 * @param source The source identifier to test.
 * @return @c YES when the voice holds @p source.
 */
- (BOOL)isSameSource:(unsigned int)source;
/**
 * @brief Starts (or resumes) playback of the bound source.
 */
- (void)play;
/**
 * @brief Stops playback and rewinds the voice.
 */
- (void)stop;
/**
 * @brief Pauses playback, leaving the play position in place.
 */
- (void)pause;
/**
 * @brief Resumes playback from a paused state.
 */
- (void)offPause;
/**
 * @brief Sets the voice's playback volume.
 * @param volume The gain in the range zero to one.
 */
- (void)setVolume:(float)volume;
/**
 * @brief The voice's current id, matched against a play handle's low half to resolve the voice.
 */
- (unsigned int)currentID;
/**
 * @brief The voice's playback state.
 */
- (AVBusStatus)status;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
