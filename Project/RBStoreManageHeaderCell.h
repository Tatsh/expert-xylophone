/** @file
 * The section-header cell for the store manage page's grouped tune table. It shows the kana
 * section title and an expand/collapse indicator, and forwards a tap to the target's toggle
 * action.
 *
 * Minimal stub: only the surface @c RBStoreManageViewController messages is declared here; the
 * full class is reconstructed separately.
 *
 * Reconstructed from Ghidra project rb458, program rb458 (class @c RBStoreManageHeaderCell, image
 * base 0x100000000). @ghidraAddress values are offsets relative to the image base.
 */

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * @brief A tappable section-header cell for the store manage tune table.
 */
@interface RBStoreManageHeaderCell : UITableViewHeaderFooterView

/**
 * @brief The expand/collapse indicator label.
 */
@property(nonatomic, strong, nullable) UILabel *openedLabel;

/**
 * @brief The section-title label.
 */
@property(nonatomic, strong, nullable) UILabel *titleLabel;

/**
 * @brief The table section this header represents.
 */
@property(nonatomic, assign) NSInteger section;

/**
 * @brief Initialises the header cell for a section, wiring its tap to the target's toggle action.
 * @param reuseIdentifier The cell reuse identifier.
 * @param frame The cell frame.
 * @param section The table section index.
 * @param target The object whose @c toggleOpen: action the header fires.
 * @return The initialised header cell.
 */
- (nullable instancetype)initWithReuseIdentifier:(nullable NSString *)reuseIdentifier
                                           frame:(CGRect)frame
                                         section:(NSInteger)section
                                      withTarget:(nullable id)target;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
