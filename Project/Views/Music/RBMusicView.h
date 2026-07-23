/** @file
 * The music-select detail view. It is the panel that slides down over the music grid when a song is
 * chosen: it shows the jacket, the music and artist name images, the BPM, the per-difficulty score,
 * rank, full-combo, and achievement-rate readouts, and it hosts the paged setting scroll (the
 * difficulty, colour, and CPU sub-views), the decide, double-play, history, random, and pastel
 * buttons, and the replay-ghost indicator. It drives the transition into gameplay by seeding the
 * shared @c RBUserSettingData and @c GameSystem from the chosen setting and calling the hosting
 * view controller's play entry point. @c RBMenuView owns and presents it, and @c RBSettingView
 * holds it as its @c parentView.
 *
 * Reconstructed from Ghidra project rb458, program rb458 (class @c RBMusicView, image base
 * 0x100000000). @ghidraAddress values are offsets relative to the image base.
 */

#import <UIKit/UIKit.h>

@class MusicData;
@class MusicDataExtend;
@class RBMenuView;
@class RBMusicARView;
@class RBMusicColorView;
@class RBMusicCPUView;
@class RBMusicDifficultyView;
@class RBMusicHistoryView;
@class RBMusicOtherView;
@class RBMusicScoreView;
@class RBMusicSpeedView;

NS_ASSUME_NONNULL_BEGIN

/**
 * @brief The music-select detail view presented over the music grid.
 *
 * The adopted protocols are transcribed from the binary's class_ro_t baseProtocols list, in order:
 * UIScrollViewDelegate and UIGestureRecognizerDelegate.
 */
@interface RBMusicView : UIView <UIScrollViewDelegate, UIGestureRecognizerDelegate>

#pragma mark Lifecycle

/**
 * @brief Create the detail view for the given music and build its whole panel.
 *
 * Calls through to @c super, seeds the theme from @c RBUserSettingData, sets the music, resets the
 * game type, and builds the panel, difficulty selection, and setting view. On a font variant the
 * animated line overlay is also built.
 * @param frame The view's frame rectangle.
 * @param MusicData The music this detail view describes.
 * @return The initialised view, or @c nil.
 * @ghidraAddress 0xcbbac
 */
- (nullable instancetype)initWithFrame:(CGRect)frame MusicData:(nullable MusicData *)MusicData;

#pragma mark View construction

/**
 * @brief Build the entire detail panel: the jacket, the name images, the BPM, the score, rank,
 * full-combo, and achievement-rate readouts, the paged setting scroll and its difficulty, colour,
 * and CPU sub-views, and every button.
 * @ghidraAddress 0xcc078
 */
- (void)SetupView;

/**
 * @brief Build the per-difficulty BPM digit image column, laying the digits out from @p Point.
 * @param bpm The song BPM.
 * @param Point The origin the digit column is laid out from; its x is advanced per digit.
 * @ghidraAddress 0xcbe70
 */
- (void)setBpm:(int)bpm Point:(CGPoint *)Point;

/**
 * @brief Build the animated select-line overlay (font-variant layouts only).
 * @ghidraAddress 0xd2764
 */
- (void)SetUpLineView;

#pragma mark Score, rank, and difficulty readout

/**
 * @brief Refresh the score, achievement-rate, rank, and full-combo readouts for the current
 * difficulty, then update the ghost and per-difficulty sub-view.
 * @ghidraAddress 0xd2fd8
 */
- (void)ShowSelectDifficulty;

/**
 * @brief Set the rank badge image for the given rank, or clear it for @c -1.
 * @param SetRankView The rank index, or @c -1 to clear the badge.
 * @ghidraAddress 0xd2ddc
 */
- (void)SetRankView:(int)SetRankView;

/**
 * @brief Show or hide the replay-ghost indicator for the given difficulty, dimming it per the
 * user's ghost style.
 * @param SetGhostView The difficulty to test for a saved replay.
 * @ghidraAddress 0xd397c
 */
