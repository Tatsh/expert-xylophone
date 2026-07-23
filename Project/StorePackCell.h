/** @file
 * The phone-layout single-pack table cell. Each row shows one purchasable song pack: a jacket
 * drawn as a shadowed @c CALayer, a name label, a price label, a right-aligned "installed" label
 * that stands in for the owned-state overlay, and "new" and "sequence-extension" corner badges.
 * The jacket artwork itself is supplied by @c RBStorePageViewController, which sets
 * @c artworkView.contents directly. Used by @c RBStorePageViewController on the phone layout (the
 * pad layout uses @c StoreTableCell and @c StorePackView instead).
 *
 * Reconstructed from Ghidra project rb458, program rb458 (class @c StorePackCell, image base
 * 0x100000000). @ghidraAddress values are offsets relative to the image base.
 */

#import <UIKit/UIKit.h>

@class StorePackInfo;

NS_ASSUME_NONNULL_BEGIN

/**
 * @brief The phone-layout single-pack table cell.
 */
@interface StorePackCell : UITableViewCell

/**
 * @brief The layer that holds the pack jacket artwork; its @c contents is set by the store page.
 * @ghidraAddress 0xf5a1c (getter)
 * @ghidraAddress 0xf5a2c (setter)
 */
@property(nonatomic, strong, nullable) CALayer *artworkView;

/**
 * @brief The stretchable background image view behind the cell, installed as its background view.
 * @ghidraAddress 0xf5a64 (getter)
 * @ghidraAddress 0xf5a74 (setter)
 */
@property(nonatomic, strong, nullable) UIImageView *bgView;

/**
 * @brief The pack name label.
 * @ghidraAddress 0xf5aac (getter)
 * @ghidraAddress 0xf5abc (setter)
 */
@property(nonatomic, strong, nullable) UILabel *labelName;

/**
 * @brief The pack price label.
 * @ghidraAddress 0xf5af4 (getter)
 * @ghidraAddress 0xf5b04 (setter)
 */
@property(nonatomic, strong, nullable) UILabel *labelPrice;

/**
 * @brief The right-aligned owned-state label, shown once the pack is purchased and hidden
 * otherwise. Its visibility backs the @c purchased state.
 * @ghidraAddress 0xf5b3c (getter)
 * @ghidraAddress 0xf5b4c (setter)
 */
@property(nonatomic, strong, nullable) UILabel *labelPurchased;

/**
 * @brief The "new" corner badge layer, whose @c contents holds the badge image.
 * @ghidraAddress 0xf5b84 (getter)
 * @ghidraAddress 0xf5b94 (setter)
 */
@property(nonatomic, strong, nullable) CALayer *iconNew;

/**
 * @brief The "sequence-extension" corner badge image view.
 * @ghidraAddress 0xf5bcc (getter)
 * @ghidraAddress 0xf5bdc (setter)
 */
@property(nonatomic, strong, nullable) UIImageView *iconSp;

/**
 * @brief Whether the pack is owned, expressed as the visibility of @c labelPurchased.
 *
 * The getter returns @c YES when @c labelPurchased is visible; the setter shows it when set to
 * @c YES. There is no backing ivar.
 * @ghidraAddress 0xf5528 (getter)
 * @ghidraAddress 0xf5588 (setter)
 */
@property(nonatomic, assign, getter=isPurchased) BOOL purchased;

/**
 * @brief Sets the cell background image on @c bgView.
 * @param bgImage The background image.
 * @ghidraAddress 0xf5898
 */
- (void)setBgImage:(nullable UIImage *)bgImage;

/**
 * @brief Sets the label background tint on the name, price, and owned-state labels.
 * @param bgColor The background tint colour.
 * @ghidraAddress 0xf5924
 */
- (void)setBgColor:(nullable UIColor *)bgColor;

/**
 * @brief Populates the cell's labels and corner badges from the given pack.
 *
 * The jacket artwork is not set here; the store page assigns @c artworkView.contents separately.
 * @param loadPackInfo The pack to display.
 * @ghidraAddress 0xf55e4
 */
- (void)loadPackInfo:(nullable StorePackInfo *)loadPackInfo;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
