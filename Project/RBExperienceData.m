//
//  RBExperienceData.m
//  REFLEC BEAT plus
//
//  Reconstructed from Ghidra project rb458, program rb458 (class RBExperienceData). Verified
//  against the arm64 disassembly (the coder msgSends are variadic and their float arguments travel
//  the soft-float path, so the decompiler drops or garbles them; the takeover point accumulator is
//  reconstructed from the raw disassembly of -takeoverPoint).
//

#import "RBExperienceData.h"

// Collaborator classes reached from the persistence, unlock, and takeover paths. Their headers are
// not yet reconstructed in this tree; the imports resolve once those classes land, matching the
// speculative-import style already used by AppDelegate.mm, ScoreData.m, and ReplayData.m.
#import "AppDelegate.h"
#import "BFCodec.h"
#import "NSArray+RB.h"
#import "RBBonusData.h"
#import "RBCoreDataManager.h"
#import "RBMusicManager.h"
#import "RBUserSettingData.h"
#import "ScoreData.h"

// Plain-C engine helpers shared with the persistence and progression layers. They live in the C++
// engine bridge, which is not C-safe, so their prototypes are declared locally rather than by
// importing that bridge.
// @ghidraAddress 0x17534 (Md5StringToData)
NSData *Md5StringToData(const char *pString);
// Returns the shared level-threshold tables consulted by the takeover migration.
void *GetLevelTablesInstance(void);
// Reports whether the player has reached the level that unlocks a category's item.
bool CheckLevelThresholdReached(void *pLevelTables, int category, int itemID);
// Returns the application's bundle version string.
NSString *GetBundleVersionString(void);

@interface RBExperienceData ()

/**
 * @brief Encodes a point value into its enciphered on-disk form.
 * @ghidraAddress 0x1bc554
 */
- (NSMutableData *)encodePoint:(float)point;
/**
 * @brief Decodes a point value from its enciphered on-disk form.
 * @ghidraAddress 0x1bc770
 */
- (float)decodePoint:(NSData *)data;
/**
 * @brief Encodes the reward mapping into its enciphered on-disk form.
 * @ghidraAddress 0x1bc9f4
 */
- (NSMutableData *)encodeAppliIds:(NSDictionary *)appliIds;
/**
 * @brief Decodes the reward mapping from its enciphered on-disk form.
 * @ghidraAddress 0x1bcbd8
 */
- (NSMutableDictionary *)decodeAppliIds:(NSData *)data;
/**
 * @brief Records a diagnostic message. Compiled to an empty stub in the shipped build.
 * @ghidraAddress 0x1bd0cc
 */
- (void)writeLog:(NSString *)message;
/// Reports whether the premium theme identifier is present. This factors out the fast enumeration
/// that @c takeover repeats inline for each cosmetic category.
- (BOOL)themaContainsPremium;

@end

/// Archive keys for each persisted field. They match the property names bar the abbreviations here.
static NSString *const kVersionCoderKey = @"kVersionKey";
static NSString *const kPointCoderKey = @"kPointKey";
static NSString *const kDataCoderKey = @"kDataKey";
static NSString *const kPointBCoderKey = @"kPointBKey";
static NSString *const kDataBCoderKey = @"kDataBKey";
static NSString *const kBgmItemsCoderKey = @"kBgmItemsKey";
static NSString *const kShotItemsCoderKey = @"kShotItemsKey";
static NSString *const kExplosionItemsCoderKey = @"kExplosionItemsKey";
static NSString *const kFrameItemsCoderKey = @"kFrameItemsKey";
static NSString *const kBackgroundItemsCoderKey = @"kBackgroundItemsKey";
static NSString *const kMusicItemsCoderKey = @"kMusicItemsKey";
static NSString *const kThemaItemsCoderKey = @"kThemaItemsKey";
static NSString *const kInstalledAppliIdDataCoderKey = @"kInstalledAppliIdDataKey";

/// Diagnostic log messages. The receiver's @c writeLog: is a stub, so these travel no further than
/// the call, but they are retained here for fidelity with the shipped build.
static NSString *const kLogEncodeCheckPoint = @"encode check ng - save";
static NSString *const kLogEncodeCheckPointB = @"encode check [pointB] NG - save";
static NSString *const kLogDecodePointDataNull = @"decodepoint - data is null";
static NSString *const kLogDecodeErrorNoVersion = @"decode error - init without version";
static NSString *const kLogDecodeErrorWithVersion = @"decode error - init with version";
static NSString *const kLogDecodeError = @"decode error";

