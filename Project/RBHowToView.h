/** @file
 * The how-to-play help popup view. It is an @c RBMusicMenuPopupView configured with the default
 * popup type, presenting the paged how-to-play instruction artwork in a horizontally paging scroll
 * view with a page control.
 *
 * Reconstructed from Ghidra project rb458, program rb458 (class RBHowToView, image base
 * 0x100000000). @ghidraAddress values are offsets relative to the image base.
 */

#import <UIKit/UIKit.h>

#import "RBMusicMenuPopupView.h"

@class RBSettingView;

NS_ASSUME_NONNULL_BEGIN

/**
 * @brief Popup view that shows the paged how-to-play instructions over the settings screen.
 *
 * The instruction pages are laid out side by side inside a paging @c UIScrollView, with a
 * @c UIPageControl mirroring and driving the current page. The page count and page geometry depend
 * on the current theme, the iPad idiom, and whether the device is Retina.
 */
@interface RBHowToView : RBMusicMenuPopupView <UIScrollViewDelegate>

/**
 * @brief Create the how-to-play popup with the given frame.
 *
 * Calls through to @c super, then selects the default popup type and builds the view.
 * @param frame The view's frame rectangle.
 * @return The initialised view, or @c nil.
 * @ghidraAddress 0x99eb0
 */
- (nullable instancetype)initWithFrame:(CGRect)frame;

/**
 * @brief Build the how-to-play content: the paging scroll view, the page control, and the
 * instruction pages.
 *
 * Calls through to @c super, then reads the theme and idiom/Retina flags to size the scroll
 * view and page control, populates one image page per instruction, and lays out the scroll view's
 * content size.
 * @ghidraAddress 0x9a200
 */
- (void)setupView;

/**
 * @brief Add the instruction-page image at @p index into the scroll view.
 *
 * Loads @c 03_howtoplay/how_<index+1>, wraps it in a @c UIImageView, and positions it at page
 * @p index (one scroll-view width per page). Does nothing for an @p index beyond the last page.
 * @param index The zero-based page index.
 * @ghidraAddress 0x9a9d4
 */
- (void)createViewSame:(int)index;

/**
 * @brief Recompute the scroll view's content size from the current page count.
 * @ghidraAddress 0x9aba8
 */
- (void)layoutScrollView;

/**
 * @brief Scroll to the page selected by the page control.
 *
 * Only scrolls when the scroll view is not being tracked, dragged, or decelerating, so a manual
 * swipe is not overridden.
 * @param sender The page control that changed value.
 * @ghidraAddress 0x9ac6c
 */
- (void)pageDidChangeValue:(nullable id)sender;

/**
 * @brief The paging scroll view holding the instruction pages.
 */
@property(strong, nonatomic, nullable) UIScrollView *scrollView;

/**
 * @brief The page control mirroring and driving the current instruction page.
 */
@property(strong, nonatomic, nullable) UIPageControl *pageControl;

/**
 * @brief The settings view that owns and presents this how-to-play popup.
 */
@property(weak, nonatomic, nullable) RBSettingView *settingView;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
