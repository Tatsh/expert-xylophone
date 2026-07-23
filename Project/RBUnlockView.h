/** @file
 * The experience/unlock item picker hosted by @c RBCustomView on the themed (Limelight and Colette)
 * layouts. It shows the player's lime-point balance, an optional Applilink reward banner button,
 * and one horizontal @c RBUnlockCollectionView per unlock package stacked in a scroll view. Tapping
 * an item opens the @c RBCustomInfoPopupView confirmation popup; confirming spends the points,
 * records the unlock in @c RBExperienceData, reports it to the server, and, for music items,
 * downloads the track.
 *
 * Reconstructed from Ghidra project rb458, program rb458 (class RBUnlockView, image base
 * 0x100000000). @ghidraAddress values are offsets relative to the image base.
 */

#import <UIKit/UIKit.h>

#import "Downloader.h"
#import "RBUnlockCollectionView.h"
#import "StoreDownloadManager.h"
#import "UIAlertView+RB.h"

@class DAProgressOverlayView;
@class RBCustomInfoPopupView;
@class RBCustomView;
@class RBNumberLabel;
@class RBUnlockCollectionCell;

NS_ASSUME_NONNULL_BEGIN

/**
 * @brief The experience/unlock item picker.
 */
@interface RBUnlockView : UIView <RBUnlockCollectionViewDelegate,
                                  DownloaderDelegate,
                                  StoreDownloadManagerDelegate,
                                  UIAlertViewDelegate>

/**
 * @brief Create the picker with the given frame and build its subviews.
 * @param frame The view's frame rectangle.
 * @return The initialised view, or @c nil.
 * @ghidraAddress 0x94284
 */
- (nullable instancetype)initWithFrame:(CGRect)frame;

/**
 * @brief Build the reward banner button, the lime-point count label and its backdrop, the package
 * scroll view, and the loading spinner, then reload the package list.
 * @ghidraAddress 0x94314
 */
- (void)setupView;

/**
 * @brief Rebuild the scroll view's contents: the reward banner button (when a banner is available)
 * and one @c RBUnlockCollectionView per unlock package, sizing the scroll content to fit.
 * @ghidraAddress 0x94ba0
 */
- (void)reloadData;

/**
 * @brief Request the unlock catalogue from the server, spinning the loading indicator until it
 * arrives.
 * @ghidraAddress 0x955e0
 */
- (void)request;

/**
 * @brief The customize picker's item view, exposed for the tutorial highlight.
 * @return The package scroll view.
 * @ghidraAddress 0x973b4
 */
- (nullable UIScrollView *)getUnlockItemView;

/**
 * @brief Forward the parent-view reference; stored as @c parentCustomView.
 * @param parentView The customize popup that owns this picker.
 * @ghidraAddress 0x942f8
 */
- (void)setParentView:(nullable RBCustomView *)parentView;

/**
 * @brief The customize popup that owns this picker, held weakly.
 */
@property(weak, nonatomic, nullable) RBCustomView *parentCustomView;

/**
 * @brief The framed backdrop behind the lime-point count.
 */
@property(strong, nonatomic, nullable) UIImageView *pointBackgroundView;

/**
 * @brief The label showing the player's current lime-point balance.
 */
@property(strong, nonatomic, nullable) RBNumberLabel *pointLabel;

/**
 * @brief The scroll view stacking the per-package pickers.
 */
@property(strong, nonatomic, nullable) UIScrollView *scrollView;

/**
 * @brief The unlock-confirmation popup shown for the tapped item.
 */
@property(strong, nonatomic, nullable) RBCustomInfoPopupView *popupView;

/**
 * @brief The spinner shown while the catalogue is loading.
 */
@property(strong, nonatomic, nullable) UIActivityIndicatorView *activityIndicatorView;

/**
 * @brief The batch runner downloading an unlocked music track.
 */
@property(strong, nonatomic, nullable) StoreDownloadManager *storeDownloadManager;

/**
 * @brief The catalogue/music-info download in flight.
 */
@property(strong, nonatomic, nullable) Downloader *downloader;

/**
 * @brief The progress overlay drawn over the tapped cell while its content downloads.
 */
@property(strong, nonatomic, nullable) DAProgressOverlayView *progressOverlayView;

/**
 * @brief The package picker whose cell was tapped, held weakly.
 */
@property(weak, nonatomic, nullable) RBUnlockCollectionView *selectedView;

/**
 * @brief The tapped cell, held weakly.
 */
@property(weak, nonatomic, nullable) RBUnlockCollectionCell *selectedCell;

/**
 * @brief The display name of the music track being downloaded.
 */
@property(copy, nonatomic, nullable) NSString *dlMusicName;

/**
 * @brief A random key echoed by the music-info request to guard against a stale response.
 */
@property(assign, nonatomic) int unlockRandomKey;

/**
 * @brief The most recently shown alert.
 */
@property(strong, nonatomic, nullable) UIAlertView *alertView;

/**
 * @brief The reward banner image URL, when a banner is available.
 */
@property(strong, nonatomic, nullable) NSString *rewardBannerUrl;

/**
 * @brief The reward banner button shown above the packages.
 */
@property(strong, nonatomic, nullable) UIButton *rewardButton;

/**
 * @brief The reward banner image view.
 */
@property(strong, nonatomic, nullable) UIImageView *rewardBannerImageView;

/**
 * @brief The reward banner identifier.
 */
@property(strong, nonatomic, nullable) NSString *rewardId;

/**
 * @brief The nonce sent with the reward-check request and validated against its response.
 */
@property(strong, nonatomic, nullable) NSString *nonce;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