/// The largest tolerated absolute difference between a point value and the value recovered from its
/// enciphered round trip before a decode error is logged.
/// @ghidraAddress 0x2ee878 (g_flPointRoundTripTolerance)
static const double kPointRoundTripTolerance = 1.0e-5;

/// The initial capacity reserved for the mutable dictionary of reward application identifiers and
/// for the mutable buffers that the cipher helpers build.
static const NSUInteger kInstalledAppliIdsCapacity = 20;
static const NSUInteger kCipherBufferCapacity = 128;

/// The length in bytes of the random salt word prefixed to enciphered point and reward data.
static const NSUInteger kCipherSaltLength = 4;

/// The value @c indexOfObject: returns when an object is absent.
static const NSUInteger kNotFoundIndex = NSNotFound;

// The Limelight theme drives @c point and the Colette theme drives @c pointB. The Classic theme
// earns no campaign points.

/// The minimum clear rank that awards a clear bonus in the takeover point recomputation. It matches
/// the "cleared" threshold applied to each difficulty's stored rank.
static const int kClearedRank = 2;

/// The default theme identifiers seeded by @c initialized.
static const int kDefaultThemaIds[] = {0, 1, 2};

/// The default unlocked item identifiers seeded by @c initialized.
static const int kDefaultBgmItemIds[] = {15, 1, 0};
static const int kDefaultShotItemIds[] = {0, 1, 2};
static const int kDefaultExprosionItemIds[] = {12, 1, 0};
static const int kDefaultFrameItemIds[] = {14, 7};
static const int kDefaultBackgroundItemIds[] = {13, 6};

/// The theme identifier that widens the takeover default items for background music, explosions,
/// frames, and backgrounds.
static const int kTakeoverPremiumThemaId = 2;

/// The premium default item added to a category during takeover when @c kTakeoverPremiumThemaId is
/// present.
static const int kTakeoverPremiumBgmId = 15;
static const int kTakeoverPremiumExprosionId = 12;
static const int kTakeoverPremiumFrameId = 14;
static const int kTakeoverPremiumBackgroundId = 13;

/// The base default item unconditionally added to a category during takeover.
static const int kTakeoverBaseBgmId = 1;
static const int kTakeoverBaseExprosionId = 1;
static const int kTakeoverBaseFrameId = 7;
static const int kTakeoverBaseBackgroundId = 6;

/// The level-table category indices passed to @c CheckLevelThresholdReached.
static const int kLevelCategoryBgm = 0;
static const int kLevelCategoryShot = 1;
static const int kLevelCategoryExprosion = 2;
static const int kLevelCategoryFrame = 3;
static const int kLevelCategoryBackground = 4;

/// Takeover level-threshold-gated item identifier tables, one per cosmetic category.
/// @ghidraAddress 0x2ef190 (g_anTakeoverBgmTypeIds)
static const int kTakeoverBgmTypeIds[] = {0, 2, 3, 4, 5, 6};
/// @ghidraAddress 0x2ef274 (g_anTakeoverShotTypeIds)
static const int kTakeoverShotTypeIds[] = {0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11,
                                           12, 14, 15, 16, 17, 18, 19, 20, 21, 22};
/// @ghidraAddress 0x2ef3c4 (g_anTakeoverExprosionTypeIds)
static const int kTakeoverExprosionTypeIds[] = {0, 2, 3, 4, 5, 9, 10};
/// @ghidraAddress 0x2ef45c (g_anTakeoverFrameTypeIds)
static const int kTakeoverFrameTypeIds[] = {0, 1, 2, 3, 4, 5, 6};
/// @ghidraAddress 0x2ef52c (g_anTakeoverBackgroundTypeIds)
static const int kTakeoverBackgroundTypeIds[] = {0, 1, 2, 3, 4, 5};

/// The default-item baselines @c noUnlocked compares against: a fresh install holds at most this
/// many of each category, and an empty tune set. Any surplus counts as an unlock.
static const NSUInteger kDefaultBgmItemCount = 3;
static const NSUInteger kDefaultShotItemCount = 14;
static const NSUInteger kDefaultExprosionItemCount = 3;
static const NSUInteger kDefaultFrameItemCount = 3;
static const NSUInteger kDefaultBackgroundItemCount = 3;
static const NSUInteger kDefaultThemaItemCount = 3;