- (void)SetGhostView:(int)SetGhostView;

/**
 * @brief Route the per-difficulty sub-view update to the difficulty-specific handler.
 * @param switchWithDifficulty The selected difficulty.
 * @ghidraAddress 0xd0f3c
 */
- (void)switchWithDifficulty:(int)switchWithDifficulty;

#pragma mark Setting view

/**
 * @brief Select the given setting page (colour, difficulty, or CPU), animating the button highlight
 * and sub-view fade.
 * @param ShowSettingView The setting page index.
 * @return @c YES when the selection changed.
 * @ghidraAddress 0xd33a8
 */
- (BOOL)ShowSettingView:(int)ShowSettingView;

/**
 * @brief Highlight the selected setting button and dim the others.
 * @param SetSettingButtonSelected The selected button index.
 * @ghidraAddress 0xd37a8
 */
- (void)SetSettingButtonSelected:(int)SetSettingButtonSelected;

/**
 * @brief Update the pastel and double-play button availability and the decide-button enablement
 * from the current user settings.
 * @ghidraAddress 0xd3b50
 */
- (void)updateDecideButton;

/**
 * @brief Enable or disable the difficulty sub-view's buttons.
 * @param enableButton Whether the buttons are enabled.
 * @ghidraAddress 0xd6684
 */
- (void)setEnableButton:(BOOL)enableButton;

/**
 * @brief Enable or disable the setting scroll and show or hide its page control.
 * @param scrollable Whether the setting scroll can be paged.
 * @ghidraAddress 0xd65dc
 */
- (void)setScrollable:(BOOL)scrollable;

/**
 * @brief Page-control action: scroll the setting view to the selected page.
 * @param selectPage The page control.
 * @ghidraAddress 0xd60d4
 */
- (void)selectPage:(nullable id)selectPage;

#pragma mark Button actions

/**
 * @brief Decide button: seed the replay data and start the game, or the tutorial game when due.
 * @ghidraAddress 0xd4028
 */
- (void)SelectDecideButton;

/**
 * @brief Double-play button: clear the pastel modes, select the double game type, and start.
 * @ghidraAddress 0xd3fac
 */
- (void)SelectDoublePlayButton;

/**
 * @brief White-pastel button: select the white-pastel mode and start (unless animating).
 * @ghidraAddress 0xd4620
 */
- (void)SelectWhitePastelButton;

/**
 * @brief Black-pastel button: select the black-pastel mode and start (unless animating).
 * @ghidraAddress 0xd4694
 */
- (void)SelectBlackPastelButton;

/**
 * @brief History button: toggle the play-history overlay for the current music and difficulty.
 * @ghidraAddress 0xd44d0
 */
- (void)SelectHistory;

/**
 * @brief iTunes button: open the song's iTunes page through the hosting view controller.
 * @ghidraAddress 0xd4f54
 */
- (void)SelectItunes;

/**
 * @brief Seed the shared user settings and game system from the current selection, then start play.
 * @ghidraAddress 0xd4708
 */
- (void)playGame;

/**
 * @brief Seed the tutorial defaults, load the tutorial song, and start the tutorial game.
 * @ghidraAddress 0xd4c5c
 */
- (void)playTutorialGame;

#pragma mark Presentation

/**
 * @brief Animate the detail panel in (or, when @p showAnimation is @c NO, snap it in without a fade)
 * and start the select BGM.
 * @param showAnimation Whether to run the fade-in animation.
 * @ghidraAddress 0xd50a0
 */
- (void)showAnimation:(BOOL)showAnimation;

/**
 * @brief Animate the detail panel out: commit the selection to the shared settings, stop the BGM,
 * and reset the menu background.
 * @ghidraAddress 0xd5680
 */
- (void)hideAnimation;

/**
 * @brief Retry starting the select BGM on the next run-loop turn until it plays.
 * @ghidraAddress 0xd5ca4
 */
- (void)ReplayMusic;

#pragma mark First-info hint animation

