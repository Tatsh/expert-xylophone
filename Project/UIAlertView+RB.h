/** @file
 * @c UIAlertView convenience factories used across the game. Every method builds a
 * @c UIAlertView with fixed (localized or hard-coded) titles, messages, and buttons, and — except
 * for the handful of "create" variants — immediately shows it. A few variants also tag the alert
 * so the shared delegate can tell them apart.
 *
 * Reconstructed from Ghidra project rb458, program rb458 (category @c UIAlertView(RB), image base
 * 0x100000000). @ghidraAddress values are offsets relative to the image base.
 *
 * The category is registered in the binary as a class-method category on @c UIAlertView (the
 * receiver of every selector is the @c UIAlertView class object), so all methods are class methods.
 * Selector names are preserved verbatim, including the binary's misspellings (@c strageAlertView,
 * @c showInfomation, @c showAddLimepointByApplilink::).
 */

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * @brief Alert-presentation factories layered on @c UIAlertView.
 *
 * Delegate arguments are typed @c id<UIAlertViewDelegate> and may be @c nil; several factories keep
 * the delegate parameter for API symmetry but do not attach it to the created alert.
 */
@interface UIAlertView (RB)

/**
 * @brief Build a "DELETE SONG" confirmation alert (NO/YES) without showing it.
 * @param delegate The alert delegate.
 * @return The created alert, which the caller shows.
 * @ghidraAddress 0xdc98
 */
+ (UIAlertView *)deleteAlertViewWithDelegate:(nullable id<UIAlertViewDelegate>)delegate;

/**
 * @brief Build a low-storage "Caution" alert (Close) without showing it.
 * @return The created alert, which the caller shows.
 * @ghidraAddress 0xdd38
 */
+ (UIAlertView *)strageAlertView;

/**
 * @brief Show a "restore purchased PACKs" prompt.
 * @param delegate The alert delegate.
 * @return The shown alert.
 * @ghidraAddress 0xdd94
 */
+ (UIAlertView *)showRestoreDownloadWithDelegate:(nullable id<UIAlertViewDelegate>)delegate;

/**
 * @brief Show an "install restored PACKs" prompt.
 * @param delegate The alert delegate.
 * @return The shown alert.
 * @ghidraAddress 0xde64
 */
+ (UIAlertView *)showRestoreMessageWithDelegate:(nullable id<UIAlertViewDelegate>)delegate;

/**
 * @brief Show the "failed to connect Game Center" alert (OK).
 * @return The shown alert.
 * @ghidraAddress 0xdf34
 */
+ (UIAlertView *)showGameCenterError;

/**
 * @brief Show the network-error alert with a tag of 0.
 * @param delegate The alert delegate.
 * @return The shown alert.
 * @ghidraAddress 0xdfc0
 */
+ (UIAlertView *)showNetworkErrorWithDelegate:(nullable id<UIAlertViewDelegate>)delegate;

/**
 * @brief Show the "failed to download" error alert (Close).
 * @param delegate The alert delegate.
 * @return The shown alert.
 * @ghidraAddress 0xe090
 */
+ (UIAlertView *)showDownloadErrorWithDelegate:(nullable id<UIAlertViewDelegate>)delegate;

/**
 * @brief Show the "took over the data" notice (Close).
 * @return The shown alert.
 * @ghidraAddress 0xe158
 */
+ (UIAlertView *)showTakeoverMessage;

/**
 * @brief Show the "enable location service" information alert (OK).
 * @return The shown alert.
 * @ghidraAddress 0xe1e4
 */
+ (UIAlertView *)showInfomation;

/**
 * @brief Show an "open this place in the map?" confirmation with a caller-supplied title.
 * @param title The alert title.
 * @param delegate The alert delegate.
 * @return The shown alert.
 * @ghidraAddress 0xe270
 */
+ (UIAlertView *)showMapWithTitle:(nullable NSString *)title
                         delegate:(nullable id<UIAlertViewDelegate>)delegate;

/**
 * @brief Show an "Error" alert with a caller-supplied message (OK).
 * @param message The alert message.
 * @param delegate The alert delegate.
 * @return The shown alert.
 * @ghidraAddress 0xe358
 */
+ (UIAlertView *)showWithErrorMessage:(nullable NSString *)message
                             delegate:(nullable id<UIAlertViewDelegate>)delegate;

/**
 * @brief Show an "Error" alert with a caller-supplied message and a Retry button.
 * @param message The alert message.
 * @param delegate The alert delegate.
 * @return The shown alert.
 * @ghidraAddress 0xe42c
 */
+ (UIAlertView *)showConnectRetryWithErrorMessage:(nullable NSString *)message
                                         delegate:(nullable id<UIAlertViewDelegate>)delegate;

/**
 * @brief Show the "failed to download" error alert with a Retry button.
 * @param delegate The alert delegate.
 * @return The shown alert.
 * @ghidraAddress 0xe514
 */
+ (UIAlertView *)showConnectRetryOrCancel:(nullable id<UIAlertViewDelegate>)delegate;

/**
 * @brief Show an "%\@ has been added." alert for an unlocked music item (OK).
 * @param delegate The alert delegate.
 * @param musicName The music name substituted into the message.
 * @return The shown alert.
 * @ghidraAddress 0xe5e4
 */
+ (UIAlertView *)showUnlockedMusicInfoWithDelegate:(nullable id<UIAlertViewDelegate>)delegate
                                         musicName:(nullable NSString *)musicName;

