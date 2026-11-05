/**
 * @file
 * A lightweight line-and-dot plot view.
 *
 * It draws a polyline through a series of boxed numeric
 * values, one dashed segment between each adjacent pair, with a filled dot at every point, and
 * labels the top and bottom of the plot with the current maximum and minimum values. It is hosted
 * by @c RBMusicHistoryView, which feeds it the recent-play achievement-rate history.
 *
 * Reconstructed from Ghidra project rb458, program rb458 (class @c GraphView, image base
 * 0x100000000). Ghidra addresses are offsets relative to the image base. The class has no
 * embedded @c __FILE__ path, so it is placed at the @c Project/ root.
 */

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * A dashed-polyline achievement-rate plot with per-point dots and min/max value labels.
 *
 * The class has no adopted protocols: its class_ro_t baseProtocols list is null. Its superclass is
 * @c UIView.
 */
@interface GraphView : UIView

/**
 * Whether an animation is currently in flight.
 *
 * This flag is carried verbatim from the host panel's layout and is not read by any of the view's
 * own methods; it is retained to match the binary's ivar and property layout.
 */
@property(nonatomic, assign) BOOL m_IsAnimation;
/**
 * The plotted values, each a boxed @c float, ordered left to right.
 */
@property(nonatomic, strong, nullable) NSMutableArray *dataArray;
/**
 * The per-point overlay views. Allocated on initialisation and cleared on reset.
 */
@property(nonatomic, strong, nullable) NSMutableArray *pointArray;
/**
 * The origin of the first plotted point, in the view's coordinate space.
 */
@property(nonatomic, assign) CGPoint startPos;
/**
 * The horizontal spacing between adjacent plotted points.
 */
@property(nonatomic, assign) float dotIntervalX;
/**
 * The value mapped to the top of the plot.
 */
@property(nonatomic, assign) float maxValue;
/**
 * The value mapped to the bottom of the plot.
 */
@property(nonatomic, assign) float minValue;
/**
 * The colour of the filled per-point dots.
 */
@property(nonatomic, strong, nullable) UIColor *dotColor;
/**
 * The stroke width used to draw each per-point dot.
 */
@property(nonatomic, assign) float dotSize;
/**
 * The colour of the connecting polyline.
 */
@property(nonatomic, strong, nullable) UIColor *lineColor;
/**
 * The stroke width of the connecting polyline.
 */
@property(nonatomic, assign) float lineSize;

/**
 * Initialises the plot, allocates its point overlay array, and applies the default layout.
 * @param frame The view frame.
 * @return The initialised plot.
 */
- (instancetype)initWithFrame:(CGRect)frame;

/**
 * Applies the default plot layout: the starting point, hidden state, and translucent
 * background.
 */
- (void)CreateView;

/**
 * Sets the dot and line styling in one call, converting each colour through its @c CGColor
 * so a copy independent of the caller's colour space is stored.
 * @param option The dot colour.
 * @param dotSize The dot stroke width.
 * @param lineColor The polyline colour.
 * @param lineSize The polyline stroke width.
 */
- (void)setOption:(nullable UIColor *)option
          dotSize:(float)dotSize
        lineColor:(nullable UIColor *)lineColor
         lineSize:(float)lineSize;

/**
 * Replaces the plotted data and rescales the plot, with the minimum line pinned to zero.
 * @param data The boxed @c float values to plot.
 * @param maxValue The value mapped to the top of the plot.
 */
- (void)setData:(nullable NSArray *)data maxValue:(float)maxValue;

/**
 * Replaces the plotted data and rescales the plot.
 *
 * Copies @p data into @c dataArray, sets @c maxValue, and derives @c minValue. When
 * @p isMovableMinLine is @c NO the minimum line stays at zero; when @c YES it is lowered to the
 * smallest plotted value and then snapped down to the nearest of a fixed set of round thresholds.
 * The horizontal starting offset and point spacing are then derived from the point count and view
 * width, and the top and bottom value labels are rebuilt.
 * @param data The boxed @c float values to plot.
 * @param maxValue The value mapped to the top of the plot.
 * @param isMovableMinLine Whether the minimum line may drop below zero to fit the data.
 */
- (void)setData:(nullable NSArray *)data
            maxValue:(float)maxValue
    isMovableMinLine:(BOOL)isMovableMinLine;

/**
 * Clears the plotted data and overlay points and returns the plot to its empty default
 * state, then requests a redraw.
 */
- (void)reset;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
