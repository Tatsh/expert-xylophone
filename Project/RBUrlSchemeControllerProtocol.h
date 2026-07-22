/** @file
 * The protocol a per-host deep-link handler class must adopt to be dispatched to by
 * @c RBUrlSchemeManager. Handler classes are named @c RBUrlScheme<Host>Controller and are resolved
 * by name at run time.
 *
 * Reconstructed from Ghidra project rb458, program rb458 (protocol RBUrlSchemeControllerProtocol,
 * image base 0x100000000). @ghidraAddress values are offsets relative to the image base.
 */

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * @brief Adopted by per-host handlers routed to by @c RBUrlSchemeManager.
 */
@protocol RBUrlSchemeControllerProtocol <NSObject>

/**
 * @brief Perform the deep-link action for a routed URL.
 * @param action The URL's last path component, naming the action to perform.
 * @param query The URL's query string parsed into a key-value dictionary, or @c nil.
 * @return @c YES when the action was handled; @c NO otherwise.
 */
- (BOOL)action:(NSString *)action query:(nullable NSDictionary *)query;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
