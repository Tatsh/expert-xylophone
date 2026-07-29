/** @file
 * Reconstructed interface for the Applilink SDK's @c ApplilinkViewDelegate protocol.
 *
 * The advert-list lifecycle delegate: the advert area and web views notify it as the list starts,
 * appears, disappears, or fails to load or link. Every callback is optional and every sender
 * guards with @c respondsToSelector:. Reconstructed from Ghidra project rb458, program rb458.
 */

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * @brief The advert-list lifecycle delegate of the Applilink advert views.
 */
@protocol ApplilinkViewDelegate <NSObject>

@optional

/**
 * @brief Notify the delegate that the advert list started.
 */
- (void)appListDidStart;

/**
 * @brief Notify the delegate that the advert list appeared.
 */
- (void)appListDidAppear;

/**
 * @brief Notify the delegate that the advert list disappeared.
 */
- (void)appListDidDisappear;

/**
 * @brief Report an advert-list load failure to the delegate.
 * @param error The load error.
 */
- (void)appListFailLoadWithError:(NSError *)error;

/**
 * @brief Report an advert-list link failure to the delegate.
 * @param error The link error.
 */
- (void)appListFailLinkWithError:(NSError *)error;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
