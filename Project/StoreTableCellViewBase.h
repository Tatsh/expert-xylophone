/** @file
 * The shared base view for a store table cell's product tile: a tappable background image view
 * carrying a "new" corner badge, a delegate selection callback, and a product-list index. Its
 * concrete subclasses fill in the tile content — @c StoreExtendNoteCellView for an extend-note
 * product and @c StorePackView for a song pack.
 *
 * Reconstructed from Ghidra project rb458, program rb458 (class @c StoreTableCellViewBase, image
 * base 0x100000000). @ghidraAddress values are offsets relative to the image base.
 */

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * @brief Selection callbacks a store table cell view sends to its delegate.
 *
 * The base view dispatches @c cellViewSelected: through @c performSelector:withObject:, so its
 * argument is passed untyped; the receiver narrows it to the concrete cell-view class.
 */
@protocol StoreTableCellViewBaseDelegate <NSObject>

@optional
/**
 * @brief A cell view was selected.
 * @param cellView The selected cell view.
 */
- (void)cellViewSelected:(nullable id)cellView;
/**
 * @brief A cell view's action button was pressed.
 * @param productIDNumber The boxed product identifier the button acts on.
 */
- (void)selectButton:(nullable NSNumber *)productIDNumber;

@end

/**
 * @brief The shared base view for a store table cell's product tile.
 */
@interface StoreTableCellViewBase : UIView

/**
 * @brief The delegate notified of selections.
 * @ghidraAddress 0x177d24 (getter)
 * @ghidraAddress 0x177d44 (setter)
 */
@property(nonatomic, weak, nullable) id<StoreTableCellViewBaseDelegate> delegate;
/**
 * @brief The product-list index this view displays.
 * @ghidraAddress 0x177d58 (getter)
 * @ghidraAddress 0x177d68 (setter)
 */
@property(nonatomic, assign) NSUInteger index;
/**
 * @brief The tappable background image view that hosts the tile content.
 * @ghidraAddress 0x177d78 (getter)
 * @ghidraAddress 0x177d88 (setter)
 */
@property(nonatomic, strong, nullable) UIImageView *backGroundImageView;
/**
 * @brief The "new" corner badge image view.
 * @ghidraAddress 0x177dc0 (getter)
 * @ghidraAddress 0x177dd0 (setter)
 */
@property(nonatomic, strong, nullable) UIImageView *iconNew;

/**
 * @brief Sets the view's background image on the background image view.
 * @param bgImage The background image.
 * @ghidraAddress 0x177ac0
 */
- (void)setBgImage:(nullable UIImage *)bgImage;
/**
 * @brief Shows or hides the "new" corner badge, bringing it to the front when shown.
 * @param isNew Whether the item is flagged as new.
 * @ghidraAddress 0x177b4c
 */
- (void)setIsNew:(BOOL)isNew;
/**
 * @brief Resets the tile content to its empty state.
 *
 * The base implementation is empty; subclasses override it to clear their own content.
 * @ghidraAddress 0x177d20
 */
- (void)reset;
/**
 * @brief Handles a tap on the tile and forwards it to the delegate.
 * @param recognizer The tap gesture recogniser.
 * @ghidraAddress 0x177c40
 */
- (void)handleTap:(nullable UITapGestureRecognizer *)recognizer;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
