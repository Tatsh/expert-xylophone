/**
 * @file
 * The header view shown at the top of the phone-layout pack detail table: the pack artwork
 * with its reflection, the pack name and comment labels, the "new" marker, and the purchase button.
 *
 * Reconstructed from Ghidra project rb458, program rb458 (class @c StoreDetailHeaderView, image
 * base 0x100000000). Ghidra addresses are offsets relative to the image base.
 */

#import <UIKit/UIKit.h>

@class StorePackInfo;

NS_ASSUME_NONNULL_BEGIN

/**
 * The pack detail table header view.
 *
 * The view lays out, over the pack background, the pack artwork and a dimmed reflection of it, the
 * pack name and comment labels, a "new" badge, and the purchase button that reports taps to the
 * detail controller.
 */
@interface StoreDetailHeaderView : UIImageView

/**
 * The pack name label, drawn top-right of the artwork.
 */
@property(nonatomic, strong, nullable) UILabel *labelName;

/**
 * The pack long-form comment label, drawn below the name.
 */
@property(nonatomic, strong, nullable) UILabel *labelComment;

/**
 * The purchase button that reports taps to the detail controller.
 */
@property(nonatomic, strong, nullable) UIButton *buttonPurchase;

/**
 * The stretchable pack background image view filling the header.
 */
@property(nonatomic, strong, nullable) UIImageView *bgView;

/**
 * The pack artwork image view.
 */
@property(nonatomic, strong, nullable) UIImageView *artworkView;

/**
 * The dimmed reflection of the artwork drawn below it.
 */
@property(nonatomic, strong, nullable) UIImageView *reflectionArtworkView;

/**
 * The "new" badge overlaid when the pack is newly listed.
 */
@property(nonatomic, strong, nullable) UIImageView *iconNewMarker;

/**
 * Populate the name and comment labels and the "new" marker from the given pack.
 * @param info The pack to display.
 * @ghidraAddress 0xed47c
 */
- (void)loadPackInfo:(nullable StorePackInfo *)info;

/**
 * Set the displayed pack artwork and regenerate its reflection.
 * @param artwork The artwork image.
 * @ghidraAddress 0xeda24
 */
- (void)setArtwork:(nullable UIImage *)artwork;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