/**
 * @brief Run the one-time setting-scroll hint animation.
 * @ghidraAddress 0xd5d4c
 */
- (void)firstInfoAnimation;

/**
 * @brief Show the one-time setting-scroll hint the first time the detail view opens.
 * @ghidraAddress 0xd5f38
 */
- (void)firstInfoAnimationCheck;

/**
 * @brief Advance the setting-scroll hint after each scroll step, or finish it.
 * @ghidraAddress 0xd61e0
 */
- (void)setFirstScrollAnimation;

/**
 * @brief Continue the setting-scroll hint once a hint scroll step ends.
 * @ghidraAddress 0xd61b0
 */
- (void)firstInfoScrollEnd;

#pragma mark UIScrollViewDelegate

/**
 * @brief Update the setting page control and title images as the setting scroll moves.
 * @param scrollViewDidScroll The scrolling scroll view.
 * @ghidraAddress 0xd66e0
 */
- (void)scrollViewDidScroll:(nullable UIScrollView *)scrollViewDidScroll;

#pragma mark UIGestureRecognizerDelegate

/**
 * @brief Background-tap handler: dismiss the detail panel when the tap is outside the panel.
 * @param tapGesture The tap gesture recogniser.
 * @ghidraAddress 0xd6bfc
 */
- (void)tapGesture:(nullable UITapGestureRecognizer *)tapGesture;

/**
 * @brief Gate the background-tap gesture so it does not fire on the panel or on a control.
 * @param gestureRecognizer The gesture recogniser.
 * @param shouldReceiveTouch The touch to test.
 * @return @c YES when the tap should be received.
 * @ghidraAddress 0xd6cec
 */
- (BOOL)gestureRecognizer:(nullable UIGestureRecognizer *)gestureRecognizer
       shouldReceiveTouch:(nullable UITouch *)shouldReceiveTouch;

#pragma mark Tutorial accessors

/**
 * @brief The decide button the tutorial highlights.
 * @return The decide button.
 * @ghidraAddress 0xd6b1c
 */
- (nullable UIButton *)getDecideButton;

/**
 * @brief The double-play button the tutorial highlights, or @c nil when it has not been built.
 * @return The double-play button, or @c nil.
 * @ghidraAddress 0xd6b28
 */
- (nullable UIButton *)getDoubleButton;

/**
 * @brief The difficulty button the tutorial highlights for the given difficulty.
 * @param getDifficultyButton The difficulty index.
 * @return The difficulty button.
 * @ghidraAddress 0xd6b8c
 */
- (nullable UIButton *)getDifficultyButton:(int)getDifficultyButton;

#pragma mark Properties

/** @brief The music this detail view describes. */
@property(strong, nonatomic, nullable) MusicData *musicData;
/** @brief The extended music record, when the extended (level 4) difficulty is selected. */
@property(strong, nonatomic, nullable) MusicDataExtend *extMusicData;
/** @brief The music menu that presents this detail view, held weakly. */
@property(weak, nonatomic, nullable) RBMenuView *musicMenuView;

/** @brief Whether this detail view was reached from the random-select button. */
@property(assign, nonatomic) BOOL isRandom;
/** @brief Whether the white-pastel mode is selected. */
@property(assign, nonatomic) BOOL m_IsWhitePastelMode;
/** @brief Whether the black-pastel mode is selected. */
@property(assign, nonatomic) BOOL m_IsBlackPastelMode;

