//
//  ScoreData.m
//  REFLEC BEAT plus
//
//  Reconstructed from Ghidra project rb458, program rb458 (class ScoreData). Verified against the
//  arm64 disassembly (the Core Data fetch-predicate format strings and the tamper-hash buffer
//  layout are variadic or scrambled and are dropped or garbled by the decompiler).
//

#import "ScoreData.h"

#import <CommonCrypto/CommonDigest.h>

// Collaborator classes reached from the class-level helpers. Their headers are not yet reconstructed
// in this tree (the same speculative imports AppDelegate.mm already uses); they resolve once those
// classes land.
#import "RBCoreDataManager.h"
#import "RBMusicManager.h"
#import "RBScoreHash.h"

#import "neEngineBridge.h"

// The Core Data entity name backing this class.
static NSString *const kScoreDataEntityName = @"ScoreData";

// Fetch-predicate format strings.
static NSString *const kPredicateTuneIDEquals = @"tuneID == %d";
static NSString *const kPredicateTuneIDIn = @"tuneID in %@";
static NSString *const kPredicateRecentInRange =
    @"lastPlayDate > %@ AND 100000000 < tuneID AND tuneID < 900000000";

// The default clear rank stored for a reset chart.
static const int kResetClearRank = -1;

// The default score stored for a reset chart, also used as the low clamp in @c checkOverScore.
static const int kResetScore = -1;

// Score bounds enforced by @c checkOverScore.
static const int kScoreMinimum = -1;
static const int kScoreMaximum = 9999;

// The lowest score that contributes to @c totalScore: a score is counted only when it lies in the
// inclusive 1...9999 range.
static const int kScoreScoringMinimum = 1;

// The lowest tune identifier @c totalScore treats as a real chart; identifiers below it are skipped.
static const int kMinimumValidTuneID = 1;

// Achievement-rate bounds enforced by @c checkOverScore.
static const float kAchievementRateMinimum = 0.0f;
static const float kAchievementRateMaximum = 1.0f;

// Multiplier applied to each achievement rate before it is folded into the tamper hash.
// @ghidraAddress 0x2f8540 (g_flAchievementRateHashScale)
static const float kAchievementRateHashScale = 1000.0f;

// The number of tunes processed per fetch batch in @c totalScore.
static const NSUInteger kTotalScoreBatchSize = 15;

// Frame-bonus thresholds used by @c getFrameBonusType.
static const int kFrameBonusClearRankThreshold = 3;
static const int kFrameBonusPerfectClearRank = 5;
static const int kFrameBonusMaxTier = 2;

@implementation ScoreData

@dynamic tuneID;
@dynamic fcBas;
@dynamic fcMed;
@dynamic fcHar;
@dynamic raBas;
@dynamic raMed;
@dynamic raHar;
@dynamic scoBas;
@dynamic scoMed;
@dynamic scoHar;
@dynamic arBas;
@dynamic arMed;
@dynamic arHar;
@dynamic lastPlayDate;
@dynamic pcBas;
@dynamic pcMed;
@dynamic pcHar;
@dynamic chksco;

#pragma mark - Fetching

+ (instancetype)getScoreData:(unsigned int)tuneID
      inManagedObjectContext:(NSManagedObjectContext *)context {
    /** @ghidraAddress 0x5c444 */
    NSFetchRequest *request = [[NSFetchRequest alloc] init];
    NSEntityDescription *entity = [NSEntityDescription entityForName:kScoreDataEntityName
                                             inManagedObjectContext:context];
    request.entity = entity;
    request.predicate = [NSPredicate predicateWithFormat:kPredicateTuneIDEquals, tuneID];
    NSArray *results = [context executeFetchRequest:request error:nil];
    if (results.count == 0) {
        ScoreData *record = [ScoreData recordWithTuneID:tuneID inManagedObjectContext:context];
        NSError *error = nil;
        if (![context save:&error]) {
            NSArray *detailedErrors = error.userInfo[NSDetailedErrorsKey];
            for (NSError *detailedError in detailedErrors) {
                (void)detailedError;
            }
        }
        return record;
    }
    ScoreData *record = results.lastObject;
    if (![ScoreData checkScore:record]) {
        [ScoreData reset:record];
    }
    [record checkOverScore];
    return record;
}

