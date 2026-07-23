/** @file
 * The header view shown at the top of the phone-layout pack detail table: the pack artwork with its
 * reflection, the pack name and comment labels, the "new" marker, and the purchase button.
 *
 * Reconstructed from Ghidra project rb458, program rb458 (class @c StoreDetailHeaderView, image
 * base 0x100000000). @ghidraAddress values are offsets relative to the image base.
 */

#import <UIKit/UIKit.h>

@class StorePackInfo;

NS_ASSUME_NONNULL_BEGIN

/**
 * @brief The pack detail table header view.
 *
 * The view lays out, over the pack background, the pack artwork and a dimmed reflection of it, the
 * pack name and comment labels, a "new" badge, and the purchase button that reports taps to the
 * detail controller.
 */
@interface StoreDetailHeaderView : UIImageView

/**
 * @brief The pack name label, drawn top-right of the artwork.
 */
@property(nonatomic, strong, nullable) UILabel *labelName;

/**
 * @brief The pack long-form comment label, drawn below the name.
 */
@property(nonatomic, strong, nullable) UILabel *labelComment;

/**
 * @brief The purchase button that reports taps to the detail controller.
 */
@property(nonatomic, strong, nullable) UIButton *buttonPurchase;

/**
 * @brief The stretchable pack background image view filling the header.
 */
@property(nonatomic, strong, nullable) UIImageView *bgView;

/**
 * @brief The pack artwork image view.
 */
@property(nonatomic, strong, nullable) UIImageView *artworkView;

/**
 * @brief The dimmed reflection of the artwork drawn below it.
 */
@property(nonatomic, strong, nullable) UIImageView *reflectionArtworkView;

/**
 * @brief The "new" badge overlaid when the pack is newly listed.
 */
@property(nonatomic, strong, nullable) UIImageView *iconNewMarker;

/**
 * @brief Populate the name and comment labels and the "new" marker from the given pack.
 * @param info The pack to display.
 * @ghidraAddress 0xed47c
 */
- (void)loadPackInfo:(nullable StorePackInfo *)info;

/**
 * @brief Set the displayed pack artwork and regenerate its reflection.
 * @param artwork The artwork image.
 * @ghidraAddress 0xeda24
 */
- (void)setArtwork:(nullable UIImage *)artwork;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
