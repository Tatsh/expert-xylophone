/** @file
 * @c NSData property-list deserialisation helpers. Decode an XML property-list payload held in an
 * @c NSData into an @c NSDictionary or a mutable @c NSArray, selecting the Core Foundation parser
 * that matches the running iOS version.
 *
 * Reconstructed from Ghidra project rb458, program rb458 (category @c NSData(RB), image base
 * 0x100000000). @ghidraAddress values are offsets relative to the image base.
 *
 * The category's methods are recorded in the binary's instance-method list and every caller
 * dispatches them to an @c NSData instance, so they are reconstructed as instance methods.
 */

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * @brief Property-list deserialisation helpers layered on @c NSData.
 */
@interface NSData (RB)

/**
 * @brief Deserialise the receiver's XML property-list bytes into a dictionary.
 * @return A defensive copy of the parsed dictionary, or @c nil when the payload does not decode to
 * an @c NSDictionary.
 * @ghidraAddress 0x1a4470
 */
- (nullable NSDictionary *)dictionary;

/**
 * @brief Deserialise the receiver's XML property-list bytes into a mutable array.
 * @return A mutable copy of the parsed array, or @c nil when the payload does not decode to an
 * @c NSArray.
 * @ghidraAddress 0x1a45f8
 */
- (nullable NSMutableArray *)mutableArray;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
