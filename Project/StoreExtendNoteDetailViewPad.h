/**
 * @file
 * The pad note-detail overlay view, shown over a dimming cover to present a single extend
 * note's detail, sample, and purchase controls.
 *
 * It is the pad-layout counterpart to
 * @c RBStoreExtendNoteDetailViewController.
 *
 * Reconstructed from Ghidra project rb458, program rb458 (class @c StoreExtendNoteDetailViewPad,
 * image base 0x100000000). Ghidra addresses are offsets relative to the image base.
 */

#import <UIKit/UIKit.h>

#import "Downloader.h"

@class Downloader;
@class StoreButtonView;
@class StoreExtendNoteInfo;
@class StoreImageView;

NS_ASSUME_NONNULL_BEGIN

/**
 * The pad note-detail overlay view.
 *
 * This is the note-detail card presented by @c RBStoreExtendPageViewController on the pad layout
 * (the phone layout pushes @c RBStoreExtendNoteDetailViewController instead). It conforms to the
 * sample-audio downloader's @c DownloaderDelegate protocol.
 */
@interface StoreExtendNoteDetailViewPad : UIView <DownloaderDelegate>

/**
 * The delegate that receives detail-view actions (the hosting page controller).
 *
 * The view messages the delegate through @c performSelector: with @c selectButton:,
 * @c detailViewClose, and @c showTerms, so it is modelled as an untyped weak reference.
 */
@property(nonatomic, weak, nullable) id delegate;
/**
 * The extend-note record being displayed.
 */
@property(nonatomic, strong, nullable) StoreExtendNoteInfo *noteInfo;
/**
 * The card that hosts the artwork, labels, and purchase button.
 */
@property(nonatomic, strong, nullable) UIView *noteView;
/**
 * The bold title label shown at the top of the card.
 */
@property(nonatomic, strong, nullable) UILabel *labelTitle;
/**
 * The tappable jacket artwork, which doubles as the sample-BGM control.
 */
@property(nonatomic, strong, nullable) StoreImageView *artworkView;
/**
 * The music-name label.
 */
@property(nonatomic, strong, nullable) UILabel *labelMusicName;
/**
 * The artist-name label.
 */
@property(nonatomic, strong, nullable) UILabel *labelArtistName;
/**
 * The difficulty-level label.
 */
@property(nonatomic, strong, nullable) UILabel *labelLevel;
/**
 * A label declared by the binary, unused in the shipped flow.
 */
@property(nonatomic, strong, nullable) UILabel *labelID;
/**
 * The copyright text view inside the detail card.
 */
@property(nonatomic, strong, nullable) UITextView *copyrightView;
/**
 * The purchase / download action button.
 */
@property(nonatomic, strong, nullable) StoreButtonView *downloadBtn;
/**
 * The external-link action button.
 */
@property(nonatomic, strong, nullable) StoreButtonView *linkBtn;
/**
 * The active campaign identifier, or @c -1 when no note is loaded.
 */
@property(nonatomic, assign) int campaignID;
/**
 * The in-flight sample-BGM downloader.
 */
@property(nonatomic, strong, nullable) Downloader *sampleDownloader;
/**
 * A general-purpose activity indicator (declared by the binary).
 */
@property(nonatomic, strong, nullable) UIActivityIndicatorView *indicator;
/**
 * A loading label (declared by the binary).
 */
@property(nonatomic, strong, nullable) UILabel *labelLoading;
/**
 * The tappable sample-BGM button overlaid on the artwork.
 */
@property(nonatomic, strong, nullable) UIButton *sampleBtn;
/**
 * The "now playing" glyph shown over the artwork while a sample plays.
 */
@property(nonatomic, strong, nullable) UIImageView *playingView;
/**
 * The scrolling container that hosts the banner, description, and copyright.
 */
@property(nonatomic, strong, nullable) UIScrollView *detailView;
/**
 * The rounded banner image view inside the detail card.
 */
@property(nonatomic, strong, nullable) StoreImageView *bannerView;
/**
 * The description text view inside the detail card.
 */
@property(nonatomic, strong, nullable) UITextView *descriptionTextView;
/**
 * The spinner shown over the sample button while a sample downloads.
 */
@property(nonatomic, strong, nullable) UIActivityIndicatorView *indicatorSample;

