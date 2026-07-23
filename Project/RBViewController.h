/** @file
 * The application's root view controller. It hosts the OpenGL ES game view (@c neGLView) and the
 * music-select menu (@c RBMenuView), drives the game task/draw loop from a @c CADisplayLink, and
 * owns the transitions into the preview and gameplay screens. It also implements the Twitter
 * (Social framework) posting flow, the playlist popover presentation, the corporate-logo button,
 * and the iTunes store product presentation, so it acts as several delegates
 * (@c NSURLConnection, @c UINavigationController, @c SKStoreProductViewControllerDelegate, and the
 * playlist/menu-sort callbacks).
 *
 * Reconstructed from Ghidra project rb458, program rb458 (class RBViewController, image base
 * 0x100000000). @ghidraAddress values are offsets relative to the image base.
 */

#import <UIKit/UIKit.h>

#import "RBBaseViewController.h"

@class CADisplayLink;
@class MusicData;
@class NSOperationQueue;
@class NSURLConnection;
@class NSURLRequest;
@class RBCorporateViewController;
@class RBMenuView;
@class RBPlaylistViewController;
@class RBTermAgreeView;
@class SKStoreProductViewController;
@class TwitterImageCreater;
@class UIPopoverController;
@class neGLView;

NS_ASSUME_NONNULL_BEGIN

/**
 * @brief Root view controller that hosts the game GL view and music-select menu and runs the
 * display-link game loop.
 */
@interface RBViewController : RBBaseViewController <UINavigationControllerDelegate>

#pragma mark - Class helpers

/**
 * @brief Reports whether the legacy Twitter compose API class is present at runtime.
 * @return @c YES when @c TWTweetComposeViewController can be resolved by name.
 * @ghidraAddress 0x8d540
 */
+ (BOOL)hasTwitterAPI;

/**
 * @brief Reports whether a tweet can currently be composed for the Twitter service.
 * @return @c YES when the Twitter API is present and available for the Twitter service type.
 * @ghidraAddress 0x8d564
 */
+ (BOOL)canTweet;

#pragma mark - Lifecycle and view loop

/**
 * @brief Initialises the loop timing, resume, and preview-cache state.
 * @ghidraAddress 0x88fc0
 */
- (instancetype)init;

/**
 * @brief Loads the view, creates the @c neGLView, and adds the corporate button.
 * @ghidraAddress 0x89050
 */
- (void)loadView;

/**
 * @brief Hides the navigation bar and toolbar and forces the status bar hidden.
 * @param animated Whether the appearance is animated.
 * @ghidraAddress 0x8a134
 */
- (void)viewWillAppear:(BOOL)animated;

/** @brief Returns the hosted OpenGL ES view.
 * @ghidraAddress 0x8af30
 */
- (nullable neGLView *)openGLView;

/**
 * @brief Runs one game-logic tick and compacts the shared touch list.
 * @ghidraAddress 0x8af3c
 */
- (void)Task;

/**
 * @brief Renders one frame when the render timer has elapsed.
 * @ghidraAddress 0x8af88
 */
- (void)Draw;

/**
 * @brief Rebuilds the GL viewport and camera projection for the current front-buffer size.
 * @ghidraAddress 0x8a800
 */
- (void)UpdateProjection;

/**
 * @brief Rebuilds the projection after the GL view is laid out.
 * @param glView The GL view that was laid out.
 * @ghidraAddress 0x8a7e4
 */
- (void)LayoutedGLView:(nullable neGLView *)glView;

#pragma mark - Display-link loop control

/**
 * @brief Marks the loop active and (re)creates the display-link timer.
 * @ghidraAddress 0x8b0a8
 */
- (void)StartLoop;

/**
 * @brief Marks the loop inactive and invalidates the display-link timer.
 * @ghidraAddress 0x8b0c4
 */
- (void)StopLoop;

/**
 * @brief Clears the resume flag and (re)creates the display-link timer.
 * @ghidraAddress 0x8b0f8
 */
- (void)RestartLoop;

/**
 * @brief Creates the display-link timer when resumed and looping.
 * @ghidraAddress 0x8b2a0
 */
- (void)CreateTimer;

/**
 * @brief Invalidates and releases the display-link timer.
 * @ghidraAddress 0x8b314
 */
- (void)RemoveTimer;

/**
 * @brief Lazily creates the @c CADisplayLink, targets @c -mainLoop, and adds it to the run loop.
 * @ghidraAddress 0x8b110
 */
- (void)CreateDisplayLinkTimer;

/**
 * @brief Sets the loop frame interval (in units of display refreshes) and recreates the timer.
 * @param milliSec The frame interval to store.
 * @ghidraAddress 0x8b288
 */
- (void)SetLoopTimeMilliSec:(float)milliSec;

#pragma mark - Menu view management

/**
 * @brief Creates the music menu view and the tweet cover view if they do not yet exist.
 * @ghidraAddress 0x89c90
 */
