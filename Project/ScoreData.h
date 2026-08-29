/**
 * @file
 * The Core Data managed object that stores a player's per-tune score record: full-combo
 * flags, clear ranks, scores, achievement rates, play counts, the last play date, and a
 * tamper-detection hash. The class also vends class-level helpers to fetch, create, reset,
 * validate, and aggregate these records against the app's shared managed object context.
 *
 * Reconstructed from Ghidra project rb458, program rb458 (class ScoreData, image base
 * 0x100000000). Ghidra addresses are offsets relative to the image base.
 */

#import <CoreData/CoreData.h>
#import <Foundation/Foundation.h>

/**
 * The frame-bonus tier awarded on the music-select screen for a tune, derived from its
 * full-combo flags and clear ranks.
 */
typedef NS_ENUM(NSInteger, ScoreDataFrameBonusType) {
    ScoreDataFrameBonusTypeNone = 0,   /*!< No frame bonus. */
    ScoreDataFrameBonusTypeBronze = 1, /*!< The first (lower) frame-bonus tier. */
    ScoreDataFrameBonusTypeGold = 2,   /*!< The second (higher) frame-bonus tier. */
};

NS_ASSUME_NONNULL_BEGIN

/**
 * A Core Data record holding one tune's best results across the basic, medium, and hard
 * difficulties, together with a hash that guards the stored values against tampering.
 *
 * All stored attributes are @c \@dynamic; Core Data synthesises their accessors at runtime.
 */
@interface ScoreData : NSManagedObject

/**
 * The tune identifier that this record belongs to.
 */
@property(nonatomic, retain, nullable) NSNumber *tuneID;

/**
 * Whether the basic chart has been cleared with a full combo.
 */
@property(nonatomic, retain, nullable) NSNumber *fcBas;

/**
 * Whether the medium chart has been cleared with a full combo.
 */
@property(nonatomic, retain, nullable) NSNumber *fcMed;

/**
 * Whether the hard chart has been cleared with a full combo.
 */
@property(nonatomic, retain, nullable) NSNumber *fcHar;

/**
 * The clear rank for the basic chart.
 */
@property(nonatomic, retain, nullable) NSNumber *raBas;

/**
 * The clear rank for the medium chart.
 */
@property(nonatomic, retain, nullable) NSNumber *raMed;

/**
 * The clear rank for the hard chart.
 */
@property(nonatomic, retain, nullable) NSNumber *raHar;

/**
 * The best score for the basic chart.
 */
@property(nonatomic, retain, nullable) NSNumber *scoBas;

/**
 * The best score for the medium chart.
 */
@property(nonatomic, retain, nullable) NSNumber *scoMed;

/**
 * The best score for the hard chart.
 */
@property(nonatomic, retain, nullable) NSNumber *scoHar;

/**
 * The best achievement rate for the basic chart.
 */
@property(nonatomic, retain, nullable) NSNumber *arBas;

/**
 * The best achievement rate for the medium chart.
 */
@property(nonatomic, retain, nullable) NSNumber *arMed;

/**
 * The best achievement rate for the hard chart.
 */
@property(nonatomic, retain, nullable) NSNumber *arHar;

/**
 * The date the tune was last played.
 */
@property(nonatomic, retain, nullable) NSDate *lastPlayDate;

/**
 * The play count for the basic chart.
 */
@property(nonatomic, retain, nullable) NSNumber *pcBas;

/**
 * The play count for the medium chart.
 */
@property(nonatomic, retain, nullable) NSNumber *pcMed;

/**
 * The play count for the hard chart.
 */
@property(nonatomic, retain, nullable) NSNumber *pcHar;

/**
 * The tamper-detection hash over the stored score values.
 */
@property(nonatomic, retain, nullable) NSData *chksco;

/**
 * Fetches the score record for a tune, creating and persisting a fresh reset record when
 * none exists.
 * @param tuneID The tune identifier to look up.
 * @param context The managed object context to query.
 * @return The existing or newly created record for the tune.
 * @ghidraAddress 0x5c444
 */
+ (instancetype)getScoreData:(unsigned int)tuneID
      inManagedObjectContext:(NSManagedObjectContext *)context;

/**
 * Fetches the score records for a set of tunes, validating and persisting each before
 * returning them.
 * @param tuneIDs The collection of tune identifiers to look up.
 * @param context The managed object context to query.
 * @return The matching records.
 * @ghidraAddress 0x5c854
 */
+ (NSArray *)getScoreDatas:(NSArray *)tuneIDs
    inManagedObjectContext:(NSManagedObjectContext *)context;

/**
 * Inserts a new score record for a tune and resets it to default values.
 * @param tuneID The tune identifier for the new record.
 * @param context The managed object context to insert into.
 * @return The newly inserted, reset record.
 * @ghidraAddress 0x5cd7c
 */
+ (instancetype)recordWithTuneID:(unsigned int)tuneID
          inManagedObjectContext:(NSManagedObjectContext *)context;

/**
 * Resets a record's stored values to their defaults and recomputes its tamper hash.
 * @param record The record to reset.
 * @ghidraAddress 0x5ce78
 */
+ (void)reset:(ScoreData *)record;

/**
 * Computes the tamper hash for a set of already unpacked per-difficulty score figures.
 * @param tuneID The tune identifier.
 * @param basic The Basic-difficulty score figure.
 * @param medium The Medium-difficulty score figure.
 * @param hard The Hard-difficulty score figure.
 * @param hash The sixteen-byte buffer that receives the computed digest.
 * @ghidraAddress 0x5d300
 */
+ (void)hashScoreforTune:(int)tuneID
                   Basic:(int)basic
                  Medium:(int)medium
                    Hard:(int)hard
                    Hash:(unsigned char *)hash;

/**
 * Recomputes the tamper hash for a record's current score values.
 * @param record The record to hash.
 * @return The freshly computed hash data.
 * @ghidraAddress 0x5d3bc
 */
+ (NSData *)hashScore:(ScoreData *)record;

/**
 * Validates a record by comparing its stored hash against a freshly computed one.
 * @param record The record to check.
 * @return @c YES when the record's stored hash matches the recomputed hash, otherwise @c NO.
 * @ghidraAddress 0x5d698
 */
+ (BOOL)checkScore:(nullable ScoreData *)record;

/**
 * The total of the clamped best scores across every valid record for the currently
 * available tunes.
 * @return The aggregate score.
 * @ghidraAddress 0x5d778
 */
+ (long long)totalScore;

/**
 * The number of records played after the epoch whose tune identifiers fall within the
 * standard tune range.
 * @return The record count.
 * @ghidraAddress 0x5e820
 */
+ (long long)totalRecordCount;

/**
 * The frame-bonus tier for this record, derived from its full-combo flags and clear ranks.
 * @return The frame-bonus tier.
 * @ghidraAddress 0x5df3c
 */
- (ScoreDataFrameBonusType)getFrameBonusType;

/**
 * Clamps this record's out-of-range achievement rates and scores back into their valid
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
