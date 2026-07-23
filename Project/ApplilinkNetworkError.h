/** @file
 * Minimal reconstructed interface for the Applilink recommend SDK's @c ApplilinkNetworkError
 * factory.
 *
 * The Applilink SDK ships as a closed third-party library, so only the class method that
 * @c RecommendNetwork messages is declared here. Reconstructed from Ghidra project rb458, program
 * rb458.
 */

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * @brief Localised-error factory for the Applilink SDK.
 */
@interface ApplilinkNetworkError : NSObject

/**
 * @brief Build a localised @c NSError for an Applilink error code.
 * @param code The Applilink error code.
 * @return The localised error.
 */
+ (NSError *)localizedApplilinkErrorWithCode:(NSInteger)code;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
