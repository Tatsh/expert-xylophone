/** @file
 * A single tune row in the phone-layout pack detail table: artwork, name, artist, per-difficulty
 * levels, a sequence-extension icon, and the sample-play state. This is a minimal stub declaring
 * only the surface @c RBStoreDetailViewController relies on; the full cell class is reconstructed
 * separately.
 *
 * Reconstructed from Ghidra project rb458, program rb458 (class @c StoreDetailMusicCell, image base
 * 0x100000000). @ghidraAddress values are offsets relative to the image base.
 */

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * @brief A tune row in the pack detail table.
 */
@interface StoreDetailMusicCell : UITableViewCell

/**
 * @brief The controller the cell reports sample-play changes to.
 */
@property(nonatomic, weak, nullable) id parent;

/**
 * @brief The extend-note product identifier the sequence icon links to, or @c -1 when none.
 */
@property(nonatomic, assign) int pid;

/**
 * @brief The iTunes URL for the tune, opened when the row's link is followed.
 */
@property(nonatomic, strong, nullable) NSString *link;

/**
 * @brief The label showing the tune name.
 */
@property(nonatomic, strong, nullable) UILabel *labelName;

/**
 * @brief The label showing the tune artist.
 */
@property(nonatomic, strong, nullable) UILabel *labelArtist;

/**
 * @brief The label showing the three per-difficulty levels.
 */
@property(nonatomic, strong, nullable) UILabel *labelLevels;

/**
 * @brief The artwork image view.
 */
@property(nonatomic, strong, nullable) UIImageView *artworkView;

/**
 * @brief The sequence-extension icon, shown only when the tune has extend notes.
 */
@property(nonatomic, strong, nullable) UIImageView *iconSp;

/**
 * @brief The stretchable background image drawn behind the row.
 */
@property(nonatomic, strong, nullable) UIImage *bgImage;

/**
 * @brief The pixel height of a tune row.
 */
+ (CGFloat)cellHeight;

/**
 * @brief Enter the sample-playing state.
 */
- (void)samplePlaying;

/**
 * @brief Enter the sample-downloading state.
 */
- (void)sampleDownloading;

/**
 * @brief Return to the idle (stopped) sample state.
 */
- (void)sampleStop;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
