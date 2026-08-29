#import "ReplayData.h"

#import "BFCodec.h"
#import "NSFileManager+RB.h"
#import "SSZipArchive.h"
#import "enginecrypto.h"

static NSString *const kVersionCoderKey = @"ver";
static NSString *const kTuneIDCoderKey = @"tuneID";
static NSString *const kDiffCoderKey = @"diff";
static NSString *const kSeedCoderKey = @"seed";
static NSString *const kCntNoteCoderKey = @"cntNote";
static NSString *const kScoreCoderKey = @"score";
static NSString *const kCntComCoderKey = @"cntCom";
static NSString *const kCntJustCoderKey = @"cntJust";
static NSString *const kCntGreatCoderKey = @"cntGreat";
static NSString *const kCntGoodCoderKey = @"cntGood";
static NSString *const kCntMissCoderKey = @"cntMiss";
static NSString *const kCntJRCoderKey = @"cntJR";
static NSString *const kArCoderKey = @"ar";
static NSString *const kReplayCoderKey = @"replay";
static NSString *const kPlayDateCoderKey = @"playDate";
static NSString *const kUserCoderKey = @"user";
static NSString *const kChkscoCoderKey = @"chksco";

static NSString *const kReplayDirectoryName = @"replay";

static NSString *const kReplayPathFormat = @"%@/%09d_%d.rbp";

static NSString *const kTempDataPathFormat = @"%@/tmp.data";

static NSString *const kReplayCipherPassphrase = @"REFLECBEATplus";

static const int kDefaultReplayVersion = 10000;

// The load and save paths each keep their own boxed copy.
static NSNumber *g_pReplayDataDefaultVersion = nil;     // @ghidraAddress 0x3dc9f0
static NSNumber *g_pReplayDataDefaultVersionSave = nil; // @ghidraAddress 0x3dc9f8

/**
 * @ghidraAddress 0x10708c
 * Boxes the two default replay-version numbers once at load time.
 */
__attribute__((constructor)) static void InitializeDefaultReplayVersions(void) {
    @autoreleasepool {
        g_pReplayDataDefaultVersion = [NSNumber numberWithInt:kDefaultReplayVersion];
        g_pReplayDataDefaultVersionSave = [NSNumber numberWithInt:kDefaultReplayVersion];
    }
}

// Advanced difficulties are folded back into the basic range before a path is formed.
static const int kFirstAdvancedDifficulty = 3;
static const int kAdvancedDifficultyOffset = 3;

static const NSUInteger kReplaySaltLength = 4;

static const NSUInteger kReplayEncodeCapacity = 128;

@implementation ReplayData

#pragma mark - Lifecycle

- (instancetype)init {
    /** @ghidraAddress 0x105290 */
    self = [super init];
    if (self) {
        [self reset];
    }
    return self;
}

- (void)reset {
    /** @ghidraAddress 0x105304 */
    self.version = nil;
    self.tuneID = nil;
    self.diff = nil;
    self.seed = nil;
    self.cntNote = nil;
    self.score = nil;
    self.cntCom = nil;
    self.cntJust = nil;
    self.cntGreat = nil;
    self.cntGood = nil;
    self.cntMiss = nil;
    self.cntJR = nil;
    self.ar = nil;
    self.replay = nil;
    self.playDate = nil;
    self.user = nil;
    self.chksco = nil;
}

#pragma mark - NSCoding

