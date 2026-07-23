/** @file
 * The header view shown at the top of the phone-layout pack detail table: pack artwork and the
 * purchase button. This is a minimal stub declaring only the surface
 * @c RBStoreDetailViewController relies on; the full view class is reconstructed separately.
 *
 * Reconstructed from Ghidra project rb458, program rb458 (class @c StoreDetailHeaderView, image
 * base 0x100000000). @ghidraAddress values are offsets relative to the image base.
 */

#import <UIKit/UIKit.h>

@class StorePackInfo;

NS_ASSUME_NONNULL_BEGIN

/**
 * @brief The pack detail table header view.
 */
@interface StoreDetailHeaderView : UIImageView

/**
 * @brief The purchase button that reports taps to the detail controller.
 */
@property(nonatomic, strong, nullable) UIButton *buttonPurchase;

/**
 * @brief Populate the header from the given pack.
 * @param info The pack to display.
 */
- (void)loadPackInfo:(nullable StorePackInfo *)info;

/**
 * @brief Set the displayed pack artwork.
 * @param artwork The artwork image.
 */
- (void)setArtwork:(nullable UIImage *)artwork;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
