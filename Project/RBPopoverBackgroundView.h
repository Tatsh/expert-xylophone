/** @file
 * A custom popover chrome for the music-select popover. It is a @c UIPopoverBackgroundView subclass
 * that draws the game's own arrow-and-body artwork (the @c 01_music_select/sel_popover_* image set)
 * instead of the system default: it overrides the required geometry class methods
 * (@c arrowHeight, @c arrowBase, and @c contentViewInsets), tracks the arrow offset and direction
 * through its two required accessors, and rebuilds the stretched background and arrow images in
 * @c layoutSubviews.
 *
 * Reconstructed from Ghidra project rb458, program rb458 (class @c RBPopoverBackgroundView, image
 * base 0x100000000). @ghidraAddress values are offsets relative to the image base. The class has no
 * embedded @c __FILE__ path, so it is placed at the @c Project/ root. The design follows the
 * @c GIKPopoverBackgroundView pattern (the private @c _popoverExtents ivar keeps the binary's
 * @c GIKPopoverExtents struct type verbatim).
 */

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * @brief A music-select popover background drawn with the game's own arrow-and-body artwork.
 *
 * The class adopts no protocols: its class_ro_t baseProtocols list is null. Its superclass is
 * @c UIPopoverBackgroundView.
 */
@interface RBPopoverBackgroundView : UIPopoverBackgroundView

/**
 * @brief The distance the arrow is shifted along its edge from the centre of the popover.
 *
 * The setter runs the drop-shadow path animation (when the OS does not manage the popover's
 * default appearance) and requests a re-layout.
 * @ghidraAddress 0xd91b0 (getter)
 * @ghidraAddress 0xd7d20 (setter)
 */
@property(nonatomic, assign) CGFloat arrowOffset;

/**
 * @brief The edge the arrow points from, as a @c UIPopoverArrowDirection single-bit value.
 *
 * The setter re-applies the drop shadow and requests a re-layout.
 * @ghidraAddress 0xd91c0 (getter)
 * @ghidraAddress 0xd8030 (setter)
 */
@property(nonatomic, assign) UIPopoverArrowDirection arrowDirection;

/**
 * @brief The image view that renders the popover's background and arrow artwork.
 *
 * Allocated in @c initWithFrame: and added as a subview; @c layoutSubviews sizes, centres, and
 * re-images it each pass.
 * @ghidraAddress 0xd91d0 (getter)
 * @ghidraAddress 0xd91e0 (setter)
 */
@property(nonatomic, strong, nullable) UIImageView *popoverBackground;

/**
 * @brief The arrow height reserved above the content, in points.
 * @return A fixed @c 19.0.
 * @ghidraAddress 0xd7c28
 */
+ (CGFloat)arrowHeight;

/**
 * @brief The width of the arrow's base, in points.
 * @return A fixed @c 37.0.
 * @ghidraAddress 0xd7c30
 */
+ (CGFloat)arrowBase;

/**
 * @brief The insets from the popover's edges to its content view.
 * @return A uniform @c 8.0 inset on every edge.
 * @ghidraAddress 0xd7c14
 */
+ (UIEdgeInsets)contentViewInsets;

/**
 * @brief Initialises the view and allocates its background image view.
 * @param frame The view frame.
 * @return The initialised view.
 * @ghidraAddress 0xd7c68
 */
- (instancetype)initWithFrame:(CGRect)frame;

/**
 * @brief Lays out the background image view, recomputing the popover extents, the half-base, and
 * the arrow centre, then re-images the background for the current arrow direction.
 * @ghidraAddress 0xd8188
 */
- (void)layoutSubviews;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
