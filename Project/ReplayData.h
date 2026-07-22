/** @file
 * The archived record of a single play: its tune, difficulty, seed, judgement tallies, score,
 * achievement rate, play date, owning user, tamper hash, and the per-note replay events that let
 * the game reconstruct a ghost. The class encodes and decodes itself through @c NSCoding, and its
 * class-level helpers persist the archive to and from an on-disk, Blowfish-enciphered ZIP file
 * under the documents directory.
 *
 * Reconstructed from Ghidra project rb458, program rb458 (class ReplayData, image base
 * 0x100000000). @ghidraAddress values are offsets relative to the image base.
 */

#import <Foundation/Foundation.h>

@class ReplayNote;

NS_ASSUME_NONNULL_BEGIN

/**
 * @brief An archivable record of one play, including the per-note events needed to replay it.
 */
@interface ReplayData : NSObject <NSCoding>

/**
 * @brief The replay format version.
 * @ghidraAddress 0x106368 (getter)
 * @ghidraAddress 0x106378 (setter)
 */
@property(nonatomic, strong, nullable) NSNumber *version;
/**
 * @brief The tune identifier this replay belongs to.
 * @ghidraAddress 0x1063b0 (getter)
 * @ghidraAddress 0x1063c0 (setter)
 */
@property(nonatomic, strong, nullable) NSNumber *tuneID;
/**
 * @brief The difficulty the tune was played on.
 * @ghidraAddress 0x1063f8 (getter)
 * @ghidraAddress 0x106408 (setter)
 */
@property(nonatomic, strong, nullable) NSNumber *diff;
/**
 * @brief The random seed used for the play.
 * @ghidraAddress 0x106440 (getter)
 * @ghidraAddress 0x106450 (setter)
 */
@property(nonatomic, strong, nullable) NSNumber *seed;
/**
 * @brief The total number of notes in the chart.
 * @ghidraAddress 0x106488 (getter)
 * @ghidraAddress 0x106498 (setter)
 */
@property(nonatomic, strong, nullable) NSNumber *cntNote;
/**
 * @brief The score achieved.
 * @ghidraAddress 0x1064d0 (getter)
 * @ghidraAddress 0x1064e0 (setter)
 */
@property(nonatomic, strong, nullable) NSNumber *score;
/**
 * @brief The combo count.
 * @ghidraAddress 0x106518 (getter)
 * @ghidraAddress 0x106528 (setter)
 */
@property(nonatomic, strong, nullable) NSNumber *cntCom;
/**
 * @brief The Just count.
 * @ghidraAddress 0x106560 (getter)
 * @ghidraAddress 0x106570 (setter)
 */
@property(nonatomic, strong, nullable) NSNumber *cntJust;
/**
 * @brief The Great count.
 * @ghidraAddress 0x1065a8 (getter)
 * @ghidraAddress 0x1065b8 (setter)
 */
@property(nonatomic, strong, nullable) NSNumber *cntGreat;
/**
 * @brief The Good count.
 * @ghidraAddress 0x1065f0 (getter)
 * @ghidraAddress 0x106600 (setter)
 */
@property(nonatomic, strong, nullable) NSNumber *cntGood;
/**
 * @brief The Miss count.
 * @ghidraAddress 0x106638 (getter)
 * @ghidraAddress 0x106648 (setter)
 */
@property(nonatomic, strong, nullable) NSNumber *cntMiss;
/**
 * @brief The Just Reflec count.
 * @ghidraAddress 0x106680 (getter)
 * @ghidraAddress 0x106690 (setter)
 */
@property(nonatomic, strong, nullable) NSNumber *cntJR;
/**
 * @brief The achievement rate.
 * @ghidraAddress 0x1066c8 (getter)
 * @ghidraAddress 0x1066d8 (setter)
 */
@property(nonatomic, strong, nullable) NSNumber *ar;
/**
 * @brief The date the tune was played.
 * @ghidraAddress 0x106710 (getter)
 * @ghidraAddress 0x106720 (setter)
 */
@property(nonatomic, strong, nullable) NSDate *playDate;
/**
 * @brief The owning user's server-data entry.
 * @ghidraAddress 0x106758 (getter)
 * @ghidraAddress 0x106768 (setter)
 */
@property(nonatomic, strong, nullable) id user;
/**
 * @brief The tamper-detection hash over the score values.
 * @ghidraAddress 0x1067a0 (getter)
 * @ghidraAddress 0x1067b0 (setter)
 */
@property(nonatomic, strong, nullable) NSData *chksco;
/**
 * @brief The archived per-note replay events, as an array of @c ReplayNote.
 * @ghidraAddress 0x1067e8 (getter)
 * @ghidraAddress 0x1067f8 (setter)
 */
@property(nonatomic, strong, nullable) NSArray<ReplayNote *> *replay;
/**
 * @brief A secondary per-note replay array. Declared by the shipped class but never populated,
 * archived, or reset.
 * @ghidraAddress 0x106830 (getter)
 * @ghidraAddress 0x106840 (setter)
 */
@property(nonatomic, strong, nullable) NSArray<ReplayNote *> *replay2;

/**
 * @brief Whether a saved replay exists on disk for a tune and difficulty.
 * @param tuneID The tune identifier to look up.
 * @param difficulty The difficulty to look up; advanced difficulties (three and above) are folded
 * back into the basic range before the on-disk path is formed.
 * @return @c YES when the replay file exists, otherwise @c NO. Also returns @c NO after creating
 * the replay directory when it was missing.
 * @ghidraAddress 0x10546c
 */
+ (BOOL)isExistReplayData:(int)tuneID difficulty:(int)difficulty;

/**
 * @brief Loads and unarchives the saved replay for a tune and difficulty.
 * @param tuneID The tune identifier to load.
 * @param difficulty The difficulty to load; advanced difficulties (three and above) are folded
 * back into the basic range before the on-disk path is formed.
 * @return The unarchived replay, or @c nil when none exists or the archive could not be read.
 * @ghidraAddress 0x1055b4
 */
+ (nullable instancetype)loadReplayData:(int)tuneID difficulty:(int)difficulty;

/**
 * @brief Archives a replay and writes it to disk as a Blowfish-enciphered ZIP.
 * @param replayData The replay to save.
 * @return @c YES on success, otherwise @c NO.
 * @ghidraAddress 0x1059b4
 */
+ (BOOL)saveReplayData:(nullable ReplayData *)replayData;

/**
 * @brief Shifts a date from UTC into the device's local time zone.
 * @param date The date to convert.
 * @return A date offset by the local time zone's seconds from GMT, or @c nil when @p date is
 * @c nil.
 * @ghidraAddress 0x105fc0
 */
+ (nullable NSDate *)convertLocalDate:(nullable NSDate *)date;

/**
 * @brief Enciphers archived replay data, prefixing it with a random salt word.
 * @param data The archived data to encipher.
 * @return The enciphered data.
 * @ghidraAddress 0x1060a0
 */
+ (NSData *)encode:(NSData *)data;

/**
 * @brief Deciphers enciphered replay data and strips its salt-word prefix.
 * @param data The enciphered data to decipher.
 * @return The deciphered archive data.
 * @ghidraAddress 0x106204
 */
+ (NSData *)decode:(NSData *)data;

/**
 * @brief Resets every stored field to @c nil.
 * @ghidraAddress 0x105304
 */
- (void)reset;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
