/** @file
 * The music-menu hub view. It is the @c UIView that hosts the whole music-select screen: the paged
 * music grid (an @c RBCollectionView driven by an @c RBMusicGridLayout of @c RBMusicCell items),
 * the menu chrome (the settings, ranking, and store buttons, the playlist add, delete, and finish
 * buttons, the random button, the wandering mascot, the scrolling news ticker, the page slider,
 * and the paging background), the search bar, and every overlay it presents over itself (the
 * settings panel, the
 * how-to-play, customize, theme, search, credits, notification, Applilink, and terms popups,
 * the first-run tutorial, the selected-music detail view, and the push-notification banner). It
 * also
 * owns the news download, the store update-time flash badges, and the playlist-editing mode.
 *
 * Reconstructed from Ghidra project rb458, program rb458 (class @c RBMenuView, image base
 * 0x100000000). @ghidraAddress values are offsets relative to the image base.
 */

#import <UIKit/UIKit.h>

#import "Downloader.h"
#import "RBCollectionView.h"
#import "RBMenuNewsTickerView.h"
#import "RBMenuPageSlider.h"

// The binary's class_ro_t adopts RBTermAgreeViewDelegate, whose protocol is not yet reconstructed;
// forward-declare it so the adopted-protocol list matches the binary verbatim.
@protocol RBTermAgreeViewDelegate;

@class Downloader;
@class RBCollectionView;
@class RBMenuBGEffectView;
@class RBMenuButton;
@class RBMenuMascot;
@class RBMenuNewsTickerView;
@class RBMenuPageSliderView;
@class RBMenuTutorialView;
@class RBMusicCell;
@class RBMusicData;
@class RBMusicGridLayout;
@class RBMusicView;
@class RBNotificationPagePhoneViewController;
@class RBPushNotificationView;
@class RBSearchMapViewController;
@class RBSettingView;
@class RBStoreTabController;
@class RBTermPhoneViewController;
@class RBViewController;

NS_ASSUME_NONNULL_BEGIN

/**
 * @brief The music-menu hub view that hosts the music grid, the menu chrome, and every overlay
 * presented over the music-select screen.
 */
// The adopted protocols are transcribed from the binary's class_ro_t baseProtocols list, in order:
// UICollectionViewDelegate, UICollectionViewDataSource, RBCollectionViewDelegate,
// UIGestureRecognizerDelegate, RBTermAgreeViewDelegate, DownloaderDelegate, and UISearchBarDelegate.
// (UIScrollViewDelegate is reached through UICollectionViewDelegate, and RBMenuPageSliderDelegate is
// only conformed to informally, so neither appears in the binary's list.)
@interface RBMenuView : UIView <UICollectionViewDelegate,
                                UICollectionViewDataSource,
                                RBCollectionViewDelegate,
                                UIGestureRecognizerDelegate,
                                RBTermAgreeViewDelegate,
                                DownloaderDelegate,
                                UISearchBarDelegate>

#pragma mark Lifecycle

/**
 * @brief Create the menu hub owned by the given view controller and build all of its subviews.
 * @param frame The view's frame rectangle.
 * @param viewController The hosting view controller, held weakly.
 * @return The initialised view, or @c nil.
 * @ghidraAddress 0xa20a8
 */
- (nullable instancetype)initWithFrame:(CGRect)frame
                        viewController:(nullable RBViewController *)viewController;

/**
 * @brief Build every subview of the hub: the paging background, the header and footer chrome, the
 * music grid and its layout, the menu and playlist buttons, the mascot, the news ticker, the
 * search bar, and the cover view.
 * @ghidraAddress 0xa47f8
 */
- (void)CreateView;

#pragma mark Rotation and layout

/**
 * @brief Prepare for a device rotation: record the centred grid item, fade the grid and background
 * out, and forward the event to the tutorial overlay and page slider.
 * @ghidraAddress 0xa113c
 */
- (void)willRotate;

/**
 * @brief Finish a device rotation: restore the equivalent page, fade the grid and background back
 * in, re-lay the paging background, and forward the event to the tutorial overlay and page slider.
 * @ghidraAddress 0xa13d8
 */
