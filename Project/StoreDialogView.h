/** @file
 * The store's modal download dialog. It is a @c UIView subclass showing a progress indicator, a
 * progress bar, an abort button, and a status message while a store download runs;
 * @c RBStoreTabController owns one and shows or hides it over the store tabs. Only the surface
 * that @c RBStoreTabController messages is declared here; the full class is reconstructed
 * separately.
 *
 * Reconstructed from Ghidra project rb458, program rb458 (class @c StoreDialogView, image base
 * 0x100000000). @ghidraAddress values are offsets relative to the image base.
 */

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * @brief The store download progress dialog.
 */
@interface StoreDialogView : UIView

/**
 * @brief The spinning activity indicator shown while a download is in progress.
 */
@property(strong, nonatomic, nullable) UIActivityIndicatorView *indicatorView;

/**
 * @brief The download progress bar.
 */
@property(strong, nonatomic, nullable) UIProgressView *progressView;

/**
 * @brief The abort button; disabled while the show or hide animation runs.
 */
@property(strong, nonatomic, nullable) UIButton *buttonAbort;

/**
 * @brief The status message label.
 */
@property(strong, nonatomic, nullable) UILabel *labelMessage;

/**
 * @brief The dialog delegate, receiving the download-dialog callbacks.
 */
@property(weak, nonatomic, nullable) id delegate;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
