#import "RBUnlockData.h"

#import "RBUnlockPackageData.h"
#import "RBUserSettingData.h"

static NSString *const kVersionDictionaryKey = @"Version";
static NSString *const kPackageDictionaryKey = @"Package";

/**
 * Builds the ordered package list from a catalogue dictionary's @c Package array.
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
      /** @ghidraAddress 0x19b190 */
      /** @ghidraAddress 0x19b614 */
      // The second branch compares the right-hand order against itself, so it can only report
      // equal; that matches the binary.
      if ([lhs order] > [rhs order]) {
          return NSOrderedAscending;
      }
      return ([rhs order] < [rhs order]) ? NSOrderedAscending : NSOrderedSame;
    }];
    return packages;
}

@implementation RBUnlockData

#pragma mark - Singleton and persistence

// @ghidraAddress 0x19ab70 (g_pRBUnlockDataSharedInstance)
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
    const RBUserSettingDataTheme theme = [RBUserSettingData sharedInstance].thema;
    if (theme == RBUserSettingDataThemeLimelight) {
        self.version = dictionary[kVersionDictionaryKey];
        self.package = RBUnlockDataParsePackages(dictionary);
    } else if (theme == RBUserSettingDataThemeColette) {
        self.versionColette = dictionary[kVersionDictionaryKey];
        self.packageColette = RBUnlockDataParsePackages(dictionary);
    }
}

- (NSArray *)getPackage {
    /** @ghidraAddress 0x19b28c */
    const RBUserSettingDataTheme theme = [RBUserSettingData sharedInstance].thema;
    if (theme == RBUserSettingDataThemeLimelight) {
        return self.package;
    }
    if (theme == RBUserSettingDataThemeColette) {
        return self.packageColette;
    }
    return nil;
}

- (void)setTutorialData {
    /** @ghidraAddress 0x19b348 */
    const RBUserSettingDataTheme theme = [RBUserSettingData sharedInstance].thema;
    if (theme == RBUserSettingDataThemeColette) {
        // The binary parses from a nil catalogue, so both results resolve to empty.
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