- (void)didRotate;

#pragma mark Presentation

/**
 * @brief Fade the whole menu in, load the music-select BGM and voices, reload the music data, and
 * schedule the interactive-enable and tutorial start.
 * @ghidraAddress 0xaa24c
 */
- (void)showAnimation;

/**
 * @brief Fade the whole menu out, stopping the news and background effect, and run the closing
 * tutorial step if needed.
 * @param hideAnimation The completion object invoked once the fade finishes.
 * @ghidraAddress 0xaaac8
 */
- (void)hideAnimation:(nullable id)hideAnimation;

/**
 * @brief Whether the menu is currently shown.
 * @return @c YES while the menu is shown.
 * @ghidraAddress 0xaafe4
 */
- (BOOL)isShow;

/**
 * @brief Present @p view over the menu, removing the previously shown view first.
 * @param view The view to show, or @c nil to clear it.
 * @ghidraAddress 0xa200c
 */
- (void)setShowView:(nullable UIView *)view;

/**
 * @brief Retry playing the music-select BGM on the next run-loop turn until it starts.
 * @ghidraAddress 0xaaa20
 */
- (void)ReplayMusic;

#pragma mark Music list and selection

/**
 * @brief Reload the menu's music data after the purchased-music catalogue, search, or playlist
 * changes: rebuild the list, reload the grid, recompute the page count, and refresh the playlist
 * button artwork.
 * @ghidraAddress 0xa8e28
 */
- (void)reloadMusicData;

/**
 * @brief Rebuild @c musicList from the music manager, applying the active search text and the
 * current playlist selection, then sort it.
 * @ghidraAddress 0xa9108
 */
- (void)createMusicList;

/**
 * @brief Present the detail view for the given music, animating it in.
 * @param selectMusic The music to select.
 * @param animated Whether to animate the detail view in.
 * @ghidraAddress 0xaaff0
 */
- (void)selectMusic:(nullable RBMusicData *)selectMusic animated:(BOOL)animated;

/**
 * @brief Pick and present a random music from the current list.
 * @param selectRandom The control that triggered the selection; its tag selects the animation.
 * @ghidraAddress 0xab3c8
 */
- (void)selectRandom:(nullable id)selectRandom;

/**
 * @brief Return a random integer in the inclusive range @p getRandamInt ... @p max, seeding the C
 * random generator once.
 * @param getRandamInt The lower bound.
 * @param max The upper bound.
 * @return The random integer.
 * @ghidraAddress 0xab350
 */
- (int)getRandamInt:(int)getRandamInt max:(int)max;

/**
 * @brief Remove and release the selected-music detail view, then refresh the information badges.
 * @ghidraAddress 0xab7ac
 */
- (void)releaseSelectMusic;

#pragma mark Setting view and menu buttons

/**
 * @brief Handle the settings button: toggle the settings overlay.
 * @ghidraAddress 0xab9d4
 */
- (void)SelectSettingButton;

/**
 * @brief Hide the settings overlay if it is showing.
 * @ghidraAddress 0xab9e0
 */
- (void)hideSettingView;

/**
 * @brief Toggle the settings overlay: build and open it, or close it.
 * @ghidraAddress 0xaba74
 */
- (void)toggleSettingView;

/**
 * @brief Handle the ranking button: dismiss the search bar and settings, then present the ranking
 * overlay.
 * @ghidraAddress 0xacd54
 */
- (void)SelectRankingButton;

/**
 * @brief Handle the store button: dismiss the search bar and settings, then verify the terms
 * version before opening the store.
 * @ghidraAddress 0xace3c
 */
- (void)SelectStoreButton;

/**
 * @brief Open the store tab controller, or re-open it when a pending store target is queued.
 * @ghidraAddress 0xad948
 */
- (void)StoreOpen;

/**
 * @brief Detach and release the store tab controller, restoring the menu BGM, news, and background
 * effect.
 * @ghidraAddress 0xab854
 */
- (void)RemoveStoreViewController;