+ (NSArray *)getScoreDatas:(NSArray *)tuneIDs
    inManagedObjectContext:(NSManagedObjectContext *)context {
    /** @ghidraAddress 0x5c854 */
    NSFetchRequest *request = [[NSFetchRequest alloc] init];
    NSEntityDescription *entity = [NSEntityDescription entityForName:kScoreDataEntityName
                                             inManagedObjectContext:context];
    request.entity = entity;
    request.predicate = [NSPredicate predicateWithFormat:kPredicateTuneIDIn, tuneIDs];
    NSArray *results = [context executeFetchRequest:request error:nil];
    NSMutableArray *records = [NSMutableArray arrayWithCapacity:tuneIDs.count];
    BOOL needsSave = NO;
    for (ScoreData *record in results) {
        if (![ScoreData checkScore:record]) {
            [ScoreData reset:record];
            needsSave = YES;
        } else {
            BOOL clamped = [record checkOverScore];
            [records addObject:record];
            needsSave = needsSave || clamped;
        }
    }
    if (needsSave) {
        NSError *error = nil;
        if (![context save:&error]) {
            NSArray *detailedErrors = error.userInfo[NSDetailedErrorsKey];
            for (NSError *detailedError in detailedErrors) {
                (void)detailedError;
            }
        }
    }
    return records;
}

+ (instancetype)recordWithTuneID:(unsigned int)tuneID
          inManagedObjectContext:(NSManagedObjectContext *)context {
    /** @ghidraAddress 0x5cd7c */
    ScoreData *record =
        [NSEntityDescription insertNewObjectForEntityForName:kScoreDataEntityName
                                      inManagedObjectContext:context];
    record.tuneID = [NSNumber numberWithInt:(int)tuneID];
    [ScoreData reset:record];
    return record;
}

#pragma mark - Resetting

+ (void)reset:(ScoreData *)record {
    /** @ghidraAddress 0x5ce78 */
    record.fcBas = [NSNumber numberWithBool:NO];
    record.fcMed = [NSNumber numberWithBool:NO];
    record.fcHar = [NSNumber numberWithBool:NO];
    record.raBas = [NSNumber numberWithInt:kResetClearRank];
    record.raMed = [NSNumber numberWithInt:kResetClearRank];
    record.raHar = [NSNumber numberWithInt:kResetClearRank];
    record.scoBas = [NSNumber numberWithInt:kResetScore];
    record.scoMed = [NSNumber numberWithInt:kResetScore];
    record.scoHar = [NSNumber numberWithInt:kResetScore];
    record.arBas = [NSNumber numberWithFloat:0.0f];
    record.arMed = [NSNumber numberWithFloat:0.0f];
    record.arHar = [NSNumber numberWithFloat:0.0f];
    record.lastPlayDate = [NSDate dateWithTimeIntervalSince1970:0];
    record.pcBas = [NSNumber numberWithInt:0];
    record.pcMed = [NSNumber numberWithInt:0];
    record.pcHar = [NSNumber numberWithInt:0];
    record.chksco = [ScoreData hashScore:record];
}

#pragma mark - Tamper hash

// Folds a tune's identifier and per-difficulty score and achievement-rate figures into an eight
// word buffer and returns its MD5 digest. The pairing of the words depends on the font-variant
// flag returned by @c GetFontVariantFlag so that the layout matches the shipped build's region.
// @ghidraAddress 0x5d300
static void ScoreDataHashScoreForTune(int tuneID,
                                      int basic,
                                      int medium,
                                      int hard,
                                      unsigned char *pHash) {
    int words[kHashWordCount];
    words[kHashWordTuneID] = tuneID;
    words[kHashWordSlot2] = medium;
    words[kHashWordSlot5] = hard + medium;
    words[kHashWordSlot7] = medium + basic + hard;
    if (GetFontVariantFlag() != kFontVariantDefault) {
        words[kHashWordSlot1] = basic;
        words[kHashWordSlot3] = hard;
        words[kHashWordSlot4] = medium + basic;
        words[kHashWordSlot6] = hard + basic;
    } else {
        words[kHashWordSlot1] = hard;
        words[kHashWordSlot3] = basic;
        words[kHashWordSlot4] = hard + basic;
        words[kHashWordSlot6] = medium + basic;
    }
    ComputeMd5Digest(words, sizeof(words), pHash);
}