/** @brief The themed base panel that hosts every sub-view. */
@property(strong, nonatomic, nullable) UIView *baseView;
/** @brief The panel background image view. */
@property(strong, nonatomic, nullable) UIImageView *bgImageView;
/** @brief The one-time setting-scroll hint image view. */
@property(strong, nonatomic, nullable) UIImageView *firstInfoView;
/** @brief The jacket image. */
@property(strong, nonatomic, nullable) UIImage *jacketImage;
/** @brief The music-name image view. */
@property(strong, nonatomic, nullable) UIImageView *musicNameImageView;
/** @brief The artist-name image view. */
@property(strong, nonatomic, nullable) UIImageView *artistNameImageView;
/** @brief The jacket image view. */
@property(strong, nonatomic, nullable) UIImageView *jacketImageView;
/** @brief The per-difficulty score readout. */
@property(strong, nonatomic, nullable) RBMusicScoreView *scoreView;
/** @brief The full-combo badge. */
@property(strong, nonatomic, nullable) UIImageView *fullComboView;
/** @brief The rank badge. */
@property(strong, nonatomic, nullable) UIImageView *rankView;
/** @brief The achievement-rate readout. */
@property(strong, nonatomic, nullable) RBMusicARView *arView;
/** @brief The three setting page buttons (colour, difficulty, and CPU). */
@property(strong, nonatomic, nullable) NSMutableArray *settingButtons;
/** @brief The selected-state overlays of the three setting buttons. */
@property(strong, nonatomic, nullable) NSMutableArray *settingButtonEffects;
/** @brief The dimming covers of the three setting buttons. */
@property(strong, nonatomic, nullable) NSMutableArray *settingButtonCovers;
/** @brief The difficulty-selection sub-view. */
@property(strong, nonatomic, nullable) RBMusicDifficultyView *difficultyView;
/** @brief The speed-selection sub-view. */
@property(strong, nonatomic, nullable) RBMusicSpeedView *speedView;
/** @brief The dimming cover over the double-play button. */
@property(strong, nonatomic, nullable) UIImageView *doubleButtonCoverView;
/** @brief The extra options sub-view. */
@property(strong, nonatomic, nullable) RBMusicOtherView *otherView;
/** @brief The per-note extend-note sub-views. */
@property(strong, nonatomic, nullable) NSMutableArray *extendNoteViews;
/** @brief The player-colour sub-view. */
@property(strong, nonatomic, nullable) RBMusicColorView *colorView;
/** @brief The CPU-level sub-view. */
@property(strong, nonatomic, nullable) RBMusicCPUView *cpuView;
/** @brief The paged setting scroll that hosts the difficulty, colour, and CPU sub-views. */
@property(strong, nonatomic, nullable) UIScrollView *settingScroll;
/** @brief The setting scroll's page control. */
@property(strong, nonatomic, nullable) UIPageControl *settingPage;
/** @brief The per-page setting title images. */
@property(strong, nonatomic, nullable) NSMutableArray *settingTitleImages;
/** @brief The song's iTunes URL string, when it has one. */
@property(strong, nonatomic, nullable) NSString *iTunesURL;
/** @brief The animated select-line overlay (font-variant layouts). */
@property(strong, nonatomic, nullable) UIView *lineView;
/** @brief The animated select-line overlay layers. */
@property(strong, nonatomic, nullable) NSMutableArray *lineAnimationLayers;
/** @brief The BPM digit column origin. */
@property(assign, nonatomic) CGPoint bpmOrigin;
/** @brief The BPM label image view. */
@property(strong, nonatomic, nullable) UIImageView *bpmImageView;
/** @brief The decide button. */
@property(strong, nonatomic, nullable) UIButton *decideButton;
/** @brief The double-play button. */
@property(strong, nonatomic, nullable) UIButton *doubleButton;
/** @brief The play-history overlay. */
@property(strong, nonatomic, nullable) RBMusicHistoryView *historyView;
/** @brief The history button. */
@property(strong, nonatomic, nullable) UIButton *historyButton;
/** @brief The random-select button. */
@property(strong, nonatomic, nullable) UIButton *randomButton;
/** @brief The white-pastel play button (held without ownership, matching the binary). */
@property(assign, nonatomic, nullable) UIButton *whitePastelButton;
/** @brief The black-pastel play button (held without ownership, matching the binary). */
@property(assign, nonatomic, nullable) UIButton *blackPastelButton;
/** @brief The replay-ghost indicator image view. */
@property(strong, nonatomic, nullable) UIImageView *ghostImageView;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C++
// kate: hl Objective-C++;
// vim: set ft=objcpp :