- (instancetype)initWithCoder:(NSCoder *)aDecoder {
    /** @ghidraAddress 0x1048bc */
    self = [super init];
    if (self) {
        self.version = [aDecoder decodeObjectForKey:kVersionCoderKey];
        self.tuneID = [aDecoder decodeObjectForKey:kTuneIDCoderKey];
        self.diff = [aDecoder decodeObjectForKey:kDiffCoderKey];
        self.seed = [aDecoder decodeObjectForKey:kSeedCoderKey];
        self.cntNote = [aDecoder decodeObjectForKey:kCntNoteCoderKey];
        self.score = [aDecoder decodeObjectForKey:kScoreCoderKey];
        self.cntCom = [aDecoder decodeObjectForKey:kCntComCoderKey];
        self.cntJust = [aDecoder decodeObjectForKey:kCntJustCoderKey];
        self.cntGreat = [aDecoder decodeObjectForKey:kCntGreatCoderKey];
        self.cntGood = [aDecoder decodeObjectForKey:kCntGoodCoderKey];
        self.cntMiss = [aDecoder decodeObjectForKey:kCntMissCoderKey];
        self.cntJR = [aDecoder decodeObjectForKey:kCntJRCoderKey];
        self.ar = [aDecoder decodeObjectForKey:kArCoderKey];
        self.replay = [aDecoder decodeObjectForKey:kReplayCoderKey];
        self.playDate = [aDecoder decodeObjectForKey:kPlayDateCoderKey];
        self.user = [aDecoder decodeObjectForKey:kUserCoderKey];
        self.chksco = [aDecoder decodeObjectForKey:kChkscoCoderKey];
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder *)aCoder {
    /** @ghidraAddress 0x104df4 */
    [aCoder encodeObject:self.version forKey:kVersionCoderKey];
    [aCoder encodeObject:self.tuneID forKey:kTuneIDCoderKey];
    [aCoder encodeObject:self.diff forKey:kDiffCoderKey];
    [aCoder encodeObject:self.seed forKey:kSeedCoderKey];
    [aCoder encodeObject:self.cntNote forKey:kCntNoteCoderKey];
    [aCoder encodeObject:self.score forKey:kScoreCoderKey];
    [aCoder encodeObject:self.cntCom forKey:kCntComCoderKey];
    [aCoder encodeObject:self.cntJust forKey:kCntJustCoderKey];
    [aCoder encodeObject:self.cntGreat forKey:kCntGreatCoderKey];
    [aCoder encodeObject:self.cntGood forKey:kCntGoodCoderKey];
    [aCoder encodeObject:self.cntMiss forKey:kCntMissCoderKey];
    [aCoder encodeObject:self.cntJR forKey:kCntJRCoderKey];
    [aCoder encodeObject:self.ar forKey:kArCoderKey];
    [aCoder encodeObject:self.replay forKey:kReplayCoderKey];
    [aCoder encodeObject:self.playDate forKey:kPlayDateCoderKey];
    [aCoder encodeObject:self.user forKey:kUserCoderKey];
    [aCoder encodeObject:self.chksco forKey:kChkscoCoderKey];
}

#pragma mark - Cipher

+ (NSData *)encode:(NSData *)data {
    /** @ghidraAddress 0x1060a0 */
    NSMutableData *buffer = [[NSMutableData alloc] initWithCapacity:kReplayEncodeCapacity];
    uint32_t salt = arc4random();
    [buffer appendBytes:&salt length:kReplaySaltLength];
    [buffer appendData:data];
    BFCodec *codec = [[BFCodec alloc] init];
    [codec cipherInit:Md5StringToData(kReplayCipherPassphrase.UTF8String)];
    [codec encipher:buffer];
    return buffer;
}

+ (NSData *)decode:(NSData *)data {
    /** @ghidraAddress 0x106204 */
    NSMutableData *buffer = [[NSMutableData alloc] initWithData:data];
    BFCodec *codec = [[BFCodec alloc] init];
    [codec cipherInit:Md5StringToData(kReplayCipherPassphrase.UTF8String)];
    [codec decipher:buffer];
    NSRange payloadRange = NSMakeRange(kReplaySaltLength, buffer.length - kReplaySaltLength);
    return [buffer subdataWithRange:payloadRange];
}

#pragma mark - Persistence

+ (BOOL)isExistReplayData:(int)tuneID difficulty:(int)difficulty {
    /** @ghidraAddress 0x10546c */
    int normalizedDifficulty = difficulty;
    if (difficulty >= kFirstAdvancedDifficulty) {
        normalizedDifficulty = difficulty - kAdvancedDifficultyOffset;
    }
    NSString *directory =
        [[NSFileManager documentDirectoryPath] stringByAppendingPathComponent:kReplayDirectoryName];
    if (![NSFileManager isDirectoryExist:directory]) {
        [NSFileManager createDirectory:directory];
        return NO;
    }
    NSString *path =
        [NSString stringWithFormat:kReplayPathFormat, directory, tuneID, normalizedDifficulty];
    return [NSFileManager isFileExist:path];
}

+ (instancetype)loadReplayData:(int)tuneID difficulty:(int)difficulty {
    /** @ghidraAddress 0x1055b4 */
    int normalizedDifficulty = difficulty;
    if (difficulty >= kFirstAdvancedDifficulty) {
        normalizedDifficulty = difficulty - kAdvancedDifficultyOffset;
    }
    if (![ReplayData isExistReplayData:tuneID difficulty:normalizedDifficulty]) {
        return nil;
    }
    NSString *directory =
        [[NSFileManager documentDirectoryPath] stringByAppendingPathComponent:kReplayDirectoryName];
    NSString *zipPath =
        [NSString stringWithFormat:kReplayPathFormat, directory, tuneID, normalizedDifficulty];
    NSString *tempPath = [NSString stringWithFormat:kTempDataPathFormat, directory];
    if ([[NSFileManager defaultManager] fileExistsAtPath:tempPath]) {
        [[NSFileManager defaultManager] removeItemAtPath:tempPath error:nil];
    }
    NSError *unzipError = nil;
    if (![SSZipArchive unzipFileAtPath:zipPath
                         toDestination:directory
                             overwrite:YES
                              password:nil
                                 error:&unzipError]) {
        return nil;
    }
    NSData *enciphered = [NSData dataWithContentsOfFile:tempPath];
    if (!enciphered) {
        return nil;
    }
    NSData *archive = [ReplayData decode:enciphered];
    if (!archive) {
        return nil;
    }
    ReplayData *replayData = [NSKeyedUnarchiver unarchiveObjectWithData:archive];
    if (!replayData) {
        return nil;
    }
    if (!replayData.version) {
        replayData.version = g_pReplayDataDefaultVersion;
    }
    return replayData;
}

+ (BOOL)saveReplayData:(ReplayData *)replayData {
    /** @ghidraAddress 0x1059b4 */
    if (!replayData) {
        return NO;
    }
    if (replayData.diff.intValue >= kFirstAdvancedDifficulty) {
        replayData.diff =
            [NSNumber numberWithInt:replayData.diff.intValue - kAdvancedDifficultyOffset];
    }
    if (!replayData.version) {
        replayData.version = g_pReplayDataDefaultVersionSave;
    }
    NSData *archive = [NSKeyedArchiver archivedDataWithRootObject:replayData];
    NSData *enciphered = [ReplayData encode:archive];
    if (!enciphered) {
        return NO;
    }
    NSString *directory =
        [[NSFileManager documentDirectoryPath] stringByAppendingPathComponent:kReplayDirectoryName];
    NSString *tempPath = [NSString stringWithFormat:kTempDataPathFormat, directory];
    if ([[NSFileManager defaultManager] fileExistsAtPath:tempPath]) {
        [[NSFileManager defaultManager] removeItemAtPath:tempPath error:nil];
    }
    [enciphered writeToFile:tempPath atomically:YES];
    NSString *zipPath = [NSString stringWithFormat:kReplayPathFormat,
                                                   directory,
                                                   replayData.tuneID.unsignedIntValue,
                                                   replayData.diff.unsignedIntValue];
    if ([[NSFileManager defaultManager] fileExistsAtPath:zipPath]) {
        [[NSFileManager defaultManager] removeItemAtPath:zipPath error:nil];
    }
    NSArray *files = [NSArray arrayWithObjects:&tempPath count:1];
    [SSZipArchive createZipFileAtPath:zipPath withFilesAtPaths:files];
    return YES;
}

#pragma mark - Date helpers

+ (NSDate *)convertLocalDate:(NSDate *)date {
    /** @ghidraAddress 0x105fc0 */
    if (!date) {
        return nil;
    }
    NSInteger secondsFromGMT = [[NSTimeZone systemTimeZone] secondsFromGMTForDate:date];
    return [date dateByAddingTimeInterval:(NSTimeInterval)secondsFromGMT];
}

@end
