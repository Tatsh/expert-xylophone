/** @file
 * A single extend-note product view embedded in a pad pack-table cell (the left or right half of a
 * two-product row), and the base delegate protocol its selections are reported through.
 *
 * Minimal interface; the full class is reconstructed separately.
 *
 * Reconstructed from Ghidra project rb458, program rb458 (class @c StoreExtendNoteCellView, image
 * base 0x100000000). @ghidraAddress values are offsets relative to the image base.
 */

#import <UIKit/UIKit.h>

@class StoreExtendNoteInfo;

NS_ASSUME_NONNULL_BEGIN

/**
 * @brief Selection callbacks a store table cell view sends to its delegate.
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
 * @brief A single extend-note product view inside a pad pack-table cell.
 */
@interface StoreExtendNoteCellView : UIView

/**
 * @brief The delegate notified of selections.
 */
@property(nonatomic, weak, nullable) id<StoreTableCellViewBaseDelegate> delegate;
/**
 * @brief The product-list index this view displays.
 */
@property(nonatomic, assign) NSInteger index;

/**
 * @brief Loads the given extend-note record into the view at the given product-list index.
 * @param info The extend-note record to display.
 * @param index The product-list index of the record.
 */
- (void)loadExtendNoteInfo:(nullable StoreExtendNoteInfo *)info index:(NSInteger)index;
/**
 * @brief Sets the view's background image.
 * @param image The background image.
 */
- (void)setBgImage:(nullable UIImage *)image;
/**
 * @brief Sets the view's artwork image.
 * @param artwork The artwork image.
 */
- (void)setArtwork:(nullable UIImage *)artwork;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
