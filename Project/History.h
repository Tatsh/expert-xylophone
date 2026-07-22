/** @file
 * The score-history manager for the play-record log. This class vends only class-level helpers
 * that fetch, create, validate, hash, delete, and aggregate the Core Data records of the
 * @c History entity against a managed object context. Each fetched record is validated against its
 * stored tamper hash and reset when the hash does not match, then wrapped in a @c HistoryData
 * transfer object before being returned to callers.
 *
 * Reconstructed from Ghidra project rb458, program rb458 (class History, image base 0x100000000).
 * @ghidraAddress values are offsets relative to the image base.
 */

#import <CoreData/CoreData.h>
#import <Foundation/Foundation.h>

/**
 * @brief The chart difficulty a history query is filtered by.
 */
typedef NS_ENUM(unsigned int, HistoryDifficulty) {
    /** The basic chart. */
    HistoryDifficultyBasic = 0,
    /** The medium chart. */
    HistoryDifficultyMedium = 1,
    /** The hard chart. */
    HistoryDifficultyHard = 2,
};

/**
 * @brief A stateless manager over the @c History Core Data entity that stores a player's per-play
 * results (hit counts, score, achievement rate, play date, play count, and a tamper-detection
 * hash).
 */
@interface History : NSObject

/**
 * @brief Fetches the play-history transfer objects for a tune and difficulty, most recent first.
 * @param tuneID The tune identifier to look up.
 * @param difficulty The chart difficulty to look up.
 * @param context The managed object context to query.
 * @return The matching history transfer objects.
 * @ghidraAddress 0x5a7d0
 */
+ (NSArray *)getScoreData:(unsigned int)tuneID
                Difficulty:(HistoryDifficulty)difficulty
    inManagedObjectContext:(NSManagedObjectContext *)context;

/**
 * @brief Fetches the play-history transfer objects recorded after the day before a reference date.
 * @param date The reference date; records newer than one day before it are returned.
 * @param context The managed object context to query.
 * @return The matching history transfer objects.
 * @ghidraAddress 0x5abd8
 */
+ (NSArray *)getScoreData:(NSDate *)date inManagedObjectContext:(NSManagedObjectContext *)context;

/**
 * @brief Fetches the play-history transfer objects recorded within a date range, up to a limit.
 * @param startDate The inclusive lower bound of the play-date range, or @c nil to disable range
 * filtering.
 * @param endDate The inclusive upper bound of the play-date range, or @c nil to disable range
 * filtering.
 * @param limit The maximum number of records to fetch, or zero to use the default limit.
 * @param context The managed object context to query.
 * @return The matching history transfer objects.
 * @ghidraAddress 0x5afec
 */
+ (NSArray *)getScoreDataWithStartDate:(NSDate *)startDate
                            andEndDate:(NSDate *)endDate
                              andLimit:(unsigned int)limit
                inManagedObjectContext:(NSManagedObjectContext *)context;

/**
 * @brief Deletes the most recent history records held by a context and saves it.
 * @param context The managed object context to delete from and save.
 * @ghidraAddress 0x5b434
 */
+ (void)deleteObject:(NSManagedObjectContext *)context;

/**
 * @brief The number of history records held by a context.
 * @param context The managed object context to count.
 * @return The record count, or zero when the count could not be determined.
 * @ghidraAddress 0x5b69c
 */
+ (long long)count:(NSManagedObjectContext *)context;

/**
 * @brief Inserts a new history record for a tune and difficulty and resets it to defaults.
 * @param tuneID The tune identifier for the new record; identifiers below the minimum are rejected.
 * @param difficulty The chart difficulty for the new record.
 * @param context The managed object context to insert into.
 * @return The newly inserted, reset record, or @c nil when the tune identifier is out of range.
 * @ghidraAddress 0x5b7ac
 */
+ (id)recordWithTuneID:(unsigned int)tuneID
                Difficulty:(HistoryDifficulty)difficulty
    inManagedObjectContext:(NSManagedObjectContext *)context;

/**
 * @brief Resets a record's counts, play date, play count, and tamper hash to their defaults.
 * @param record The record to reset.
 * @ghidraAddress 0x5b900
 */
+ (void)reset:(id)record;

/**
 * @brief Computes the tamper hash for a set of already unpacked play figures.
 * @param tuneID The tune identifier.
 * @param difficulty The chart difficulty.
 * @param score The score.
 * @param just The Just hit count.
 * @param great The Great hit count.
 * @param good The Good hit count.
 * @param miss The Miss count.
 * @param jr The JR count.
 * @param combo The best combo.
 * @param date The play date expressed as an interval since the reference date.
 * @param count The play count.
 * @param hash The sixteen-byte buffer that receives the computed digest.
 * @ghidraAddress 0x5bb88
 */
+ (void)hashScoreforTune:(int)tuneID
              Difficulty:(int)difficulty
                   Score:(int)score
                    Just:(int)just
                   Great:(int)great
                    Good:(int)good
                    Miss:(int)miss
                      JR:(int)jr
                   Combo:(int)combo
                    Date:(double)date
                   Count:(long long)count
                    Hash:(unsigned char *)hash;

/**
 * @brief Computes the tamper hash for a record's current play figures.
 * @param record The record to hash.
 * @return The freshly computed sixteen-byte hash data.
 * @ghidraAddress 0x5bc38
 */
+ (NSData *)hashScore:(id)record;

/**
 * @brief Validates a record by comparing its stored hash against a freshly computed one.
 * @param record The record to check.
 * @return @c YES when the record's stored hash matches the recomputed hash, otherwise @c NO.
 * @ghidraAddress 0x5c01c
 */
+ (BOOL)checkScore:(id)record;

/**
 * @brief The achievement rate of a record's hit counts.
 * @param source The record to score, or @c nil for a zero rate.
 * @return The achievement rate as @c (just * 3 + great * 2 + good) / ((just + great + good + miss)
 * * 3).
 * @ghidraAddress 0x5c0fc
 */
+ (float)getAR:(id)source;

/**
 * @brief Whether a record represents a full combo, that is, no Miss and every hit accounted for by
 * the best combo.
 * @param source The record to test, or @c nil for @c NO.
 * @return @c YES when the record is a full combo, otherwise @c NO.
 * @ghidraAddress 0x5c290
 */
+ (BOOL)getFullCombo:(id)source;

@end

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
