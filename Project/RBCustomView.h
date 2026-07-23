/** @file
 * The customize popup view. It is an @c RBMusicMenuPopupView configured with the customize popup
 * type, hosting the customize item picker (@c RBCustomSelectView) and, on the themed layouts, the
 * experience/unlock picker (@c RBUnlockView), a set/unlock mode-toggle button pair with a framed
 * gradient backdrop and a flashing effect overlay, and the reward list (@c RBRewardListView) that
 * slides in over the picker.
 *
 * Reconstructed from Ghidra project rb458, program rb458 (class RBCustomView, image base
 * 0x100000000). @ghidraAddress values are offsets relative to the image base.
 */

#import <UIKit/UIKit.h>

#import "RBCustomSelectView.h"
#import "RBMusicMenuPopupView.h"
#import "RBRewardListView.h"
#import "RBUnlockView.h"

@class RBSettingView;

NS_ASSUME_NONNULL_BEGIN

/**
 * @brief Popup view that hosts the customize picker, the experience/unlock picker, the set/unlock
 * mode toggle, and the reward list over the settings screen.
 *
 * The customize picker always fills the content view; the experience picker, the mode-toggle
 * buttons, the gradient frame, the effect overlay, and the reward list are only built on the
 * themed layouts (theme @c 1 and theme @c 2). Their geometry depends on the current theme and font
 * variant.
 */
@interface RBCustomView : RBMusicMenuPopupView

/**
 * @brief Create the customize popup with the given frame.
 *
 * Calls through to @c super, selects the customize popup type, and builds the view.
 * @param frame The view's frame rectangle.
 * @return The initialised view, or @c nil.
 * @ghidraAddress 0x96664
 */
- (nullable instancetype)initWithFrame:(CGRect)frame;

/**
 * @brief Build the customize content: the customize picker and, on the themed layouts, the
 * experience picker, the mode-toggle buttons, the gradient frame, the effect overlay, and the
 * reward list.
 *
 * Calls through to @c super, then reads the theme and iPad idiom flag to size and place each
 * subview. The experience picker starts translated off screen so the mode toggle can slide it in.
 * @ghidraAddress 0x96724
 */
- (void)setupView;

/**
 * @brief Fade the popup in, then persist the user settings.
 * @ghidraAddress 0x987b0
 */
- (void)showAnimation;

/**
 * @brief Hide the reward list, persist the user settings, then fade the popup out.
 * @ghidraAddress 0x99a6c
 */
- (void)hideAnimation;

/**
 * @brief Switch to the customize picker: slide the experience picker out and the customize picker
 * in, and launch the experience tutorial on completion when it is pending.
 *
 * Ignored while a transition is already running.
 * @param sender The set-mode button that sent the action.
 * @ghidraAddress 0x98ec4
 */
- (void)toCustomize:(nullable id)sender;

/**
 * @brief Switch to the experience/unlock picker: request its data, slide the customize picker out
 * and the experience picker in, and launch the customize tutorial on completion when it is
 * pending.
 *
 * Ignored while a transition is already running.
 * @param sender The unlock-mode button that sent the action.
 * @ghidraAddress 0x98834
 */
- (void)toUnlock:(nullable id)sender;

/**
 * @brief Reveal the reward list over the picker: hide the title and gradation, fade the list in,
 * and start loading its contents on completion.
 *
 * Ignored while a transition is already running.
 * @param sender The control that sent the action.
 * @ghidraAddress 0x99494
 */
- (void)toRewardList:(nullable id)sender;

/**
 * @brief Hide the reward list and restore the title and gradation.
 *
 * Ignored while a transition is already running.
 * @ghidraAddress 0x997a0
 */
- (void)hideRewardList;

/**
 * @brief The unlock-mode toggle button, exposed for the tutorial highlight.
 * @return The experience unlock button.
 * @ghidraAddress 0x99b30
 */
- (nullable UIButton *)getUnlockButtonView;

/**
 * @brief The set-mode (customize) toggle button, exposed for the tutorial highlight.
 * @return The experience set button.
 * @ghidraAddress 0x99b3c
 */
- (nullable UIButton *)getCustomButtonView;

/**
 * @brief The customize picker, exposed for the tutorial highlight.
 * @return The customize item view.
 * @ghidraAddress 0x99b48
 */
- (nullable RBCustomSelectView *)getCustomizeItemView;

/**
 * @brief The settings view that owns and presents this customize popup.
 */
@property(weak, nonatomic, nullable) RBSettingView *settingView;

/**
 * @brief The customize item picker filling the content view.
 */
@property(strong, nonatomic, nullable) RBCustomSelectView *customizeItemView;

/**
 * @brief The experience/unlock item picker, built only on the themed layouts.
 */
@property(strong, nonatomic, nullable) RBUnlockView *experienceItemView;

/**
 * @brief A legacy experience button. Declared by the binary but not built by @c setupView.
 */
@property(strong, nonatomic, nullable) UIButton *experienceButton;

/**
 * @brief The set-mode toggle button that switches to the customize picker.
 */
@property(strong, nonatomic, nullable) UIButton *experienceSetButton;

/**
 * @brief The unlock-mode toggle button that switches to the experience picker.
 */
@property(strong, nonatomic, nullable) UIButton *experienceUnlockButton;

/**
 * @brief The flashing overlay drawn under the currently selected mode-toggle button.
 */
@property(strong, nonatomic, nullable) UIImageView *experienceButtonEffectView;

/**
 * @brief The gradient frame drawn behind the mode-toggle buttons at the bottom of the content
 * view.
 */
@property(strong, nonatomic, nullable) UIImageView *experienceButtonFrameView;

/**
 * @brief The reward list that slides in over the picker.
 */
@property(strong, nonatomic, nullable) RBRewardListView *rewardListView;

/**
 * @brief Whether this is the first time the popup is shown.
 */
@property(assign, nonatomic) BOOL firstInfo;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
