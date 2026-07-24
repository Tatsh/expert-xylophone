/** @file
 * @c NSArray property-list deserialisation helper. Decode an XML property-list payload held in an
 * @c NSData into an immutable @c NSArray, selecting the Core Foundation parser that matches the
 * running iOS version.
 *
 * Reconstructed from Ghidra project rb458, program rb458 (category @c NSArray(RB), image base
 * 0x100000000). @ghidraAddress values are offsets relative to the image base. This is a partial
 * category holding only the single method the binary's category method list carries.
 *
 * The method is dispatched to the @c NSArray class object by its sole caller
 * (@c -[RBExperienceData decodePoint:]), so it is reconstructed as a class method.
 */

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * @brief Property-list deserialisation helper layered on @c NSArray.
 */
@interface NSArray (RB)

/**
 * @brief Deserialise XML property-list bytes into an immutable array.
 * @param data The serialised property-list payload.
 * @return A copy of the parsed array, or @c nil when the payload does not decode to an @c NSArray.
 * @ghidraAddress 0x12f410
 */
+ (nullable NSArray *)arrayFromPropertyListData:(nullable NSData *)data;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
