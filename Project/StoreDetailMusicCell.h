/** @file
 * A single tune row in the phone-layout pack detail table: artwork, name, artist, per-difficulty
 * levels, an iTunes link button, a sequence-extension icon, and the sample-play state.
 *
 * Reconstructed from Ghidra project rb458, program rb458 (class @c StoreDetailMusicCell, image base
 * 0x100000000). @ghidraAddress values are offsets relative to the image base.
 */

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * @brief A tune row in the pack detail table.
 *
 * The cell owns its jacket, labels, an iTunes link button, and an overlay that shows the
 * sample-download spinner and the play glyph. Tapping the sequence icon offers to jump to the
 * extend-note store, so the cell also serves as its own alert delegate.
 */
@interface StoreDetailMusicCell : UITableViewCell <UIAlertViewDelegate>

/**
 * @brief The tune artwork image view, inset from the top-left with a rasterised drop shadow.
 */
@property(nonatomic, strong, nullable) UIImageView *artworkView;

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
 * @brief The iTunes URL the link button opens, stored as an @c NSURL.
 */
@property(nonatomic, strong, nullable) NSURL *linkURL;

/**
 * @brief The stretchable background image view drawn behind the row.
 */
@property(nonatomic, strong, nullable) UIImageView *bgView;

/**
 * @brief The sample-playback overlay hosting the spinner and the play glyph.
 */
@property(nonatomic, strong, nullable) UIView *sampleView;

/**
 * @brief The spinner shown while the sample is downloading.
 */
@property(nonatomic, strong, nullable) UIActivityIndicatorView *indicator;

/**
 * @brief The play glyph shown while the sample is playing.
 */
@property(nonatomic, strong, nullable) UIImageView *playingView;

/**
 * @brief The bottom-right iTunes link button.
 */
@property(nonatomic, strong, nullable) UIButton *buttonLink;

/**
 * @brief The sequence-extension icon button, shown only when the tune has extend notes.
 */
@property(nonatomic, strong, nullable) UIButton *iconSp;

/**
 * @brief The controller the cell reports sample-play changes to and asks to switch stores.
 */
@property(nonatomic, weak, nullable) id parent;

/**
 * @brief The extend-note product identifier the sequence icon links to, or a non-positive value
 * when none.
 */
@property(nonatomic, assign) int pid;

/**
 * @brief The pixel height of a tune row.
 * @return The fixed row height, 80 points.
 * @ghidraAddress 0xedde8
 */
+ (CGFloat)cellHeight;

/**
 * @brief Set the iTunes link, converting the string to an @c NSURL and hiding the link button when
 * it is @c nil.
 * @param link The iTunes URL string, or @c nil.
 * @ghidraAddress 0xef810
 */
- (void)setLink:(nullable NSString *)link;

/**
 * @brief Set the stretchable row background image.
 * @param bgImage The background image.
 * @ghidraAddress 0xef784
 */
- (void)setBgImage:(nullable UIImage *)bgImage;

/**
 * @brief Enter the sample-playing state: hide the spinner and show the play glyph.
 * @ghidraAddress 0xefab8
 */
- (void)samplePlaying;

/**
 * @brief Enter the sample-downloading state: show the spinner and hide the play glyph.
 * @ghidraAddress 0xef9e0
 */
- (void)sampleDownloading;

/**
 * @brief Return to the idle (stopped) sample state, hiding the overlay.
 * @ghidraAddress 0xef940
 */
- (void)sampleStop;

/**
 * @brief Open the tune's iTunes URL through the app's root view controller.
 * @param sender The link button.
 * @ghidraAddress 0xef5cc
 */
- (void)handleLink:(nullable id)sender;

/**
 * @brief Offer to jump to the extend-note store for this tune.
 * @param sender The sequence icon button.
 * @ghidraAddress 0xefbc4
 */
- (void)tapSp:(nullable id)sender;

/**
 * @brief Ask the parent to switch to the extend-note store when the offer is confirmed.
 * @param alertView The alert view.
 * @param buttonIndex The tapped button index.
 * @ghidraAddress 0xefc30
 */
- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex;

/**
 * @brief Handle a cancelled offer alert.
 * @param alertView The alert view.
 * @ghidraAddress 0xefd88
 */
- (void)alertViewCancel:(UIAlertView *)alertView;

/**
 * @brief Make the presented alert exclusive-touch once it appears.
 * @param alertView The alert view.
 * @ghidraAddress 0xefd8c
 */
- (void)didPresentAlertView:(UIAlertView *)alertView;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
