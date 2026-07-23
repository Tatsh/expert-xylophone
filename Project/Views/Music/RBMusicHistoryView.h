/** @file
 * The play-history panel hosted by @c RBMusicView. It shows the recent-play achievement-rate graph
 * for the currently selected tune and difficulty, revealing and hiding itself with a fade
 * animation. The panel builds its plotted data from the @c History Core Data records through the
 * shared @c RBCoreDataManager context.
 *
 * Reconstructed from Ghidra project rb458, program rb458 (class RBMusicHistoryView, image base
 * 0x100000000). @ghidraAddress values are offsets relative to the image base.
 */

#import <UIKit/UIKit.h>

@class GraphView;

NS_ASSUME_NONNULL_BEGIN

/**
 * @brief The play-history overlay for a tune and difficulty, hosting an achievement-rate graph that
 * animates in and out.
 */
@interface RBMusicHistoryView : UIView

/**
 * @brief Whether an in or out animation is currently running; guards against overlapping toggles.
 * @ghidraAddress 0x53a8 (getter)
 * @ghidraAddress 0x53b8 (setter)
 */
@property(nonatomic, assign) BOOL m_IsAnimation;
/**
 * @brief The tune identifier whose play history is shown.
 * @ghidraAddress 0x5368 (getter)
 * @ghidraAddress 0x5378 (setter)
 */
@property(nonatomic, assign) int musicID;
/**
 * @brief The chart difficulty whose play history is shown.
 * @ghidraAddress 0x5388 (getter)
 * @ghidraAddress 0x5398 (setter)
 */
@property(nonatomic, assign) int difficulty;
/**
 * @brief The static background artwork behind the graph.
 * @ghidraAddress 0x53c8 (getter)
 * @ghidraAddress 0x53d8 (setter)
 */
@property(nonatomic, strong, nullable) UIImageView *graphSheetView;
/**
 * @brief The achievement-rate graph that plots the play-history data.
 * @ghidraAddress 0x5410 (getter)
 * @ghidraAddress 0x5420 (setter)
 */
@property(nonatomic, strong, nullable) GraphView *graphView;
/**
 * @brief The plotted achievement-rate values, one per play-history record.
 * @ghidraAddress 0x5458 (getter)
 * @ghidraAddress 0x5468 (setter)
 */
@property(nonatomic, strong, nullable) NSMutableArray *dataArray;
/**
 * @brief The per-point views overlaid on the graph.
 * @ghidraAddress 0x54a0 (getter)
 * @ghidraAddress 0x54b0 (setter)
 */
@property(nonatomic, strong, nullable) NSMutableArray *pointViewArray;

/**
 * @brief Initialises the panel, building its background artwork and graph, and starts hidden.
 * @param frame The panel frame.
 * @return The initialised panel.
 * @ghidraAddress 0x480c
 */
- (instancetype)initWithFrame:(CGRect)frame;

/**
 * @brief Builds the background artwork view and the graph view, starts hidden and transparent, and
 * applies the translucent background colour.
 * @ghidraAddress 0x4980
 */
- (void)CreateView;

/**
 * @brief Rebuilds the graph's plotted data from the play-history records for the current tune and
 * difficulty, most recent first.
 * @ghidraAddress 0x4b98
 */
- (void)createGraphData;

/**
 * @brief Reveals the panel for a tune and difficulty and fades it in, then rebuilds the graph data.
 * @param musicID The tune identifier to show history for.
 * @param difficulty The chart difficulty to show history for.
 * @ghidraAddress 0x4e40
 */
- (void)showAnimation:(int)musicID difficulty:(int)difficulty;

/**
 * @brief Fades the panel out and fully resets the graph once hidden.
 * @ghidraAddress 0x5010
 */
- (void)hideAnimation;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
