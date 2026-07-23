/** @file
 * The phone-layout single-product extend-note table cell. Each row shows one purchasable
 * extend-note item: a jacket drawn as a shadowed @c CALayer, a name label, an artist label, a
 * level label, a right-aligned purchased/price label, and a "new" corner badge. The jacket artwork
 * itself is supplied by @c RBStoreExtendPageViewController, which sets @c artworkLayer.contents
 * directly. Used by @c RBStoreExtendPageViewController on the phone layout (the pad layout uses
 * @c StoreExtendNoteCell and @c StoreExtendNoteCellView instead). It is the phone-specific sibling
 * of @c StoreExtendNoteCellView, sharing the same product presentation but built as a
 * @c UITableViewCell rather than an embedded @c UIView.
 *
 * Reconstructed from Ghidra project rb458, program rb458 (class @c StoreExtendNoteCellPhone, image
 * base 0x100000000). @ghidraAddress values are offsets relative to the image base.
 */

#import <QuartzCore/QuartzCore.h>
#import <UIKit/UIKit.h>

@class StoreExtendNoteInfo;

NS_ASSUME_NONNULL_BEGIN

/**
 * @brief The phone-layout single-product extend-note table cell.
 */
@interface StoreExtendNoteCellPhone : UITableViewCell

/**
 * @brief The layer that holds the product jacket artwork; its @c contents is set by the store
 * page.
 * @ghidraAddress 0x1c2030 (getter)
 * @ghidraAddress 0x1c2040 (setter)
 */
@property(nonatomic, strong, nullable) CALayer *artworkLayer;

/**
 * @brief The stretchable background image view behind the cell, installed as its background view.
 * @ghidraAddress 0x1c2078 (getter)
 * @ghidraAddress 0x1c2088 (setter)
 */
@property(nonatomic, strong, nullable) UIImageView *bgImageView;

/**
 * @brief The product name label.
 * @ghidraAddress 0x1c20c0 (getter)
 * @ghidraAddress 0x1c20d0 (setter)
 */
@property(nonatomic, strong, nullable) UILabel *nameLabel;

/**
 * @brief The product artist label.
 * @ghidraAddress 0x1c2108 (getter)
 * @ghidraAddress 0x1c2118 (setter)
 */
@property(nonatomic, strong, nullable) UILabel *artistLabel;

/**
 * @brief The comment label. Declared in the class metadata but never synthesised: it has no
 * backing ivar and no accessors in the binary, so it is exposed as a @c dynamic property to match.
 */
@property(nonatomic, strong, nullable) UILabel *commentLabel;

/**
 * @brief The chart-level label, showing the extend note's difficulty level.
 * @ghidraAddress 0x1c2150 (getter)
 * @ghidraAddress 0x1c2160 (setter)
 */
@property(nonatomic, strong, nullable) UILabel *levelLabel;

/**
 * @brief The right-aligned purchased/price label, which shows the price while the item is
 * purchasable and is blanked once the item's archive is downloaded or installed.
 * @ghidraAddress 0x1c2198 (getter)
 * @ghidraAddress 0x1c21a8 (setter)
 */
@property(nonatomic, strong, nullable) UILabel *purchasedLabel;

/**
 * @brief The "new" corner badge layer, whose @c contents holds the badge image.
 * @ghidraAddress 0x1c21e0 (getter)
 * @ghidraAddress 0x1c21f0 (setter)
 */
@property(nonatomic, strong, nullable) CALayer *iconNewLayer;

/**
 * @brief Whether the item is owned, expressed as the visibility of @c purchasedLabel.
 *
 * The getter returns @c YES when @c purchasedLabel is visible; the setter shows it when set to
 * @c YES. There is no backing ivar.
 * @ghidraAddress 0x1c1b78 (getter)
 * @ghidraAddress 0x1c1bd8 (setter)
 */
@property(nonatomic, assign, getter=isPurchased) BOOL purchased;

/**
 * @brief Populates the cell's labels and "new" badge from the given extend-note item.
 *
 * The name, artist, and level labels are filled from the item, the "new" badge is shown when the
 * item is flagged new, and the purchased label is revealed and set to the item's price while the
 * item is purchasable, blanked once its archive is downloaded or installed, and left untouched in
 * the error state. The jacket artwork is not set here; the store page assigns
 * @c artworkLayer.contents separately.
 * @param loadExtendNoteInfo The extend-note item to display.
 * @param index The product-list index of the item. Accepted for parity with the pad cell but
 * unused.
 * @ghidraAddress 0x1c1c34
 */
- (void)loadExtendNoteInfo:(nullable StoreExtendNoteInfo *)loadExtendNoteInfo
                     index:(NSInteger)index;

/**
 * @brief Sets the cell background image on @c bgImageView.
 * @param bgImage The background image.
 * @ghidraAddress 0x1c1fa0
 */
- (void)setBgImage:(nullable UIImage *)bgImage;

/**
 * @brief Sets the cell background tint. This is a no-op in the phone cell; it is accepted only for
 * call-site parity with the pad layout.
 * @param bgColor The background tint colour.
 * @ghidraAddress 0x1c202c
 */
- (void)setBgColor:(nullable UIColor *)bgColor;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
