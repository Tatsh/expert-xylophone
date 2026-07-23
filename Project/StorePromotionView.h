/** @file
 * The rotating store promotion banner carousel and the delegate protocol it uses to report a pack
 * tap and the currently previewing sample tune. The view hosts a paging scroll view of banner
 * tiles (each a @c BannerView built from a promotion dictionary), advances them on a timer,
 * downloads each banner image and sample tune, and previews the sample through @c RBBGMManager.
 *
 * Reconstructed from Ghidra project rb458, program rb458 (class @c StorePromotionView, image base
 * 0x100000000). @ghidraAddress values are offsets relative to the image base.
 */

#import <UIKit/UIKit.h>

#import "Downloader.h"
#import "ImageDownloader.h"

@class BannerView;
@class PagingScrollView;
@class StorePromotionView;

NS_ASSUME_NONNULL_BEGIN

/**
 * @brief Callbacks a @c StorePromotionView sends to its delegate.
 *
 * Both are declared @c \@optional in the binary's protocol.
 */
@protocol StorePromotionViewDelegate <NSObject>

@optional

/**
 * @brief Sent when a promotion banner naming a pack is tapped.
 * @param promotionView The tapped promotion view.
 * @param packId The pack identifier the banner names.
 */
- (void)storePromotionViewTaped:(StorePromotionView *)promotionView PackID:(int)packId;

/**
 * @brief Sent when the previewing sample tune changes, naming the tune now playing.
 * @param name The tune name now previewing, or @c nil when preview stops.
 */
- (void)setPlaySampleName:(nullable NSString *)name;

@end

/**
 * @brief The rotating store promotion banner carousel shown above the pack list.
 */
@interface StorePromotionView
    : UIView <UIScrollViewDelegate, ImageDownloaderDelegate, DownloaderDelegate>

#pragma mark - Properties

/**
 * @brief The paging scroll view that holds the banner tiles.
 */
@property(nonatomic, strong, nullable) PagingScrollView *scrollView;
/**
 * @brief The width of a single banner page.
 */
@property(nonatomic, assign) CGFloat pageWidth;
/**
 * @brief The horizontal inset of the paging scroll view from the view's leading edge.
 */
@property(nonatomic, assign) CGFloat pageOffsetX;
/**
 * @brief The banner tile's origin offset within the view.
 */
@property(nonatomic, assign) CGPoint bannerOffset;
/**
 * @brief The activity indicator shown until the first banner image loads.
 */
@property(nonatomic, strong, nullable) UIActivityIndicatorView *indicator;
/**
 * @brief The timer that advances the carousel to the next page.
 */
@property(nonatomic, strong, nullable) NSTimer *timer;
/**
 * @brief The banner tile views, one per page (with two extra wrap-around copies).
 */
@property(nonatomic, strong, nullable) NSMutableArray<BannerView *> *bannerViewArray;
/**
 * @brief The promotion dictionaries backing the banners, keyed by @c ID, @c ImageURL, @c Name,
 * @c SampleURL, and @c image.
 */
@property(nonatomic, strong, nullable) NSMutableArray<NSDictionary *> *promotionDataArray;
/**
 * @brief The in-flight banner-image downloaders.
 */
@property(nonatomic, strong, nullable) NSMutableArray<ImageDownloader *> *imageDownloader;
/**
 * @brief The in-flight sample-tune downloaders, keyed by pack identifier.
 */
@property(nonatomic, strong, nullable)
    NSMutableDictionary<NSString *, Downloader *> *sampleDownloader;
/**
 * @brief The delegate notified of banner taps and sample-preview changes.
 */
@property(nonatomic, weak, nullable) id<StorePromotionViewDelegate> delegate;
/**
 * @brief Whether the view may start sample playback.
 */
@property(nonatomic, assign) BOOL isSamplePlayable;

#pragma mark - Setup

/**
 * @brief Initialise the carousel and build its scroll view and downloader collections.
 * @param frame The initial frame.
 * @return The initialised view.
 * @ghidraAddress 0x1000ffbbc
 */
- (nullable instancetype)initWithFrame:(CGRect)frame;

#pragma mark - Image and data

/**
 * @brief Set the banner promotion dictionaries and build the banner tiles and downloaders.
 * @param imageURLs The promotion dictionaries to display, or @c nil.
 * @ghidraAddress 0x1001009e8
 */
- (void)setImageURLs:(nullable NSArray<NSDictionary *> *)imageURLs;

/**
 * @brief The number of promotion pages.
 * @return The promotion page count.
 * @ghidraAddress 0x100101924
 */
- (NSUInteger)getImageCount;

/**
 * @brief The pack identifier the currently centred banner names.
 * @return The pack identifier, or @c -1 when the current page is out of range or unnamed.
 * @ghidraAddress 0x1001008cc
 */
- (int)getPackID;

#pragma mark - Animation

/**
 * @brief Start the carousel: preview the current banner's sample and schedule the page timer.
 * @ghidraAddress 0x100102b04
 */
- (void)startAnimation;
/**
 * @brief Stop the carousel by invalidating the page timer.
 * @ghidraAddress 0x100103048
 */
- (void)stopAnimation;
/**
 * @brief Advance the carousel to the next page, previewing its sample tune.
 * @ghidraAddress 0x100101984
 */
- (void)setNext;

#pragma mark - Sample playback

/**
 * @brief Begin sample playback by (re)starting the carousel.
 * @ghidraAddress 0x100102a14
 */
- (void)startSamplePlay;
/**
 * @brief Stop sample playback, stopping and popping any pushed preview BGM.
 * @ghidraAddress 0x100102a20
 */
- (void)stopSamplePlay;

#pragma mark - Rotation and teardown

/**
 * @brief React to an interface rotation, re-laying the scroll view for the new view width.
 * @param width The new view width.
 * @ghidraAddress 0x100103c6c
 */
- (void)scrollViewDidRotate:(float)width;

/**
 * @brief Tear down the carousel: cancel every downloader, stop preview, and detach the scroll view.
 * @ghidraAddress 0x100100138
 */
- (void)cancel;

/**
 * @brief Resize the banner image view to match a new host size.
 *
 * An empty stub in the binary: no image-view resize is applied. The hosting
 * @c StorePromotionTableCell sends this from its @c -layoutSubviews.
 * @param imageViewSize The new size, in points.
 * @ghidraAddress 0x1001008c8
 */
- (void)setImageViewSize:(CGSize)imageViewSize;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
