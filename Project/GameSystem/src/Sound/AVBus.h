/**
 * @file
 * An AVFoundation sound-effect voice, @c AVBus.
 */

#import <Foundation/Foundation.h>

#include "audiosourceslot.h"

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
 * @return @c YES when a bound, idle player was prepared.
 * @ghidraAddress 0x41798
 */
- (BOOL)prepare;
/**
 * @brief Binds a sound source to this voice and returns the voice's new current id.
 *
 * The record carries either a URL or a data buffer; whichever is set selects the player the voice
 * is built from.
 * @param source The source record to bind.
 * @return The voice's current id, packed into the low half of a play handle by the mixer.
 * @ghidraAddress 0x4169c
 */
- (unsigned int)setSource:(AudioSourceSlot::SourceRecord *)source;
/**
 * @brief Unbinds the voice's current source and invalidates its outstanding play handles.
 * @return @c YES when a player was released.
 * @ghidraAddress 0x4171c
 */
- (BOOL)removeSource;
/**
 * @brief Whether the voice is currently bound to @p source.
 * @param source The source record to test.
 * @return @c YES when the voice holds @p source.
 * @ghidraAddress 0x41f20
 */
- (BOOL)isSameSource:(AudioSourceSlot::SourceRecord *)source;
/**
 * @brief Starts (or resumes) playback of the bound source.
 * @return @c YES when the voice was in a playable (prepared or paused) state.
 * @ghidraAddress 0x41898
 */
- (BOOL)play;
/**
 * @brief Stops playback and rewinds the voice.
 * @return @c YES when the voice held a player.
 * @ghidraAddress 0x41964
 */
- (BOOL)stop;
/**
 * @brief Pauses playback. The binary stops the underlying player rather than pausing it, so the
 * play position is not retained.
 * @return @c YES when the voice held a player.
 * @ghidraAddress 0x41a08
 */
- (BOOL)pause;
/**
 * @brief Resumes playback from a paused state.
 * @return @c YES when the voice was paused and holds a player.
 * @ghidraAddress 0x41afc
 */
- (BOOL)offPause;
/**
 * @brief Sets the voice's playback volume.
 * @param volume The gain in the range zero to one.
 * @return @c YES when the voice held a player.
 * @ghidraAddress 0x41bc0
 */
- (BOOL)setVolume:(float)volume;
/**
 * @brief The voice's playback volume.
 * @return The player's gain, or one when no source is bound.
 * @ghidraAddress 0x41c64
 */
- (float)volume;
/**
 * @brief The voice's current id, matched against a play handle's low half to resolve the voice.
 * @ghidraAddress 0x41f38
 */
- (unsigned int)currentID;
/**
 * @brief The voice's playback state.
 * @ghidraAddress 0x41d04
 */
- (AVBusStatus)status;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C++
// kate: hl Objective-C++;
// vim: set ft=objcpp :