+ (NSData *)hashScore:(ScoreData *)record {
    /** @ghidraAddress 0x5d3bc */
    int tuneID = record.tuneID.intValue;
    int scoreBasic = record.scoBas.intValue;
    float rateBasic = record.arBas.floatValue;
    int scoreMedium = record.scoMed.intValue;
    float rateMedium = record.arMed.floatValue;
    int scoreHard = record.scoHar.intValue;
    float rateHard = record.arHar.floatValue;
    unsigned char digest[kHashDigestLength];
    ScoreDataHashScoreForTune(tuneID,
                              (int)(rateBasic * kAchievementRateHashScale) + scoreBasic,
                              (int)(rateMedium * kAchievementRateHashScale) + scoreMedium,
                              (int)(rateHard * kAchievementRateHashScale) + scoreHard,
                              digest);
    return [NSData dataWithBytes:digest length:kHashDigestLength];
}

+ (BOOL)checkScore:(ScoreData *)record {
    /** @ghidraAddress 0x5d698 */
    if (record == nil) {
        return NO;
    }
    NSData *expected = [ScoreData hashScore:record];
    return [expected isEqualToData:record.chksco];
}

#pragma mark - Aggregates

+ (long long)totalScore {
    /** @ghidraAddress 0x5d778 */
    NSManagedObjectContext *context = [RBCoreDataManager sharedInstance].managedObjectContext;
    NSArray *musicIDs = [RBMusicManager getInstance].getMusicIDs;
    NSUInteger musicCount = musicIDs.count;
    if (musicCount == 0) {
        return 0;
    }
    long long total = 0;
    NSUInteger processed = 0;
    while (processed < musicCount) {
        NSUInteger batchLength = MIN(musicCount - processed, kTotalScoreBatchSize);
        NSArray *batch = [musicIDs subarrayWithRange:NSMakeRange(processed, batchLength)];
        NSMutableIndexSet *pendingIDs = [[NSMutableIndexSet alloc] init];
        for (NSNumber *musicID in batch) {
            if (musicID.intValue >= kMinimumValidTuneID) {
                [pendingIDs addIndex:(NSUInteger)musicID.intValue];
            }
        }
        NSFetchRequest *request = [[NSFetchRequest alloc] init];
        NSEntityDescription *entity = [NSEntityDescription entityForName:kScoreDataEntityName
                                                 inManagedObjectContext:context];
        request.entity = entity;
        request.predicate = [NSPredicate predicateWithFormat:kPredicateTuneIDIn, batch];
        NSArray *results = [context executeFetchRequest:request error:nil];
        for (ScoreData *record in results) {
            NSUInteger tuneIndex = (NSUInteger)record.tuneID.intValue;
            if (![pendingIDs containsIndex:tuneIndex]) {
                continue;
            }
            if (![ScoreData checkScore:record]) {
                continue;
            }
            // A score contributes only when it lies in the valid 1...9999 range; the binary tests
            // (score - kScoreScoringMinimum) as an unsigned value so that non-positive scores fall
            // out as zero.
            int scoreBasic = record.scoBas.intValue;
            long long clampedBasic =
                ((unsigned int)(scoreBasic - kScoreScoringMinimum) < (unsigned int)kScoreMaximum)
                    ? scoreBasic
                    : 0;
            int scoreMedium = record.scoMed.intValue;
            long long clampedMedium =
                ((unsigned int)(scoreMedium - kScoreScoringMinimum) < (unsigned int)kScoreMaximum)
                    ? scoreMedium
                    : 0;
            int scoreHard = record.scoHar.intValue;
            long long clampedHard =
                ((unsigned int)(scoreHard - kScoreScoringMinimum) < (unsigned int)kScoreMaximum)
                    ? scoreHard
                    : 0;
            [pendingIDs removeIndex:tuneIndex];
            total += clampedBasic + clampedMedium + clampedHard;
        }
        [context reset];
        processed += batchLength;
    }
    return total;
}

