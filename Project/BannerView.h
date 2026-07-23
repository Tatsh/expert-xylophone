/** @file
 * A single store promotion banner tile: an image with an associated pack and optional sample tune.
 * This is a minimal stub declaring only the surface @c StorePromotionView relies on; the full class
 * is reconstructed separately.
 *
 * Reconstructed from Ghidra project rb458, program rb458 (class @c BannerView, image base
 * 0x100000000). @ghidraAddress values are offsets relative to the image base.
 */

#import <UIKit/UIKit.h>

@class StorePackInfo;

NS_ASSUME_NONNULL_BEGIN

/**
 * @brief A store promotion banner tile.
 */
@interface BannerView : UIView

/**
 * @brief The banner artwork image view.
 */
@property(nonatomic, strong, nullable) UIImageView *imageView;
/**
 * @brief The pack the banner names.
 */
@property(nonatomic, strong, nullable) StorePackInfo *packInfo;
/**
 * @brief The downloaded sample tune bytes, or @c nil until the sample downloads.
 */
@property(nonatomic, copy, nullable) NSData *sampleData;
/**
 * @brief The sample tune name shown while previewing.
 */
@property(nonatomic, copy, nullable) NSString *musicName;
/**
 * @brief The corner radius applied to the banner tile.
 */
@property(nonatomic, assign) CGFloat cornerRadius;

/**
 * @brief Whether this banner is currently previewing its sample tune.
 * @return @c YES while previewing.
 */
- (BOOL)getIsSamplePlaying;
/**
 * @brief Mark the banner as previewing its sample tune.
 */
- (void)startSamplePlay;
/**
 * @brief Mark the banner as no longer previewing its sample tune.
 */
- (void)stopSamplePlay;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
