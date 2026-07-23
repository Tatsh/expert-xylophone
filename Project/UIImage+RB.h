/** @file
 * @c UIImage convenience factories and image-processing helpers used across the game: themed and
 * localised named-asset loading (with an @c NSCache texture cache), rectangular cropping, a bottom
 * reflection (an alpha-gradient mask), and a per-channel @c CIColorMatrix tint.
 *
 * Reconstructed from Ghidra project rb458, program rb458 (category @c UIImage(RB), image base
 * 0x100000000). @ghidraAddress values are offsets relative to the image base.
 *
 * The asset-loading and cache methods are recorded in the binary's class-method list and every
 * caller dispatches them to the @c UIImage class object, so they are reconstructed as class
 * methods; the cropping and image-processing methods are instance methods dispatched to a
 * @c UIImage instance.
 */

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * @brief Asset-loading, cropping, and image-processing helpers layered on @c UIImage.
 */
@interface UIImage (RB)

/**
 * @brief Load the named game asset, consulting and populating the texture cache.
 *
 * Equivalent to @c imageWithName:useCache: with @p useCache set to @c YES.
 * @param name The asset name (without extension).
 * @return The loaded image, or @c nil when the asset is missing.
 * @ghidraAddress 0x1a2830
 */
+ (nullable UIImage *)imageWithName:(NSString *)name;

/**
 * @brief Load the named game asset, optionally consulting and populating the texture cache.
 *
 * The asset is resolved in order: the current theme directory, the shared @c "00_Share" directory,
 * the primary and fallback @c lproj bundle images, and finally @c imageNamedWithoutCache:.
 * @param name The asset name (without extension).
 * @param useCache Whether to store a freshly loaded image in the texture cache.
 * @return The loaded image, or @c nil when the asset is missing.
 * @ghidraAddress 0x1a2858
 */
+ (nullable UIImage *)imageWithName:(NSString *)name useCache:(BOOL)useCache;

/**
 * @brief Load a PNG asset from an image directory under the current theme, retrying under the
 * device's Retina setting.
 *
 * Tries the Retina variant first when the device is Retina, then the non-Retina variant.
 * @param name The asset name (without extension).
 * @param imageDirectory The base image directory.
 * @param themaDirectory The theme sub-directory.
 * @return The loaded image, or @c nil when the asset is missing.
 * @ghidraAddress 0x1a1a0c
 */
+ (nullable UIImage *)imageWithName:(NSString *)name
                     imageDirectory:(NSString *)imageDirectory
                     themaDirectory:(NSString *)themaDirectory;

/**
 * @brief Load a PNG asset from an image directory under the current theme, with a localised
 * @c lproj fallback.
 *
 * Builds @c imageDirectory/themaDirectory/name.png (appending @c "@2x" to @p name when @p retina is
 * set), then on a miss retries with the primary and fallback @c lproj folder inserted before the
 * file name.
 * @param name The asset name (without extension).
 * @param imageDirectory The base image directory.
 * @param themaDirectory The theme sub-directory.
 * @param retina Whether to load the Retina (@c "@2x") variant.
 * @return The loaded image, or @c nil when the asset is missing.
 * @ghidraAddress 0x1a1644
 */
+ (nullable UIImage *)imageWithName:(NSString *)name
                     imageDirectory:(NSString *)imageDirectory
                     themaDirectory:(NSString *)themaDirectory
                             retina:(BOOL)retina;

/**
 * @brief Load a localised PNG resource from the main bundle without the texture cache.
 *
 * Resolves the resource through a language (@c ja / @c en) and region (@c JP) fallback chain, first
 * for the font-variant Retina-tagged name and then for the plain name.
 * @param name The base resource name (without extension).
 * @return The loaded image, or @c nil when the resource is missing.
 * @ghidraAddress 0x1a1b08
 */
+ (nullable UIImage *)imageNamedWithoutCache:(NSString *)name;

/**
 * @brief Empty the shared themed-image cache.
 *
 * Called on a theme change or a memory warning.
 * @ghidraAddress 0x1a1630
 */
+ (void)clearImageCache;

/**
 * @brief Crop the receiver to a sub-rectangle, honouring its Retina scale.
 * @param rect The crop rectangle, in points; multiplied by the receiver's scale when it is 2.0 or
 * 3.0.
 * @return The cropped image, preserving the receiver's scale and orientation.
 * @ghidraAddress 0x1a2fa4
 */
- (nullable UIImage *)clipImageWithRect:(CGRect)rect;

/**
 * @brief Build a bottom reflection of the receiver, faded by a top-to-bottom alpha gradient.
 * @param height The reflection height, in points; multiplied by the receiver's scale on Retina.
 * @return The reflected, gradient-masked image, or @c nil when @p height is zero or the receiver is
 * unavailable.
 * @ghidraAddress 0x1a2c0c
 */
- (nullable UIImage *)reflectedImageWithHeight:(CGFloat)height;

/**
 * @brief Tint the receiver by a @c CIColorMatrix built from a colour's components.
 * @param color The tint colour; its red, green, blue, and alpha components scale the matching
 * channels (falling back to a grey scale when the colour is not RGBA).
 * @return The tinted image.
 * @ghidraAddress 0x1a31a0
 */
- (nullable UIImage *)colorMatrixFilterWithColor:(UIColor *)color;

/**
 * @brief Tint the receiver by a per-channel @c CIColorMatrix multiply.
 * @param red The red-channel multiplier.
 * @param green The green-channel multiplier.
 * @param blue The blue-channel multiplier.
 * @param alpha The alpha-channel multiplier.
 * @return The tinted image, preserving the receiver's scale.
 * @ghidraAddress 0x1a3268
 */
- (nullable UIImage *)colorMatrixFilterWithRed:(CGFloat)red
                                         green:(CGFloat)green
                                          blue:(CGFloat)blue
                                         alpha:(CGFloat)alpha;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