/// The cached singleton returned by @c sharedInstance.
/// @ghidraAddress 0x3df4a0 (g_pRBExperienceDataSharedInstance)
static RBExperienceData *sSharedInstance = nil;

@implementation RBExperienceData

#pragma mark - Lifecycle

- (instancetype)init {
    /** @ghidraAddress 0x1b8910 */
    self = [super init];
    if (self) {
        self.version = nil;
        self.pointData = nil;
        self.pointDataB = nil;
        self.pointDataC = nil;
        self.bgmItems = [NSMutableSet set];
        self.shotItems = [NSMutableSet set];
        self.explosionItems = [NSMutableSet set];
        self.frameItems = [NSMutableSet set];
        self.backgroundItems = [NSMutableSet set];
        self.musicItems = [NSMutableSet set];
        self.themaItems = [NSMutableSet set];
        self.installedAppliIds =
            [[NSMutableDictionary alloc] initWithCapacity:kInstalledAppliIdsCapacity];
    }
    return self;
}

#pragma mark - Singleton and persistence

+ (instancetype)sharedInstance {
    /** @ghidraAddress 0x1b9cfc */
    if (sSharedInstance == nil) {
        NSData *archived = [[NSUserDefaults standardUserDefaults]
            dataForKey:NSStringFromClass([self class])];
        RBExperienceData *restored = [NSKeyedUnarchiver unarchiveObjectWithData:archived];
        if (restored == nil) {
            restored = [[RBExperienceData alloc] init];
            [restored initialized];
        }
        sSharedInstance = restored;
    }
    return sSharedInstance;
}