/**
 * Loads the given extend-note record into the detail view, refreshing every label, the
 * artwork, and the action button, or clears the labels and artwork when @p info is @c nil.
 * @param info The extend-note record to display, or @c nil to clear.
 * @ghidraAddress 0x2600c
 */
- (void)setInfo:(nullable StoreExtendNoteInfo *)info;

/**
 * Reveals the loaded note's detail card and starts the artwork download.
 * @ghidraAddress 0x2563c
 */
- (void)showNoteInfo;

/**
 * Clears the currently displayed note, hiding every subview and cancelling any downloads.
 * @ghidraAddress 0x24b78
 */
- (void)removeNoteInfo;

/**
 * Cancels any in-flight detail loading. The shipped build does nothing.
 * @ghidraAddress 0x24f68
 */
- (void)cancelLoading;

/**
 * Stops the sample-BGM playback and pops it from the BGM stack.
 * @ghidraAddress 0x24f6c
 */
- (void)stopSample;

/**
 * Sets the action button to its "installing" state.
 * @ghidraAddress 0x26824
 */
- (void)setButtonTextInstalling;

/**
 * Sets the action button to its "installed" state.
 * @ghidraAddress 0x268d4
 */
- (void)setButtonTextInstalled;

/**
 * Refreshes the action button colour, title, and enabled state from the current note's
 * ownership state.
 * @ghidraAddress 0x26984
 */
- (void)selfCheckButtonText;

/**
 * Retained hook that records the download flag. The shipped build ignores the value.
 * @param downloadFlag The requested download flag.
 * @ghidraAddress 0x26424
 */
- (void)setDownloadFlag:(BOOL)downloadFlag;

/**
 * Reports whether the given music item's purchased music file exists on disk.
 * @param hasItem A zero flag selecting the existence check.
 * @param itemID The music identifier to test.
 * @return @c YES when the item's purchased music file exists on disk.
 * @ghidraAddress 0x26428
 */
- (BOOL)hasItem:(int)hasItem itemID:(int)itemID;

/**
 * Sets the loaded artwork image, sizing the artwork view and fading it in.
 * @param artwork The downloaded artwork image.
 * @ghidraAddress 0x2655c
 */
- (void)setArtwork:(nullable UIImage *)artwork;

/**
 * Returns the artwork inset used when the artwork is square (jacket-sized).
 * @param getArtworkMargin The iPad idiom flag selecting the layout.
 * @return The artwork origin inset.
 * @ghidraAddress 0x2653c
 */
- (CGSize)getArtworkMargin:(BOOL)getArtworkMargin;

/**
 * Returns the artwork size used when the artwork is not square (banner-sized).
 * @param getItemSize The iPad idiom flag selecting the layout.
 * @return The artwork size.
 * @ghidraAddress 0x26548
 */
- (CGSize)getItemSize:(BOOL)getItemSize;

/**
 * Puts the sample overlay into its stopped visual state.
 * @ghidraAddress 0x2534c
 */
- (void)sampleViewStop;

/**
 * Puts the sample overlay into its downloading visual state.
 * @ghidraAddress 0x25444
 */
- (void)sampleViewDownloading;

/**
 * Puts the sample overlay into its playing visual state.
 * @ghidraAddress 0x25540
 */
- (void)sampleViewPlaying;

/**
 * Toggles the sample-BGM state in response to a tap on the sample button.
 * @ghidraAddress 0x250d4
 */
- (void)pushSampleBtn;

/**
 * Notifies the delegate to select this note for purchase in response to the action button.
 * @param pushCellButton The button that fired the event.
 * @ghidraAddress 0x25860
 */
- (void)pushCellButton:(nullable id)pushCellButton;

/**
 * Handles a tap on the external-link button. The shipped build does nothing.
 * @param pushLink The button that fired the event.
 * @ghidraAddress 0x2585c
 */
- (void)pushLink:(nullable id)pushLink;

/**
 * Pushes the terms-of-service screen by notifying the delegate.
 * @ghidraAddress 0x259e0
 */
- (void)showTerm;

/**
 * Stops the sample when a foreground BGM-finished notification fires.
 * @param finishBgm The notification object.
 * @ghidraAddress 0x259c4
 */
- (void)finishBgm:(nullable id)finishBgm;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