/**
 * @brief Terms-agreement completion callback that opens the store.
 * @ghidraAddress 0xae3a4
 */
- (void)didFinishedSendAgree;

#pragma mark Setting sub-screens

/**
 * @brief Present the how-to-play overlay.
 * @ghidraAddress 0xabf94
 */
- (void)showHowToView;

/**
 * @brief Present the customize overlay, starting the customize tutorial step if needed.
 * @ghidraAddress 0xac0bc
 */
- (void)showCustomizeView;

/**
 * @brief Present the theme-selection overlay.
 * @ghidraAddress 0xac274
 */
- (void)showThema;

/**
 * @brief Present the map-search screen: a pushed controller on phones, an overlay on pads.
 * @ghidraAddress 0xac348
 */
- (void)showSearchView;

/**
 * @brief Present the staff-credits overlay.
 * @ghidraAddress 0xac564
 */
- (void)showCreditView;

/**
 * @brief Present the notification-page screen: a pushed controller on phones, an overlay on pads.
 * @ghidraAddress 0xac638
 */
- (void)showNotificationPageView;

/**
 * @brief Present the Applilink overlay.
 * @ghidraAddress 0xac808
 */
- (void)showApplilinkView;

/**
 * @brief Present the terms-of-use screen: a pushed controller on phones, an overlay on pads.
 * @ghidraAddress 0xac8dc
 */
- (void)showTermView;

/**
 * @brief Dismiss the currently shown overlay if it responds to @c hideAnimation.
 * @ghidraAddress 0xb5dfc
 */
- (void)closeCustomize;

#pragma mark Background effect

/**
 * @brief Start the animated background and mascot on the pastel theme.
 * @ghidraAddress 0xacaac
 */
- (void)startBGEffect;

/**
 * @brief Stop the animated background and mascot on the pastel theme.
 * @ghidraAddress 0xacc20
 */
- (void)stopBGEffect;

#pragma mark News ticker

/**
 * @brief Handle a tap on the news ticker: follow its link, or route to the store or notification
 * page.
 * @param sender The news ticker.
 * @ghidraAddress 0xade28
 */
- (void)TouchNews:(nullable id)sender;

/**
 * @brief Start or refresh the news download, or advance the ticker when the cache is still fresh.
 * @ghidraAddress 0xaf0a0
 */
- (void)startNews;

/**
 * @brief Restart the news download from the retry timer.
 * @ghidraAddress 0xaf2a8
 */
- (void)startNewsFromTimer;

/**
 * @brief Advance the news ticker to the next non-empty news text and schedule the next change.
 * @ghidraAddress 0xaf350
 */
- (void)showNextNewsText;

/**
 * @brief Stop the news ticker, cancel its timer, and cancel the news download.
 * @ghidraAddress 0xaf7e8
 */
- (void)stopNews;

/**
 * @brief Server-date callback stub. The binary body is empty.
 * @ghidraAddress 0xaf8bc
 */
- (void)SetServerDateYear:(int)year
                    Month:(int)month
                      Day:(int)day
                     Hour:(int)hour
                   Minute:(int)minute
                   Second:(int)second;

/**
 * @brief Refresh the settings/store button flash badges from the unseen-content flags.
 * @ghidraAddress 0xaf8c0
 */
- (void)showInfomation;

#pragma mark Downloader delegate

/**
 * @brief News/terms download completion: parse the news JSON, update the store badge, seed the
 * ticker, and show any pending information HUD.
 * @param downloader The finished downloader.
 * @ghidraAddress 0xae3b0
 */
- (void)downloaderFinished:(nullable Downloader *)downloader;

/**
 * @brief News download failure: schedule a retry timer.
 * @param downloader The failed downloader.
 * @ghidraAddress 0xaee80
 */
- (void)downloaderError:(nullable Downloader *)downloader;

#pragma mark Search

/**
 * @brief Rebuild the folded per-music search-term dictionary from the music manager.
 * @ghidraAddress 0xafa84
 */
- (void)createSearchDictionary;

