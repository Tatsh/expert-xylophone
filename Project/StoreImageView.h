/** @file
 * A store artwork image view that lazily downloads its image from a URL and can report whether the
 * image has finished loading.
 *
 * Minimal stub for the surface @c RBCampaignDetailViewController messages; the full class is
 * reconstructed separately. Reconstructed from Ghidra project rb458, program rb458 (class
 * @c StoreImageView, image base 0x100000000).
 */

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * @brief A store artwork image view backed by a remote URL.
 */
@interface StoreImageView : UIImageView

/**
 * @brief Sets the remote artwork URL to load.
 * @param imageURL The artwork URL string, or @c nil to clear.
 */
- (void)setImageURL:(nullable NSString *)imageURL;
/**
 * @brief Reports whether the artwork has finished loading.
 * @return @c YES once the image is available.
 */
- (BOOL)loadedImage;
/**
 * @brief Starts downloading the artwork from the configured URL.
 */
- (void)startDownloadImage;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
