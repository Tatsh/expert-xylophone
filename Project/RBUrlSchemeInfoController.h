/** @file
 * Deep-link handler for the @c info host of the game's custom URL scheme. It is one of the per-host
 * handler classes resolved by name and dispatched to by @c RBUrlSchemeManager, and it adopts
 * @c RBUrlSchemeControllerProtocol. Its @c -action:query: turns the routed action into a
 * @c <action>RbAction: selector and forwards the query to that handler; @c -webRbAction: builds the
 * news web-info URL from the query's @c id parameter and hands it to the application delegate.
 *
 * Reconstructed from Ghidra project rb458, program rb458 (class RBUrlSchemeInfoController, image
 * base 0x100000000). @ghidraAddress values are offsets relative to the image base.
 */

#import <Foundation/Foundation.h>

#import "RBUrlSchemeControllerProtocol.h"

NS_ASSUME_NONNULL_BEGIN

/**
 * @brief Handles @c info deep links routed by @c RBUrlSchemeManager.
 */
@interface RBUrlSchemeInfoController : NSObject <RBUrlSchemeControllerProtocol>

/**
 * @brief Dispatch a routed action to its matching @c <action>RbAction: handler method.
 *
 * The action name is turned into a selector of the form @c <action>RbAction: (for example
 * @c webRbAction: for the @c web action). When the receiver responds to that selector, it is
 * invoked with the parsed query dictionary as its only argument and its @c BOOL result is returned.
 * @param action The routed action name (the URL's last path component).
 * @param query The URL's query string parsed into a key-value dictionary, or @c nil.
 * @return The handler method's result, or @c NO when the receiver has no matching handler.
 * @ghidraAddress 0x176604
 */
- (BOOL)action:(NSString *)action query:(nullable NSDictionary *)query;

/**
 * @brief Build the news web-info URL for a @c web deep link and store it on the app delegate.
 *
 * Reads the @c id entry of the query dictionary; when it is present and its integer value is at
 * least one, the base web-info URL is copied and, unless it already contains a query string, the
 * @c ?webId=<id>&target=<region> parameters are appended before the result is set as the app
 * delegate's web-info URL.
 * @param query The parsed query dictionary; its @c id entry supplies the web identifier.
 * @return @c YES when the @c id parameter was valid; @c NO otherwise.
 * @ghidraAddress 0x17671c
 */
- (BOOL)webRbAction:(nullable NSDictionary *)query;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
