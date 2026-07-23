/** @file
 * The phone extend-note detail view controller, pushed onto the store navigation stack to present
 * a single extend note's detail, sample, and purchase controls.
 *
 * Reconstructed from Ghidra project rb458, program rb458 (class
 * @c RBStoreExtendNoteDetailViewController, image base 0x100000000). @ghidraAddress values are
 * offsets relative to the image base.
 */

#import <UIKit/UIKit.h>

#import "Downloader.h"
#import "RBBaseViewController.h"

@class NSMutableDictionary;
@class StoreButtonView;
@class StoreExtendNoteInfo;
@class StoreImageView;
@class UIActivityIndicatorView;

NS_ASSUME_NONNULL_BEGIN

/**
 * @brief The phone extend-note detail view controller.
 *
 * This is the note-detail screen pushed by @c RBStoreExtendPageViewController on the phone layout
 * (the pad layout uses @c StoreExtendNoteDetailViewPad instead). It conforms to the sample-audio
 * downloader's @c DownloaderDelegate protocol.
 */
@interface RBStoreExtendNoteDetailViewController : RBBaseViewController <DownloaderDelegate>

/**
 * @brief The delegate that receives detail-view actions (the hosting page controller).
 *
 * The controller messages the delegate through @c performSelector: with @c selectButton: and
 * @c detailViewClose, so it is modelled as an untyped weak reference.
 */
@property(nonatomic, weak, nullable) id delegate;
/**
 * @brief The extend-note record being displayed.
 */
@property(nonatomic, strong, nullable) StoreExtendNoteInfo *info;
/**
 * @brief The scrolling container that hosts the item and detail views.
 */
@property(nonatomic, strong, nullable) UIScrollView *mainView;
/**
 * @brief The upper card holding the artwork, labels, and purchase button.
 */
@property(nonatomic, strong, nullable) UIView *itemView;
/**
 * @brief The tappable jacket artwork, which doubles as the sample-BGM control.
 */
@property(nonatomic, strong, nullable) StoreImageView *artworkView;
/**
 * @brief The "new" badge shown over the artwork.
 */
@property(nonatomic, strong, nullable) UIImageView *iconNew;
/**
 * @brief The music-name label.
 */
@property(nonatomic, strong, nullable) UILabel *labelMusicName;
/**
 * @brief The artist-name label.
 */
@property(nonatomic, strong, nullable) UILabel *labelArtistName;
/**
 * @brief The difficulty-level label.
 */
@property(nonatomic, strong, nullable) UILabel *labelLevel;
/**
 * @brief The purchase / download action button.
 */
@property(nonatomic, strong, nullable) StoreButtonView *downloadBtn;
/**
 * @brief The in-flight sample-BGM downloader.
 */
@property(nonatomic, strong, nullable) Downloader *sampleDownloader;
/**
 * @brief The dimming overlay shown over the artwork while sampling.
 */
@property(nonatomic, strong, nullable) UIView *sampleView;
/**
 * @brief The "now playing" glyph shown over the artwork while a sample plays.
 */
@property(nonatomic, strong, nullable) UIImageView *playingView;
/**
 * @brief The spinner shown over the artwork while a sample downloads.
 */
@property(nonatomic, strong, nullable) UIActivityIndicatorView *indicatorSample;
/**
 * @brief The lower card holding the banner, description, and terms link.
 */
@property(nonatomic, strong, nullable) UIView *detailView;
/**
 * @brief The rounded banner image view inside the detail card.
 */
@property(nonatomic, strong, nullable) StoreImageView *bannerView;
/**
 * @brief The description text view inside the detail card.
 */
@property(nonatomic, strong, nullable) UITextView *descriptionTextView;
/**
 * @brief The terms-of-service link view inside the detail card.
 */
@property(nonatomic, strong, nullable) UIView *termLinkView;
/**
 * @brief A general-purpose activity indicator (declared by the binary; unused in the shipped
 * flow).
 */
@property(nonatomic, strong, nullable) UIActivityIndicatorView *indicator;
/**
 * @brief A loading label (declared by the binary; unused in the shipped flow).
 */
@property(nonatomic, strong, nullable) UILabel *labelLoading;
/**
 * @brief The access-in-progress activity indicator (declared by the binary).
 */
@property(nonatomic, strong, nullable) UIActivityIndicatorView *accessingIndicator;
/**
 * @brief The access-in-progress label (declared by the binary).
 */
@property(nonatomic, strong, nullable) UILabel *accessingLabel;
/**
 * @brief The per-product artwork downloaders, keyed by boxed product identifier.
 */
@property(nonatomic, strong, nullable) NSMutableDictionary *artworkDownloaders;
/**
 * @brief The pack-info download confirmation alert, retained while it is shown.
 */
@property(nonatomic, strong, nullable) UIAlertView *packinfoDownloadAlertView;
/**
 * @brief The product's row index within the hosting table.
 */
