/** @file
 * The store's modal download dialog. It is a @c UIView subclass showing a spinning activity
 * indicator, a status message label, a download progress bar, and an abort button; it is presented
 * over the store tabs while a store download runs. @c RBStoreTabController owns one and shows or
 * hides it over the dimming cover view. The abort button forwards to the dialog's delegate through
 * the @c StoreDialogViewDelegate protocol.
 *
 * Reconstructed from Ghidra project rb458, program rb458 (class @c StoreDialogView, image base
 * 0x100000000). @ghidraAddress values are offsets relative to the image base.
 */

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@class StoreDialogView;

/**
 * @brief Callbacks a @c StoreDialogView sends to its delegate.
 *
 * The dialog only ever messages its delegate through @c -respondsToSelector: followed by
 * @c -performSelector:withObject:, so every method is optional.
 */
@protocol StoreDialogViewDelegate <NSObject>

@optional

/**
 * @brief Sent when the user taps the dialog's abort button.
 * @param dialog The dialog whose abort button was tapped.
 */
- (void)storeDialogCancel:(StoreDialogView *)dialog;

@end

/**
 * @brief The store download progress dialog.
 */
@interface StoreDialogView : UIView

/**
 * @brief The spinning activity indicator shown while a download is in progress.
 */
@property(strong, nonatomic, nullable) UIActivityIndicatorView *indicatorView;

/**
 * @brief The status message label.
 */
@property(strong, nonatomic, nullable) UILabel *labelMessage;

/**
 * @brief The download progress bar.
 */
@property(strong, nonatomic, nullable) UIProgressView *progressView;

/**
 * @brief The abort button; disabled by the host while the show or hide animation runs.
 */
@property(strong, nonatomic, nullable) UIButton *buttonAbort;

/**
 * @brief The dialog delegate, which receives the abort callback.
 */
@property(weak, nonatomic, nullable) id<StoreDialogViewDelegate> delegate;

/**
 * @brief Build the dialog: the rounded shadowed panel, the activity indicator, the message label,
 * the progress bar, and the abort button.
 *
 * @param frame The view's frame rectangle; the subviews are laid out relative to its size.
 * @return The initialised view, or @c nil.
 * @ghidraAddress 0xf10ec
 */
- (nullable instancetype)initWithFrame:(CGRect)frame;

/**
 * @brief Re-lay the message label and toggle the download controls.
 *
 * When @p messageOnly is @c YES the progress bar and abort button are hidden and the message label
 * sits just below centre; otherwise they are shown and the label sits just above centre.
 *
 * @param messageOnly Whether to hide the progress bar and abort button and show only the message.
 * @ghidraAddress 0xf1ccc
 */
- (void)layout:(BOOL)messageOnly;

/**
 * @brief The abort button action; forwards @c -storeDialogCancel: to the delegate.
 * @param sender The abort button.
 * @ghidraAddress 0xf1eb8
 */
- (void)btnAbort:(nullable id)sender;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
