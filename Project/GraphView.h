/** @file
 * A lightweight line-and-dot plot view. It draws a polyline through a series of boxed numeric
 * values, one dashed segment between each adjacent pair, with a filled dot at every point, and
 * labels the top and bottom of the plot with the current maximum and minimum values. It is hosted
 * by @c RBMusicHistoryView, which feeds it the recent-play achievement-rate history.
 *
 * Reconstructed from Ghidra project rb458, program rb458 (class @c GraphView, image base
 * 0x100000000). @ghidraAddress values are offsets relative to the image base. The class has no
 * embedded @c __FILE__ path, so it is placed at the @c Project/ root.
 */

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * @brief A dashed-polyline achievement-rate plot with per-point dots and min/max value labels.
 *
 * The class has no adopted protocols: its class_ro_t baseProtocols list is null. Its superclass is
 * @c UIView.
 */
@interface GraphView : UIView

/**
 * @brief Whether an animation is currently in flight.
 *
 * This flag is carried verbatim from the host panel's layout and is not read by any of the view's
 * own methods; it is retained to match the binary's ivar and property layout.
 * @ghidraAddress 0x7214 (getter)
 * @ghidraAddress 0x7224 (setter)
 */
@property(nonatomic, assign) BOOL m_IsAnimation;
/**
 * @brief The plotted values, each a boxed @c float, ordered left to right.
 * @ghidraAddress 0x7234 (getter)
 * @ghidraAddress 0x7244 (setter)
 */
@property(nonatomic, strong, nullable) NSMutableArray *dataArray;
/**
 * @brief The per-point overlay views. Allocated on initialisation and cleared on reset.
 * @ghidraAddress 0x727c (getter)
 * @ghidraAddress 0x728c (setter)
 */
@property(nonatomic, strong, nullable) NSMutableArray *pointArray;
/**
 * @brief The origin of the first plotted point, in the view's coordinate space.
 * @ghidraAddress 0x72c4 (getter)
 * @ghidraAddress 0x72d8 (setter)
 */
@property(nonatomic, assign) CGPoint startPos;
/**
 * @brief The horizontal spacing between adjacent plotted points.
 * @ghidraAddress 0x72ec (getter)
 * @ghidraAddress 0x72fc (setter)
 */
@property(nonatomic, assign) float dotIntervalX;
/**
 * @brief The value mapped to the top of the plot.
 * @ghidraAddress 0x730c (getter)
 * @ghidraAddress 0x731c (setter)
 */
@property(nonatomic, assign) float maxValue;
/**
 * @brief The value mapped to the bottom of the plot.
 * @ghidraAddress 0x732c (getter)
 * @ghidraAddress 0x733c (setter)
 */
@property(nonatomic, assign) float minValue;
/**
 * @brief The colour of the filled per-point dots.
 * @ghidraAddress 0x734c (getter)
 * @ghidraAddress 0x735c (setter)
 */
@property(nonatomic, strong, nullable) UIColor *dotColor;
/**
 * @brief The stroke width used to draw each per-point dot.
 * @ghidraAddress 0x7394 (getter)
 * @ghidraAddress 0x73a4 (setter)
 */
@property(nonatomic, assign) float dotSize;
/**
 * @brief The colour of the connecting polyline.
 * @ghidraAddress 0x73b4 (getter)
 * @ghidraAddress 0x73c4 (setter)
 */
@property(nonatomic, strong, nullable) UIColor *lineColor;
/**
 * @brief The stroke width of the connecting polyline.
 * @ghidraAddress 0x73fc (getter)
 * @ghidraAddress 0x740c (setter)
 */
@property(nonatomic, assign) float lineSize;

/**
 * @brief Initialises the plot, allocates its point overlay array, and applies the default layout.
 * @param frame The view frame.
 * @return The initialised plot.
 * @ghidraAddress 0x5ce8
 */
- (instancetype)initWithFrame:(CGRect)frame;

/**
 * @brief Applies the default plot layout: the starting point, hidden state, and translucent
 * background.
 * @ghidraAddress 0x5dc0
 */
- (void)CreateView;

/**
 * @brief Sets the dot and line styling in one call, converting each colour through its @c CGColor
 * so a copy independent of the caller's colour space is stored.
 * @param option The dot colour.
 * @param dotSize The dot stroke width.
 * @param lineColor The polyline colour.
 * @param lineSize The polyline stroke width.
 * @ghidraAddress 0x5e84
 */
- (void)setOption:(nullable UIColor *)option
          dotSize:(float)dotSize
        lineColor:(nullable UIColor *)lineColor
         lineSize:(float)lineSize;

/**
 * @brief Replaces the plotted data and rescales the plot, with the minimum line pinned to zero.
 * @param data The boxed @c float values to plot.
 * @param maxValue The value mapped to the top of the plot.
 * @ghidraAddress 0x6004
 */
- (void)setData:(nullable NSArray *)data maxValue:(float)maxValue;

/**
 * @brief Replaces the plotted data and rescales the plot.
 *
 * Copies @p data into @c dataArray, sets @c maxValue, and derives @c minValue. When
 * @p isMovableMinLine is @c NO the minimum line stays at zero; when @c YES it is lowered to the
 * smallest plotted value and then snapped down to the nearest of a fixed set of round thresholds.
 * The horizontal starting offset and point spacing are then derived from the point count and view
 * width, and the top and bottom value labels are rebuilt.
 * @param data The boxed @c float values to plot.
 * @param maxValue The value mapped to the top of the plot.
 * @param isMovableMinLine Whether the minimum line may drop below zero to fit the data.
 * @ghidraAddress 0x6024
 */
- (void)setData:(nullable NSArray *)data
            maxValue:(float)maxValue
    isMovableMinLine:(BOOL)isMovableMinLine;

/**
 * @brief Clears the plotted data and overlay points and returns the plot to its empty default
 * state, then requests a redraw.
 * @ghidraAddress 0x702c
 */
- (void)reset;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
