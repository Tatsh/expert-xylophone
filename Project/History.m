#import "History.h"

#import "HistoryData.h"
#import "RBScoreHash.h"
#import "enginecrypto.h"

static NSString *const kHistoryEntityName = @"History";

static NSString *const kHistorySortKey = @"playDate";

static NSString *const kPredicateTuneIDAndDifficulty = @"tuneID == %d AND diff == %d";
static NSString *const kPredicatePlayDateAfter = @"playDate > %@";
static NSString *const kPredicatePlayDateInRange = @"%@ <= playDate AND playDate < %@";

// @ghidraAddress 0x2fcf30 (g_dHistoryFetchWindow)
static const NSTimeInterval kHistoryFetchWindow = -86400.0;

static const NSUInteger kDefaultFetchLimit = 100;

static const NSUInteger kDeleteFetchLimit = 20;

static const unsigned int kMinimumTuneID = 100000000;

static const int kHalfWordShift = 16;

@implementation History

#pragma mark - Fetch helpers

+ (NSArray *)getScoreData:(unsigned int)tuneID
                Difficulty:(HistoryDifficulty)difficulty
    inManagedObjectContext:(NSManagedObjectContext *)context {
    /** @ghidraAddress 0x5a7d0 */
    NSFetchRequest *request = [[NSFetchRequest alloc] init];
    request.entity = [NSEntityDescription entityForName:kHistoryEntityName
                                 inManagedObjectContext:context];
    request.predicate =
        [NSPredicate predicateWithFormat:kPredicateTuneIDAndDifficulty, tuneID, difficulty];
    NSSortDescriptor *sort = [[NSSortDescriptor alloc] initWithKey:kHistorySortKey ascending:NO];
    request.sortDescriptors = @[ sort ];
    NSArray *records = [context executeFetchRequest:request error:nil];
    NSMutableArray *result = [[NSMutableArray alloc] init];
    for (NSManagedObject *record in records) {
        if (![History checkScore:record]) {
            [History reset:record];
        }
        [result addObject:[[HistoryData alloc] initWithData:record]];
    }
    return result;
}

+ (NSArray *)getScoreData:(NSDate *)date inManagedObjectContext:(NSManagedObjectContext *)context {
    /** @ghidraAddress 0x5abd8 */
    NSFetchRequest *request = [[NSFetchRequest alloc] init];
    request.entity = [NSEntityDescription entityForName:kHistoryEntityName
                                 inManagedObjectContext:context];
    NSDate *since = [NSDate dateWithTimeInterval:kHistoryFetchWindow sinceDate:date];
    NSDate *localSince = [HistoryData convertLocalDate:since];
    request.predicate = [NSPredicate predicateWithFormat:kPredicatePlayDateAfter, localSince];
    NSArray *records = [context executeFetchRequest:request error:nil];
    NSMutableArray *result = [[NSMutableArray alloc] init];
    for (NSManagedObject *record in records) {
        if (![History checkScore:record]) {
            [History reset:record];
        }
        [result addObject:[[HistoryData alloc] initWithData:record]];
    }
    return result;
}

+ (NSArray *)getScoreDataWithStartDate:(NSDate *)startDate
                            andEndDate:(NSDate *)endDate
                              andLimit:(unsigned int)limit
                inManagedObjectContext:(NSManagedObjectContext *)context {
    /** @ghidraAddress 0x5afec */
    NSFetchRequest *request = [[NSFetchRequest alloc] init];
    request.entity = [NSEntityDescription entityForName:kHistoryEntityName
                                 inManagedObjectContext:context];
    if (startDate && endDate) {
        NSDate *localStart = [HistoryData convertLocalDate:startDate];
        NSDate *localEnd = [HistoryData convertLocalDate:endDate];
        request.predicate =
            [NSPredicate predicateWithFormat:kPredicatePlayDateInRange, localStart, localEnd];
    }
    request.fetchLimit = limit != 0 ? limit : kDefaultFetchLimit;
    NSArray *records = [context executeFetchRequest:request error:nil];
    NSMutableArray *result = [[NSMutableArray alloc] init];
    for (NSManagedObject *record in records) {
        if (![History checkScore:record]) {
            [History reset:record];
        }
        [result addObject:[[HistoryData alloc] initWithData:record]];
    }
    return result;
}

#pragma mark - Mutation helpers

+ (void)deleteObject:(NSManagedObjectContext *)context {
    /** @ghidraAddress 0x5b434 */
    NSFetchRequest *request = [[NSFetchRequest alloc] init];
    request.entity = [NSEntityDescription entityForName:kHistoryEntityName
                                 inManagedObjectContext:context];
    request.fetchLimit = kDeleteFetchLimit;
    NSArray *records = [context executeFetchRequest:request error:nil];
    if (records.count != 0) {
        for (NSManagedObject *record in records) {
            [context deleteObject:record];
        }
        [context save:nil];
    }
}

