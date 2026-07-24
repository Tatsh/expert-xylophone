/** @file
 * Deep-link handler for the @c store host of the game's custom URL scheme. It is one of the
 * per-host handler classes resolved by name and dispatched to by @c RBUrlSchemeManager, and it
 * adopts @c RBUrlSchemeControllerProtocol. Its @c -action:query: turns the routed action into a
 * @c <action>RbAction: selector and forwards the query to that handler; the per-action handlers
 * read the query's @c id parameter and store it on the application delegate as the pack, campaign,
 * or extended-note identifier used to open the store.
 *
 * Reconstructed from Ghidra project rb458, program rb458 (class RBUrlSchemeStoreController, image
 * base 0x100000000). @ghidraAddress values are offsets relative to the image base.
 */

#import <Foundation/Foundation.h>

#import "RBUrlSchemeControllerProtocol.h"

NS_ASSUME_NONNULL_BEGIN

/**
 * @brief Handles @c store deep links routed by @c RBUrlSchemeManager.
 */
@interface RBUrlSchemeStoreController : NSObject <RBUrlSchemeControllerProtocol>

/**
 * @brief Dispatch a routed action to its matching @c <action>RbAction: handler method.
 *
 * The action name is turned into a selector of the form @c <action>RbAction: (for example
 * @c packRbAction: for the @c pack action). When the receiver responds to that selector, it is
 * invoked with the parsed query dictionary as its only argument and its @c BOOL result is returned.
 * @param action The routed action name (the URL's last path component).
 * @param query The URL's query string parsed into a key-value dictionary, or @c nil.
 * @return The handler method's result, or @c NO when the receiver has no matching handler.
 * @ghidraAddress 0x5550
 */
- (BOOL)action:(NSString *)action query:(nullable NSDictionary *)query;

/**
 * @brief Store the pack identifier from a @c pack deep link on the app delegate.
 *
 * Reads the @c id entry of the query dictionary; when it is present and its integer value is at
 * least one, it is set as the app delegate's pack identifier for opening the store.
 * @param query The parsed query dictionary; its @c id entry supplies the pack identifier.
 * @return @c YES when the @c id parameter was valid; @c NO otherwise.
 * @ghidraAddress 0x5668
 */
- (BOOL)packRbAction:(nullable NSDictionary *)query;

/**
 * @brief Store the campaign identifier from a @c campaign deep link on the app delegate.
 *
 * Reads the @c id entry of the query dictionary; when it is present and its integer value is at
 * least one, it is set as the app delegate's campaign identifier for opening the store.
 * @param query The parsed query dictionary; its @c id entry supplies the campaign identifier.
 * @return @c YES when the @c id parameter was valid; @c NO otherwise.
 * @ghidraAddress 0x5744
 */
- (BOOL)campaignRbAction:(nullable NSDictionary *)query;

/**
 * @brief Store the extended-note pack identifier from a @c seq deep link on the app delegate.
 *
 * Reads the @c id entry of the query dictionary; when it is present and its integer value is at
 * least one, it is set as the app delegate's extended-note pack identifier for opening the store.
 * @param query The parsed query dictionary; its @c id entry supplies the extended-note pack
 * identifier.
 * @return @c YES when the @c id parameter was valid; @c NO otherwise.
 * @ghidraAddress 0x5820
 */
- (BOOL)seqRbAction:(nullable NSDictionary *)query;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
