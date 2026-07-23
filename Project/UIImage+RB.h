/** @file
 * @c UIImage convenience factories used across the game: named-asset loading (with an optional
 * texture cache) and rectangular cropping. Only the members the resource-download flow uses are
 * declared here.
 *
 * Speculative interface reconstructed from Ghidra project rb458, program rb458 (category
 * @c UIImage(RB), image base 0x100000000).
 */

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * @brief Asset-loading and cropping helpers layered on @c UIImage.
 */
@interface UIImage (RB)

/**
 * @brief Load the named game asset, using the texture cache.
 * @param name The asset name (without extension).
 * @return The loaded image, or @c nil when the asset is missing.
 */
+ (nullable UIImage *)imageWithName:(NSString *)name;
/**
 * @brief Load the named game asset, optionally using the texture cache.
 * @param name The asset name (without extension).
 * @param useCache Whether to consult and populate the texture cache.
 * @return The loaded image, or @c nil when the asset is missing.
 */
+ (nullable UIImage *)imageWithName:(NSString *)name useCache:(BOOL)useCache;

/**
 * @brief Crop this image to @p rect.
 * @param rect The crop rectangle, in points.
 * @return The cropped image.
 */
- (nullable UIImage *)clipImageWithRect:(CGRect)rect;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