/**
 * @brief Slide the search bar in and start editing, seeding it with the backed-up query and, on
 * the pastel theme, the pastel search mascot.
 * @ghidraAddress 0xb0274
 */
- (void)showSearchBar;

/**
 * @brief Resign the search bar's first-responder status.
 * @ghidraAddress 0xb0e18
 */
- (void)setSearchBarNonActive;

/**
 * @brief Slide the search bar out, backing up the query and clearing the filter.
 * @ghidraAddress 0xb0eac
 */
- (void)hideSearchBar;

/**
 * @brief Clear the search query and hide the search bar.
 * @ghidraAddress 0xb16dc
 */
- (void)tapSearchMusicCancel;

/**
 * @brief Update the search-token array from the query, returning whether the token set changed.
 * @param searchString The raw query string.
 * @return @c YES when the token set changed.
 * @ghidraAddress 0xb17b8
 */
- (BOOL)searchStringChanged:(nullable NSString *)searchString;

/**
 * @brief Split and fold a query string into its unique non-empty search tokens.
 * @param searchString The raw query string.
 * @return The search-token array.
 * @ghidraAddress 0xb1b5c
 */
- (nullable NSMutableArray *)getSearchArray:(nullable NSString *)searchString;

/**
 * @brief Apply the current search tokens as the global search filter and reload the music data.
 * @ghidraAddress 0xb1d14
 */
- (void)exeSearchPickUp;

/**
 * @brief Whether every current search token is found in the given music's search-term list.
 * @param matchTitle The music to test.
 * @return @c YES when the music matches every search token.
 * @ghidraAddress 0xb1e4c
 */
- (BOOL)matchTitle:(nullable RBMusicData *)matchTitle;

#pragma mark Tutorial

/**
 * @brief Build the tutorial overlay for the music-select or customize step when it is due.
 * @ghidraAddress 0xb52a0
 */
- (void)preStartTutorial;

/**
 * @brief Start the pending tutorial step once its target control is on screen.
 * @ghidraAddress 0xb5678
 */
- (void)startTutorial;

/**
 * @brief The tutorial song's cell the music-select tutorial step highlights.
 * @return The tutorial music cell, or @c nil.
 * @ghidraAddress 0xb58c4
 */
- (nullable RBMusicCell *)getTutorialMusicCell;

/**
 * @brief The song grid the music-select tutorial step highlights.
 * @return The collection view.
 * @ghidraAddress 0xb5be8
 */
- (nullable RBCollectionView *)getCollectionView;

/**
 * @brief The settings button the settings tutorial step highlights.
 * @return The settings button.
 * @ghidraAddress 0xb5bf4
 */
- (nullable RBMenuButton *)getSettingButton;

/**
 * @brief The store button the store tutorial step highlights.
 * @return The store button.
 * @ghidraAddress 0xb5c00
 */
- (nullable RBMenuButton *)getStoreButton;

/**
 * @brief Hide the mascot and search mascot for the duration of a tutorial step.
 * @ghidraAddress 0xb5c0c
 */
- (void)setPastelForTutorialStart;

/**
 * @brief Restore the search mascot after a tutorial step (the mascot itself stays hidden).
 * @ghidraAddress 0xb5cb0
 */
- (void)setPastelForTutorialEnd;

/**
 * @brief Tear down the tutorial overlay.
 * @ghidraAddress 0xb5d54
 */
- (void)closeTutorial;

#pragma mark Playlist editing

/**
 * @brief Enter playlist add or delete mode, sliding the menu buttons to reveal the edit controls.
 * @ghidraAddress 0xb5ec4
 */
- (void)playlistEditStart;

/**
 * @brief Leave playlist editing, sliding the menu buttons back and reloading the music data.
 * @ghidraAddress 0xb740c
 */
- (void)playlistEditFinish;

/**
 * @brief Enable or disable the add/delete confirm button from the current edit selection.
 * @ghidraAddress 0xb8618
 */
- (void)playlistAddDelButtonUpdate;

/**
 * @brief Handle the playlist add-confirm button: add the edit selection to the active playlist.
 * @ghidraAddress 0xb8754
 */