- (void)createView;

/**
 * @brief Removes the music menu view from its superview and releases it.
 * @ghidraAddress 0x89c24
 */
- (void)removeView;

/**
 * @brief Shows the music-select menu, releases cached textures, stops the loop, and applies the
 * takeover point.
 * @ghidraAddress 0x8b3bc
 */
- (void)showMusicListView;

/**
 * @brief Runs the erosion-mark score update check for this controller.
 * @ghidraAddress 0x8e2d8
 */
- (void)updateErosionMarkScore;

#pragma mark - Preview and gameplay

/**
 * @brief Enters the song preview: applies user settings to the game system, updates the
 * projection, pauses BGM, and starts the loop.
 * @ghidraAddress 0x8be40
 */
- (void)startPreview;

/**
 * @brief Hides the menu and cover views to show the preview scene.
 * @ghidraAddress 0x8c8cc
 */
- (void)showPreview;

/**
 * @brief Leaves the preview, restores the menu, reloads the menu BGM, and restores the projection.
 * @ghidraAddress 0x8c970
 */
- (void)hidePreview;

/**
 * @brief Populates the game system from the selected song's scores and user settings, hides the
 * menu, and starts the game loop.
 * @param musicData The selected song, or @c nil for the preview song.
 * @param randSeed The random seed to seed the game with.
 * @ghidraAddress 0x8b5b8
 */
- (void)playGameWithMusicData:(nullable MusicData *)musicData RandSeed:(int)randSeed;

/**
 * @brief Notifies that the game client has reached its end (no-op placeholder).
 * @ghidraAddress 0x8b5b4
 */
- (void)clientIsGameEnd;

#pragma mark - Playlist popover

/**
 * @brief Presents the playlist "add to set" popover for the given music set.
 * @param musicSet The music set to add to.
 * @ghidraAddress 0x89798
 */
- (void)playListAddMusicSet:(nullable id)musicSet;

/**
 * @brief Handles the playlist button: opens the playlist create/browse popover.
 * @param sender The control that fired the action.
 * @ghidraAddress 0x8997c
 */
- (void)playListButtonPush:(nullable id)sender;

/**
 * @brief Presents the playlist popover anchored on the menu's playlist button.
 * @ghidraAddress 0x893c4
 */
- (void)showPresentViewController;

/**
 * @brief Presents the playlist navigation controller either modally or in a popover.
 * @param anchorView The view the popover is anchored to.
 * @ghidraAddress 0x8945c
 */
- (void)showPresentViewController:(nullable UIView *)anchorView;

/**
 * @brief Dismisses the playlist popover and reloads the menu after a playlist selection.
 * @param viewController The playlist view controller that finished.
 * @ghidraAddress 0x8a294
 */
- (void)didSelectPlaylistViewController:(nullable id)viewController;

/**
 * @brief Reloads the menu after a sort-order selection.
 * @param viewController The sort view controller that finished.
 * @ghidraAddress 0x8a3e8
 */
- (void)didSelectMenuSortViewController:(nullable id)viewController;

#pragma mark - Rotation

/**
 * @brief Notifies the menu view that a rotation is beginning.
 * @param toInterfaceOrientation The target interface orientation.
 * @param duration The rotation animation duration.
 * @ghidraAddress 0x8a530
 */
- (void)willRotateToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation
                                duration:(NSTimeInterval)duration;

/**
 * @brief Notifies the menu view that a rotation has finished.
 * @param fromInterfaceOrientation The previous interface orientation.
 * @ghidraAddress 0x8a584
 */
- (void)didRotateFromInterfaceOrientation:(UIInterfaceOrientation)fromInterfaceOrientation;

/**
 * @brief Drives the menu rotation callbacks alongside the modern size-transition coordinator.
 * @param size The new view size.
 * @param coordinator The transition coordinator.
 * @ghidraAddress 0x8a5d8
 */
- (void)viewWillTransitionToSize:(CGSize)size
       withTransitionCoordinator:(id<UIViewControllerTransitionCoordinator>)coordinator;

#pragma mark - Corporate button and terms

/**
 * @brief Lazily creates the corporate-logo button and adds it to the view.
 * @ghidraAddress 0x8e2f4
 */
- (void)setupCorporateButton;

/**
 * @brief Fades the corporate button to the given alpha, removing it once fully faded.
 * @param alpha The target alpha value.
 * @ghidraAddress 0x8e550
 */
- (void)fadeCorporateButton:(float)alpha;

/**
 * @brief Opens the corporate web link (Safari view controller when available, otherwise the
 * browser).
 * @param sender The button that fired the action.
 * @ghidraAddress 0x8e898
 */
- (void)tapCorporateButton:(nullable id)sender;

/**
 * @brief Presents the terms-agreement popup with the given delegate.
 * @param delegate The delegate to notify when the terms are agreed.
 * @ghidraAddress 0x8e118
 */
- (void)showTermsWithDelegate:(nullable id)delegate;

