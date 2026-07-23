//
//  RBUnlockData.m
//  REFLEC BEAT plus
//
//  Reconstructed from Ghidra project rb458, program rb458 (class RBUnlockData). Verified against
//  the arm64 disassembly.
//

#import "RBUnlockData.h"

#import "RBUnlockPackageData.h"
#import "RBUserSettingData.h"

// The dictionary key under which the catalogue version string is supplied.
static NSString *const kVersionDictionaryKey = @"Version";
// The dictionary key under which the catalogue package array is supplied.
static NSString *const kPackageDictionaryKey = @"Package";

// The player theme identifiers returned by @c -[RBUserSettingData thema].
typedef enum {
    // The default theme.
    RBUnlockDataThemeDefault = 1,
    // The Colette theme.
    RBUnlockDataThemeColette = 2,
} RBUnlockDataTheme;

/**
 * @brief Builds the ordered package list from a catalogue dictionary's @c Package array.
 *
 * Each raw package entry is wrapped in a freshly parsed @c RBUnlockPackageData, and the results are
 * sorted in descending order of their display order.
 *
 * @param dictionary The catalogue dictionary to read the package array from.
 * @return The sorted, mutable package list.
 */
static NSArray *RBUnlockDataParsePackages(NSDictionary *dictionary) {
    NSMutableArray *packages = [NSMutableArray array];
    for (id rawPackage in dictionary[kPackageDictionaryKey]) {
        RBUnlockPackageData *entry = [[RBUnlockPackageData alloc] init];
        [entry parseDictionary:rawPackage];
        [packages addObject:entry];
    }
    [packages sortUsingComparator:^NSComparisonResult(id lhs, id rhs) {
      /** @ghidraAddress 0x19b094 */
      // The shipped comparator orders a higher package order first. Its second branch compares
      // the right-hand order against itself, so it can only ever report the two packages as
      // equal; this reproduces that behaviour faithfully.
      if ([lhs order] > [rhs order]) {
          return NSOrderedAscending;
      }
      return ([rhs order] < [rhs order]) ? NSOrderedAscending : NSOrderedSame;
    }];
    return packages;
}

@implementation RBUnlockData

#pragma mark - Singleton and persistence

// @ghidraAddress 0x3df348 (g_pRBUnlockDataSharedInstance)
+ (instancetype)sharedInstance {
    /** @ghidraAddress 0x19ab70 */
    static RBUnlockData *instance = nil;
    if (instance == nil) {
        instance = [[RBUnlockData alloc] init];
    }
    return instance;
}

- (void)save {
    /** @ghidraAddress 0x19abd4 */
}

#pragma mark - Parsing

- (void)parseDictionary:(NSDictionary *)dictionary {
    /** @ghidraAddress 0x19abd8 */
    RBUnlockDataTheme theme = [[RBUserSettingData sharedInstance] thema];
    if (theme == RBUnlockDataThemeDefault) {
        self.version = dictionary[kVersionDictionaryKey];
        self.package = RBUnlockDataParsePackages(dictionary);
    } else if (theme == RBUnlockDataThemeColette) {
        self.versionColette = dictionary[kVersionDictionaryKey];
        self.packageColette = RBUnlockDataParsePackages(dictionary);
    }
}

- (NSArray *)getPackage {
    /** @ghidraAddress 0x19b28c */
    RBUnlockDataTheme theme = [[RBUserSettingData sharedInstance] thema];
    if (theme == RBUnlockDataThemeDefault) {
        return self.package;
    }
    if (theme == RBUnlockDataThemeColette) {
        return self.packageColette;
    }
    return nil;
}

- (void)setTutorialData {
    /** @ghidraAddress 0x19b348 */
    RBUnlockDataTheme theme = [[RBUserSettingData sharedInstance] thema];
    if (theme == RBUnlockDataThemeColette) {
        // The shipped tutorial path parses from a nil catalogue, so both the version string and the
        // package list resolve to empty. This is reproduced faithfully.
        NSDictionary *tutorialDictionary = nil;
        self.versionColette = tutorialDictionary[kVersionDictionaryKey];
        self.packageColette = RBUnlockDataParsePackages(tutorialDictionary);
    }
}

#pragma mark - Description

- (NSString *)description {
    /** @ghidraAddress 0x19aa64 */
    return [NSString stringWithFormat:@"<%@: %p version:%@ package:%@>",
                                      NSStringFromClass([self class]),
                                      self,
                                      self.version,
                                      self.package];
}

@end
