/** @file
 * A single extend-note product view embedded in a pad pack-table cell (the left or right half of a
 * two-product row). It lays out the tune artwork, its name, artist, comment, and difficulty level,
 * and a purchased/price overlay label, on top of the tappable background inherited from
 * @c StoreTableCellViewBase. Its selections are reported through the base
 * @c StoreTableCellViewBaseDelegate protocol.
 *
 * The binary class is @c StoreExtendNoteView; this project names it @c StoreExtendNoteCellView to
 * distinguish it from the phone-layout @c StoreExtendNoteCellPhone. It is messaged by
 * @c StoreExtendNoteCell and @c RBStoreExtendPageViewController.
 *
 * Reconstructed from Ghidra project rb458, program rb458 (class @c StoreExtendNoteView, image base
 * 0x100000000). @ghidraAddress values are offsets relative to the image base.
 */

#import <UIKit/UIKit.h>

#import "StoreTableCellViewBase.h"

@class StoreExtendNoteInfo;

NS_ASSUME_NONNULL_BEGIN

/**
 * @brief A single extend-note product view inside a pad pack-table cell.
 */
@interface StoreExtendNoteCellView : StoreTableCellViewBase

/**
 * @brief The tune artwork image view.
 * @ghidraAddress 0x4d058 (getter)
 * @ghidraAddress 0x4d068 (setter)
 */
@property(nonatomic, strong, nullable) UIImageView *artworkImageView;
/**
 * @brief The shadowed backing plate shown behind the artwork.
 * @ghidraAddress 0x4d0a0 (getter)
 * @ghidraAddress 0x4d0b0 (setter)
 */
@property(nonatomic, strong, nullable) UIImageView *artworkBackImageView;
/**
 * @brief The tune name label.
 * @ghidraAddress 0x4d0e8 (getter)
 * @ghidraAddress 0x4d0f8 (setter)
 */
@property(nonatomic, strong, nullable) UILabel *nameLabel;
/**
 * @brief The tune artist label.
 * @ghidraAddress 0x4d130 (getter)
 * @ghidraAddress 0x4d140 (setter)
 */
@property(nonatomic, strong, nullable) UILabel *artistLabel;
/**
 * @brief The tune comment label.
 * @ghidraAddress 0x4d158 (getter)
 * @ghidraAddress 0x4d188 (setter)
 */
@property(nonatomic, strong, nullable) UILabel *commentLabel;
/**
 * @brief The difficulty-level label.
 * @ghidraAddress 0x4d1a0 (getter)
 * @ghidraAddress 0x4d1d0 (setter)
 */
@property(nonatomic, strong, nullable) UILabel *levelLabel;
/**
 * @brief The purchased/price overlay label.
 * @ghidraAddress 0x4d1d8 (getter)
 * @ghidraAddress 0x4d208 (setter)
 */
@property(nonatomic, strong, nullable) UILabel *purchasedLabel;
/**
 * @brief An informational deep link associated with the item, when present.
 * @ghidraAddress 0x4d250 (getter)
 * @ghidraAddress 0x4d260 (setter)
 */
@property(nonatomic, strong, nullable) NSString *linkURL;
/**
 * @brief Whether the extend note is purchased, derived from the purchased-label visibility.
 * @ghidraAddress 0x4cb68 (getter)
 * @ghidraAddress 0x4cbc8 (setter)
 */
@property(nonatomic, assign) BOOL isPurchased;

/**
 * @brief Loads the given extend-note record into the view at the given product-list index.
 * @param info The extend-note record to display.
 * @param index The product-list index of the record.
 * @ghidraAddress 0x4cc28
 */
- (void)loadExtendNoteInfo:(nullable StoreExtendNoteInfo *)info index:(NSUInteger)index;
/**
 * @brief Sets the view's artwork image.
 * @param artwork The artwork image.
 * @ghidraAddress 0x4cadc
 */
- (void)setArtwork:(nullable UIImage *)artwork;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
