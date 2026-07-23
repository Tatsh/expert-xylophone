/** @file
 * A collection-view cell that presents a single music entry in a paged music grid.
 * @c RBMusicGridLayout registers this class as its decoration view.
 *
 * The cell layers a frame-bonus background image, an artwork image view, per-difficulty clear-rank
 * and full-combo indicator layers, and a title and artist label whose colours track the current
 * theme. @c updateScoreData: and @c updateScoreData:spData: refresh the indicator layers from the
 * player's per-chart score data; @c show and @c hide cross-fade the whole cell.
 *
 * Reconstructed from Ghidra project rb458, program rb458 (class @c RBMusicCell, image base
 * 0x100000000). @ghidraAddress values are offsets relative to the image base.
 */

#import <UIKit/UIKit.h>

@class CALayer;
@class MusicData;
@class RBMenuView;
@class ScoreData;

NS_ASSUME_NONNULL_BEGIN

/**
 * @brief A grid cell presenting a single music entry.
 */
@interface RBMusicCell : UICollectionViewCell

/**
 * @brief Build the cell's background layer, artwork view, per-difficulty indicator layers, and
 * title and artist labels.
 * @param frame The cell's frame rectangle.
 * @return The initialised cell, or @c nil.
 * @ghidraAddress 0xbaa1c
 */
- (nullable instancetype)initWithFrame:(CGRect)frame;

/**
 * @brief Assemble the cell's subviews and layers: the frame-bonus background, the artwork view, the
 * clear-base, clear, rank-base, and rank indicator layers for each of the four difficulties, and
 * the theme-coloured title and artist labels.
 * @ghidraAddress 0xbb064
 */
- (void)SetupView;

/**
 * @brief Refresh the frame-bonus background and the clear-rank and full-combo indicator layers for
 * the first three difficulties from @p scoreData.
 * @param scoreData The player's score data for this chart, or @c nil to clear the indicators.
 * @ghidraAddress 0xbc94c
 */
- (void)updateScoreData:(nullable ScoreData *)scoreData;

/**
 * @brief Refresh the frame-bonus background and the clear-rank and full-combo indicator layers for
 * all four difficulties, taking the fourth (Special) difficulty from @p spData.
 * @param scoreData The player's score data for the first three difficulties, or @c nil.
 * @param spData The player's score data for the fourth (Special) difficulty, or @c nil.
 * @ghidraAddress 0xbd2b0
 */
- (void)updateScoreData:(nullable ScoreData *)scoreData spData:(nullable ScoreData *)spData;

/**
 * @brief Cross-fade the cell in: reveal it and animate its alpha from zero to one.
 * @ghidraAddress 0xbdd48
 */
- (void)show;

/**
 * @brief Cross-fade the cell out: animate its alpha to zero, then hide it.
 * @ghidraAddress 0xbde2c
 */
- (void)hide;

/**
 * @brief The frame-bonus background layer drawn behind the artwork.
 * @ghidraAddress 0xbe148 (getter)
 * @ghidraAddress 0xbe158 (setter)
 */
@property(strong, nonatomic, nullable) CALayer *bgImageLayer;

/**
 * @brief The per-difficulty clear-rank base layers.
 * @ghidraAddress 0xbe190 (getter)
 * @ghidraAddress 0xbe1a0 (setter)
 */
@property(strong, nonatomic, nullable) NSArray<CALayer *> *rankBaseImageLayers;

/**
 * @brief The per-difficulty clear-rank indicator layers.
 * @ghidraAddress 0xbe1d8 (getter)
 * @ghidraAddress 0xbe1e8 (setter)
 */
@property(strong, nonatomic, nullable) NSArray<CALayer *> *rankImageLayers;

/**
 * @brief The per-difficulty full-combo base layers.
 * @ghidraAddress 0xbe220 (getter)
 * @ghidraAddress 0xbe230 (setter)
 */
@property(strong, nonatomic, nullable) NSArray<CALayer *> *clearBaseImageLayers;

/**
 * @brief The per-difficulty full-combo indicator layers.
 * @ghidraAddress 0xbe268 (getter)
 * @ghidraAddress 0xbe278 (setter)
 */
@property(strong, nonatomic, nullable) NSArray<CALayer *> *clearImageLayers;

/**
 * @brief The "add to playlist" button.
 * @ghidraAddress 0xbe0b8 (getter)
 * @ghidraAddress 0xbe0c8 (setter)
 */
@property(strong, nonatomic, nullable) UIButton *addButton;

/**
 * @brief The "remove from playlist" button.
 * @ghidraAddress 0xbe100 (getter)
 * @ghidraAddress 0xbe110 (setter)
 */
@property(strong, nonatomic, nullable) UIButton *removeButton;

/**
 * @brief The cell's frame-bonus type, indexing the background image. Stored as a 32-bit @c int in
 * the binary, matching a @c ScoreDataFrameBonusType raw value.
 * @ghidraAddress 0xbe2b0 (getter)
 * @ghidraAddress 0xbe2c0 (setter)
 */
@property(nonatomic, assign) int bgType;

/**
 * @brief The music-select menu view that owns this cell. Held weakly to avoid a retain cycle.
 * @ghidraAddress 0xbdf64 (getter)
 * @ghidraAddress 0xbdf84 (setter)
 */
@property(weak, nonatomic, nullable) RBMenuView *menuView;

/**
 * @brief The cell's artwork image view.
 * @ghidraAddress 0xbdff0 (setter)
 */
@property(strong, nonatomic, nullable) UIImageView *artworkImageView;

/**
 * @brief The music title label.
 * @ghidraAddress 0xbe038 (setter)
 */
@property(strong, nonatomic, nullable) UILabel *titleLabel;

/**
 * @brief The music artist label.
 * @ghidraAddress 0xbe080 (setter)
 */
@property(strong, nonatomic, nullable) UILabel *artistLabel;

/**
 * @brief The music entry backing this cell.
 * @ghidraAddress 0xbdf98 (getter)
 * @ghidraAddress 0xbdfa8 (setter)
 */
@property(strong, nonatomic, nullable) MusicData *musicData;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
