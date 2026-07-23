/** @file
 * The pad two-up store list's pack tile: a single purchasable song pack rendered as a tile with a
 * jacket, name, comment, price, an owned-state overlay button, and "new" and "sequence-extension"
 * corner badges. It reports a tap to its delegate through the @c StorePackViewDelegate protocol.
 * The same delegate type is shared by the pack detail surfaces (@c RBStoreDetailViewController and
 * @c StorePackDetailViewPad), which send further informal messages listed below.
 *
 * Reconstructed from Ghidra project rb458, program rb458 (class @c StorePackView, image base
 * 0x100000000). @ghidraAddress values are offsets relative to the image base.
 */

#import <UIKit/UIKit.h>

@class StorePackInfo;
@class StorePackView;

NS_ASSUME_NONNULL_BEGIN

/**
 * @brief The messages a @c StorePackView and its detail surfaces send to their shared delegate.
 *
 * The compiled protocol in the binary declares a single optional method, @c packViewSelected:,
 * which is the only message @c StorePackView itself sends (from its tap handler). The remaining
 * methods are not part of the compiled @c protocol_t: they are informal delegate messages that the
 * pack detail surfaces (@c RBStoreDetailViewController and @c StorePackDetailViewPad) send to the
 * same @c id<StorePackViewDelegate> delegate through @c respondsToSelector: and
 * @c performSelector:. They are declared here so every collaborator shares one delegate type.
 */
@protocol StorePackViewDelegate <NSObject>

@optional

/**
 * @brief Sent when a pack tile is tapped.
 *
 * This is the only method in the binary's compiled @c StorePackViewDelegate protocol.
 * @param packView The tapped pack tile.
 */
- (void)packViewSelected:(StorePackView *)packView;

/**
 * @brief Sent by the pack detail surface when it should be dismissed.
 *
 * Informal: not part of the compiled protocol; sent by @c RBStoreDetailViewController.
 */
- (void)detailViewClose;

/**
 * @brief Sent by the pack detail surface to begin buying the given pack.
 *
 * Informal: not part of the compiled protocol; sent by @c RBStoreDetailViewController.
 * @param packInfo The pack to buy.
 */
- (void)detailViewStartPurchase:(StorePackInfo *)packInfo;

/**
 * @brief Sent by the pack detail surface to re-download an already-purchased pack's tunes.
 *
 * Informal: not part of the compiled protocol; sent by @c RBStoreDetailViewController.
 * @param packInfo The pack to re-download.
 */
- (void)reDownloadPackMusics:(StorePackInfo *)packInfo;

/**
 * @brief Sent by the pack detail surface to switch to the sequence-extension store for a tune.
 *
 * Informal: not part of the compiled protocol; sent by @c RBStoreDetailViewController.
 */
- (void)switchToSpecialStore;

@end

/**
 * @brief A single pack tile in the pad two-up store list.
 */
@interface StorePackView : UIView

/**
 * @brief The delegate notified when the tile is tapped.
 * @ghidraAddress 0xfefc0 (getter)
 * @ghidraAddress 0xfefe0 (setter)
 */
@property(nonatomic, weak, nullable) id<StorePackViewDelegate> delegate;

/**
 * @brief The flattened pack-list index this tile displays.
 *
 * Set by @c loadPackInfo:index:; the store page reads it back when routing a tap.
 * @ghidraAddress 0xfeff4 (getter)
 */
@property(nonatomic, assign, readonly) NSUInteger index;

/**
 * @brief The tile background image view, which also hosts the tap gesture recogniser.
 * @ghidraAddress 0xff004 (getter)
 * @ghidraAddress 0xff014 (setter)
 */
@property(nonatomic, strong, nullable) UIImageView *backGroundImageView;

/**
 * @brief The jacket artwork image view.
 * @ghidraAddress 0xff04c (getter)
 * @ghidraAddress 0xff05c (setter)
 */
@property(nonatomic, strong, nullable) UIImageView *artworkImageView;

/**
 * @brief The framed backing image view behind the jacket, showing the default jacket placeholder.
 * @ghidraAddress 0xff094 (getter)
 * @ghidraAddress 0xff0a4 (setter)
 */
@property(nonatomic, strong, nullable) UIImageView *artworkBackImageView;

/**
 * @brief The pack name label.
 * @ghidraAddress 0xff0dc (getter)
 * @ghidraAddress 0xff0ec (setter)
 */
@property(nonatomic, strong, nullable) UILabel *nameLabel;

/**
 * @brief The pack short-comment label.
 * @ghidraAddress 0xff124 (getter)
 * @ghidraAddress 0xff134 (setter)
 */
@property(nonatomic, strong, nullable) UILabel *commentLabel;

/**
 * @brief The pack price label.
 * @ghidraAddress 0xff16c (getter)
 * @ghidraAddress 0xff17c (setter)
 */
@property(nonatomic, strong, nullable) UILabel *priceLabel;

/**
 * @brief The owned-state overlay button, shown (as a disabled "installed" cover) once the pack is
 * purchased and hidden otherwise.
 * @ghidraAddress 0xff1b4 (getter)
 * @ghidraAddress 0xff1c4 (setter)
 */
@property(nonatomic, strong, nullable) UIButton *purchasedButton;

/**
 * @brief The "new" corner badge image view.
 *
 * The runtime property metadata types this @c CALayer, but the instance the binary stores is a
 * @c UIImageView (from @c initWithImage:) and the backing @c _iconNew ivar is typed
 * @c UIImageView; it is modelled here as the @c UIImageView it actually is.
 * @ghidraAddress 0xff1fc (getter)
 * @ghidraAddress 0xff20c (setter)
 */
@property(nonatomic, strong, nullable) UIImageView *iconNew;

/**
 * @brief The "sequence-extension" corner badge image view.
 * @ghidraAddress 0xff244 (getter)
 * @ghidraAddress 0xff254 (setter)
 */
@property(nonatomic, strong, nullable) UIImageView *iconSp;

/**
 * @brief Whether the pack is owned, expressed as the visibility of @c purchasedButton.
 *
 * The getter returns @c YES when @c purchasedButton is visible; the setter shows it when set to
 * @c YES. There is no backing ivar.
 * @ghidraAddress 0xfebd8 (getter)
 * @ghidraAddress 0xfec38 (setter)
 */
@property(nonatomic, assign, getter=isPurchased) BOOL purchased;

/**
 * @brief Sets the tile background image on @c backGroundImageView.
 * @param bgImage The background image.
 * @ghidraAddress 0xfe9e0
 */
- (void)setBgImage:(nullable UIImage *)bgImage;

/**
 * @brief Sets the jacket artwork on @c artworkImageView.
 * @param artwork The jacket image.
 * @ghidraAddress 0xfea6c
 */
- (void)setArtwork:(nullable UIImage *)artwork;

/**
 * @brief Populates the tile from the given pack and records its flattened list index.
 * @param loadPackInfo The pack to display.
 * @param index The flattened pack-list index.
 * @ghidraAddress 0xfec94
 */
- (void)loadPackInfo:(nullable StorePackInfo *)loadPackInfo index:(NSUInteger)index;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
