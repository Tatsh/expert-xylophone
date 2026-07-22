/** @file
 * A singleton data model describing the unlock catalogue: the catalogue version string and the
 * ordered list of unlock packages, held separately for the default theme and the Colette theme.
 * The model parses its contents from a server-supplied dictionary keyed by @c Version and
 * @c Package, building an array of @c RBUnlockPackageData entries sorted by their display order,
 * and vends the package list appropriate to the player's currently selected theme.
 *
 * Reconstructed from Ghidra project rb458, program rb458 (class RBUnlockData, image base
 * 0x100000000). @ghidraAddress values are offsets relative to the image base.
 */

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * @brief The singleton catalogue of unlockable content, parsed from the server response and
 * partitioned by theme.
 */
@interface RBUnlockData : NSObject

/**
 * @brief The catalogue version for the default theme.
 * @ghidraAddress 0x19b710 (getter)
 * @ghidraAddress 0x19b720 (setter)
 */
@property(nonatomic, copy, nullable) NSString *version;
/**
 * @brief The ordered unlock packages for the default theme, each an @c RBUnlockPackageData.
 * @ghidraAddress 0x19b72c (getter)
 * @ghidraAddress 0x19b73c (setter)
 */
@property(nonatomic, strong) NSArray *package;
/**
 * @brief The catalogue version for the Colette theme.
 * @ghidraAddress 0x19b774 (getter)
 * @ghidraAddress 0x19b784 (setter)
 */
@property(nonatomic, copy, nullable) NSString *versionColette;
/**
 * @brief The ordered unlock packages for the Colette theme, each an @c RBUnlockPackageData.
 * @ghidraAddress 0x19b790 (getter)
 * @ghidraAddress 0x19b7a0 (setter)
 */
@property(nonatomic, strong) NSArray *packageColette;

/**
 * @brief Returns the shared unlock-data singleton, allocating and initialising it on first use.
 * @return The shared @c RBUnlockData instance.
 * @ghidraAddress 0x19ab70
 */
+ (instancetype)sharedInstance;

/**
 * @brief Persists the receiver. The shipped build performs no work here.
 * @ghidraAddress 0x19abd4
 */
- (void)save;

/**
 * @brief Parses the unlock catalogue from a server-supplied dictionary into the theme matching the
 * player's current selection, replacing that theme's version string and package list.
 * @param dictionary The catalogue dictionary, keyed by @c Version and @c Package.
 * @ghidraAddress 0x19abd8
 */
- (void)parseDictionary:(NSDictionary *)dictionary;

/**
 * @brief Returns the package list for the player's currently selected theme.
 * @return The default-theme or Colette-theme package list, or @c nil for an unrecognised theme.
 * @ghidraAddress 0x19b28c
 */
- (nullable NSArray *)getPackage;

/**
 * @brief Seeds the Colette-theme catalogue with its built-in tutorial packages.
 * @ghidraAddress 0x19b348
 */
- (void)setTutorialData;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