- (void)SelectPlaylistAddButton;

/**
 * @brief Handle the playlist delete-confirm button: remove the edit selection from the active
 * playlist and reload.
 * @ghidraAddress 0xb882c
 */
- (void)SelectPlaylistDelButton;

/**
 * @brief Handle the playlist finish button: persist the playlist and leave editing.
 * @ghidraAddress 0xb8aa4
 */
- (void)SelectPlaylistFinButton;

/**
 * @brief Enter the given playlist edit mode when the current mode allows it.
 * @param currentMenuMode The edit mode to enter.
 * @return @c YES when the mode was entered.
 * @ghidraAddress 0xb8b14
 */
- (BOOL)setCurrentMenuMode:(int)currentMenuMode;

#pragma mark Page slider

/**
 * @brief Present the page slider over the search bar area when nothing else is shown.
 * @param showPageSlider Unused; the presentation is gated by the search-bar position.
 * @ghidraAddress 0xb8b90
 */
- (void)showPageSlider:(BOOL)showPageSlider;

/**
 * @brief Page-slider delegate callback: page the grid to the requested page and update the
 * slider's index label.
 * @param changePage A three-element array: the snapped page, the fractional page, and whether the
 * drag has ended.
 * @ghidraAddress 0xb8e94
 */
- (void)changePage:(nullable NSArray<NSNumber *> *)changePage;

#pragma mark Mascot

/**
 * @brief Toggle the music cells' visibility when the mascot is tapped.
 * @ghidraAddress 0xb93c4
 */
- (void)touchMascot;

#pragma mark Push notification

/**
 * @brief Slide the push-notification banner in when nothing blocks it.
 * @ghidraAddress 0xb4810
 */
- (void)showPushNotificationView;

/**
 * @brief Push-notification action: route to the store, an external URL, or a web page.
 * @ghidraAddress 0xb4ae8
 */
- (void)actionFromPushNotificationView;

/**
 * @brief Push-notification dismissal: restore or keep the search mascots hidden.
 * @ghidraAddress 0xb4f2c
 */
- (void)finishPushNotification;

#pragma mark Collection view cell configuration

/**
 * @brief Configure a music cell for the current playlist-edit state and load its artwork and
 * score.
 * @param configureCell The cell to configure.
 * @ghidraAddress 0xb2280
 */
- (void)configureCell:(nullable RBMusicCell *)configureCell;

/**
 * @brief Advance the search-pick-up handler for a long-press on the grid.
 * @param handleLongPressGesture The long-press gesture recogniser.
 * @ghidraAddress 0xb21e4
 */
- (void)handleLongPressGesture:(nullable UILongPressGestureRecognizer *)handleLongPressGesture;

/**
 * @brief Handle the end of any grid scroll: snap the page, reconfigure visible cells, and page the
 * background.
 * @param scrollViewDidEndScroll The scroll view that stopped.
 * @ghidraAddress 0xb2fec
 */
- (void)scrollViewDidEndScroll:(nullable UIScrollView *)scrollViewDidEndScroll;

#pragma mark RBCollectionView layout and touch forwarding

/**
 * @brief Collection-view will-layout callback. The binary body is empty.
 * @param willLayoutSubviews The collection view.
 * @ghidraAddress 0xb43a0
 */
- (void)willLayoutSubviews:(nullable UIView *)willLayoutSubviews;

/**
 * @brief Collection-view did-layout callback: recompute the page count, snap the current page, and
 * update the mascot's bounce limits.
 * @param didLayoutSubviews The collection view.
 * @ghidraAddress 0xb43a4
 */
- (void)didLayoutSubviews:(nullable UIView *)didLayoutSubviews;

/**
 * @brief Collection-view touch-began forwarding. The binary body is empty.
 * @param touches The began touches.
 * @param event The event the touches belong to.
 * @ghidraAddress 0xb4740
 */
- (void)touchesBeganFromRBCollectionView:(nullable NSSet *)touches
                               withEvent:(nullable UIEvent *)event;