/**
 * @brief Show the age/monthly-spending-limit selection alert (Cancel plus three choices).
 * @param delegate The alert delegate.
 * @return The shown alert.
 * @ghidraAddress 0xe6e8
 */
+ (UIAlertView *)showSelectPurchaseLimitTypeWithDelegate:(nullable id<UIAlertViewDelegate>)delegate;

/**
 * @brief Show the "monthly spending limit exceeded" alert (OK).
 * @param delegate The alert delegate. Kept for API symmetry; not attached to the alert.
 * @return The shown alert.
 * @ghidraAddress 0xe93c
 */
+ (UIAlertView *)showPurchaseOverMessageWithDelegate:(nullable id<UIAlertViewDelegate>)delegate;

/**
 * @brief Show a campaign's terms of use (OK).
 * @param campaign An object responding to @c -campaignTermsDescription supplying the message body.
 * @return The shown alert.
 * @ghidraAddress 0xea50
 */
+ (UIAlertView *)showUnlockTermsDescription2:(id)campaign;

/**
 * @brief Show the "new version available" alert (Cancel plus an "AppStore" button).
 * @param delegate The alert delegate.
 * @return The shown alert.
 * @ghidraAddress 0xebc0
 */
+ (UIAlertView *)showAlertUpdateForUnlock:(nullable id<UIAlertViewDelegate>)delegate;

/**
 * @brief Show the "insufficient points" alert (OK).
 * @return The shown alert.
 * @ghidraAddress 0xed10
 */
+ (UIAlertView *)showAlertShortageOfPoint;

/**
 * @brief Show the "new version available, move to App Store?" alert with a tag of 3.
 * @param delegate The alert delegate.
 * @return The shown alert.
 * @ghidraAddress 0xee34
 */
+ (UIAlertView *)showAlertLatestApplication:(nullable id<UIAlertViewDelegate>)delegate;

/**
 * @brief Show the "update data found, download?" alert with a tag of 1.
 * @param delegate The alert delegate.
 * @return The shown alert.
 * @ghidraAddress 0xef18
 */
+ (UIAlertView *)showDownloadWithDelegate:(nullable id<UIAlertViewDelegate>)delegate;

/**
 * @brief Show the "latest game data required" alert with a tag of 2 (OK).
 * @param delegate The alert delegate.
 * @return The shown alert.
 * @ghidraAddress 0xeffc
 */
+ (UIAlertView *)showAlertNeedResourceUpdate:(nullable id<UIAlertViewDelegate>)delegate;

/**
 * @brief Show the "App Installed Reward: %\@ lime points have been added." alert (OK).
 * @param limePoint The number of lime points substituted into the message.
 * @param delegate The alert delegate.
 * @return The shown alert.
 * @ghidraAddress 0xf150
 */
+ (UIAlertView *)showAddLimepointByApplilink:(int)
                                   limePoint:(nullable id<UIAlertViewDelegate>)delegate;

/**
 * @brief Show the "reordering needs a download" alert (NO/YES) built with a fixed message.
 * @param delegate The alert delegate.
 * @return The shown alert.
 * @ghidraAddress 0xf2e0
 */
+ (UIAlertView *)showAlertNeedDownloadMusicNameList:(nullable id<UIAlertViewDelegate>)delegate;

/**
 * @brief Build the "WELCOME TO colette!!" theme-unlock alert (OK) without showing it.
 * @return The created alert, which the caller shows.
 * @ghidraAddress 0xf3e4
 */
+ (UIAlertView *)showColetteThemaUnlockMessage;

/**
 * @brief Build the "enter serial code" alert (Cancel/OK) without showing it.
 * @param delegate The alert delegate.
 * @return The created alert, which the caller shows.
 * @ghidraAddress 0xf588
 */
+ (UIAlertView *)showSerialcodeDialog:(nullable id<UIAlertViewDelegate>)delegate;

/**
 * @brief Enable exclusive touch on every subview of a view.
 * @param view The container view whose subviews are configured.
 * @ghidraAddress 0xf764
 */
+ (void)setExclusiveTouchForView:(nullable UIView *)view;

/**
 * @brief Build the "additional sequences" purchase-requirement alert (NO/YES) without showing it.
 * @param requirement The requirement text substituted into the message.
 * @param delegate The alert delegate.
 * @return The created alert, which the caller shows.
 * @ghidraAddress 0xf8cc
 */
+ (UIAlertView *)showPurchasePack:(nullable NSString *)requirement
                         delegate:(nullable id<UIAlertViewDelegate>)delegate;

/**
 * @brief Build the "purchase additional sequences?" alert (NO/YES) without showing it.
 * @param delegate The alert delegate.
 * @return The created alert, which the caller shows.
 * @ghidraAddress 0xf9e0
 */
+ (UIAlertView *)showMovePackDetailToExtendDetail:(nullable id<UIAlertViewDelegate>)delegate;

/**
 * @brief Show an alert listing the given strings, one per line under a fixed header (YES).
 * @param musics A collection of strings appended to the message body.
 * @return The shown alert.
 * @ghidraAddress 0xfa84
 */
+ (UIAlertView *)showAlertNotFoundMusics:(nullable id<NSFastEnumeration>)musics;

/**
 * @brief Show the "Erosion Mark play history found, fix score?" alert (NO/YES).
 * @param delegate The alert delegate.
 * @return The shown alert.
 * @ghidraAddress 0xfcb0
 */
+ (UIAlertView *)showAlertUpdateErosionMark:(nullable id<UIAlertViewDelegate>)delegate;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
