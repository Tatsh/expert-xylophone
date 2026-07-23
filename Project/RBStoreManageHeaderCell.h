/** @file
 * The section-header cell for the store manage page's grouped tune table. It shows the kana
 * section title and an expand/collapse indicator, and forwards a tap to the target's toggle
 * action.
 *
 * Reconstructed from Ghidra project rb458, program rb458 (class @c RBStoreManageHeaderCell, image
 * base 0x100000000). @ghidraAddress values are offsets relative to the image base.
 */

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * @brief A tappable section-header cell for the store manage tune table.
 *
 * The header lays out a leading title label and a trailing expand/collapse triangle over an
 * alternating translucent background, and installs a tap gesture that fires the target's
 * @c toggleOpen: action.
 */
@interface RBStoreManageHeaderCell : UITableViewHeaderFooterView

/**
 * @brief The table section this header represents.
 */
@property(nonatomic, assign) NSInteger section;

/**
 * @brief The object whose @c toggleOpen: action the header's tap gesture fires.
 *
 * The header holds the target without owning it, matching the binary's @c assign attribute.
 */
@property(nonatomic, unsafe_unretained, nullable) id tapDelegate;

/**
 * @brief The trailing expand/collapse indicator label.
 *
 * Owned by the view hierarchy, so the header keeps only an unretained back-reference, matching the
 * binary's @c assign attribute.
 */
@property(nonatomic, unsafe_unretained, nullable) UILabel *openedLabel;

/**
 * @brief The leading section-title label.
 */
@property(nonatomic, strong, nullable) UILabel *titleLabel;

/**
 * @brief Initialises the header cell for a section, wiring its tap to the target's toggle action.
 *
 * The @p section index only selects the alternating background colour here; the caller assigns the
 * @c section property separately.
 *
 * @param reuseIdentifier The cell reuse identifier.
 * @param frame The cell frame; only its width is used for layout.
 * @param section The table section index, used for the background parity.
 * @param target The object whose @c toggleOpen: action the header's tap gesture fires.
 * @return The initialised header cell, or @c nil if the superclass initialiser fails.
 * @ghidraAddress 0x1cd7c8
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
