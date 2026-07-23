/** @file
 * The paging scroll view used to lay the store promotion banners side by side.
 *
 * Reconstructed from Ghidra project rb458, program rb458 (class @c PagingScrollView, image base
 * 0x100000000). @ghidraAddress values are offsets relative to the image base.
 */

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * @brief A horizontally paging scroll view whose banners can be tapped even when they extend past
 * the scroll view's own bounds.
 *
 * The carousel clips the visible page but keeps the neighbouring pages' banners laid out beyond the
 * bounds. Overriding hit testing lets those out-of-bounds banners still receive touches.
 */
@interface PagingScrollView : UIScrollView

/**
 * @brief Returns the first subview whose frame contains @p point, or the scroll view itself when
 * none does.
 *
 * Unlike the default implementation, a subview is returned even when @p point lies outside the
 * scroll view's own bounds, so a banner on an adjacent (clipped) page can still be tapped.
 *
 * @param point The point, in the receiver's coordinate system.
 * @param event The event that triggered the hit test, or @c nil.
 * @return The banner subview under @p point, or @c self when there is none.
 * @ghidraAddress 0xff494
 */
- (nullable UIView *)hitTest:(CGPoint)point withEvent:(nullable UIEvent *)event;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
