/**
 * @file
 * The customize item picker hosted by @c RBCustomView.
 *
 * It fills the popup content view with a
 * vertically scrolling stack of per-category item grids (@c RBCustomSelectCollectionView): the
 * theme background music, tap shot, explosion, frame, background, note, gauge, and timing
 * categories, followed by a preview button that starts the game preview.
 *
 * Reconstructed from Ghidra project rb458, program rb458 (class @c RBCustomSelectView, image base
 * 0x100000000). Ghidra addresses are offsets relative to the image base.
 */

#import <UIKit/UIKit.h>

#import "RBCustomSelectCollectionView.h"
#import "RBUserSettingData.h"

NS_ASSUME_NONNULL_BEGIN

/**
 * Customize item picker view.
 *
 * The picker owns a scroll view holding one @c RBCustomSelectCollectionView per customization
 * category, stacked top to bottom, plus a preview button. The stack layout (each grid's start Y,
 * width, height, and the inter-grid margin) depends on the current iPad idiom: the default-font
 * layout omits the gauge category, and the two layouts use different metrics.
 */
@interface RBCustomSelectView : UIView

/**
 * Create the picker with the given frame and build its subviews.
 * @param frame The view's frame rectangle.
 * @return The initialised view, or @c nil.
 * @ghidraAddress 0x1687dc
 */
- (instancetype)initWithFrame:(CGRect)frame;

/**
 * Build the scroll view, the per-category item grids, and the preview button.
 * @ghidraAddress 0x1688c0
 */
- (void)setupView;

/**
 * The vertical origin of the first category grid, chosen by the theme and the iPad idiom.
 *
 * The sole caller passes the current player theme; a Classic theme starts the stack higher than the
 * others, and the two iPad idioms use different offsets.
 * @param thema The current player theme.
 * @return The first grid's top offset within the scroll view.
 * @ghidraAddress 0x168850
 */
- (float)getCollectionViewStartY:(RBUserSettingDataTheme)thema;

/**
 * The vertical gap left between consecutive category grids, chosen by the iPad idiom.
 * @return The inter-grid margin.
 * @ghidraAddress 0x16889c
 */
- (float)getCollectionViewMargin;

/**
 * Reload every category grid's item content.
 * @ghidraAddress 0x1696d4
 */
- (void)reloadData;

/**
 * Start the game preview and play the decide sound effect.
 * @param sender The preview button that sent the action.
 * @ghidraAddress 0x169828
 */
- (void)prevButtonTap:(nullable id)sender;

/**
 * The scroll view holding the stacked category grids and the preview button.
 */
@property(strong, nonatomic, nullable) UIScrollView *scrollView;

/**
 * The theme background-music category grid.
 */
@property(strong, nonatomic, nullable) RBCustomSelectCollectionView *bgmCollectionView;

/**
 * The tap shot-sound category grid.
 */
@property(strong, nonatomic, nullable) RBCustomSelectCollectionView *shotCollectionView;

/**
 * The explosion-effect category grid.
 */
@property(strong, nonatomic, nullable) RBCustomSelectCollectionView *explosionCollectionView;

/**
 * The frame category grid.
 */
@property(strong, nonatomic, nullable) RBCustomSelectCollectionView *frameCollectionView;

/**
 * The background category grid.
 */
@property(strong, nonatomic, nullable) RBCustomSelectCollectionView *bgCollectionView;

/**
 * The note-skin category grid.
 */
@property(strong, nonatomic, nullable) RBCustomSelectCollectionView *noteCollectionView;

/**
 * The gauge category grid, built only on the non-default font layout.
 */
@property(strong, nonatomic, nullable) RBCustomSelectCollectionView *gaugeCollectionView;

/**
 * The judge-timing category grid.
 */
@property(strong, nonatomic, nullable) RBCustomSelectCollectionView *timingCollectionView;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
