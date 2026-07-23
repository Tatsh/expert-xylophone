/** @file
 * Reconstructed interface for the Applilink recommend SDK's @c ApplilinkNetworkError factory.
 *
 * @c ApplilinkNetworkError is the SDK's @c NSError factory: it owns the Applilink error domain and
 * a cached table that maps each Applilink error code to a localised message, then builds an
 * @c NSError carrying that message in its @c userInfo. The Applilink SDK ships as a closed
 * third-party library, so only the class methods that the reconstructed callers message are
 * declared here. Reconstructed from Ghidra project rb458, program rb458.
 */

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * @brief The error domain of every @c NSError produced by @c ApplilinkNetworkError.
 * @ghidraAddress 0x344791
 */
extern NSErrorDomain const ApplilinkErrorDomain;

/**
 * @brief Localised-error factory for the Applilink SDK.
 */
@interface ApplilinkNetworkError : NSObject

/**
 * @brief Build a localised @c NSError for an Applilink error code.
 *
 * Equivalent to calling @c localizedApplilinkErrorWithCode:userInfo: with a @c nil user-info
 * dictionary.
 *
 * @param code The Applilink error code.
 * @return The localised error in the @c ApplilinkErrorDomain domain.
 * @ghidraAddress 0x211f04
 */
+ (NSError *)localizedApplilinkErrorWithCode:(NSInteger)code;

/**
 * @brief Build a localised @c NSError for an Applilink error code, merging caller-supplied
 * user-info entries.
 *
 * The returned error's @c userInfo is @c userInfo with the localised description for @c code added
 * under @c NSLocalizedDescriptionKey. Unknown codes fall back to the message for the unexpected-error
 * code.
 *
 * @param code The Applilink error code.
 * @param userInfo Additional user-info entries to merge, or @c nil.
 * @return The localised error in the @c ApplilinkErrorDomain domain.
 * @ghidraAddress 0x20fb18
 */
+ (NSError *)localizedApplilinkErrorWithCode:(NSInteger)code
                                    userInfo:(nullable NSDictionary *)userInfo;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
