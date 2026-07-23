/** @file
 * The Applilink ad SDK's URL percent-encoding helper class. Minimal stub: only the surface the SDK
 * classes message is declared here; the full class is reconstructed separately.
 *
 * Reconstructed from Ghidra project rb458, program rb458 (class @c NSStringURLEncoding, image base
 * 0x100000000). @ghidraAddress values are offsets relative to the image base.
 */

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * @brief The Applilink SDK's URL percent-encoding helper.
 */
@interface NSStringURLEncoding : NSObject

/**
 * @brief Percent-encode a string for use in a URL query component.
 * @param string The string to encode.
 * @return The percent-encoded string, or @c nil.
 * @ghidraAddress 0x20c1f4
 */
+ (nullable NSString *)URLEncodedString:(nullable NSString *)string;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