/**
 * @brief Collection-view touch-ended forwarding: dismiss the keyboard while the search bar shows.
 * @param touches The ended touches.
 * @param event The event the touches belong to.
 * @ghidraAddress 0xb4744
 */
- (void)touchesEndedFromRBCollectionView:(nullable NSSet *)touches
                               withEvent:(nullable UIEvent *)event;

#pragma mark Debug

/**
 * @brief Debug no-op that walks the grid's subviews. The binary discards its results.
 * @ghidraAddress 0xb95c8
 */
- (void)debugAlphaLog;

#pragma mark Properties

/** @brief Whether the menu is currently shown. */
@property(assign, nonatomic) BOOL showed;
/** @brief Whether the music cells are hidden (toggled by tapping the mascot). */
@property(assign, nonatomic) BOOL musicCellHidden;
/** @brief Whether the next music selection is a battle-mode selection. */
@property(assign, nonatomic) BOOL battleMusicSelect;

/** @brief The index of the news text currently shown in the ticker. */
@property(assign, nonatomic) int newsInfoIndex;
/** @brief The grid item recorded before a rotation, used to restore the equivalent page. */
@property(assign, nonatomic) int prevIndex;
/** @brief The current playlist edit mode. */
@property(assign, nonatomic) int playListEditMode;

/** @brief The base Y position of the pastel search mascot, derived from the font variant. */
@property(assign, nonatomic) float searchPastelPosBaseY;

/** @brief The number of distinct paging background images. */
@property(assign, nonatomic) NSUInteger backgroundImageCount;
/** @brief The paging background's current logical page. */
@property(assign, nonatomic) NSUInteger backgroundCurrentPage;

/** @brief The current grid page index. Setting it updates the page label. */
@property(assign, nonatomic) NSInteger currentPageIndex;
/** @brief The number of grid pages (never less than one). Setting it updates the page label. */
@property(assign, nonatomic) NSInteger maxPage;

