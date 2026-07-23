/** @file
 * The unlock-confirmation popup presented over the customize screen when the player taps a locked
 * item in the unlock picker. It dims the whole screen and floats a rounded, framed panel showing the
 * item's artwork, its lime-point cost, and yes/no buttons that confirm or cancel the unlock. Music
 * items additionally download and overlay a themed frame image around the artwork.
 *
 * Reconstructed from Ghidra project rb458, program rb458 (class RBCustomInfoPopupView, image base
 * 0x100000000). @ghidraAddress values are offsets relative to the image base.
 */

#import <UIKit/UIKit.h>

@class ImageDownloader;
@class RBNumberLabel;
@class RBUnlockPackageItemData;

NS_ASSUME_NONNULL_BEGIN

/**
 * @brief The unlock-confirmation popup shown over the customize screen.
 *
 * A @c UIControl whose whole-screen frame dims the customize screen behind a centred, rounded panel.
 * The owning @c RBUnlockView wires the yes/no button actions, sets @c itemData (which lays out the
 * artwork and cost), sets @c pointLabel to the player's current balance, and drives @c showAnimation
 * and @c hideAnimation.
 */
@interface RBCustomInfoPopupView : UIControl

/**
 * @brief Create the popup with the given frame.
 *
 * Records the font variant as @c isPad, builds the panel through @c setupView, and marks the control
 * as exclusively touched.
 * @param frame The view's frame rectangle (the whole host view's bounds).
 * @return The initialised view, or @c nil.
 * @ghidraAddress 0x19bd40
 */
- (nullable instancetype)initWithFrame:(CGRect)frame;

/**
 * @brief Build the popup chrome: the centred base panel, its clear background, the rounded clipped
 * content view, the item artwork and frame image views, the cost label, and the yes/no buttons.
 *
 * The button and label geometry depends on the font variant (@c isPad) and the current player theme.
 * @ghidraAddress 0x19bdec
 */
- (void)setupView;

/**
 * @brief Fade the popup in, playing the popup-open sound effect and marking it animating for the
 * duration of the transition.
 * @ghidraAddress 0x19ded8
 */
- (void)showAnimation;

/**
 * @brief Fade the popup out, then remove it from its superview.
 * @ghidraAddress 0x19e058
 */
- (void)hideAnimation;

/**
 * @brief Touch-up handler that dismisses the popup.
 * @param sender The control that sent the action.
 * @ghidraAddress 0x19e1dc
 */
- (void)tap:(nullable id)sender;

/**
 * @brief The item being confirmed. Assigning it lays out the artwork, sizes it by theme and font
 * variant, sets the cost label, and, for a music item, downloads and overlays the frame image.
 * @ghidraAddress 0x19e1f8
 */
@property(strong, nonatomic, nullable) RBUnlockPackageItemData *itemData;

/**
 * @brief The base panel that hosts the background, content view, artwork, and buttons.
 */
@property(strong, nonatomic, nullable) UIView *baseView;

/**
 * @brief The rounded, clipped content view that holds the cost label and buttons.
 */
@property(strong, nonatomic, nullable) UIView *contentView;

/**
 * @brief The item artwork image view.
 */
@property(strong, nonatomic, nullable) UIImageView *imageView;

/**
 * @brief The frame image view overlaid around the artwork for a music item.
 */
@property(strong, nonatomic, nullable) UIImageView *frameImageView;

/**
 * @brief The label showing the item's lime-point cost.
 */
@property(strong, nonatomic, nullable) RBNumberLabel *usePointLabel;

/**
 * @brief The label showing the player's current lime-point balance.
 */
@property(strong, nonatomic, nullable) RBNumberLabel *pointLabel;

/**
 * @brief The confirm button.
 */
@property(strong, nonatomic, nullable) UIButton *yesButton;

/**
 * @brief The cancel button.
 */
@property(strong, nonatomic, nullable) UIButton *noButton;

/**
 * @brief The image downloader that fetches the music-item frame image.
 */
@property(strong, nonatomic, nullable) ImageDownloader *imageDownloader;

/**
 * @brief Whether the layout uses the wide (iPad) font variant.
 */
@property(assign, nonatomic) BOOL isPad;

/**
 * @brief Whether a show or hide animation is currently running.
 */
@property(assign, nonatomic) BOOL animating;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