+ (long long)count:(NSManagedObjectContext *)context {
    /** @ghidraAddress 0x5b69c */
    NSFetchRequest *request = [[NSFetchRequest alloc] init];
    request.entity = [NSEntityDescription entityForName:kHistoryEntityName
                                 inManagedObjectContext:context];
    NSError *error = nil;
    NSUInteger count = [context countForFetchRequest:request error:&error];
    return count != NSNotFound ? (long long)count : 0;
}

+ (id)recordWithTuneID:(unsigned int)tuneID
                Difficulty:(HistoryDifficulty)difficulty
    inManagedObjectContext:(NSManagedObjectContext *)context {
    /** @ghidraAddress 0x5b7ac */
    if (tuneID < kMinimumTuneID) {
        return nil;
    }
    id record = [NSEntityDescription insertNewObjectForEntityForName:kHistoryEntityName
                                              inManagedObjectContext:context];
    [record setTuneID:[NSNumber numberWithInt:(int)tuneID]];
    [record setDiff:[NSNumber numberWithInt:(int)difficulty]];
    [History reset:record];
    return record;
}

+ (void)reset:(id)record {
    /** @ghidraAddress 0x5b900 */
    [record setCntJust:[NSNumber numberWithInt:0]];
    [record setCntGreat:[NSNumber numberWithInt:0]];
    [record setCntGood:[NSNumber numberWithInt:0]];
    [record setCntMiss:[NSNumber numberWithInt:0]];
    [record setCntJR:[NSNumber numberWithInt:0]];
    [record setCntCom:[NSNumber numberWithInt:0]];
    [record setPlayDate:[NSDate dateWithTimeIntervalSince1970:0]];
    [record setPc:[NSNumber numberWithInt:0]];
    [record setChksco:[History hashScore:record]];
}

#pragma mark - Tamper hash

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
                    Hash:(unsigned char *)hash {
    /** @ghidraAddress 0x5bb88 */
    uint64_t dateBits = 0;
    memcpy(&dateBits, &date, sizeof(dateBits));
    uint64_t countBits = (uint64_t)count;
    int words[kHashWordCount];
    words[kHashWordTuneID] = tuneID;
    words[kHashWordSlot1] =
        difficulty + (int16_t)dateBits + (int16_t)(countBits >> (kHalfWordShift * 3));
    words[kHashWordSlot2] = just + score;
    words[kHashWordSlot3] = great;
    words[kHashWordSlot4] = good;
    words[kHashWordSlot5] =
        miss + (int16_t)(dateBits >> kHalfWordShift) + (int16_t)(countBits >> (kHalfWordShift * 2));
    words[kHashWordSlot6] =
        jr + (int16_t)(countBits >> kHalfWordShift) + (int16_t)(dateBits >> (kHalfWordShift * 2));
    words[kHashWordSlot7] =
        combo + (int16_t)countBits + (int16_t)(dateBits >> (kHalfWordShift * 3));
    ComputeMd5Digest(words, sizeof(words), hash);
}

+ (NSData *)hashScore:(id)record {
    /** @ghidraAddress 0x5bc38 */
    int tuneID = [[record tuneID] intValue];
    int difficulty = [[record diff] intValue];
    int score = [[record score] intValue];
    int just = [[record cntJust] intValue];
    int great = [[record cntGreat] intValue];
    int good = [[record cntGood] intValue];
    int miss = [[record cntMiss] intValue];
    int jr = [[record cntJR] intValue];
    int combo = [[record cntCom] intValue];
    double date = [[record playDate] timeIntervalSinceReferenceDate];
    long long count = [[record pc] longLongValue];
    unsigned char digest[kHashDigestLength];
    [History hashScoreforTune:tuneID
                   Difficulty:difficulty
                        Score:score
                         Just:just
                        Great:great
                         Good:good
                         Miss:miss
                           JR:jr
                        Combo:combo
                         Date:date
                        Count:count
                         Hash:digest];
    return [NSData dataWithBytes:digest length:kHashDigestLength];
}

+ (BOOL)checkScore:(id)record {
    /** @ghidraAddress 0x5c01c */
    if (record == nil) {
        return NO;
    }
    NSData *expected = [History hashScore:record];
    return [expected isEqualToData:[record chksco]];
}

#pragma mark - Scoring helpers

+ (float)getAR:(id)source {
    /** @ghidraAddress 0x5c0fc */
    if (source == nil) {
        return 0.0f;
    }
    int just = [[source cntJust] intValue];
    int great = [[source cntGreat] intValue];
    int good = [[source cntGood] intValue];
    int miss = [[source cntMiss] intValue];
    return (float)(just * 3 + great * 2 + good) / ((float)(just + great + good + miss) * 3.0f);
}

+ (BOOL)getFullCombo:(id)source {
    /** @ghidraAddress 0x5c290 */
    if (source == nil) {
        return NO;
    }
    int just = [[source cntJust] intValue];
    int great = [[source cntGreat] intValue];
    int good = [[source cntGood] intValue];
    int miss = [[source cntMiss] intValue];
    int combo = [[source cntCom] intValue];
    return just + great + good + miss == combo;
}

@end
