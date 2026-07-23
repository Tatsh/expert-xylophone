/** @file
 * A single tune row inside the pad-layout pack detail panel (@c StorePackDetailViewPad): a jacket,
 * a name, an artist, difficulty levels, an iTunes-link button, a sample-playback button, and an
 * optional cross-sell badge that offers to jump to the extend-note store.
 *
 * Reconstructed from Ghidra project rb458, program rb458 (class @c StorePackMusicView, image base
 * 0x100000000). @ghidraAddress values are offsets relative to the image base.
 */

#import <UIKit/UIKit.h>

@class StoreImageView;
@class StoreMusicInfo;
@class StorePackDetailViewPad;

NS_ASSUME_NONNULL_BEGIN

/**
 * @brief A single tune row in the pad pack detail panel.
 */
@interface StorePackMusicView : UIView

/**
 * @brief The tune jacket artwork view, which downloads its own image.
 */
@property(nonatomic, strong, nullable) StoreImageView *artworkView;

/**
 * @brief The tune name label.
 */
@property(nonatomic, strong, nullable) UILabel *labelName;

/**
 * @brief The tune artist label.
 */
@property(nonatomic, strong, nullable) UILabel *labelArtist;

/**
 * @brief The difficulty-levels label ("LEVEL:  %d / %d / %d").
 */
@property(nonatomic, strong, nullable) UILabel *labelLevels;

/**
 * @brief The sample-playback button.
 */
@property(nonatomic, strong, nullable) UIButton *buttonSample;

/**
 * @brief The iTunes-link button.
 */
@property(nonatomic, strong, nullable) UIButton *buttonLink;

/**
 * @brief The busy indicator overlaid on the sample button while a sample downloads.
 */
@property(nonatomic, strong, nullable) UIActivityIndicatorView *indicatorSample;

/**
 * @brief The stretchable tune-cell background image view.
 */
@property(nonatomic, strong, nullable) UIImageView *bg;

/**
 * @brief The cross-sell badge that offers to jump to the extend-note store for this tune.
 */
@property(nonatomic, strong, nullable) UIView *iconSpView;

/**
 * @brief The owning pad pack detail panel.
 */
@property(nonatomic, weak, nullable) StorePackDetailViewPad *parent;

/**
 * @brief The tune's extend-note product identifier, or @c 0 when the tune has no extend note.
 */
@property(nonatomic, assign) int pid;

/**
 * @brief Populate the row from the given tune, or clear it when @c info is @c nil.
 * @param info The tune to display.
 * @ghidraAddress 0xfc814
 */
- (void)setInfo:(nullable StoreMusicInfo *)info;

/**
 * @brief Select the light or dark tune-cell background.
 * @param bg @c YES for the dark background, @c NO for the light one.
 * @ghidraAddress 0xfd100
 */
- (void)setBG:(BOOL)bg;

/**
 * @brief Put the sample button into its idle (stopped) state.
 * @ghidraAddress 0xfce3c
 */
- (void)sampleStop;

/**
 * @brief Put the sample button into its downloading state.
 * @ghidraAddress 0xfcf28
 */
- (void)sampleDownloading;

/**
 * @brief Put the sample button into its playing state.
 * @ghidraAddress 0xfd014
 */
- (void)samplePlaying;

/**
 * @brief Handle a tap on the cross-sell badge by showing the extend-note store prompt.
 * @ghidraAddress 0xfd208
 */
- (void)tapSp;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
