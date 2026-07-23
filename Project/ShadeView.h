/** @file
 * Reconstructed interface for the Applilink recommend advert SDK's @c ShadeView.
 *
 * @c ShadeView is the translucent full-screen @c UIView subclass that dims the screen behind an
 * interstitial advert (see @c RecommendFullScreenController). It paints a semi-transparent dark
 * backdrop, and a tap that ends inside it asks its @c delegate to dismiss the advert through
 * @c ShadeViewDelegate. The Applilink SDK ships as a closed third-party library. Reconstructed from
 * Ghidra project rb458, program rb458.
 */

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * @brief The delegate that a @c ShadeView notifies when the backdrop is tapped.
 */
@protocol ShadeViewDelegate <NSObject>

@optional

/**
 * @brief Called when a touch ends inside the shade so the delegate can dismiss the advert.
 */
- (void)closeShadeView;

@end

/**
 * @brief The translucent full-screen backdrop shown behind an interstitial advert.
 */
@interface ShadeView : UIView

/**
 * @brief The delegate notified when the shade is tapped.
 */
@property(nonatomic, weak, nullable) id<ShadeViewDelegate> delegate;

/**
 * @brief Initialise the shade, enabling user interaction and painting the translucent backdrop.
 * @param frame The shade frame.
 * @ghidraAddress 0x22b498
 */
- (instancetype)initWithFrame:(CGRect)frame;

/**
 * @brief Ask the delegate to close the shade when a touch ends inside it.
 * @param touches The touches that ended.
 * @param event The event the touches belong to.
 * @ghidraAddress 0x22b55c
 */
- (void)touchesEnded:(NSSet *)touches withEvent:(nullable UIEvent *)event;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
