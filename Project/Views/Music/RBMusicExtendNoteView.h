/** @file
 * The extend-note (追加ノート) badge shown for a tune in the music-select screen. When a tune has a
 * purchased extend (special) note pack, @c RBMusicView builds one of these to advertise it: a tappable
 * difficulty button carrying the special-chart frame and its level-number glyph, plus a translucent
 * caption panel showing the pack's comment. The view looks its pack up through
 * @c RBExtendNoteManager by the extend-note identifier it is initialised with and reads the pack's
 * difficulty and comment from the resulting @c MusicDataExtend catalogue entry.
 *
 * Reconstructed from Ghidra project rb458, program rb458 (class @c RBMusicExtendNoteView, image base
 * 0x100000000). @ghidraAddress values are offsets relative to the image base.
 */

#import <UIKit/UIKit.h>

@class RBMusicView;

NS_ASSUME_NONNULL_BEGIN

/**
 * @brief The music-select extend-note badge: a difficulty button plus a comment caption panel.
 *
 * The class adopts no protocols: its class_ro_t baseProtocols list is null. Its superclass is
 * @c UIView.
 */
@interface RBMusicExtendNoteView : UIView

/**
 * @brief Create the badge for an extend note and populate its button and caption.
 *
 * Calls through to @c super, records the owning music view and the extend-note identifier, derives
 * the horizontal layout offset from the current theme and device idiom (a non-zero offset only on
 * the Colette theme, and only @c 8.0 on iPad), and then builds the difficulty button and comment
 * panel with @c SetupView.
 *
 * @param frame The badge frame.
 * @param ExtendNoteID The extend-note identifier the badge advertises.
 * @param MusicSelectedBase The owning music-select view; held weakly as a back-reference.
 * @return The initialised badge.
 * @ghidraAddress 0x3c318
 */
- (nullable instancetype)initWithFrame:(CGRect)frame
                          ExtendNoteID:(unsigned int)ExtendNoteID
                     MusicSelectedBase:(nullable RBMusicView *)MusicSelectedBase;

/**
 * @brief Build the difficulty button and the translucent comment caption panel.
 *
 * Looks the pack up through @c RBExtendNoteManager by @c extendNoteID, chooses the themed difficulty
 * frame and its selected overlay, stacks the level-number glyph on the button, positions everything
 * from the theme- and idiom-dependent layout metrics, and lays the pack's comment into a truncating
 * label inside a half-opacity grey panel beside the button.
 * @ghidraAddress 0x3c4c8
 */
- (void)SetupView;

/**
 * @brief A flash-pulse hook mirroring the @c UIImageView(RB) selector; the binary leaves it empty.
 * @param SetFlashEffectDuration The one-way pulse duration (ignored).
 * @param Start The start opacity (ignored).
 * @param End The end opacity (ignored).
 * @ghidraAddress 0x3cf50
 */
- (void)SetFlashEffectDuration:(float)SetFlashEffectDuration Start:(float)Start End:(float)End;

/** @brief The extend-note identifier the badge advertises. @ghidraAddress 0x3cf54, 0x3cf64 */
@property(nonatomic, assign) unsigned int extendNoteID;
/** @brief The horizontal layout offset applied on the wide (pad) Colette layout.
 * @ghidraAddress 0x3cff0, 0x3d000 */
@property(nonatomic, assign) float layoutOffset;
/** @brief The owning music-select view, held weakly as a back-reference.
 * @ghidraAddress 0x3cf74, 0x3cf94 */
@property(nonatomic, weak, nullable) RBMusicView *musicSelectedBase;
/** @brief The tappable difficulty button carrying the special-chart frame and level glyph.
 * @ghidraAddress 0x3cfa8, 0x3cfb8 */
@property(nonatomic, strong, nullable) UIButton *difficultyButton;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
