/** @file
 * A store artwork image view that lazily downloads its image from a URL and fades it in once the
 * download finishes.
 *
 * The view is a @c UIImageView subclass that hosts two child image views: a @c backgroundView that
 * shows a placeholder jacket, and a foreground @c imageView that starts fully transparent and is
 * faded in when the remote artwork arrives. Downloading is delegated to an @c ImageDownloader, whose
 * completion callbacks arrive through the adopted @c ImageDownloaderDelegate protocol.
 *
 * Reconstructed from Ghidra project rb458, program rb458 (class @c StoreImageView, image base
 * 0x100000000). @ghidraAddress values are offsets relative to the image base.
 */

#import <UIKit/UIKit.h>

#import "ImageDownloader.h"

NS_ASSUME_NONNULL_BEGIN

/**
 * @brief A store artwork image view backed by a remote URL, with a placeholder and a fade-in.
 */
@interface StoreImageView : UIImageView <ImageDownloaderDelegate>

/**
 * @brief The remote artwork URL to load, as a string.
 * @ghidraAddress 0xf4300 (getter)
 * @ghidraAddress 0xf4310 (setter)
 */
@property(nonatomic, strong, nullable) NSString *imageURL;
/**
 * @brief The downloader driving the current artwork fetch, or @c nil when idle.
 * @ghidraAddress 0xf4348 (getter)
 * @ghidraAddress 0xf4358 (setter)
 */
@property(nonatomic, strong, nullable) ImageDownloader *imageDownloader;
/**
 * @brief The background child image view that shows the placeholder jacket.
 * @ghidraAddress 0xf4390 (getter)
 * @ghidraAddress 0xf43a0 (setter)
 */
@property(nonatomic, strong, nullable) UIImageView *backgroundView;
/**
 * @brief The foreground child image view that shows the downloaded artwork.
 * @ghidraAddress 0xf43d8 (getter)
 * @ghidraAddress 0xf43e8 (setter)
 */
@property(nonatomic, strong, nullable) UIImageView *imageView;

/**
 * @brief Starts downloading the artwork from the configured @c imageURL.
 *
 * Does nothing when @c imageURL is @c nil or a download is already in flight.
 * @ghidraAddress 0xf3b44
 */
- (void)startDownloadImage;
/**
 * @brief Reports whether the foreground artwork has finished loading.
 * @return @c YES once the downloaded image is present.
 * @ghidraAddress 0xf3e90
 */
- (BOOL)loadedImage;
/**
 * @brief Cancels any in-flight download and shows the given image in the foreground view.
 * @param image The image to display, or @c nil to clear it.
 * @ghidraAddress 0xf3cec
 */
- (void)unloadImage:(nullable UIImage *)image;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
