/** @file
 * The draggable page slider that pages the music-menu grid. It is a @c UIControl subclass drawn as
 * a rounded translucent track (the gauge view) with a small image grip that the player drags, and
 * a floating index label that shows the target page while dragging. It maps a horizontal touch to
 * an integer page in the inclusive range @c barMin ... @c barMax and reports each change to its
 * delegate. It is created and wrapped by @c RBMenuPageSliderView.
 *
 * Reconstructed from Ghidra project rb458, program rb458 (class RBMenuPageSlider, image base
 * 0x100000000). @ghidraAddress values are offsets relative to the image base.
 */

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@class RBMenuPageSlider;

/**
 * @brief Receives page-change notifications from an @c RBMenuPageSlider.
 *
 * The slider messages the delegate informally with @c performSelector:withObject: guarded by
 * @c respondsToSelector:, so every method is optional.
 */
@protocol RBMenuPageSliderDelegate <NSObject>

@optional

/**
 * @brief Sent whenever the slider's value changes during or at the end of a drag.
 * @param parameters A three-element array: the snapped integer page as an @c NSNumber, the raw
 * fractional page position as an @c NSNumber, and whether the drag has ended as a boolean
 * @c NSNumber.
 * @ghidraAddress 0x1bfb24
 */
- (void)changePage:(NSArray<NSNumber *> *)parameters;

@end

/**
 * @brief A draggable @c UIControl page slider for the music-menu grid.
 */
@interface RBMenuPageSlider : UIControl

/**
 * @brief Create the slider, building its grip sprite, gauge track, and index label, and wire it to
 * a delegate.
 * @param frame The slider's frame; its height drives the gauge and grip geometry.
 * @param delegate The object to notify of page changes, or @c nil.
 * @return The initialised slider, or @c nil.
 * @ghidraAddress 0x1beba8
 */
- (nullable instancetype)initWithFrame:(CGRect)frame delegate:(nullable id)delegate;

/**
 * @brief Reconfigure the page range and jump to a page.
 * @param pageMax The highest selectable page (the range is 1 ... @c pageMax); the per-page pixel
 * step is recomputed from the gauge width, and collapses to zero for a single-page range.
 * @param currentPage The page to move the grip to.
 * @ghidraAddress 0x1bf698
 */
- (void)reset:(NSUInteger)pageMax currentPage:(NSUInteger)currentPage;

/**
 * @brief Set the current page value, clamp it to the range, and reposition the grip and index
 * label.
 * @param value The page value; it is clamped to @c barMin ... @c barMax and truncated to an
 * integer.
 * @ghidraAddress 0x1bf79c
 */
- (void)setValue:(float)value;

/**
 * @brief Map a touch point to a page value, update the slider, and notify the delegate.
 * @param point The touch location in the slider's coordinate space.
 * @param isEnd Whether this is the final update of the drag; when set, the value is snapped to a
 * whole page.
 * @ghidraAddress 0x1bfb24
 */
- (void)sliderChangeWithTouchPoint:(CGPoint)point isEnd:(BOOL)isEnd;

/**
 * @brief The snapped current page value.
 */
@property(assign, nonatomic) float value;

/**
 * @brief The rounded translucent track the grip slides along.
 */
@property(strong, nonatomic, nullable) UIView *slideGaugeView;

/**
 * @brief The draggable grip sprite.
 */
@property(strong, nonatomic, nullable) UIImageView *gripView;

/**
 * @brief The floating label that shows the target page number while dragging.
 */
@property(strong, nonatomic, nullable) UILabel *indexLabel;

/**
 * @brief The lowest selectable page (always 1).
 */
@property(assign, nonatomic) NSUInteger barMin;

/**
 * @brief The highest selectable page.
 */
@property(assign, nonatomic) NSUInteger barMax;

/**
 * @brief The gauge-width pixels per page, used to convert between touch position and page value.
 */
@property(assign, nonatomic) CGFloat step;

/**
 * @brief The object notified of page changes.
 */
@property(weak, nonatomic, nullable) id<RBMenuPageSliderDelegate> delegate;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
