//
//  RBBonusData.m
//  REFLEC BEAT plus
//
//  Reconstructed from Ghidra project rb458, program rb458 (class RBBonusData). Verified against
//  the arm64 disassembly (the coder msgSends are variadic and their float arguments travel the
//  soft-float path, so the decompiler drops them).
//

#import "RBBonusData.h"

// Archive and user-defaults keys for each bonus multiplier. They match the property names.
static NSString *const kClearBonusCoderKey = @"kClearBonus";
static NSString *const kFullComboBonusCoderKey = @"kFullComboBonus";
static NSString *const kMiss1BonusCoderKey = @"kMiss1Bonus";
static NSString *const kMiss2BonusCoderKey = @"kMiss2Bonus";
static NSString *const kRankAAAPBonusCoderKey = @"kRankAAAPBonus";
static NSString *const kRankAAABonusCoderKey = @"kRankAAABonus";
static NSString *const kRankAABonusCoderKey = @"kRankAABonus";
static NSString *const kRankABonusCoderKey = @"kRankABonus";
static NSString *const kRankBBonusCoderKey = @"kRankBBonus";
static NSString *const kFirstPlayBonusCoderKey = @"kFirstPlayBonus";
static NSString *const kBlackPastelBonusCoderKey = @"kBlackPastelBonus";
static NSString *const kPastelBonusCoderKey = @"kPastelBonus";
static NSString *const kEarlyPlayBonusCoderKey = @"kEarlyPlayBonus";
static NSString *const kHotMusicBonusCoderKey = @"kHotMusicBonus";

// The default multipliers seeded into a fresh instance by @c init.
static const float kDefaultClearBonus = 1.0f;
static const float kDefaultFullComboBonus = 2.0f;
static const float kDefaultMiss1Bonus = 1.5f;
static const float kDefaultMiss2Bonus = 1.0f;
static const float kDefaultRankAAAPBonus = 3.0f;
static const float kDefaultRankAAABonus = 2.5f;
static const float kDefaultRankAABonus = 2.0f;
static const float kDefaultRankABonus = 1.0f;
static const float kDefaultRankBBonus = 0.5f;
static const float kDefaultFirstPlayBonus = 10.0f;
static const float kDefaultBlackPastelBonus = 20.0f;
static const float kDefaultPastelBonus = 10.0f;
static const float kDefaultEarlyPlayBonus = 5.0f;
static const float kDefaultHotMusicBonus = 10.0f;

@implementation RBBonusData

#pragma mark - Lifecycle

- (instancetype)init {
    /** @ghidraAddress 0x1f3704 */
    self = [super init];
    if (self) {
        self.clearBonus = kDefaultClearBonus;
        self.fullComboBonus = kDefaultFullComboBonus;
        self.miss1Bonus = kDefaultMiss1Bonus;
        self.miss2Bonus = kDefaultMiss2Bonus;
        self.rankAAAPBonus = kDefaultRankAAAPBonus;
        self.rankAAABonus = kDefaultRankAAABonus;
        self.rankAABonus = kDefaultRankAABonus;
        self.rankABonus = kDefaultRankABonus;
        self.rankBBonus = kDefaultRankBBonus;
        self.firstPlayBonus = kDefaultFirstPlayBonus;
        self.blackPastelBonus = kDefaultBlackPastelBonus;
        self.pastelBonus = kDefaultPastelBonus;
        self.earlyPlayBonus = kDefaultEarlyPlayBonus;
        self.hotMusicBonus = kDefaultHotMusicBonus;
    }
    return self;
}

#pragma mark - Singleton and persistence

// @ghidraAddress 0x3df580 (g_pRBBonusDataSharedInstance)
+ (instancetype)sharedInstance {
    /** @ghidraAddress 0x1f3df8 */
    static RBBonusData *instance = nil;
    if (instance == nil) {
        NSData *archived = [[NSUserDefaults standardUserDefaults]
            dataForKey:NSStringFromClass([self class])];
        RBBonusData *restored = [NSKeyedUnarchiver unarchiveObjectWithData:archived];
        if (restored == nil) {
            restored = [[RBBonusData alloc] init];
        }
        instance = restored;
    }
    return instance;
}

- (void)save {
    /** @ghidraAddress 0x1f3f30 */
    NSData *archived = [NSKeyedArchiver archivedDataWithRootObject:self];
    [[NSUserDefaults standardUserDefaults] setObject:archived
                                              forKey:NSStringFromClass([self class])];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

#pragma mark - NSCoding

- (instancetype)initWithCoder:(NSCoder *)coder {
    /** @ghidraAddress 0x1f38b4 */
    self = [super init];
    if (self) {
        self.clearBonus = [coder decodeFloatForKey:kClearBonusCoderKey];
        self.fullComboBonus = [coder decodeFloatForKey:kFullComboBonusCoderKey];
        self.miss1Bonus = [coder decodeFloatForKey:kMiss1BonusCoderKey];
        self.miss2Bonus = [coder decodeFloatForKey:kMiss2BonusCoderKey];
        self.rankAAAPBonus = [coder decodeFloatForKey:kRankAAAPBonusCoderKey];
        self.rankAAABonus = [coder decodeFloatForKey:kRankAAABonusCoderKey];
        self.rankAABonus = [coder decodeFloatForKey:kRankAABonusCoderKey];
        self.rankABonus = [coder decodeFloatForKey:kRankABonusCoderKey];
        self.rankBBonus = [coder decodeFloatForKey:kRankBBonusCoderKey];
        self.firstPlayBonus = [coder decodeFloatForKey:kFirstPlayBonusCoderKey];
        self.blackPastelBonus = [coder decodeFloatForKey:kBlackPastelBonusCoderKey];
        self.pastelBonus = [coder decodeFloatForKey:kPastelBonusCoderKey];
        self.earlyPlayBonus = [coder decodeFloatForKey:kEarlyPlayBonusCoderKey];
        self.hotMusicBonus = [coder decodeFloatForKey:kHotMusicBonusCoderKey];
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder *)coder {
    /** @ghidraAddress 0x1f3bb0 */
    [coder encodeFloat:self.clearBonus forKey:kClearBonusCoderKey];
    [coder encodeFloat:self.fullComboBonus forKey:kFullComboBonusCoderKey];
    [coder encodeFloat:self.miss1Bonus forKey:kMiss1BonusCoderKey];
    [coder encodeFloat:self.miss2Bonus forKey:kMiss2BonusCoderKey];
    [coder encodeFloat:self.rankAAAPBonus forKey:kRankAAAPBonusCoderKey];
    [coder encodeFloat:self.rankAAABonus forKey:kRankAAABonusCoderKey];
    [coder encodeFloat:self.rankAABonus forKey:kRankAABonusCoderKey];
    [coder encodeFloat:self.rankABonus forKey:kRankABonusCoderKey];
    [coder encodeFloat:self.rankBBonus forKey:kRankBBonusCoderKey];
    [coder encodeFloat:self.firstPlayBonus forKey:kFirstPlayBonusCoderKey];
    [coder encodeFloat:self.blackPastelBonus forKey:kBlackPastelBonusCoderKey];
    [coder encodeFloat:self.pastelBonus forKey:kPastelBonusCoderKey];
    [coder encodeFloat:self.earlyPlayBonus forKey:kEarlyPlayBonusCoderKey];
    [coder encodeFloat:self.hotMusicBonus forKey:kHotMusicBonusCoderKey];
}

@end
