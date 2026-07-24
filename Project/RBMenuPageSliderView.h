/** @file
 * The popup wrapper that hosts the music-menu page slider. It is an @c RBPopupView subclass that
 * allocates and embeds a single @c RBMenuPageSlider, exposes it through the @c slider property, and
 * forwards the popup's show/reset lifecycle to it. @c RBMenuView creates one lazily in
 * @c showPageSlider: and slides it in over the search bar.
 *
 * Reconstructed from Ghidra project rb458, program rb458 (class RBMenuPageSliderView, image base
 * 0x100000000). @ghidraAddress values are offsets relative to the image base.
 */

#import <UIKit/UIKit.h>

#import "RBMenuPageSlider.h"
#import "RBPopupView.h"

NS_ASSUME_NONNULL_BEGIN

/**
 * @brief A popup that wraps and presents an @c RBMenuPageSlider.
 */
@interface RBMenuPageSliderView : RBPopupView

/**
 * @brief Create the wrapper and its embedded slider.
 *
 * Initialises the popup base with @p frame, disables its show/hide animation flag, makes the base,
 * content, and self views resize flexibly, then allocates an @c RBMenuPageSlider over the same
 * frame, stores it in @c slider, and adds it as a subview.
 * @param frame The wrapper's frame, passed straight through to the embedded slider.
 * @param delegate The object the embedded slider reports page changes to, or @c nil.
 * @return The initialised wrapper, or @c nil.
 * @ghidraAddress 0x1c01bc
 */
- (nullable instancetype)initWithFrame:(CGRect)frame
                              delegate:(nullable id<RBMenuPageSliderDelegate>)delegate;

/**
 * @brief Reconfigure the embedded slider's page range and slide the popup in.
 *
 * Resets the slider to the given page range and current page, repositions it directly below the
 * supplied frame, then runs the popup's show animation.
 * @param frame The reference frame whose bottom edge the slider is aligned to.
 * @param pageMax The highest selectable page.
 * @param currentPage The page to start on.
 * @ghidraAddress 0x1c03b4
 */
- (void)showView:(CGRect)frame pageMax:(NSUInteger)pageMax currentPage:(NSUInteger)currentPage;

/**
 * @brief Prepare the embedded slider for a device rotation.
 *
 * Hides the slider by dropping it to full transparency and marks the view as animating; the
 * complementary @c didRotate fades it back in once the rotation completes.
 * @ghidraAddress 0x1c0578
 */
- (void)willRotate;

/**
 * @brief Fade the embedded slider back to full opacity after a device rotation.
 * @ghidraAddress 0x1c05e8
 */
- (void)didRotate;

/**
 * @brief Reconfigure the embedded slider's page range and current page.
 * @param pageMax The highest selectable page.
 * @param currentPage The page to move the grip to.
 * @ghidraAddress 0x1c0750
 */
- (void)reset:(NSUInteger)pageMax currentPage:(NSUInteger)currentPage;

/**
 * @brief The embedded page slider.
 * @ghidraAddress 0x1c0a38
 */
@property(strong, nonatomic, nullable) RBMenuPageSlider *slider;

/**
 * @brief The floating index-label text shown while paging.
 */
@property(strong, nonatomic, nullable) NSString *indexLabel;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
