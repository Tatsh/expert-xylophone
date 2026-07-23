/** @file
 * The staff-credits popup view. It is an @c RBMusicMenuPopupView configured with the credits popup
 * type, presenting the scrolling credits artwork centred in the popup's content view.
 *
 * Reconstructed from Ghidra project rb458, program rb458 (class RBCreditsView, image base
 * 0x100000000). @ghidraAddress values are offsets relative to the image base.
 */

#import <UIKit/UIKit.h>

#import "RBMusicMenuPopupView.h"

@class RBSettingView;

NS_ASSUME_NONNULL_BEGIN

/**
 * @brief Popup view that shows the staff credits roll over the settings screen.
 */
@interface RBCreditsView : RBMusicMenuPopupView

/**
 * @brief Create the credits popup with the given frame.
 *
 * Calls through to @c super, then selects the credits popup type and builds the view.
 * @param frame The view's frame rectangle.
 * @return The initialised view, or @c nil.
 * @ghidraAddress 0x96328
 */
- (nullable instancetype)initWithFrame:(CGRect)frame;

/**
 * @brief Build the credits content: lay the credits-text image out in the popup content view.
 *
 * Calls through to @c super, then adds the @c 07_credits/cre_text image to the content view,
 * centred horizontally and vertically within the remaining space below a theme-dependent top
 * offset.
 * @ghidraAddress 0x963b4
 */
- (void)setupView;

/**
 * @brief The settings view that owns and presents this credits popup.
 */
@property(weak, nonatomic, nullable) RBSettingView *settingView;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
