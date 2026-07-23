/** @file
 * Reconstructed interface for the Applilink advert SDK's @c ApplilinkMessage helper.
 *
 * @c ApplilinkMessage is the SDK's stateless localised-message helper: it resolves a message key
 * into the corresponding localised string from the reward bundle's @c "Message" table, supplying a
 * built-in English fallback for the two known keys. The class has no instance state; its single
 * member is a class method. Reconstructed from Ghidra project rb458, program rb458.
 */

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * @brief Applilink SDK localised user-facing message helper.
 */
@interface ApplilinkMessage : NSObject

/**
 * @brief Resolve a message key into its localised string.
 *
 * The value is looked up under @p localizedMessage in the reward bundle's @c "Message" strings
 * table. A built-in English default is supplied for each of the two recognised keys:
 * @c "RewardNetworkAppListTitle" falls back to @c "App List" and
 * @c "RewardNetworkAppListCloseButton" falls back to @c "Close"; any other key falls back to the
 * empty string.
 * @param localizedMessage The message key to look up.
 * @return The localised message string.
 * @ghidraAddress 0x21fe28
 */
+ (nullable NSString *)localizedMessage:(nullable NSString *)localizedMessage;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