@property(nonatomic, assign) int workingIndex;
/**
 * @brief The active campaign identifier.
 */
@property(nonatomic, assign) int campaignID;
/**
 * @brief Set while the view is being torn down, gating the delegate close notifications.
 */
@property(nonatomic, assign) BOOL closingFlag;
/**
 * @brief The index of the loaded sample, or -1 when no sample is queued.
 */
@property(nonatomic, assign) int samplePlayedIndex;

/**
 * @brief Initialises the controller with the given extend-note record.
 * @param info The extend-note record to display.
 * @return The initialised controller.
 * @ghidraAddress 0x1a76bc
 */
- (nullable instancetype)initWithExtendNoteInfo:(nullable StoreExtendNoteInfo *)info;

/**
 * @brief Loads the given extend-note record into the detail view, refreshing every label, the
 * artwork, and the action button, or clears the view when @p info is @c nil.
 * @param info The extend-note record to display, or @c nil to clear.
 * @ghidraAddress 0x1a78f4
 */
- (void)setExtendNoteInfo:(nullable StoreExtendNoteInfo *)info;

/**
 * @brief Retained hook that records the download flag. The shipped build ignores the value.
 * @param downloadFlag The requested download flag.
 * @ghidraAddress 0x1a7db0
 */
- (void)setDownloadFlag:(BOOL)downloadFlag;

/**
 * @brief Sets the displayed purchase state of the detail cell, refreshing the action button colour
 * and title from the current note's ownership state.
 * @param purchaseState Whether the note is purchased.
 * @ghidraAddress 0x1a7db4
 */
- (void)setPurchaseState:(BOOL)purchaseState;

/**
 * @brief Reports whether the given music item is already installed on disk.
 * @param hasItem A zero flag selecting the existence check.
 * @param itemID The music identifier to test.
 * @return @c YES when the item's purchased music file exists on disk.
 * @ghidraAddress 0x1a7f2c
 */
- (BOOL)hasItem:(int)hasItem itemID:(int)itemID;

/**
 * @brief Reveals the loaded note's item detail, starting the artwork download if needed.
 * @ghidraAddress 0x1a8040
 */
- (void)showItemInfo;

/**
 * @brief Reveals the item detail when a note record is loaded.
 * @ghidraAddress 0x1a8224
 */
- (void)loadInfo;

/**
 * @brief Loads and plays the downloaded sample BGM, pushing it onto the BGM stack.
 * @ghidraAddress 0x1a8278
 */
- (void)sampleStart;

/**
 * @brief Stops the sample-BGM playback and pops it from the BGM stack.
 * @ghidraAddress 0x1a83d4
 */
- (void)sampleStop;

/**
 * @brief Stops any playing sample and notifies the delegate to select this note for purchase.
 * @ghidraAddress 0x1a8508
 */
- (void)selectButton;

/**
 * @brief Puts the sample overlay into its stopped visual state.
 * @ghidraAddress 0x1a8628
 */
- (void)sampleViewStop;

/**
 * @brief Puts the sample overlay into its downloading visual state.
 * @ghidraAddress 0x1a8700
 */
- (void)sampleViewDownloading;

/**
 * @brief Puts the sample overlay into its playing visual state.
 * @ghidraAddress 0x1a87e4
 */
- (void)sampleViewPlaying;

/**
 * @brief Toggles the sample-BGM state in response to a tap on the artwork.
 * @ghidraAddress 0x1a88c0
 */
- (void)handleTapArtworkView;

/**
 * @brief Stops the sample when a foreground BGM-finished notification fires.
 * @param finishBgm The notification object.
 * @ghidraAddress 0x1a8b38
 */
- (void)finishBgm:(nullable id)finishBgm;

/**
 * @brief Retained hook for a queued item-info download. The shipped build does nothing.
 * @ghidraAddress 0x1a8dc4
 */
- (void)itemInfoDownload;

/**
 * @brief Puts the controller into its loading state.
 * @ghidraAddress 0x1aba24
 */
- (void)updateLayout;

/**
 * @brief Sets the action button to its "buy" state with the price title.
 * @ghidraAddress 0x1ac470
 */
- (void)setButtonTextBuy;

/**
 * @brief Sets the action button to its "install" state.
 * @ghidraAddress 0x1ac5fc
 */
- (void)setButtonTextInstall;

/**
 * @brief Sets the action button to its "installing" state.
 * @ghidraAddress 0x1ac6ac
 */
- (void)setButtonTextInstalling;

/**
 * @brief Sets the action button to its "installed" state.
 * @ghidraAddress 0x1ac75c
 */
- (void)setButtonTextInstalled;

/**
 * @brief Refreshes the action button text from the current note's ownership state.
 * @ghidraAddress 0x1ac80c
 */
- (void)selfCheckButtonText;

/**
 * @brief Pushes the terms-of-service screen onto the navigation stack.
 * @ghidraAddress 0x1aca50
 */
- (void)showTerm;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
