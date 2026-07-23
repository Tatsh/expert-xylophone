/** @file
 * The pad-layout pack detail panel shown over the store's dimming cover. It is the pad counterpart
 * to the phone @c RBStoreDetailViewController: a single self-drawn @c UIView that lays out a pack's
 * artwork, name, comment, copyright, purchase button, up to four tune rows (each a
 * @c StorePackMusicView), an artist-site button, and a trailing terms label, and drives the pack's
 * buy or re-download action through its delegate.
 *
 * Reconstructed from Ghidra project rb458, program rb458 (class @c StorePackDetailViewPad, image
 * base 0x100000000). @ghidraAddress values are offsets relative to the image base.
 */

#import <UIKit/UIKit.h>

#import "Downloader.h"
#import "StorePackInfoDownloader.h"
#import "StorePackView.h"

@class Downloader;
@class StoreImageView;
@class StorePackInfo;
@class StorePackInfoDownloader;
@class StorePackMusicView;

NS_ASSUME_NONNULL_BEGIN

/**
 * @brief The pad-layout pack detail panel.
 */
@interface StorePackDetailViewPad : UIView <DownloaderDelegate, StorePackInfoDownloaderDelegate>

/**
 * @brief The delegate that drives the panel's purchase, re-download, terms, and close actions.
 * @ghidraAddress 0xfb02c (getter)
 * @ghidraAddress 0xfb04c (setter)
 */
@property(nonatomic, weak, nullable) id<StorePackViewDelegate> delegate;

/**
 * @brief The pack the panel currently displays.
 * @ghidraAddress 0xfafe4 (getter)
 * @ghidraAddress 0xfaff4 (setter)
 */
@property(nonatomic, strong, nullable) StorePackInfo *packInfo;

/**
 * @brief The container view that hosts every per-pack subview (artwork, labels, button, tune rows).
 * @ghidraAddress 0xfb060 (getter)
 * @ghidraAddress 0xfb070 (setter)
 */
@property(nonatomic, strong, nullable) UIView *packView;

/**
 * @brief The four tune rows, one @c StorePackMusicView per pack tune slot.
 * @ghidraAddress 0xfb0a8 (getter)
 * @ghidraAddress 0xfb0b8 (setter)
 */
@property(nonatomic, strong, nullable) NSMutableArray<StorePackMusicView *> *musicViews;

/**
 * @brief The pack jacket artwork view, which downloads its own image from the pack's artwork URL.
 * @ghidraAddress 0xfb0f0 (getter)
 * @ghidraAddress 0xfb100 (setter)
 */
@property(nonatomic, strong, nullable) StoreImageView *packArtworkView;

/**
 * @brief The pack name label.
 * @ghidraAddress 0xfb138 (getter)
 * @ghidraAddress 0xfb148 (setter)
 */
@property(nonatomic, strong, nullable) UILabel *labelPackName;

/**
 * @brief The pack comment label.
 * @ghidraAddress 0xfb180 (getter)
 * @ghidraAddress 0xfb190 (setter)
 */
@property(nonatomic, strong, nullable) UILabel *labelComment;

/**
 * @brief The pack copyright-notice text view.
 * @ghidraAddress 0xfb1c8 (getter)
 * @ghidraAddress 0xfb1d8 (setter)
 */
@property(nonatomic, strong, nullable) UITextView *copyrightView;

/**
 * @brief The purchase / install / re-download action button.
 * @ghidraAddress 0xfb210 (getter)
 * @ghidraAddress 0xfb220 (setter)
 */
@property(nonatomic, strong, nullable) UIButton *buttonPurchase;

/**
 * @brief The spinner shown over the loading label while the pack detail downloads.
 * @ghidraAddress 0xfb258 (getter)
 * @ghidraAddress 0xfb268 (setter)
 */
@property(nonatomic, strong, nullable) UIActivityIndicatorView *indicator;

/**
 * @brief The centred loading label shown while the pack detail downloads.
 * @ghidraAddress 0xfb2a0 (getter)
 * @ghidraAddress 0xfb2b0 (setter)
 */
@property(nonatomic, strong, nullable) UILabel *labelLoading;