+ (long long)totalRecordCount {
    /** @ghidraAddress 0x5e820 */
    NSManagedObjectContext *context = [RBCoreDataManager sharedInstance].managedObjectContext;
    NSFetchRequest *request = [[NSFetchRequest alloc] init];
    NSEntityDescription *entity = [NSEntityDescription entityForName:kScoreDataEntityName
                                             inManagedObjectContext:context];
    request.entity = entity;
    NSDate *epoch = [NSDate dateWithTimeIntervalSince1970:0];
    request.predicate = [NSPredicate predicateWithFormat:kPredicateRecentInRange, epoch];
    request.includesSubentities = NO;
    NSError *error = nil;
    NSUInteger count = [context countForFetchRequest:request error:&error];
    return (count == NSNotFound) ? 0 : (long long)count;
}

#pragma mark - Per-record queries

- (ScoreDataFrameBonusType)getFrameBonusType {
    /** @ghidraAddress 0x5df3c */
    BOOL allFullCombo = NO;
    if (self.fcHar.boolValue && self.fcMed.boolValue) {
        allFullCombo = self.fcBas.boolValue;
    }
    int clearRankHard = GetClearRank(self.arHar.floatValue);
    int clearRankMedium = GetClearRank(self.arMed.floatValue);
    int clearRankBasic = GetClearRank(self.arBas.floatValue);
    // When every difficulty clears above the bonus threshold the tier starts at the top of the
    // full-combo scale (2 with all full combos, otherwise 1); otherwise it collapses to the
    // full-combo flag alone (1 or 0).
    int tier = allFullCombo ? kFrameBonusMaxTier : ScoreDataFrameBonusTypeBronze;
    if (clearRankBasic <= kFrameBonusClearRankThreshold ||
        clearRankMedium <= kFrameBonusClearRankThreshold ||
        clearRankHard <= kFrameBonusClearRankThreshold) {
        tier = allFullCombo ? ScoreDataFrameBonusTypeBronze : ScoreDataFrameBonusTypeNone;
    }
    if (clearRankBasic == kFrameBonusPerfectClearRank &&
        clearRankMedium == kFrameBonusPerfectClearRank &&
        clearRankHard == kFrameBonusPerfectClearRank) {
        ++tier;
    }
    if (tier > kFrameBonusMaxTier) {
        return ScoreDataFrameBonusTypeGold;
    }
    return (tier != ScoreDataFrameBonusTypeNone) ? ScoreDataFrameBonusTypeBronze
                                                 : ScoreDataFrameBonusTypeNone;
}

- (BOOL)checkOverScore {
    /** @ghidraAddress 0x5e150 */
    BOOL changed = NO;
    if (self.arBas.floatValue < kAchievementRateMinimum ||
        self.arBas.floatValue > kAchievementRateMaximum) {
        self.arBas = [NSNumber numberWithFloat:0.0f];
        changed = YES;
    }
    if (self.arMed.floatValue < kAchievementRateMinimum ||
        self.arMed.floatValue > kAchievementRateMaximum) {
        self.arMed = [NSNumber numberWithFloat:0.0f];
        changed = YES;
    }
    if (self.arHar.floatValue < kAchievementRateMinimum ||
        self.arHar.floatValue > kAchievementRateMaximum) {
        self.arHar = [NSNumber numberWithFloat:0.0f];
        changed = YES;
    }
    if (self.scoBas.intValue < kScoreMinimum) {
        self.scoBas = [NSNumber numberWithInt:kResetScore];
        changed = YES;
    } else if (self.scoBas.intValue > kScoreMaximum) {
        self.scoBas = [NSNumber numberWithInt:kScoreMaximum];
        changed = YES;
    }
    if (self.scoMed.intValue < kScoreMinimum) {
        self.scoMed = [NSNumber numberWithInt:kResetScore];
        changed = YES;
    } else if (self.scoMed.intValue > kScoreMaximum) {
        self.scoMed = [NSNumber numberWithInt:kScoreMaximum];
        changed = YES;
    }
    if (self.scoHar.intValue < kScoreMinimum) {
        self.scoHar = [NSNumber numberWithInt:kResetScore];
        changed = YES;
    } else if (self.scoHar.intValue > kScoreMaximum) {
        self.scoHar = [NSNumber numberWithInt:kScoreMaximum];
        changed = YES;
    }
    if (!changed) {
        return NO;
    }
    self.chksco = [ScoreData hashScore:self];
    return YES;
}

@end
