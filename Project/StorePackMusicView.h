/** @file
 * A single tune row inside the pad-layout pack detail panel (@c StorePackDetailViewPad): a jacket,
 * a name, difficulty levels, an iTunes-link button, and a sample-playback button. This is a minimal
 * stub declaring only the surface @c StorePackDetailViewPad relies on; the full view class is
 * reconstructed separately.
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
@property(nonatomic, strong, readonly, nullable) StoreImageView *artworkView;

/**
 * @brief The iTunes-link button.
 */
@property(nonatomic, strong, readonly, nullable) UIButton *buttonLink;

/**
 * @brief The sample-playback button.
 */
@property(nonatomic, strong, readonly, nullable) UIButton *buttonSample;

/**
 * @brief The owning pad pack detail panel.
 */
@property(nonatomic, weak, nullable) StorePackDetailViewPad *parent;

/**
 * @brief Populate the row from the given tune, or clear it when @c info is @c nil.
 * @param info The tune to display.
 */
- (void)setInfo:(nullable StoreMusicInfo *)info;

/**
 * @brief Select the light or dark tune-cell background.
 * @param bg @c YES for the dark background, @c NO for the light one.
 */
- (void)setBG:(BOOL)bg;

/**
 * @brief Put the sample button into its idle (stopped) state.
 */
- (void)sampleStop;

/**
 * @brief Put the sample button into its downloading state.
 */
- (void)sampleDownloading;

/**
 * @brief Put the sample button into its playing state.
 */
- (void)samplePlaying;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
