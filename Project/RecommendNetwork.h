/** @file
 * The Applilink recommend-network advert-area facade. Only the class methods @c RBApplilinkView
 * calls are declared here.
 *
 * Speculative interface reconstructed from Ghidra project rb458, program rb458 (class
 * @c RecommendNetwork, image base 0x100000000). @ghidraAddress values are offsets relative to the
 * image base.
 */

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * @brief The companion-application recommend-advert facade over the Applilink SDK.
 *
 * The advert area reports back through an informal delegate: the delegate implements
 * @c appListDidAppear, @c appListDidDisappear, and @c appListFailLoadWithError: as it needs them.
 */
@interface RecommendNetwork : NSObject

/**
 * @brief Open the recommend-advert area inside @p parentView, filling @p rect, reporting to
 * @p delegate.
 * @param parentView The view that hosts the advert area.
 * @param rect The advert area's frame within @p parentView.
 * @param adModel The advert-model identifier.
 * @param adLocation The ad-location identifier, such as @c "ADL_TOP".
 * @param verticalAlign The vertical-alignment identifier.
 * @param delegate The advert-area delegate.
 * @ghidraAddress 0x212bb0
 */
+ (void)openAdAreaWithParentView:(nullable UIView *)parentView
                            rect:(CGRect)rect
                         adModel:(int)adModel
                      adLocation:(nullable NSString *)adLocation
                   verticalAlign:(int)verticalAlign
                        delegate:(nullable id)delegate;

/**
 * @brief Close the recommend-advert area hosted by @p parentView.
 * @param parentView The view that hosts the advert area.
 * @ghidraAddress 0x21316c
 */
+ (void)closeAdAreaWithParentView:(nullable UIView *)parentView;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