/** @brief The hosting view controller, held weakly. */
@property(weak, nonatomic, nullable) RBViewController *viewController;
/** @brief The paged music grid. */
@property(strong, nonatomic, nullable) RBCollectionView *collectionView;
/** @brief The selected-music detail view presented over the grid. */
@property(strong, nonatomic, nullable) RBMusicView *selectedView;
/** @brief The playlist toggle button. */
@property(strong, nonatomic, nullable) UIButton *playListButton;
/** @brief The random-select button. */
@property(strong, nonatomic, nullable) UIButton *randomButton;
/** @brief The new-content badge over the random button. */
@property(strong, nonatomic, nullable) UIImageView *randomInfoView;
/** @brief The new-content badge over the playlist button. */
@property(strong, nonatomic, nullable) UIImageView *playlistInfoView;
/** @brief The playlist add-song confirm button. */
@property(strong, nonatomic, nullable) RBMenuButton *playlistAddButton;
/** @brief The playlist delete-song confirm button. */
@property(strong, nonatomic, nullable) RBMenuButton *playlistDelButton;
/** @brief The settings overlay, present while it is shown. */
@property(strong, nonatomic, nullable) RBSettingView *settingView;
/** @brief The view currently shown over the menu, held weakly. */
@property(weak, nonatomic, nullable) UIView *showView;
/** @brief The first-run tutorial overlay, held weakly. */
@property(weak, nonatomic, nullable) RBMenuTutorialView *tutorialView;
/** @brief The full-screen background image view. */
@property(strong, nonatomic, nullable) UIImageView *backgroundView;
/** @brief The top header chrome image view. */
@property(strong, nonatomic, nullable) UIImageView *headerView;
/** @brief The bottom footer chrome view that holds the menu buttons. */
@property(strong, nonatomic, nullable) UIView *footerView;
/** @brief The current-page-of-total page label. */
@property(strong, nonatomic, nullable) UILabel *pageLabel;
/** @brief The horizontally paging background scroll view. */
@property(strong, nonatomic, nullable) UIScrollView *backgroundScrollView;
/** @brief The settings menu button. */
@property(strong, nonatomic, nullable) RBMenuButton *settingButton;
/** @brief The ranking menu button. */
@property(strong, nonatomic, nullable) RBMenuButton *rankButton;
/** @brief The store menu button. */
@property(strong, nonatomic, nullable) RBMenuButton *storeButton;
/** @brief The playlist finish-editing button. */
@property(strong, nonatomic, nullable) RBMenuButton *playlistFinButton;
/** @brief The store update-time flash badge. */
@property(strong, nonatomic, nullable) UIImageView *storeInfoView;
/** @brief The dimming cover view used for the show/hide fade. */
@property(strong, nonatomic, nullable) UIView *coverView;
/** @brief The timer that re-enables interaction after the show animation. */
@property(strong, nonatomic, nullable) NSTimer *showAnimationTimer;
/** @brief The pushed map-search view controller (phone builds). */
@property(strong, nonatomic, nullable) RBSearchMapViewController *mapViewController;
/** @brief The pushed notification-page web view controller (phone builds). */
@property(strong, nonatomic, nullable) RBNotificationPagePhoneViewController *webViewController;
/** @brief The pushed terms-of-use view controller (phone builds). */
@property(strong, nonatomic, nullable) RBTermPhoneViewController *termViewController;
/** @brief The scrolling news ticker banner. */
@property(strong, nonatomic, nullable) RBMenuNewsTickerView *newsView;
/** @brief The news download in flight. */
@property(strong, nonatomic, nullable) Downloader *newsDownloader;
/** @brief The store's last-seen update-time string. */
@property(strong, nonatomic, nullable) NSString *storeUpdateTime;
/** @brief The array of news texts cycled through the ticker. */
@property(strong, nonatomic, nullable) NSArray *newsInfoText;
/** @brief The timer that advances the news ticker. */
@property(strong, nonatomic, nullable) NSTimer *newsBannerTimer;
/** @brief The time the current news was fetched, used to decide cache freshness. */
@property(strong, nonatomic, nullable) NSDate *newsGetTime;
/** @brief The pushed store tab controller. */
@property(strong, nonatomic, nullable) RBStoreTabController *storeViewController;
/** @brief The terms-version download in flight. */
@property(strong, nonatomic, nullable) Downloader *termDownloader;
/** @brief The current list of music shown in the grid. */
@property(strong, nonatomic, nullable) NSMutableArray *musicList;
/** @brief The grid layout. */
@property(strong, nonatomic, nullable) RBMusicGridLayout *layout;
/** @brief The wandering mascot. */
@property(strong, nonatomic, nullable) RBMenuMascot *mascot;
/** @brief The animated pastel background effect view. */
@property(strong, nonatomic, nullable) RBMenuBGEffectView *bgEffectView;
/** @brief The search bar. */
@property(strong, nonatomic, nullable) UISearchBar *searchBar;
/** @brief The search-cancel button beside the search bar. */
@property(strong, nonatomic, nullable) UIButton *searchCancelButton;
/** @brief The backed-up search query, restored when the search bar is shown again. */
@property(strong, nonatomic, nullable) NSString *backUpString;
/** @brief The current array of folded search tokens. */
@property(strong, nonatomic, nullable) NSMutableArray *searchArray;
/** @brief The per-music folded search-term dictionary. */
@property(strong, nonatomic, nullable) NSMutableDictionary *searchDictionary;
/** @brief The per-music search-term expansion list. */
@property(strong, nonatomic, nullable) NSMutableArray *expandDictionary;
/** @brief The pastel search-mascot frames. */
@property(strong, nonatomic, nullable) NSMutableArray *searchMascotImages;
/** @brief The pastel search-mascot image view. */
@property(strong, nonatomic, nullable) UIImageView *searchMascot;
/** @brief The push-notification banner view. */
@property(strong, nonatomic, nullable) RBPushNotificationView *pushNotificationView;
/** @brief The page slider popup, held weakly. */
@property(weak, nonatomic, nullable) RBMenuPageSliderView *pageSlider;
/** @brief The set of music IDs selected during playlist editing. */
@property(strong, nonatomic, nullable) NSMutableSet *playlistEditSet;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
