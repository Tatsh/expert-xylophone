/** @file
 * Reconstructed interface for the Applilink advert SDK's @c ApplilinkBundle resource loader.
 *
 * @c ApplilinkBundle locates and caches the SDK's @c ApplilinkNetworkResources.bundle, the
 * localised resource bundle that ships the SDK's strings and images. It has no instance state (no
 * ivars or properties) and exposes a single accessor that lazily loads the bundle once, preferring
 * the device-language @c .lproj sub-bundle when @c ApplilinkCore prioritises the device languages.
 * Reconstructed from Ghidra project rb458, program rb458.
 */

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * @brief Loader for the Applilink SDK's @c ApplilinkNetworkResources localisation bundle.
 */
@interface ApplilinkBundle : NSObject

/**
 * @brief The cached @c ApplilinkNetworkResources bundle, lazily loaded on first access.
 *
 * The bundle is loaded exactly once. When @c ApplilinkCore prioritises the device languages, the
 * first preferred-language @c .lproj sub-bundle inside @c ApplilinkNetworkResources.bundle is used;
 * otherwise the top-level bundle is used. When the resource cannot be found the load logs a warning
 * and the result is @c nil.
 * @return The resource bundle, or @c nil when it could not be located.
 * @ghidraAddress 0x20d41c
 */
+ (nullable NSBundle *)rewardBundle;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