/**
 * @brief The downloader that fetches the pack's full detail (tune list) when it is not yet loaded.
 * @ghidraAddress 0xfb2e8 (getter)
 * @ghidraAddress 0xfb2f8 (setter)
 */
@property(nonatomic, strong, nullable) StorePackInfoDownloader *storePackInfoDownloader;

/**
 * @brief The downloader for the currently-playing tune sample.
 * @ghidraAddress 0xfb330 (getter)
 * @ghidraAddress 0xfb340 (setter)
 */
@property(nonatomic, strong, nullable) Downloader *sampleDownloader;

/**
 * @brief The artist-site button that opens the pack's artist URL in the browser.
 * @ghidraAddress 0xfb378 (getter)
 * @ghidraAddress 0xfb388 (setter)
 */
@property(nonatomic, strong, nullable) UIButton *artistSiteButton;

/**
 * @brief Load and display the current pack, fetching its full tune list if it is not yet present.
 * @ghidraAddress 0xf9330
 */
- (void)loadInfo;

/**
 * @brief Populate every subview from the loaded pack and begin its artwork downloads.
 * @ghidraAddress 0xf8a94
 */
- (void)showPackInfo;

/**
 * @brief Cancel any in-flight pack-detail download.
 * @ghidraAddress 0xf8154
 */
- (void)cancelLoading;

/**
 * @brief Stop any sample playback and cancel the sample download.
 * @ghidraAddress 0xf8238
 */
- (void)stopSample;

/**
 * @brief Clear the displayed pack and reset every subview to its empty state.
 * @ghidraAddress 0xf7ddc
 */
- (void)removePackInfo;

/**
 * @brief Whether every tune in the pack is already downloaded.
 * @return @c YES when the pack is fully downloaded.
 * @ghidraAddress 0xf8400
 */
- (BOOL)allDownloaded;

/**
 * @brief Recompute the purchase button label from the current ownership and download state.
 * @ghidraAddress 0xf859c
 */
- (void)selfCheckButtonText;

/**
 * @brief Set the purchase button label to the purchasable state, showing the price.
 * @ghidraAddress 0xf8714
 */
- (void)setButtonTextBuy;

/**
 * @brief Set the purchase button label to the installable state.
 * @ghidraAddress 0xf8884
 */
- (void)setButtonTextInstall;

/**
 * @brief Set the purchase button label to the installing state.
 * @ghidraAddress 0xf8934
 */
- (void)setButtonTextInstalling;

/**
 * @brief Set the purchase button label to the installed state.
 * @ghidraAddress 0xf89e4
 */
- (void)setButtonTextInstalled;

/**
 * @brief The purchase button action: begin buying or re-downloading the pack through the delegate.
 * @param doPurchase The purchase button.
 * @ghidraAddress 0xf9744
 */
- (void)doPurchase:(nullable id)doPurchase;

/**
 * @brief A tune row's link button action: open its iTunes URL through the delegate.
 * @param handleLink The tapped link button.
 * @ghidraAddress 0xf99e8
 */
- (void)handleLink:(nullable id)handleLink;

/**
 * @brief A tune row's sample button action: toggle sample playback for that tune.
 * @param handleSample The tapped sample button.
 * @ghidraAddress 0xf9c88
 */
- (void)handleSample:(nullable id)handleSample;

/**
 * @brief The artist-site button action: open the pack's artist URL in the browser.
 * @ghidraAddress 0xfa270
 */
- (void)selectWebButton;

/**
 * @brief A tune sample finished downloading: load and play it, then stop every other row.
 * @param finishBgm Unused sender.
 * @ghidraAddress 0xfa37c
 */
- (void)finishBgm:(nullable id)finishBgm;

/**
 * @brief The terms label tap action: ask the delegate to show the terms and precautions.
 * @ghidraAddress 0xfa45c
 */
- (void)showTerm;

/**
 * @brief Switch to the sequence-extension store for the given extend-note product identifier.
 * @param switchToSpecialStore The extend-note product identifier, boxed as an @c NSNumber.
 * @ghidraAddress 0xfaea4
 */
- (void)switchToSpecialStore:(nullable NSNumber *)switchToSpecialStore;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
