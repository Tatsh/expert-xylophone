/** @file
 * The full-screen news HUD overlay the music menu shows when a fresh news item is available. The
 * music-menu hub (@c RBMenuView) creates one over itself, hands it the news image URL and the
 * item's information identifier, and the HUD dims the screen, spins a loading indicator, downloads
 * the image through an @c ImageDownloader, and pops the finished image in with a scale keyframe
 * animation. Tapping the HUD, or a failed download, fades it back out and removes it; a successful
 * view records the item's identifier in @c RBUserSettingData so it is not shown again.
 *
 * Reconstructed from Ghidra project rb458, program rb458 (class @c RBNewsHUDView, image base
 * 0x100000000). @ghidraAddress values are offsets relative to the image base.
 */

#import <UIKit/UIKit.h>

#import "ImageDownloader.h"

NS_ASSUME_NONNULL_BEGIN

/**
 * @brief A tappable, dimming overlay that downloads and presents a single news image.
 *
 * The view fills its host, tinted with a half-translucent black cover, and installs a single-tap
 * gesture that dismisses it. While the news image downloads it shows a centred activity indicator;
 * once the image arrives it is added centred and given a scale-up keyframe animation, after which
 * the HUD becomes dismissible. It is its own @c ImageDownloader delegate: a load reveals the image
 * and persists the news information identifier, while a failure simply dismisses the HUD.
 */
@interface RBNewsHUDView : UIView <ImageDownloaderDelegate>

/**
 * @brief Create the news HUD with the given frame and build its subviews.
 * @param frame The view's frame rectangle.
 * @return The initialised view, or @c nil.
 * @ghidraAddress 0xbe3d4
 */
- (nullable instancetype)initWithFrame:(CGRect)frame;

/**
 * @brief Apply the dimming background, install the dismiss tap gesture, and add the centred
 * loading indicator.
 * @ghidraAddress 0xbe448
 */
- (void)setupView;

/**
 * @brief Fade the HUD in from fully transparent.
 * @ghidraAddress 0xbe5f0
 */
- (void)showAnimation;

/**
 * @brief Fade the HUD out and remove it from its superview. Ignored until the news image has
 * loaded.
 * @ghidraAddress 0xbe73c
 */
- (void)hideAnimation;

/**
 * @brief Dismiss tap-gesture handler: fade the HUD out.
 * @ghidraAddress 0xbe8a8
 */
- (void)tapped;

/**
 * @brief Begin downloading the news image, remembering its information identifier, and fade the
 * HUD in.
 * @param showImage The news image URL, as a string.
 * @param InfomationID The news item's information identifier, persisted once the image is shown.
 * @ghidraAddress 0xbe8b4
 */
- (void)showImage:(nullable NSString *)showImage InfomationID:(int)InfomationID;

/**
 * @brief @c ImageDownloader delegate callback: the news image loaded. Present it with a scale
 * animation, allow dismissal, and persist the information identifier when it is newer than the one
 * already stored.
 * @param imageDownloader The downloader that finished.
 * @param didLoad The downloader's table-view index path (unused here).
 * @ghidraAddress 0xbe99c
 */
- (void)imageDownloader:(nullable ImageDownloader *)imageDownloader
                didLoad:(nullable NSIndexPath *)didLoad;

/**
 * @brief @c ImageDownloader delegate callback: the news image failed to load. Allow dismissal and
 * fade the HUD out.
 * @param imageDownloaderDidFail The downloader that failed.
 * @param didLoad The downloader's table-view index path (unused here).
 * @ghidraAddress 0xbeff8
 */
- (void)imageDownloaderDidFail:(nullable ImageDownloader *)imageDownloaderDidFail
                       didLoad:(nullable NSIndexPath *)didLoad;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
