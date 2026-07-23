/** @file
 * The Core Data managed object that stores a player's per-tune score record: full-combo flags,
 * clear ranks, scores, achievement rates, play counts, the last play date, and a tamper-detection
 * hash. The class also vends class-level helpers to fetch, create, reset, validate, and aggregate
 * these records against the app's shared managed object context.
 *
 * Reconstructed from Ghidra project rb458, program rb458 (class ScoreData, image base
 * 0x100000000). @ghidraAddress values are offsets relative to the image base.
 */

#import <CoreData/CoreData.h>
#import <Foundation/Foundation.h>

/**
 * @brief The frame-bonus tier awarded on the music-select screen for a tune, derived from its
 * full-combo flags and clear ranks.
 */
typedef NS_ENUM(NSInteger, ScoreDataFrameBonusType) {
    ScoreDataFrameBonusTypeNone = 0,   /*!< No frame bonus. */
    ScoreDataFrameBonusTypeBronze = 1, /*!< The first (lower) frame-bonus tier. */
    ScoreDataFrameBonusTypeGold = 2,   /*!< The second (higher) frame-bonus tier. */
};

NS_ASSUME_NONNULL_BEGIN

/**
 * @brief A Core Data record holding one tune's best results across the basic, medium, and hard
 * difficulties, together with a hash that guards the stored values against tampering.
 *
 * All stored attributes are @c \@dynamic; Core Data synthesises their accessors at runtime.
 */
@interface ScoreData : NSManagedObject

/**
 * @brief The tune identifier that this record belongs to.
 */
@property(nonatomic, retain, nullable) NSNumber *tuneID;

/**
 * @brief Whether the basic chart has been cleared with a full combo.
 */
@property(nonatomic, retain, nullable) NSNumber *fcBas;

/**
 * @brief Whether the medium chart has been cleared with a full combo.
 */
@property(nonatomic, retain, nullable) NSNumber *fcMed;

/**
 * @brief Whether the hard chart has been cleared with a full combo.
 */
@property(nonatomic, retain, nullable) NSNumber *fcHar;

/**
 * @brief The clear rank for the basic chart.
 */
@property(nonatomic, retain, nullable) NSNumber *raBas;

/**
 * @brief The clear rank for the medium chart.
 */
@property(nonatomic, retain, nullable) NSNumber *raMed;

/**
 * @brief The clear rank for the hard chart.
 */
@property(nonatomic, retain, nullable) NSNumber *raHar;

/**
 * @brief The best score for the basic chart.
 */
@property(nonatomic, retain, nullable) NSNumber *scoBas;

/**
 * @brief The best score for the medium chart.
 */
@property(nonatomic, retain, nullable) NSNumber *scoMed;

/**
 * @brief The best score for the hard chart.
 */
@property(nonatomic, retain, nullable) NSNumber *scoHar;

/**
 * @brief The best achievement rate for the basic chart.
 */
@property(nonatomic, retain, nullable) NSNumber *arBas;

/**
 * @brief The best achievement rate for the medium chart.
 */
@property(nonatomic, retain, nullable) NSNumber *arMed;

/**
 * @brief The best achievement rate for the hard chart.
 */
@property(nonatomic, retain, nullable) NSNumber *arHar;

/**
 * @brief The date the tune was last played.
 */
@property(nonatomic, retain, nullable) NSDate *lastPlayDate;

/**
 * @brief The play count for the basic chart.
 */
@property(nonatomic, retain, nullable) NSNumber *pcBas;

/**
 * @brief The play count for the medium chart.
 */
@property(nonatomic, retain, nullable) NSNumber *pcMed;

/**
 * @brief The play count for the hard chart.
 */
@property(nonatomic, retain, nullable) NSNumber *pcHar;

/**
 * @brief The tamper-detection hash over the stored score values.
 */
@property(nonatomic, retain, nullable) NSData *chksco;

/**
 * @brief Fetches the score record for a tune, creating and persisting a fresh reset record when
 * none exists.
 * @param tuneID The tune identifier to look up.
 * @param context The managed object context to query.
 * @return The existing or newly created record for the tune.
 * @ghidraAddress 0x5c444
 */
+ (instancetype)getScoreData:(unsigned int)tuneID
      inManagedObjectContext:(NSManagedObjectContext *)context;

/**
 * @brief Fetches the score records for a set of tunes, validating and persisting each before
 * returning them.
 * @param tuneIDs The collection of tune identifiers to look up.
 * @param context The managed object context to query.
 * @return The matching records.
 * @ghidraAddress 0x5c854
 */
+ (NSArray *)getScoreDatas:(NSArray *)tuneIDs
    inManagedObjectContext:(NSManagedObjectContext *)context;

/**
 * @brief Inserts a new score record for a tune and resets it to default values.
 * @param tuneID The tune identifier for the new record.
 * @param context The managed object context to insert into.
 * @return The newly inserted, reset record.
 * @ghidraAddress 0x5cd7c
 */
+ (instancetype)recordWithTuneID:(unsigned int)tuneID
          inManagedObjectContext:(NSManagedObjectContext *)context;

/**
 * @brief Resets a record's stored values to their defaults and recomputes its tamper hash.
 * @param record The record to reset.
 * @ghidraAddress 0x5ce78
 */
+ (void)reset:(ScoreData *)record;

/**
 * @brief Recomputes the tamper hash for a record's current score values.
 * @param record The record to hash.
 * @return The freshly computed hash data.
 * @ghidraAddress 0x5d3bc
 */
+ (NSData *)hashScore:(ScoreData *)record;

/**
 * @brief Validates a record by comparing its stored hash against a freshly computed one.
 * @param record The record to check.
 * @return @c YES when the record's stored hash matches the recomputed hash, otherwise @c NO.
 * @ghidraAddress 0x5d698
 */
+ (BOOL)checkScore:(nullable ScoreData *)record;

/**
 * @brief The total of the clamped best scores across every valid record for the currently
 * available tunes.
 * @return The aggregate score.
 * @ghidraAddress 0x5d778
 */
+ (long long)totalScore;

/**
 * @brief The number of records played after the epoch whose tune identifiers fall within the
 * standard tune range.
 * @return The record count.
 * @ghidraAddress 0x5e820
 */
+ (long long)totalRecordCount;

/**
 * @brief The frame-bonus tier for this record, derived from its full-combo flags and clear ranks.
 * @return The frame-bonus tier.
 * @ghidraAddress 0x5df3c
 */
- (ScoreDataFrameBonusType)getFrameBonusType;

/**
 * @brief Clamps this record's out-of-range achievement rates and scores back into their valid
 * ranges, refreshing the tamper hash when any value was corrected.
 * @return @c YES when a value was clamped, otherwise @c NO.
 * @ghidraAddress 0x5e150
 */
- (BOOL)checkOverScore;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