#pragma mark - iTunes store

/**
 * @brief Presents the App Store product for a URL, or opens the URL when it is not an affiliate
 * link.
 * @param url The iTunes/App Store URL.
 * @ghidraAddress 0x8ce28
 */
- (void)openItunesWithURL:(nullable NSURL *)url;

/**
 * @brief Walks the presentation chain from the root controller to the top-most presented one.
 * @param rootViewController The root view controller to start from.
 * @return The top-most presented view controller.
 * @ghidraAddress 0x8d264
 */
- (nullable UIViewController *)getTopViewController:(nullable UIViewController *)rootViewController;

#pragma mark - Twitter

/**
 * @brief Composes and presents a tweet with the given text, images, and URLs.
 * @param text The tweet text.
 * @param images The images to attach.
 * @param urls The URLs to attach.
 * @ghidraAddress 0x8d5b4
 */
- (void)PostTwitter:(nullable NSString *)text
             Images:(nullable NSArray *)images
               URLs:(nullable NSArray *)urls;

/**
 * @brief Composes and presents a tweet built from the stored tweet text and image.
 * @ghidraAddress 0x8d9c0
 */
- (void)PostTweet;

/**
 * @brief Begins a tweet flow guarded by a network reachability probe.
 * @param imageCreater The image creator to run before posting.
 * @param text The tweet text.
 * @return @c YES when the flow was started.
 * @ghidraAddress 0x8dbbc
 */
- (BOOL)PostTwitter:(nullable TwitterImageCreater *)imageCreater Text:(nullable NSString *)text;

/**
 * @brief Runs the queued Twitter image creator and then posts the tweet on the main thread.
 * @ghidraAddress 0x8dacc
 */
- (void)PostImageCreater;

/**
 * @brief Cancels the in-flight tweet, shows a network-error alert, and clears the tweet state.
 * @ghidraAddress 0x8de58
 */
- (void)cancelTwitterConnection;

#pragma mark - Properties

/** @brief The hosted OpenGL ES game view.
 * @ghidraAddress 0x8ebc4
 */
@property(nonatomic, strong, nullable) neGLView *glView;

/** @brief The display link driving the game loop.
 * @ghidraAddress 0x8ec0c
 */
@property(nonatomic, strong, nullable) CADisplayLink *displayLink;

/** @brief The music-select menu view.
 * @ghidraAddress 0x8eac0
 */
@property(nonatomic, strong, nullable) RBMenuView *musicMenuView;

/** @brief The dimming cover shown over the menu while tweeting.
 * @ghidraAddress 0x8ec54
 */
@property(nonatomic, strong, nullable) UIView *tweetCoverView;

/** @brief The popover controller presenting the playlist navigation stack.
 * @ghidraAddress 0x8eb08
 */
@property(nonatomic, strong, nullable) UIPopoverController *playlistPopoverController;

/** @brief The playlist view controller being presented.
 * @ghidraAddress 0x8ed74
 */
@property(nonatomic, strong, nullable) RBPlaylistViewController *playlistViewController;

/** @brief The terms-agreement popup view.
 * @ghidraAddress 0x8eb50
 */
@property(nonatomic, strong, nullable) RBTermAgreeView *termAgreeView;

/** @brief The pending tweet text.
 * @ghidraAddress 0x8eb70
 */
@property(nonatomic, strong, nullable) NSString *tweetText;

/** @brief The pending tweet image.
 * @ghidraAddress 0x8eb8c
 */
@property(nonatomic, strong, nullable) UIImage *tweetImage;

/** @brief The Twitter image creator that renders the score card.
 * @ghidraAddress 0x8eba8
 */
@property(nonatomic, strong, nullable) TwitterImageCreater *twitterImageCreater;

/** @brief The serial queue that runs the Twitter image creator.
 * @ghidraAddress 0x8ec9c
 */
@property(nonatomic, strong, nullable) NSOperationQueue *twitterImageCreaterQueue;

/** @brief The reachability-probe request for the Twitter flow.
 * @ghidraAddress 0x8ece4
 */
@property(nonatomic, strong, nullable) NSURLRequest *twitterRequestTest;

/** @brief The reachability-probe connection for the Twitter flow.
 * @ghidraAddress 0x8ed2c
 */
@property(nonatomic, strong, nullable) NSURLConnection *twitterConnectionTest;

/** @brief The presented App Store product view controller.
 * @ghidraAddress 0x8edbc
 */
@property(nonatomic, strong, nullable) SKStoreProductViewController *itunesViewCtrl;

/** @brief The corporate-logo button.
 * @ghidraAddress 0x8ee04
 */
@property(nonatomic, strong, nullable) UIButton *corporateButton;

/** @brief The corporate web view controller.
 * @ghidraAddress 0x8ee24
 */
@property(nonatomic, strong, nullable) RBCorporateViewController *corporateViewCtrl;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C++
// kate: hl Objective-C++;
// vim: set ft=objcpp :
