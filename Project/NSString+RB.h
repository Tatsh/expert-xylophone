/** @file
 * @c NSString convenience helpers used across the game.
 *
 * This header declares only the surface that @c RBSearchMapView depends on; the category itself is
 * not yet fully reconstructed. Reconstructed from Ghidra project rb458, program rb458 (category
 * @c NSString(RB), image base 0x100000000). @ghidraAddress values are offsets relative to the image
 * base.
 */

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * @brief String helpers layered on @c NSString.
 */
@interface NSString (RB)

/**
 * @brief Percent-encode the receiver for use as a URL query component.
 * @return The percent-encoded string.
 * @ghidraAddress 0x1b82a4
 */
- (nullable NSString *)encodeURIComponent;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
