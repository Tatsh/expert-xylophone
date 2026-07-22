/** @file
 * Router for the game's custom-scheme and push-notification deep links. Given a URL, it derives a
 * per-host handler class named @c RBUrlScheme<Host>Controller, verifies it conforms to
 * @c RBUrlSchemeControllerProtocol, and dispatches the URL's last path component and parsed query
 * string to that handler.
 *
 * Reconstructed from Ghidra project rb458, program rb458 (class RBUrlSchemeManager, image base
 * 0x100000000). @ghidraAddress values are offsets relative to the image base.
 */

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * @brief Singleton router that dispatches deep-link URLs to per-host scheme handlers.
 */
@interface RBUrlSchemeManager : NSObject

/**
 * @brief The shared router instance, lazily created on first access.
 * @return The singleton @c RBUrlSchemeManager.
 * @ghidraAddress 0x168174
 */
+ (instancetype)sharedManager;

/**
 * @brief Route a deep-link URL to its per-host handler.
 *
 * The handler class name is built from the URL host with its first letter capitalised, in the form
 * @c RBUrlScheme<Host>Controller. If that class exists and conforms to
 * @c RBUrlSchemeControllerProtocol, it is instantiated and sent
 * @c -action:query: with the URL's last path component and the query string parsed into a
 * dictionary.
 * @param url The deep-link URL to route.
 * @return @c YES when a conforming handler was found and its action succeeded; @c NO otherwise.
 * @ghidraAddress 0x1681cc
 */
- (BOOL)parseURL:(NSURL *)url;

/**
 * @brief Parse a URL query string into a dictionary of its key-value pairs.
 *
 * Splits the query on @c & into pairs, then splits each pair on @c = into a key and value.
 * @param queryString The raw query string (without a leading @c ?), or @c nil.
 * @return A dictionary mapping each query key to its value, or @c nil when @c queryString is @c nil
 * or empty.
 * @ghidraAddress 0x168504
 */
- (nullable NSDictionary *)dictionaryFromQueryString:(nullable NSString *)queryString;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
