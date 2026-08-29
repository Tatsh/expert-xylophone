/**
 * @file
 * A single store promotion banner tile: an image with an associated pack and optional
 * sample tune.
 *
 * Used by the store promotion carousel (@c StorePromotionView) inside its paging scroll view.
 *
 * Reconstructed from Ghidra project rb458, program rb458 (class @c BannerView, image base
 * 0x100000000). Ghidra addresses are offsets relative to the image base.
 */

#import <UIKit/UIKit.h>

@class StorePackInfo;

NS_ASSUME_NONNULL_BEGIN

/**
 * A store promotion banner tile.
 */
@interface BannerView : UIView

/**
 * The banner artwork image view.
 */
@property(nonatomic, strong, nullable) UIImageView *imageView;
/**
 * The pack the banner names.
 */
@property(nonatomic, strong, nullable) StorePackInfo *packInfo;
/**
 * The downloaded sample tune bytes, or @c nil until the sample downloads.
 */
@property(nonatomic, strong, nullable) NSData *sampleData;
/**
 * The sample tune name shown while previewing.
 */
@property(nonatomic, strong, nullable) NSString *musicName;
/**
 * Whether this banner is currently previewing its sample tune.
 */
@property(nonatomic, assign) BOOL isSamplePlaying;
/**
 * Whether this banner is waiting to be removed from the carousel.
 */
@property(nonatomic, assign) BOOL isRemoveWaiting;

/**
 * Set the corner radius applied to both the tile and its artwork layer.
 * @param cornerRadius The corner radius, in points.
 * @ghidraAddress 0xff910
 */
- (void)setCornerRadius:(CGFloat)cornerRadius;
/**
 * Whether this banner is currently previewing its sample tune.
 * @return @c YES while previewing.
 * @ghidraAddress 0xff9e8
 */
- (BOOL)getIsSamplePlaying;
/**
 * Mark the banner as previewing its sample tune.
 * @ghidraAddress 0xff9c8
 */
- (void)startSamplePlay;
/**
 * Mark the banner as no longer previewing its sample tune.
 * @ghidraAddress 0xff9d8
 */
- (void)stopSamplePlay;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