- (void)save {
    /** @ghidraAddress 0x1b9e50 */
    NSData *archived = [NSKeyedArchiver archivedDataWithRootObject:self];
    [[NSUserDefaults standardUserDefaults] setObject:archived
                                              forKey:NSStringFromClass([self class])];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

- (void)initialized {
    /** @ghidraAddress 0x1bc104 */
    self.point = 0.0f;
    self.pointB = 0.0f;
    self.pointC = 0.0f;
    [self.bgmItems removeAllObjects];
    [self.shotItems removeAllObjects];
    [self.explosionItems removeAllObjects];
    [self.frameItems removeAllObjects];
    [self.backgroundItems removeAllObjects];
    [self.musicItems removeAllObjects];
    [self.themaItems removeAllObjects];
    for (NSUInteger i = 0; i < sizeof(kDefaultThemaIds) / sizeof(kDefaultThemaIds[0]); ++i) {
        [self.themaItems addObject:[NSNumber numberWithInt:kDefaultThemaIds[i]]];
    }
    [self.installedAppliIds removeAllObjects];
    for (NSUInteger i = 0; i < sizeof(kDefaultBgmItemIds) / sizeof(kDefaultBgmItemIds[0]); ++i) {
        [self addBGMType:kDefaultBgmItemIds[i]];
    }
    for (NSUInteger i = 0; i < sizeof(kDefaultShotItemIds) / sizeof(kDefaultShotItemIds[0]); ++i) {
        [self addShotType:kDefaultShotItemIds[i]];
    }
    for (NSUInteger i = 0;
         i < sizeof(kDefaultExprosionItemIds) / sizeof(kDefaultExprosionItemIds[0]);
         ++i) {
        [self addExprosionType:kDefaultExprosionItemIds[i]];
    }
    for (NSUInteger i = 0; i < sizeof(kDefaultFrameItemIds) / sizeof(kDefaultFrameItemIds[0]);
         ++i) {
        [self addFrameType:kDefaultFrameItemIds[i]];
    }
    for (NSUInteger i = 0;
         i < sizeof(kDefaultBackgroundItemIds) / sizeof(kDefaultBackgroundItemIds[0]);
         ++i) {
        [self addBackgroundType:kDefaultBackgroundItemIds[i]];
    }
}

#pragma mark - NSCoding

- (instancetype)initWithCoder:(NSCoder *)coder {
    /** @ghidraAddress 0x1b8bf0 */
    self = [super init];
    if (self) {
        self.point = [coder decodeFloatForKey:kPointCoderKey];
        if (self.point < 0.0f) {
            self.point = 0.0f;
        }
        self.version = [coder decodeObjectForKey:kVersionCoderKey];
        if (self.version == nil) {
            // A pre-versioning archive stored only the plain point; stamp the current version,
            // round trip it through the cipher, and log any drift.
            self.version = GetBundleVersionString();
            NSMutableData *encoded = [self encodePoint:self.point];
            float recovered = [self decodePoint:encoded];
            if (fabs(recovered - self.point) > kPointRoundTripTolerance) {
                [self writeLog:kLogDecodeErrorNoVersion];
            }
            self.pointData = encoded;
        } else {
            self.pointData = [coder decodeObjectForKey:kDataCoderKey];
            float recovered = [self decodePoint:self.pointData];
            if (fabs(recovered - self.point) > kPointRoundTripTolerance) {
                [self writeLog:kLogDecodeErrorWithVersion];
            }
            self.point = recovered;
        }
        self.pointB = [coder decodeFloatForKey:kPointBCoderKey];
        if (self.pointB < 0.0f) {
            self.pointB = 0.0f;
        }
        self.pointDataB = [coder decodeObjectForKey:kDataBCoderKey];
        float recoveredB = [self decodePoint:self.pointDataB];
        if (fabs(recoveredB - self.pointB) > kPointRoundTripTolerance) {
            [self writeLog:kLogDecodeError];
        }
        self.pointB = recoveredB;
        self.bgmItems = [coder decodeObjectForKey:kBgmItemsCoderKey];
        if (self.bgmItems == nil) {
            self.bgmItems = [NSMutableSet set];
        }
        self.shotItems = [coder decodeObjectForKey:kShotItemsCoderKey];
        if (self.shotItems == nil) {
            self.shotItems = [NSMutableSet set];
        }
        self.explosionItems = [coder decodeObjectForKey:kExplosionItemsCoderKey];
        if (self.explosionItems == nil) {
            self.explosionItems = [NSMutableSet set];
        }
        self.frameItems = [coder decodeObjectForKey:kFrameItemsCoderKey];
        if (self.frameItems == nil) {
            self.frameItems = [NSMutableSet set];
        }
        self.backgroundItems = [coder decodeObjectForKey:kBackgroundItemsCoderKey];
        if (self.backgroundItems == nil) {
            self.backgroundItems = [NSMutableSet set];
        }
        self.musicItems = [coder decodeObjectForKey:kMusicItemsCoderKey];
        if (self.musicItems == nil) {
            self.musicItems = [NSMutableSet set];
        }
        // The theme set is always reseeded to the three defaults rather than decoded.
        NSMutableArray *defaultThemas = [NSMutableArray arrayWithObjects:
            [NSNumber numberWithUnsignedInt:0],
            [NSNumber numberWithUnsignedInt:1],
            [NSNumber numberWithUnsignedInt:2],
            nil];
        self.themaItems = [[NSMutableSet alloc] initWithArray:defaultThemas];
        self.installedAppliIdsData = [coder decodeObjectForKey:kInstalledAppliIdDataCoderKey];
        if (self.installedAppliIdsData == nil) {
            self.installedAppliIds =
                [[NSMutableDictionary alloc] initWithCapacity:kInstalledAppliIdsCapacity];
        } else {
            self.installedAppliIds = [self decodeAppliIds:self.installedAppliIdsData];
        }
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder *)coder {
    /** @ghidraAddress 0x1b9788 */
    [coder encodeObject:self.version forKey:kVersionCoderKey];
    [coder encodeFloat:self.point forKey:kPointCoderKey];
    NSMutableData *encoded = [self encodePoint:self.point];
    float recovered = [self decodePoint:encoded];
    if (fabs(recovered - self.point) > kPointRoundTripTolerance) {
        [self writeLog:kLogEncodeCheckPoint];
    }
    self.pointData = encoded;
    [coder encodeObject:self.pointData forKey:kDataCoderKey];
    [coder encodeFloat:self.pointB forKey:kPointBCoderKey];
    NSMutableData *encodedB = [self encodePoint:self.pointB];
    float recoveredB = [self decodePoint:encodedB];
    if (fabs(recoveredB - self.pointB) > kPointRoundTripTolerance) {
        [self writeLog:kLogEncodeCheckPointB];
    }
    self.pointDataB = encodedB;
    [coder encodeObject:self.pointDataB forKey:kDataBCoderKey];
    [coder encodeObject:self.bgmItems forKey:kBgmItemsCoderKey];
    [coder encodeObject:self.shotItems forKey:kShotItemsCoderKey];
    [coder encodeObject:self.explosionItems forKey:kExplosionItemsCoderKey];
    [coder encodeObject:self.frameItems forKey:kFrameItemsCoderKey];
    [coder encodeObject:self.backgroundItems forKey:kBackgroundItemsCoderKey];
    [coder encodeObject:self.musicItems forKey:kMusicItemsCoderKey];
    [coder encodeObject:self.themaItems forKey:kThemaItemsCoderKey];
    if (self.installedAppliIds != nil) {
        self.installedAppliIdsData = [self encodeAppliIds:self.installedAppliIds];
        [coder encodeObject:self.installedAppliIdsData forKey:kInstalledAppliIdDataCoderKey];
    }
}

#pragma mark - Cipher

- (NSMutableData *)encodePoint:(float)point {
    /** @ghidraAddress 0x1bc554 */
    NSArray *boxed = [NSArray arrayWithObject:[NSNumber numberWithFloat:point]];
    NSData *plist = (__bridge_transfer NSData *)CFPropertyListCreateXMLData(
        kCFAllocatorDefault, (__bridge CFPropertyListRef)boxed);
    NSMutableData *buffer = [[NSMutableData alloc] initWithCapacity:kCipherBufferCapacity];
    uint32_t salt = arc4random();
    [buffer appendBytes:&salt length:kCipherSaltLength];
    [buffer appendData:plist];
    BFCodec *codec = [[BFCodec alloc] init];
    [codec cipherInit:Md5StringToData([AppDelegate saveDataKey].UTF8String)];
    [codec encipher:buffer];
    return buffer;
}

- (float)decodePoint:(NSData *)data {
    /** @ghidraAddress 0x1bc770 */
    if (data == nil) {
        [self writeLog:kLogDecodePointDataNull];
        return self.point;
    }
    NSMutableData *buffer = [[NSMutableData alloc] initWithData:data];
    BFCodec *codec = [[BFCodec alloc] init];
    [codec cipherInit:Md5StringToData([AppDelegate saveDataKey].UTF8String)];
    [codec decipher:buffer];
    NSRange payloadRange = NSMakeRange(kCipherSaltLength, buffer.length - kCipherSaltLength);
    NSData *payload = [buffer subdataWithRange:payloadRange];
    NSArray *boxed = [NSArray arrayFromPropertyListData:payload];
    if (boxed == nil) {
        return self.point;
    }
    return [[boxed objectAtIndex:0] floatValue];
}

- (NSMutableData *)encodeAppliIds:(NSDictionary *)appliIds {
    /** @ghidraAddress 0x1bc9f4 */
    NSMutableData *buffer = [[NSMutableData alloc] initWithCapacity:kCipherBufferCapacity];
    NSData *archive = [NSKeyedArchiver archivedDataWithRootObject:appliIds];
    uint32_t salt = arc4random();
    [buffer appendBytes:&salt length:kCipherSaltLength];
    [buffer appendData:archive];
    BFCodec *codec = [[BFCodec alloc] init];
    [codec cipherInit:Md5StringToData([AppDelegate saveDataKey].UTF8String)];
    [codec encipher:buffer];
    return buffer;
}

- (NSMutableDictionary *)decodeAppliIds:(NSData *)data {
    /** @ghidraAddress 0x1bcbd8 */
    if (data == nil) {
        [self writeLog:kLogDecodePointDataNull];
        return self.installedAppliIds;
    }
    NSMutableData *buffer = [[NSMutableData alloc] initWithData:data];
    BFCodec *codec = [[BFCodec alloc] init];
    [codec cipherInit:Md5StringToData([AppDelegate saveDataKey].UTF8String)];
    [codec decipher:buffer];
    NSRange payloadRange = NSMakeRange(kCipherSaltLength, buffer.length - kCipherSaltLength);
    NSData *payload = [buffer subdataWithRange:payloadRange];
    NSMutableDictionary *decoded = [NSKeyedUnarchiver unarchiveObjectWithData:payload];
    if (decoded == nil) {
        return self.installedAppliIds;
    }
    return decoded;
}

#pragma mark - Unlock queries

- (BOOL)unlockWithBGMtype:(int)type {
    /** @ghidraAddress 0x1b9f74 */
    for (NSNumber *item in self.bgmItems) {
        if (item.intValue == type) {
            return YES;
        }
    }
    return NO;
}

- (BOOL)unlockWithShotType:(int)type {
    /** @ghidraAddress 0x1ba0c8 */
    for (NSNumber *item in self.shotItems) {
        if (item.intValue == type) {
            return YES;
        }
    }
    return NO;
}

- (BOOL)unlockWithExprosionType:(int)type {
    /** @ghidraAddress 0x1ba21c */
    for (NSNumber *item in self.explosionItems) {
        if (item.intValue == type) {
            return YES;
        }
    }
    return NO;
}

- (BOOL)unlockWithFrameType:(int)type {
    /** @ghidraAddress 0x1ba370 */
    for (NSNumber *item in self.frameItems) {
        if (item.intValue == type) {
            return YES;
        }
    }
    return NO;
}

- (BOOL)unlockWithBackgroundType:(int)type {
    /** @ghidraAddress 0x1ba4c4 */
    for (NSNumber *item in self.backgroundItems) {
        if (item.intValue == type) {
            return YES;
        }
    }
    return NO;
}

- (BOOL)unlockWithMusicID:(int)musicID {
    /** @ghidraAddress 0x1ba618 */
    for (NSNumber *item in self.musicItems) {
        if (item.intValue == musicID) {
            return YES;
        }
    }
    return NO;
}

- (BOOL)unlockWithThemaID:(int)themaID {
    /** @ghidraAddress 0x1ba76c */
    for (NSNumber *item in self.themaItems) {
        if (item.intValue == themaID) {
            return YES;
        }
    }
    return NO;
}

- (BOOL)unlockWithType:(int)type ID:(int)ID {
    /** @ghidraAddress 0x1ba8c0 */
    switch (type) {
        case RBExperienceItemTypeBGM:
            return [self unlockWithBGMtype:ID];
        case RBExperienceItemTypeShot:
            return [self unlockWithShotType:ID];
        case RBExperienceItemTypeExprosion:
            return [self unlockWithExprosionType:ID];
        case RBExperienceItemTypeFrame:
            return [self unlockWithFrameType:ID];
        case RBExperienceItemTypeBackground:
            return [self unlockWithBackgroundType:ID];
        case RBExperienceItemTypeMusic:
            return [self unlockWithMusicID:ID];
        case RBExperienceItemTypeThema:
            return [self unlockWithThemaID:ID];
        default:
            return NO;
    }
}

#pragma mark - Unlock mutation

- (void)addBGMType:(int)type {
    /** @ghidraAddress 0x1ba980 */
    [self.bgmItems addObject:[NSNumber numberWithInt:type]];
}

- (void)addShotType:(int)type {
    /** @ghidraAddress 0x1baa24 */
    [self.shotItems addObject:[NSNumber numberWithInt:type]];
}

- (void)addExprosionType:(int)type {
    /** @ghidraAddress 0x1baac8 */
    [self.explosionItems addObject:[NSNumber numberWithInt:type]];
}

- (void)addFrameType:(int)type {
    /** @ghidraAddress 0x1bab6c */
    [self.frameItems addObject:[NSNumber numberWithInt:type]];
}

- (void)addBackgroundType:(int)type {
    /** @ghidraAddress 0x1bac10 */
    [self.backgroundItems addObject:[NSNumber numberWithInt:type]];
}

- (void)addMusicID:(int)musicID {
    /** @ghidraAddress 0x1bad00 */
    [self.musicItems addObject:[NSNumber numberWithInt:musicID]];
}

- (void)addThemaID:(int)themaID {
    /** @ghidraAddress 0x1bad80 */
    [self.themaItems addObject:[NSNumber numberWithInt:themaID]];
}

- (void)addItem:(int)type ID:(int)ID {
    /** @ghidraAddress 0x1bae00 */
    switch (type) {
        case RBExperienceItemTypeBGM:
            [self addBGMType:ID];
            break;
        case RBExperienceItemTypeShot:
            [self addShotType:ID];
            break;
        case RBExperienceItemTypeExprosion:
            [self addExprosionType:ID];
            break;
        case RBExperienceItemTypeFrame:
            [self addFrameType:ID];
            break;
        case RBExperienceItemTypeBackground:
            [self addBackgroundType:ID];
            break;
        case RBExperienceItemTypeMusic:
            [self addMusicID:ID];
            break;
        case RBExperienceItemTypeThema:
            [self addThemaID:ID];
            break;
        default:
            break;
    }
}

#pragma mark - Rewards

- (BOOL)addRewardAppliId:(id)rewardAppliId andAppliId:(id)appliId {
    /** @ghidraAddress 0x1baebc */
    if (rewardAppliId == nil || appliId == nil) {
        return NO;
    }
    NSMutableArray *granted = [self.installedAppliIds objectForKey:rewardAppliId];
    if (granted == nil) {
        granted = [[NSMutableArray alloc] initWithObjects:appliId, nil];
        [self.installedAppliIds setObject:granted forKey:rewardAppliId];
        [self save];
        return NO;
    }
    if ([granted indexOfObject:appliId] == kNotFoundIndex) {
        [granted addObject:appliId];
        [self save];
        return YES;
    }
    return NO;
}

- (NSMutableArray *)getRewardAppliId:(id)rewardAppliId {
    /** @ghidraAddress 0x1bb0a0 */
    NSMutableArray *result = [[NSMutableArray alloc] init];
    if (rewardAppliId != nil) {
        if ([self.installedAppliIds objectForKey:rewardAppliId] != nil) {
            result = [self.installedAppliIds objectForKey:rewardAppliId];
        }
    }
    return result;
}

#pragma mark - Points

- (void)addPoint:(float)point {
    /** @ghidraAddress 0x1bb21c */
    RBUserSettingDataTheme thema = [RBUserSettingData sharedInstance].thema;
    if (thema == RBUserSettingDataThemeLimelight) {
        self.point = self.point + point;
    } else if (thema == RBUserSettingDataThemeColette) {
        self.pointB = self.pointB + point;
    }
}

- (float)getPoint {
    /** @ghidraAddress 0x1bb2fc */
    RBUserSettingDataTheme thema = [RBUserSettingData sharedInstance].thema;
    if (thema == RBUserSettingDataThemeLimelight) {
        return self.point;
    }
    if (thema == RBUserSettingDataThemeColette) {
        return self.pointB;
    }
    return 0.0f;
}

- (void)resetPoint:(int)thema {
    /** @ghidraAddress 0x1bb3a8 */
    if (thema == RBUserSettingDataThemeColette) {
        self.pointB = 0.0f;
    }
}

#pragma mark - Takeover

- (void)takeover {
    /** @ghidraAddress 0x1bb3c4 */
    void *levelTables = GetLevelTablesInstance();
    for (int category = 0; category <= 8; ++category) {
        switch (category) {
            case 0: {
                if ([self themaContainsPremium]) {
                    [self addBGMType:kTakeoverPremiumBgmId];
                }
                [self addBGMType:kTakeoverBaseBgmId];
                for (NSUInteger i = 0;
                     i < sizeof(kTakeoverBgmTypeIds) / sizeof(kTakeoverBgmTypeIds[0]);
                     ++i) {
                    if (CheckLevelThresholdReached(levelTables,
                                                   kLevelCategoryBgm,
                                                   kTakeoverBgmTypeIds[i])) {
                        [self addBGMType:kTakeoverBgmTypeIds[i]];
                    }
                }
                break;
            }
            case 1: {
                for (NSUInteger i = 0;
                     i < sizeof(kTakeoverShotTypeIds) / sizeof(kTakeoverShotTypeIds[0]);
                     ++i) {
                    if (CheckLevelThresholdReached(levelTables,
                                                   kLevelCategoryShot,
                                                   kTakeoverShotTypeIds[i])) {
                        [self addShotType:kTakeoverShotTypeIds[i]];
                    }
                }
                break;
            }
            case 2: {
                if ([self themaContainsPremium]) {
                    [self addExprosionType:kTakeoverPremiumExprosionId];
                }
                [self addExprosionType:kTakeoverBaseExprosionId];
                for (NSUInteger i = 0;
                     i < sizeof(kTakeoverExprosionTypeIds) / sizeof(kTakeoverExprosionTypeIds[0]);
                     ++i) {
                    if (CheckLevelThresholdReached(levelTables,
                                                   kLevelCategoryExprosion,
                                                   kTakeoverExprosionTypeIds[i])) {
                        [self addExprosionType:kTakeoverExprosionTypeIds[i]];
                    }
                }
                break;
            }
            case 3: {
                if ([self themaContainsPremium]) {
                    [self addFrameType:kTakeoverPremiumFrameId];
                }
                [self addFrameType:kTakeoverBaseFrameId];
                for (NSUInteger i = 0;
                     i < sizeof(kTakeoverFrameTypeIds) / sizeof(kTakeoverFrameTypeIds[0]);
                     ++i) {
                    if (CheckLevelThresholdReached(levelTables,
                                                   kLevelCategoryFrame,
                                                   kTakeoverFrameTypeIds[i])) {
                        [self addFrameType:kTakeoverFrameTypeIds[i]];
                    }
                }
                break;
            }
            case 4: {
                if ([self themaContainsPremium]) {
                    [self addBackgroundType:kTakeoverPremiumBackgroundId];
                }
                [self addBackgroundType:kTakeoverBaseBackgroundId];
                for (NSUInteger i = 0;
                     i < sizeof(kTakeoverBackgroundTypeIds) / sizeof(kTakeoverBackgroundTypeIds[0]);
                     ++i) {
                    if (CheckLevelThresholdReached(levelTables,
                                                   kLevelCategoryBackground,
                                                   kTakeoverBackgroundTypeIds[i])) {
                        [self addBackgroundType:kTakeoverBackgroundTypeIds[i]];
                    }
                }
                break;
            }
            default:
                break;
        }
    }
    [self save];
}

/// Reports whether the premium theme identifier is present, widening the takeover default items.
- (BOOL)themaContainsPremium {
    for (NSNumber *item in self.themaItems) {
        if (item.intValue == kTakeoverPremiumThemaId) {
            return YES;
        }
    }
    return NO;
}

- (float)takeoverPoint {
    /** @ghidraAddress 0x1bba38 */
    RBBonusData *bonusData = [RBBonusData sharedInstance];
    NSMutableArray *musicDatas = [NSMutableArray arrayWithArray:
        [[RBMusicManager getInstance] getMusicDataArray]];
    NSMutableArray *tuneIDs = [NSMutableArray array];
    for (id musicData in musicDatas) {
        [tuneIDs addObject:[NSNumber numberWithInt:[[musicData musicID] intValue]]];
    }
    NSManagedObjectContext *context =
        [RBCoreDataManager sharedInstance].managedObjectContext;
    NSArray *records = [ScoreData getScoreDatas:tuneIDs inManagedObjectContext:context];
    float accumulated = 0.0f;
    for (NSNumber *tuneID in tuneIDs) {
        for (ScoreData *record in records) {
            if (record.tuneID.intValue != tuneID.intValue) {
                continue;
            }
            if (record.raBas.intValue >= kClearedRank) {
                accumulated += bonusData.clearBonus;
            }
            if (record.raMed.intValue >= kClearedRank) {
                accumulated += bonusData.clearBonus;
            }
            if (record.raHar.intValue >= kClearedRank) {
                accumulated += bonusData.clearBonus;
            }
        }
    }
    self.point = self.point + accumulated;
    [self save];
    return self.point;
}

#pragma mark - Queries

- (BOOL)noUnlocked {
    /** @ghidraAddress 0x1bce1c */
    if (self.bgmItems.count > kDefaultBgmItemCount) {
        return NO;
    }
    if (self.shotItems.count > kDefaultShotItemCount) {
        return NO;
    }
    if (self.explosionItems.count > kDefaultExprosionItemCount) {
        return NO;
    }
    if (self.frameItems.count > kDefaultFrameItemCount) {
        return NO;
    }
    if (self.backgroundItems.count > kDefaultBackgroundItemCount) {
        return NO;
    }
    if (self.musicItems != nil && self.musicItems.count != 0) {
        return NO;
    }
    if (self.themaItems.count > kDefaultThemaItemCount) {
        return NO;
    }
    return YES;
}

#pragma mark - Logging

- (void)writeLog:(NSString *)message {
    /** @ghidraAddress 0x1bd0cc */
    // The shipped build compiles this to an empty stub; the message is discarded.
    (void)message;
}

@end

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
