#import "RBMenuView.h"

#import "AppDelegate.h"
#import "AudioManager.h"
#import "Downloader.h"
#import "NetworkUtil.h"
#import "RBBGMManager.h"
#import "RBCampaignData.h"
#import "RBCollectionView.h"
#import "RBCoreDataManager.h"
#import "RBCreditsView.h"
#import "RBCustomView.h"
#import "RBHowToView.h"
#import "RBMenuBGEffectView.h"
#import "RBMenuButton.h"
#import "RBMenuMascot.h"
#import "RBMenuNewsTickerView.h"
#import "RBMenuPageSliderView.h"
#import "RBMenuTutorialView.h"
#import "RBMusicGridLayout.h"
#import "RBMusicManager.h"
#import "RBPlaylistManager.h"
#import "RBSettingView.h"
#import "RBTutorialManager.h"
#import "RBUserSettingData.h"
#import "RBViewController.h"
#import "ScoreData.h"
#import "UIImage+RB.h"
#import "UIImageView+RB.h"
#import "UIView+RB.h"
#import "neEngineBridge.h"

// Theme identifiers returned by RBUserSettingData.thema.
enum {
    kThemaClassic = 0, // Classic (REFLEC) theme.
    kThemaWhite = 1,   // White theme.
    kThemaPastel = 2,  // Pastel (Colette) theme; adds the animated background and mascot.
};

// Playlist selection identifiers stored in RBUserSettingData.playlistID.
enum {
    kPlaylistIDNone = 0,     // No playlist selected.
    kPlaylistIDHotBonus = 1, // The hot-bonus playlist.
    kPlaylistIDLevel = 2,    // A difficulty-level playlist.
    kPlaylistIDCustom = 3,   // A named custom playlist.
    kPlaylistIDFavorite = 4, // The favourites playlist.
};

// Playlist editing modes stored in playListEditMode.
enum {
    kMenuModePlaylistAdd = 0,      // Adding songs to a playlist.
    kMenuModePlaylistDelete = 1,   // Removing songs from a playlist.
    kMenuModePlaylistFinished = 2, // Not editing; the resting mode.
};

// Tutorial-status query indices passed to getTutorialStatus:.
static const int kTutorialStatusMusicSelect = 0x17;
static const int kTutorialStatusSetting = 0x22;
static const int kTutorialStatusCustomize = 0x22;

// Tutorial step identifiers.
static const NSUInteger kTutorialTypeMusicSelect = 0x18;
static const NSUInteger kTutorialTypeCustomize = 0;
static const NSUInteger kTutorialTypeMenuHide = 10;

// Menu-item sort modes stored in RBUserSettingData.menuItemSort.
static const int kMenuItemSortArtist = 1;

// Themed sound-effect identifiers.
static const int kSoundEffectDecide = 3;
static const long kSoundEffectSearchBarShow = 0x11;
static const long kSoundEffectSearchBarHide = 0x12;

// Search-mascot behaviour.
static const int kSearchMascotDefaultBias = 90; // rand()%100 threshold; below it uses image [0].
static const float kSearchPushNotificationOverlapFactor = -0.9f;

// Alpha and fade values.
static const CGFloat kAlphaHidden = 0.0;
static const CGFloat kAlphaOpaque = 1.0;
static const CGFloat kCoverFadeDuration = 0.5;
static const CGFloat kArtworkFadeInStartAlpha = 0.0;

// Animation timings.
static const int64_t kShowAnimationDelayNanos = 500000000; // 0.5 s show/hide completion delay.
static const NSTimeInterval kPlaylistEditAnimationDuration = 0.5;
static const NSTimeInterval kPlaylistEditAnimationDelay = 0.0;

// Page snap fractions used by didLayoutSubviews.
static const float kPageSnapLowFraction = 0.3f;
static const float kPageSnapHighFraction = 0.7f;
static const float kPageSnapMidpoint = 0.5f;
static const CGFloat kBackgroundVerticalOffsetFactor = -0.4;

// News handling.
static const NSTimeInterval kNewsGetTimeOffset = 0.0;
static const NSTimeInterval kNewsCacheValiditySeconds = -300.0; // Fresh if fetched < 5 min ago.
static const NSTimeInterval kNewsBannerDefaultInterval = 10.8;
static const CGFloat kNewsTickerDuration = 10.7;
static const CGFloat kNewsHUDCentreScale = 0.5;
static const uint32_t kNewsRandomMask = 0xff;
static const int kNewsInvalidInformationID = -1;

static NSString *const kNewsKeyUpdateTime = @"UpdateTime";
static NSString *const kNewsKeyUpdateText = @"UpdateText";
static NSString *const kNewsKeyInfo = @"Info";
static NSString *const kNewsKeyID = @"ID";
static NSString *const kNewsKeyVer = @"Ver";
static NSString *const kNewsKeyImage = @"Image";
static NSString *const kNewsKeyMessage = @"Message";
static NSString *const kNewsKeyLink = @"Link";
static NSString *const kNewsKeyCFBundleVersion = @"CFBundleVersion";

// Terms-version request and response.
static NSString *const kTermsRequestKeyTarget = @"target";
static NSString *const kTermsRequestContentType = @"application/json";
static NSString *const kTermsKeyList = @"list";
static NSString *const kTermsKeyType = @"type";
static NSString *const kTermsKeyVersion = @"version";
static const NSInteger kTermsRecordTypeCurrent = 1; // The current terms-of-service record's type.

// The search-mascot base Y positions selected by the font variant, decoded from the binary.
static const float kSearchPastelPosBaseYWide = 85.0f;
static const float kSearchPastelPosBaseYTall = 140.0f;

// The white-theme (font-variant) settings-anchor rectangle offsets, decoded from the binary.
static const CGFloat kSettingAnchorOffsetX = -102.0;
static const CGFloat kSettingAnchorOffsetY = -24.0;
static const CGFloat kSettingAnchorWidth = 204.0;
static const CGFloat kSettingAnchorHeight = 48.0;

// The music name of the tutorial's placeholder song, matched to find the tutorial cell. The
// CFString is stored as UTF-16 in the binary (@0x10036c4e0).
static NSString *const kTutorialPlaceholderMusicName = @"威風堂々";

// Autoresizing masks used verbatim from the binary's raw flag values.
static const UIViewAutoresizing kBackgroundAutoresizingMask =
    UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight; // 0x12.

// CreateView geometry, decoded from the binary.
static const CGFloat kFooterLightTallHeight = 22.0;
static const CGFloat kFooterLightWideHeight = 8.0;
static const CGFloat kFooterCapFraction = 0.5;
static const CGFloat kPageLabelHalfWidthFactor = 0.5;
static const CGFloat kPageLabelOriginXInset = -75.0;
static const CGFloat kPageLabelWidth = 150.0;
static const CGFloat kPageLabelHeight = 100.0;
static const CGFloat kPageLabelFontWide = 14.0;
static const CGFloat kPageLabelFontTall = 16.0;
static const CGFloat kNewsTickerHeightInset = -100.0;
static const CGFloat kSearchCancelWidthWide = 48.0;
static const CGFloat kSearchCancelWidthTall = 98.0;
static const CGFloat kSearchBarOriginY = -52.0;
static const CGFloat kSearchBarHeight = 52.0;
static const CGFloat kMascotWidth = 46.0;
static const CGFloat kMascotHeight = 61.0;
static const CGFloat kMascotCampaignWidth = 112.0;
static const CGFloat kMascotCampaignHeight = 126.0;
static const float kInfoFlashDuration = 0.33333334f;
static const float kInfoFlashStart = 1.0f;
static const float kInfoFlashEnd = 0.2f;
static const NSInteger kRandomButtonTag = 1;
static const int kCampaignBackgroundMaxImages = 10;
static const int kSearchMascotMaxImages = 99;

// Artwork basenames used by CreateView.
static NSString *const kTextureBackgroundName = @"01_music_select/bg";
static NSString *const kHeaderImageName = @"01_music_select/header";
static NSString *const kFooterImageName = @"01_music_select/footer";
static NSString *const kPlaylistImageName = @"01_music_select/sel_playlist";
static NSString *const kPlaylistSelImageName = @"01_music_select/sel_playlist_sel";
static NSString *const kRandomImageName = @"01_music_select/sel_random";
static NSString *const kRandomSelImageName = @"01_music_select/sel_random_sel";
static NSString *const kInfoPlaylistName = @"01_music_select/info_playlist";
static NSString *const kInfoRandomName = @"01_music_select/info_random";
static NSString *const kInfoNewName = @"01_music_select/info_new";
static NSString *const kSearchBackgroundName = @"01_music_select/search_bg";
static NSString *const kSearchMascotDefaultPrefix = @"01_music_select/search_mascot_";
static NSString *const kSearchCancelImageNameWide = @"01_music_select/search_cancel_btn_pn2";
static NSString *const kSearchCancelImageNameTall = @"01_music_select/search_cancel_btn";

// layoutSubviews per-theme geometry metrics, decoded from the binary. The "wide" set applies when
// the font-variant flag is clear (the native-resolution wide layout); the "tall" set when it is
// set. These are the design constants the button rows and columns are laid out from.
static const CGFloat kLayoutWideThemaCampaignWidthDelta = -81.0;   // @0x100300fd0
static const CGFloat kLayoutWideThemaCampaignHeightDelta = -867.0; // @0x100300fd8
static const CGFloat kLayoutWideThemaCampaignFooterNormal = 867.0; // @0x100300fe0
static const CGFloat kLayoutWideThemaCampaignFooterEdit = 912.0;   // @0x100300fe8
static const CGFloat kLayoutWideThemaClassicWidthDelta = -40.0;    // @0x100301000
static const CGFloat kLayoutWideThemaClassicHeightDelta = -865.0;  // @0x100301008
static const CGFloat kLayoutWideThemaClassicFooterNormal = 865.0;  // @0x100301010
static const CGFloat kLayoutWideThemaClassicFooterEdit = 908.0;    // @0x100301018
static const CGFloat kLayoutWidePastelWhiteSettingX = 49.0; // @0x100300ff0 (settingButton X).
static const CGFloat kLayoutWideCollectionOriginY = 60.0;   // @0x1002ee948 (all wide themes).

static const CGFloat kLayoutTallBoundsInset8 = -8.0;
static const CGFloat kLayoutTallBoundsInset16 = -16.0;
static const CGFloat kLayoutTallHeightExtra60 = -60.0; // @0x100300fc8
static const CGFloat kLayoutTallHeightExtra64 = -64.0; // @0x100300fc0
static const CGFloat kLayoutTallThemaClassicFooterYExtra = 7.0;
static const CGFloat kLayoutTallThemaCampaignFooterYExtra = 6.0;
static const CGFloat kLayoutTallThemaWhiteFooterYExtra = 4.0;

// Column and row design coordinates for the wide layout.
static const int kLayoutWideThemaClassicCol1 = 0x107;
static const int kLayoutWideThemaClassicCol2 = 0x1fa;
static const int kLayoutWideThemaClassicPlaylistX = 0x7e;
static const int kLayoutWideThemaClassicRandomX = 0x256;
static const int kLayoutWideThemaClassicCol0 = 0x361;
static const int kLayoutWideThemaClassicPlaylistFinX = 0x38c;
static const int kLayoutWideThemaOtherCol1 = 0x11d;
static const int kLayoutWideThemaOtherCol2 = 0x209;
static const int kLayoutWideThemaOtherPlaylistX = 0x88;
static const int kLayoutWideThemaOtherRandomX = 0x260;
static const int kLayoutWideThemaOtherCol0 = 0x363;
static const int kLayoutWideThemaOtherPlaylistFinX = 0x390;

static const int kLayoutSideButtonSizeWide = 0x2c;           // 44 points.
static const int kLayoutSideButtonSizeTall = 0x1e;           // 30 points.
static const int kLayoutWideCampaignHorizontalMargin = 0x28; // 40-point campaign row margin.

// The settingButton X for the wide classic theme is a design double.
static const CGFloat kLayoutWideThemaClassicSettingX = 20.0;
static const CGFloat kLayoutTallThemaWhiteSideButton = 44.0; // 0x4036 double.

// The computed (base/3) tall-layout row and column arithmetic constants. The tall layouts derive
// the button rows from a row base rather than from a fixed design coordinate.
static const CGFloat kLayoutTallRowHalfHeightFactor = -0.5; // bounds.height * -0.5 in the row math.
static const CGFloat kLayoutTallRowBaseBias = -4.0;         // The trailing bias on the row math.
static const CGFloat kLayoutTallCol2BiasClassic = -4.0;     // col2 = (bounds.width + this) - width.
static const CGFloat kLayoutTallCol2BiasWhite = -12.0;
static const int kLayoutTallPlaylistXBiasClassic = -11; // playlistX = sixth + this (-0xb).
static const int kLayoutTallPlaylistXBiasWhite = -3;
static const int kLayoutTallRandomXBias = -15;    // randomX = (sixth + col2) + this (-0xf).
static const int kLayoutTallBaseInsetPastel = -2; // base = (bounds.width - 8) - 2.
static const CGFloat kLayoutTallWhiteStoreInfoInset = -3.0; // storeInfoInsetWidth = width + this.
static const CGFloat kLayoutTallWhiteWidthExtra = -22.0; // wide white storeInfoInset = width - 22.
static const CGFloat kLayoutTallWhiteCollectionOriginXExtra = -3.0;
static const CGFloat kLayoutTallSettingXClassicPastel = 4.0; // settingButton X (the 4.0 slot).
static const CGFloat kLayoutTallSettingXWhite = 12.0;        // settingButton X for the tall white.

// Whether the C random generator has been seeded (from getRandamInt:max:).
static BOOL g_bRandamIntSeeded = NO;

// The not-yet-reconstructed collaborators this hub creates or messages. They are forward-declared
// so the hub compiles ahead of their own reconstructions; each is a small overlay or controller.
@class RBApplilinkView;
@class RBMusicSearchExpander;
@class RBNewsHUDView;
@class RBNotificationPageView;
@class RBRankingView;
@class RBSearchView;
@class RBTermView;
@class RBThemaView;

@interface RBMenuView ()

/** @brief Build the tall-layout header and the theme 0/1 footer. */
- (void)buildHeaderAndFooter:(NSInteger)thema;
/** @brief Build the campaign paging background; returns whether the effect view was used. */
- (BOOL)buildCampaignBackground:(BOOL)isFontVariant;
/** @brief Build the button bar, grid, mascot, search UI, news ticker, cover, and gestures. */
- (void)buildMenuBarWithThema:(NSInteger)thema
                  fontVariant:static_cast<BOOL>(isFontVariant)
     backgroundUsesEffectView:static_cast<BOOL>(bgUsesEffectView);
/** @brief Re-lay the wrapping paging background scroll view and its image pages. */
- (void)layoutPagingBackground;
/** @brief Lay out the search bar, cancel button, and pastel mascot for the search state. */
- (void)layoutSearchBarActive:(BOOL)active;
/** @brief Slide the menu buttons to reveal or hide the playlist-edit controls. */
- (void)shiftMenuButtonsForPlaylistEditEntering:(BOOL)entering;
/** @brief Hide or show the pastel search mascots for the push-notification transition. */
- (void)setSearchMascotsHidden:(BOOL)hidden;
/** @brief Terms-version download success: prompt to re-accept updated terms, or open the store. */
- (void)handleTermsVersionResponse;
/** @brief Terms-version download failure: present the network-error alert. */
- (void)handleTermsNetworkError;

@end

@implementation RBMenuView

#pragma mark - Rotation

- (void)willRotate {
    self.prevIndex = 0;
    [self debugAlphaLog];
    if (self.currentPageIndex != 0) {
        // Record the item roughly centred on the current page so didRotate can restore the
        // equivalent page after the geometry changes.
        NSInteger pageItemCount = self.layout.pageItemCount;
        self.prevIndex =
            static_cast<int>((static_cast<float>((self.currentPageIndex * pageItemCount)) +
                              static_cast<float>(self.layout.pageItemCount) * kPageSnapMidpoint));
    }
    self.collectionView.alpha = kAlphaHidden;
    if (self.backgroundScrollView != nil) {
        self.backgroundScrollView.alpha = kAlphaHidden;
    }
    [self debugAlphaLog];
    if (self.tutorialView != nil) {
        [self.tutorialView willRotate];
    }
    if (self.pageSlider != nil) {
        [self.pageSlider willRotate];
    }
}

- (void)didRotate {
    [self debugAlphaLog];

    int restoredPage = 0;
    if (self.prevIndex != 0) {
        NSUInteger pageItemCount = self.layout.pageItemCount;
        if (pageItemCount != 0) {
            restoredPage = static_cast<int>(
                (static_cast<long>(self.prevIndex) / static_cast<long>(pageItemCount)));
        }
    }

    CGFloat pageWidth = self.collectionView.frame.size.width;
    [self.collectionView
        scrollRectToVisible:CGRectMake(static_cast<double>(restoredPage) * pageWidth,
                                       0,
                                       self.collectionView.frame.size.width,
                                       self.collectionView.frame.size.height)
                   animated:NO];
    [self debugAlphaLog];

    self.currentPageIndex = static_cast<long>(
        (self.collectionView.contentOffset.x / self.collectionView.frame.size.width));
    self.maxPage = static_cast<long>(
        (self.collectionView.contentSize.width / self.collectionView.frame.size.width));
    self.prevIndex = 0;

    [UIView animateWithDuration:g_dAudioManagerResumeFadeInTime
                     animations:^{
                       /** @ghidraAddress 0xa1980 */
                       self.collectionView.alpha = kAlphaOpaque;
                       if (self.backgroundScrollView != nil) {
                           self.backgroundScrollView.alpha = kAlphaOpaque;
                       }
                     }];

    if (self.backgroundScrollView != nil && (GetFontVariantFlag() & 1) == 0) {
        [self layoutPagingBackground];
    }

    if (self.tutorialView != nil) {
        [self.tutorialView didRotate];
    }
    if (self.pageSlider != nil) {
        [self.pageSlider reset:self.maxPage currentPage:self.currentPageIndex + 1];
        [self.pageSlider didRotate];
    }
}

- (void)layoutSubviews {
    [super layoutSubviews];

    NSInteger thema = [RBUserSettingData sharedInstance].thema;
    // The binary dispatches on the raw font-variant flag: a zero flag takes the computed (base/3)
    // layouts and a non-zero flag takes the fixed design-coordinate layouts. The named theme sets
    // below keep the binary's own "wide" and "tall" constant names.
    BOOL isFontVariant = GetFontVariantFlag() != kFontVariantDefault;
    CGSize bounds = self.bounds.size;

    // The per-theme layout metrics. Each branch fills the same set of column and row coordinates,
    // transcribed from the decompiled soft-float computation, and drives the shared placement below.
    int footerY = 0;
    int menuButtonWidth = 0; // A one-third column stride for the setting/rank/store row.
    int settingRowY = 0;     // The setting/rank/store row Y.
    int playlistRowY = 0;    // The playlist add/delete/finish row Y.
    int col1 = 0, col2 = 0;
    int playlistX = 0, randomX = 0;
    int pageLabelInnerY = 0; // The page-label origin Y (distinct from the side-button row Y).
    int sideButtonSize = kLayoutSideButtonSizeTall;
    CGFloat settingColX = 0.0; // The setting/add/del column X (a design double).
    CGFloat collectionOriginX = 0.0;
    CGFloat collectionOriginY = 0.0;
    CGFloat sideButtonRowY = 0.0; // The playlist/random side-button (and info badge) row Y.
    CGFloat storeInfoInsetWidth = 0.0;
    int editMode = self.playListEditMode;

    if (isFontVariant) {
        // Fixed design-coordinate layouts (the binary's "wide" constants). In every wide theme the
        // page-label origin Y is the fixed column-0 coordinate, whereas the side-button row Y takes
        // that fixed coordinate only while editing and is computed from the height otherwise.
        if (thema == kThemaClassic) {
            footerY = static_cast<int>((bounds.height - self.footerView.frame.size.height));
            menuButtonWidth =
                static_cast<int>((bounds.width + kLayoutWideThemaClassicWidthDelta)) / 3;
            if (editMode == kMenuModePlaylistFinished) {
                playlistRowY = static_cast<int>((self.height + kLayoutWideThemaClassicHeightDelta +
                                                 kLayoutWideThemaClassicFooterEdit));
                sideButtonRowY = kLayoutWideThemaClassicCol0;      // 0x361 reused as the row Y.
                settingRowY = kLayoutWideThemaClassicPlaylistFinX; // 0x38c reused as the row Y.
            } else {
                sideButtonRowY =
                    static_cast<int>((self.height + kLayoutWideThemaClassicHeightDelta +
                                      kLayoutWideThemaClassicFooterNormal));
                settingRowY = static_cast<int>((self.height + kLayoutWideThemaClassicHeightDelta +
                                                kLayoutWideThemaClassicFooterEdit));
                playlistRowY = kLayoutWideThemaClassicPlaylistFinX; // 0x38c reused as the row Y.
            }
            settingColX = kLayoutWideThemaClassicSettingX;
            col1 = kLayoutWideThemaClassicCol1;
            col2 = kLayoutWideThemaClassicCol2;
            playlistX = kLayoutWideThemaClassicPlaylistX;
            randomX = kLayoutWideThemaClassicRandomX;
            pageLabelInnerY = kLayoutWideThemaClassicCol0;
            collectionOriginX = 0.0;
            collectionOriginY = kLayoutWideCollectionOriginY;
            storeInfoInsetWidth = bounds.width;
            sideButtonSize = kLayoutSideButtonSizeWide;
        } else if (thema == kThemaPastel) {
            menuButtonWidth =
                (static_cast<int>((bounds.width + kLayoutWideThemaCampaignWidthDelta)) -
                 kLayoutWideCampaignHorizontalMargin) /
                3;
            if (editMode == kMenuModePlaylistFinished) {
                playlistRowY = static_cast<int>((self.height + kLayoutWideThemaCampaignHeightDelta +
                                                 kLayoutWideThemaCampaignFooterEdit));
                sideButtonRowY = kLayoutWideThemaOtherCol0;      // 0x363 reused as the row Y.
                settingRowY = kLayoutWideThemaOtherPlaylistFinX; // 0x390 reused as the row Y.
            } else {
                sideButtonRowY =
                    static_cast<int>((self.height + kLayoutWideThemaCampaignHeightDelta +
                                      kLayoutWideThemaCampaignFooterNormal));
                settingRowY = static_cast<int>((self.height + kLayoutWideThemaCampaignHeightDelta +
                                                kLayoutWideThemaCampaignFooterEdit));
                playlistRowY = kLayoutWideThemaOtherPlaylistFinX; // 0x390 reused as the row Y.
            }
            col1 = kLayoutWideThemaOtherCol1;
            col2 = kLayoutWideThemaOtherCol2;
            playlistX = kLayoutWideThemaOtherPlaylistX;
            randomX = kLayoutWideThemaOtherRandomX;
            settingColX = kLayoutWidePastelWhiteSettingX;
            pageLabelInnerY = kLayoutWideThemaOtherCol0;
            collectionOriginX = 0.0;
            collectionOriginY = kLayoutWideCollectionOriginY;
            storeInfoInsetWidth = bounds.width;
            sideButtonSize = kLayoutSideButtonSizeWide;
        } else if (thema == kThemaWhite) {
            menuButtonWidth =
                (static_cast<int>((bounds.width + kLayoutWideThemaCampaignWidthDelta)) -
                 kLayoutWideCampaignHorizontalMargin) /
                3;
            if (editMode == kMenuModePlaylistFinished) {
                playlistRowY = static_cast<int>((self.height + kLayoutWideThemaCampaignHeightDelta +
                                                 kLayoutWideThemaCampaignFooterEdit));
                sideButtonRowY = kLayoutWideThemaOtherCol0;      // 0x363 reused as the row Y.
                settingRowY = kLayoutWideThemaOtherPlaylistFinX; // 0x390 reused as the row Y.
            } else {
                sideButtonRowY =
                    static_cast<int>((self.height + kLayoutWideThemaCampaignHeightDelta +
                                      kLayoutWideThemaCampaignFooterNormal));
                settingRowY = static_cast<int>((self.height + kLayoutWideThemaCampaignHeightDelta +
                                                kLayoutWideThemaCampaignFooterEdit));
                playlistRowY = kLayoutWideThemaOtherPlaylistFinX; // 0x390 reused as the row Y.
            }
            settingColX = kLayoutWidePastelWhiteSettingX;
            col1 = kLayoutWideThemaOtherCol1;
            col2 = kLayoutWideThemaOtherCol2;
            playlistX = kLayoutWideThemaOtherPlaylistX;
            randomX = kLayoutWideThemaOtherRandomX;
            pageLabelInnerY = kLayoutWideThemaOtherCol0;
            collectionOriginX = kLayoutTallThemaWhiteSideButton; // 0x4036 slot (44.0) reused here.
            collectionOriginY = kLayoutWideCollectionOriginY;
            storeInfoInsetWidth = bounds.width + kLayoutTallWhiteWidthExtra; // width - 22.
            sideButtonSize = kLayoutSideButtonSizeWide;
        }
    } else {
        // Computed (base/3) layouts (the binary's "tall" arithmetic). The classic and pastel themes
        // share the same column tail; the white theme uses wider insets and its own settingButton X.
        if (thema == kThemaClassic || thema == kThemaPastel) {
            int base;
            int rowBase;
            if (thema == kThemaClassic) {
                footerY = static_cast<int>(((bounds.height - self.footerView.frame.size.height) +
                                            kLayoutTallThemaClassicFooterYExtra));
                base = static_cast<int>((bounds.width + kLayoutTallBoundsInset8));
                rowBase = static_cast<int>((bounds.height + kLayoutTallHeightExtra60));
                settingColX = kLayoutTallSettingXClassicPastel; // 4.0 slot reused as button X.
                collectionOriginX = 0.0;
            } else {
                footerY = 0; // The tall pastel theme has no footer.
                base = static_cast<int>((bounds.width + kLayoutTallBoundsInset8)) +
                       kLayoutTallBaseInsetPastel;
                rowBase = static_cast<int>((bounds.height + kLayoutTallHeightExtra64 +
                                            kLayoutTallThemaCampaignFooterYExtra));
                settingColX =
                    kLayoutTallSettingXClassicPastel; // 4.0 slot reused (via shared tail).
                collectionOriginX = 0.0;
            }
            pageLabelInnerY = static_cast<int>((static_cast<double>(rowBase) +
                                                bounds.height * kLayoutTallRowHalfHeightFactor +
                                                kLayoutTallRowBaseBias));
            if (editMode == kMenuModePlaylistFinished) {
                settingRowY = rowBase;
                sideButtonRowY = static_cast<double>(pageLabelInnerY);
                playlistRowY =
                    static_cast<int>((static_cast<double>(rowBase) +
                                      (self.height - static_cast<double>(pageLabelInnerY))));
            } else {
                sideButtonRowY = static_cast<double>(
                    static_cast<int>((static_cast<double>(pageLabelInnerY) +
                                      (self.height - static_cast<double>(pageLabelInnerY)))));
                settingRowY =
                    static_cast<int>((static_cast<double>(rowBase) +
                                      (self.height - static_cast<double>(pageLabelInnerY))));
                playlistRowY = rowBase;
            }
            menuButtonWidth = base / 3;
            int sixth = base / 6;
            col1 = static_cast<int>(
                (bounds.width * kPageLabelHalfWidthFactor - static_cast<double>(sixth)));
            col2 = static_cast<int>(((bounds.width + kLayoutTallCol2BiasClassic) -
                                     static_cast<double>(menuButtonWidth)));
            playlistX = sixth + kLayoutTallPlaylistXBiasClassic;
            randomX = (sixth + col2) + kLayoutTallRandomXBias;
            collectionOriginY = 0.0;
            storeInfoInsetWidth = bounds.width;
            sideButtonSize = kLayoutSideButtonSizeTall;
        } else if (thema == kThemaWhite) {
            footerY = 0; // The tall white theme fills the footer slot from CreateView, not here.
            int base = static_cast<int>((bounds.width + kLayoutTallBoundsInset16)) +
                       kLayoutTallBaseInsetPastel;
            int rowBase = static_cast<int>(
                (bounds.height + kLayoutTallHeightExtra64 + kLayoutTallThemaWhiteFooterYExtra));
            pageLabelInnerY = static_cast<int>((static_cast<double>(rowBase) +
                                                bounds.height * kLayoutTallRowHalfHeightFactor +
                                                kLayoutTallRowBaseBias));
            if (editMode == kMenuModePlaylistFinished) {
                settingRowY = rowBase;
                sideButtonRowY = static_cast<double>(pageLabelInnerY);
                playlistRowY =
                    static_cast<int>((static_cast<double>(rowBase) +
                                      (self.height - static_cast<double>(pageLabelInnerY))));
            } else {
                sideButtonRowY = static_cast<double>(
                    static_cast<int>((static_cast<double>(pageLabelInnerY) +
                                      (self.height - static_cast<double>(pageLabelInnerY)))));
                settingRowY =
                    static_cast<int>((static_cast<double>(rowBase) +
                                      (self.height - static_cast<double>(pageLabelInnerY))));
                playlistRowY = rowBase;
            }
            menuButtonWidth = base / 3;
            int sixth = base / 6;
            col1 = static_cast<int>(
                (bounds.width * kPageLabelHalfWidthFactor - static_cast<double>(sixth)));
            col2 = static_cast<int>(
                ((bounds.width + kLayoutTallCol2BiasWhite) - static_cast<double>(menuButtonWidth)));
            playlistX = sixth + kLayoutTallPlaylistXBiasWhite;
            randomX = (sixth + col2) + kLayoutTallRandomXBias;
            settingColX = kLayoutTallSettingXWhite; // 12.0 slot reused as settingButton X.
            collectionOriginX = kLayoutTallWhiteCollectionOriginXExtra;
            collectionOriginY = 0.0;
            storeInfoInsetWidth = bounds.width + kLayoutTallWhiteStoreInfoInset; // width - 3.
            sideButtonSize = kLayoutSideButtonSizeTall;
        }
    }

    // Shared placement of every element from the metrics computed above.
    self.footerView.frame = CGRectMake(
        0, static_cast<double>(footerY), bounds.width, self.footerView.frame.size.height);
    self.settingButton.frame = CGRectMake(settingColX,
                                          static_cast<double>(settingRowY),
                                          static_cast<double>(menuButtonWidth),
                                          self.settingButton.height);
    self.rankButton.frame = CGRectMake(static_cast<double>(col1),
                                       static_cast<double>(settingRowY),
                                       static_cast<double>(menuButtonWidth),
                                       self.rankButton.height);
    self.storeButton.frame = CGRectMake(static_cast<double>(col2),
                                        static_cast<double>(settingRowY),
                                        static_cast<double>(menuButtonWidth),
                                        self.storeButton.height);
    self.playlistAddButton.frame = CGRectMake(settingColX,
                                              static_cast<double>(playlistRowY),
                                              static_cast<double>(menuButtonWidth),
                                              self.playlistAddButton.height);
    self.playlistDelButton.frame = CGRectMake(settingColX,
                                              static_cast<double>(playlistRowY),
                                              static_cast<double>(menuButtonWidth),
                                              self.playlistDelButton.height);
    self.playlistFinButton.frame = CGRectMake(static_cast<double>(col2),
                                              static_cast<double>(playlistRowY),
                                              static_cast<double>(menuButtonWidth),
                                              self.playlistFinButton.height);
    self.playListButton.frame = CGRectMake(static_cast<double>(playlistX),
                                           sideButtonRowY,
                                           static_cast<double>(sideButtonSize),
                                           static_cast<double>(sideButtonSize));
    self.randomButton.frame = CGRectMake(static_cast<double>(randomX),
                                         sideButtonRowY,
                                         static_cast<double>(sideButtonSize),
                                         static_cast<double>(sideButtonSize));
    self.pageLabel.frame =
        CGRectMake(bounds.width * kPageLabelHalfWidthFactor + kPageLabelOriginXInset,
                   static_cast<double>(pageLabelInnerY),
                   kPageLabelWidth,
                   static_cast<double>(sideButtonSize));
    self.collectionView.frame = CGRectMake(collectionOriginX,
                                           collectionOriginY,
                                           self.collectionView.frame.size.width,
                                           self.collectionView.frame.size.height);

    // Information badges sit beside their owning buttons.
    self.playlistInfoView.frame = CGRectMake(static_cast<double>((playlistX + sideButtonSize)),
                                             sideButtonRowY,
                                             self.playlistInfoView.frame.size.width,
                                             self.playlistInfoView.frame.size.height);
    self.randomInfoView.frame = CGRectMake(static_cast<double>(randomX) - storeInfoInsetWidth,
                                           sideButtonRowY,
                                           self.randomInfoView.frame.size.width,
                                           self.randomInfoView.frame.size.height);
    self.storeInfoView.frame =
        CGRectMake(static_cast<double>((col2 + menuButtonWidth)) + storeInfoInsetWidth * -0.5,
                   self.storeInfoView.frame.origin.y,
                   self.storeInfoView.frame.size.width,
                   self.storeInfoView.frame.size.height);

    if (!self.storeInfoView.isHidden) {
        [self.storeInfoView RemoveJumpEffect];
        [self.storeInfoView
            SetJumpEffectBaseX:static_cast<float>(self.storeInfoView.frame.origin.x)
                         BaseY:static_cast<float>((self.settingButton.height +
                                                   self.storeInfoView.frame.size.height * -0.5))];
    }

    self.playlistInfoView.hidden = [RBUserSettingData sharedInstance].infoPlaylist;
    self.randomInfoView.hidden = [RBUserSettingData sharedInstance].infoRandom;

    // The search bar and cancel button span the top strip.
    self.searchBar.frame = CGRectMake(0,
                                      self.searchBar.frame.origin.y,
                                      bounds.width - self.searchCancelButton.frame.size.width,
                                      self.searchBar.frame.size.height);
    self.searchCancelButton.frame =
        CGRectMake(bounds.width - self.searchCancelButton.frame.size.width,
                   self.searchCancelButton.frame.origin.y,
                   self.searchCancelButton.frame.size.width,
                   self.searchCancelButton.frame.size.height);

    // The pastel theme parks its search mascot beside the search bar.
    if ([RBUserSettingData sharedInstance].thema == kThemaPastel &&
        self.searchMascotImages.count != 0) {
        CGFloat searchBarX = self.searchBar.frame.origin.x;
        CGSize mascotSize = [self.searchMascotImages[0] size];
        if (searchBarX >= 0.0) {
            self.searchMascot.frame = CGRectMake(
                bounds.width - mascotSize.width, searchBarX, mascotSize.width, mascotSize.height);
        } else {
            self.searchMascot.frame =
                CGRectMake(bounds.width, self.searchPastelPosBaseY, mascotSize.width, searchBarX);
        }
    }

    if (!isFontVariant) {
        // Restore the correct page after a size change.
        if (self.prevIndex == 0) {
            CGFloat pageWidth = self.collectionView.frame.size.width;
            if (static_cast<long>(static_cast<int>(self.collectionView.contentOffset.x)) !=
                self.currentPageIndex * static_cast<long>(static_cast<int>(pageWidth))) {
                self.currentPageIndex = 0;
                [self.collectionView
                    scrollRectToVisible:CGRectMake(pageWidth *
                                                       static_cast<double>(self.currentPageIndex),
                                                   0,
                                                   self.collectionView.frame.size.width,
                                                   self.collectionView.frame.size.height)
                               animated:NO];
            }
        }
        if (self.backgroundScrollView != nil) {
            [self layoutPagingBackground];

            // Wrap the paging offset around the padded ends.
            NSUInteger imageCount = self.backgroundImageCount;
            NSUInteger pageOfBg =
                (imageCount != 0) ?
                    self.currentPageIndex - (self.currentPageIndex / imageCount) * imageCount :
                    self.currentPageIndex;
            CGFloat scrollWidth = self.backgroundScrollView.width;
            if (self.backgroundCurrentPage - pageOfBg == imageCount - 1) {
                [self.backgroundScrollView
                    setContentOffset:CGPointMake(
                                         scrollWidth * static_cast<double>((imageCount + 1)), 0)
                            animated:YES];
            } else if (self.backgroundCurrentPage - pageOfBg == 1 - imageCount) {
                [self.backgroundScrollView setContentOffset:CGPointZero animated:YES];
            } else {
                [self.backgroundScrollView
                    setContentOffset:CGPointMake(
                                         static_cast<double>(static_cast<long>((pageOfBg + 1))) *
                                             scrollWidth,
                                         0)
                            animated:YES];
            }
            self.backgroundCurrentPage = pageOfBg;
        }
    }
}

#pragma mark - Page index and label

- (void)setCurrentPageIndex:(NSInteger)currentPageIndex {
    if (_currentPageIndex == currentPageIndex) {
        return;
    }
    _currentPageIndex = currentPageIndex;
    self.pageLabel.text =
        [NSString stringWithFormat:@"%zd/%zd", self.currentPageIndex, self.maxPage];
}

- (void)setMaxPage:(NSInteger)maxPage {
    // The page count is clamped to at least one page.
    _maxPage = (maxPage != 0) ? maxPage : 1;
    self.pageLabel.text =
        [NSString stringWithFormat:@"%zd/%zd", self.currentPageIndex, self.maxPage];
}

- (void)setShowView:(UIView *)showView {
    // The previously shown view is torn out of its superview before the swap.
    if (_showView != nil) {
        [_showView removeFromSuperview];
    }
    _showView = showView;
}

#pragma mark - Lifecycle

- (instancetype)initWithFrame:(CGRect)frame viewController:(RBViewController *)viewController {
    self = [super initWithFrame:frame];
    if (self != nil) {
        self.viewController = viewController;
        self.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        self.newsGetTime = nil;
        self.searchPastelPosBaseY = (GetFontVariantFlag() == kFontVariantDefault) ?
                                        kSearchPastelPosBaseYWide :
                                        kSearchPastelPosBaseYTall;
        self.playListEditMode = kMenuModePlaylistFinished;
        [self CreateView];
    }
    return self;
}

- (void)dealloc {
    if (self.newsDownloader != nil) {
        [self.newsDownloader cancel];
    }
}

- (void)CreateView {
    NSInteger thema = [RBUserSettingData sharedInstance].thema;
    BOOL isFontVariant = GetFontVariantFlag() != kFontVariantDefault;
    // Set when an animated or scrolling background (not a plain static texture) is installed. It
    // gates the mascot and the campaign page-label colour.
    BOOL bgUsesEffectView = NO;

    if (thema == kThemaPastel) {
        self.backgroundColor = UIColor.whiteColor;
        if ([[RBCampaignData sharedInstance] isCampaignHinabita201703]) {
            bgUsesEffectView = [self buildCampaignBackground:isFontVariant];
        } else if (isFontVariant) {
            self.bgEffectView = [[RBMenuBGEffectView alloc] initWithFrame:self.bounds];
            [self.bgEffectView setupView];
            [self addSubview:self.bgEffectView];
            bgUsesEffectView = YES;
        } else {
            UIImage *bgImage = [UIImage imageWithName:kTextureBackgroundName];
            self.backgroundView = [[UIImageView alloc] initWithImage:bgImage];
            self.backgroundView.frame = self.bounds;
            self.backgroundView.autoresizingMask = kBackgroundAutoresizingMask;
            self.backgroundView.contentMode = UIViewContentModeScaleAspectFill;
            [self addSubview:self.backgroundView];
            bgUsesEffectView = YES;
        }
    } else {
        if (thema == kThemaClassic) {
            self.backgroundColor = UIColor.blackColor;
        } else if (thema == kThemaWhite) {
            self.backgroundColor = UIColor.whiteColor;
        }
        UIImage *bgImage = [UIImage imageWithName:kTextureBackgroundName];
        self.backgroundView = [[UIImageView alloc] initWithImage:bgImage];
        self.backgroundView.frame = self.bounds;
        self.backgroundView.autoresizingMask = kBackgroundAutoresizingMask;
        self.backgroundView.contentMode = UIViewContentModeCenter;
        [self addSubview:self.backgroundView];
    }

    if (isFontVariant) {
        [self buildHeaderAndFooter:thema];
    } else if (thema == kThemaClassic) {
        // Wide classic theme: a horizontally resizable footer pinned to the bottom.
        UIImage *footer = [UIImage imageWithName:kFooterImageName];
        CGFloat capX = footer.size.width * kFooterCapFraction;
        footer = [footer resizableImageWithCapInsets:UIEdgeInsetsMake(0, capX, 0, capX)];
        self.footerView = [[UIImageView alloc] initWithImage:footer];
        self.footerView.frame = CGRectMake(0,
                                           self.frame.size.height - footer.size.height,
                                           self.frame.size.width,
                                           footer.size.height);
        self.footerView.autoresizingMask =
            UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleTopMargin;
        [self addSubview:self.footerView];
    } else if (thema == kThemaWhite) {
        // Wide white theme: a short fixed footer strip at the origin.
        self.footerView =
            [[UIImageView alloc] initWithImage:[UIImage imageWithName:kFooterImageName]];
        self.footerView.frame = CGRectMake(0, 0, 0, kFooterLightWideHeight);
        self.footerView.autoresizingMask =
            UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleBottomMargin;
        [self addSubview:self.footerView];
    }

    [self buildMenuBarWithThema:thema
                     fontVariant:isFontVariant
        backgroundUsesEffectView:bgUsesEffectView];
}

- (void)buildHeaderAndFooter:(NSInteger)thema {
    /** @ghidraAddress 0xa5040 */
    self.headerView = [[UIImageView alloc] initWithImage:[UIImage imageWithName:kHeaderImageName]];
    self.headerView.frame =
        CGRectMake(0, 0, self.frame.size.width, self.headerView.frame.size.height);
    [self addSubview:self.headerView];

    if (thema > kThemaWhite) {
        return; // The campaign theme has no footer in the tall layout.
    }

    self.footerView = [[UIImageView alloc] initWithImage:[UIImage imageWithName:kFooterImageName]];
    if (thema == kThemaClassic) {
        self.footerView.frame =
            CGRectMake(0,
                       self.bounds.size.height - self.footerView.bounds.size.height,
                       self.frame.size.width,
                       self.footerView.frame.size.height);
    } else if (thema == kThemaWhite) {
        self.footerView.frame = CGRectMake(0, 0, self.frame.size.width, kFooterLightTallHeight);
    }
    [self addSubview:self.footerView];
}

- (BOOL)buildCampaignBackground:(BOOL)isFontVariant {
    /** @ghidraAddress 0xa4f58 */
    // Load up to ten numbered campaign images; when present they are shuffled into a horizontally
    // paging scroll view, otherwise the animated effect view is installed instead.
    NSMutableArray *images = [NSMutableArray array];
    for (int i = 1; i <= kCampaignBackgroundMaxImages; ++i) {
        NSString *name = [NSString stringWithFormat:@"%@/%@%d",
                                                    [RBCampaignData sharedInstance].campaignName,
                                                    [RBCampaignData sharedInstance].campaignName,
                                                    i];
        UIImage *image = [UIImage imageWithName:name];
        if (image == nil) {
            break;
        }
        [images addObject:image];
    }

    if (images.count == 0) {
        self.bgEffectView = [[RBMenuBGEffectView alloc] initWithFrame:self.bounds];
        [self.bgEffectView setupView];
        [self addSubview:self.bgEffectView];
        return YES;
    }

    NSMutableArray *shuffled = [NSMutableArray arrayWithCapacity:images.count];
    for (UIImage *image in images) {
        NSUInteger index = arc4random() % (shuffled.count + 1);
        [shuffled insertObject:image atIndex:index];
    }
    self.backgroundImageCount = shuffled.count;

    self.backgroundScrollView = [[UIScrollView alloc] initWithFrame:self.bounds];
    self.backgroundScrollView.contentSize =
        CGSizeMake(self.bounds.size.width * (shuffled.count + 2), self.bounds.size.height);
    self.backgroundScrollView.delegate = self;
    self.backgroundScrollView.pagingEnabled = YES;
    self.backgroundScrollView.showsHorizontalScrollIndicator = NO;
    self.backgroundScrollView.showsVerticalScrollIndicator = NO;
    self.backgroundScrollView.autoresizingMask =
        isFontVariant ? UIViewAutoresizingFlexibleWidth : kBackgroundAutoresizingMask;
    self.backgroundScrollView.contentOffset = CGPointMake(self.bounds.size.width, 0);
    self.backgroundScrollView.userInteractionEnabled = NO;
    [self addSubview:self.backgroundScrollView];
    self.backgroundCurrentPage = 1;

    CGFloat pageWidth = self.backgroundScrollView.frame.size.width;
    CGFloat firstAspect =
        static_cast<CGFloat>(static_cast<float>((pageWidth / [shuffled[0] size].width)));
    for (NSUInteger page = 0; page < shuffled.count + 2; ++page) {
        UIImage *image = shuffled[page % shuffled.count];
        UIImageView *imageView = [[UIImageView alloc] initWithImage:image];
        if (isFontVariant) {
            imageView.frame =
                CGRectMake(static_cast<int>(page) * pageWidth, 0, image.size.width, 0);
            imageView.contentMode = UIViewContentModeRedraw;
        } else {
            CGFloat scrollWidth = self.backgroundScrollView.width;
            CGFloat y =
                (scrollWidth > self.height) ? self.height * kBackgroundVerticalOffsetFactor : 0.0;
            imageView.frame = CGRectMake(static_cast<int>(page) * scrollWidth,
                                         y,
                                         firstAspect * image.size.width,
                                         firstAspect * image.size.height);
            imageView.autoresizingMask = kBackgroundAutoresizingMask;
        }
        [self.backgroundScrollView addSubview:imageView];
    }
    return NO;
}

- (void)buildMenuBarWithThema:(NSInteger)thema
                  fontVariant:static_cast<BOOL>(isFontVariant)
     backgroundUsesEffectView:static_cast<BOOL>(bgUsesEffectView) {
    /** @ghidraAddress 0xa5380 */
    // The six side-menu buttons; the play-list add and delete buttons start disabled.
    for (NSInteger type = 0; type < 6; ++type) {
        RBMenuButton *menuButton = [[RBMenuButton alloc] initWithType:(RBMenuButtonType)type];
        CGRect buttonFrame = menuButton.frame;
        switch (type) {
        case RBMenuButtonTypeSetting:
            self.settingButton = menuButton;
            [self.settingButton.button addTarget:self
                                          action:@selector(SelectSettingButton)
                                forControlEvents:UIControlEventTouchUpInside];
            break;
        case RBMenuButtonTypeRank:
            self.rankButton = menuButton;
            [self.rankButton.button addTarget:self
                                       action:@selector(SelectRankingButton)
                             forControlEvents:UIControlEventTouchUpInside];
            break;
        case RBMenuButtonTypeStore:
            self.storeButton = menuButton;
            [self.storeButton.button addTarget:self
                                        action:@selector(SelectStoreButton)
                              forControlEvents:UIControlEventTouchUpInside];
            break;
        case RBMenuButtonTypePlaylistAdd:
            self.playlistAddButton = menuButton;
            [self.playlistAddButton.button addTarget:self
                                              action:@selector(SelectPlaylistAddButton)
                                    forControlEvents:UIControlEventTouchUpInside];
            self.playlistAddButton.enabled = NO;
            break;
        case RBMenuButtonTypePlaylistDel:
            self.playlistDelButton = menuButton;
            [self.playlistDelButton.button addTarget:self
                                              action:@selector(SelectPlaylistDelButton)
                                    forControlEvents:UIControlEventTouchUpInside];
            self.playlistDelButton.enabled = NO;
            break;
        case RBMenuButtonTypePlaylistFin:
            self.playlistFinButton = menuButton;
            [self.playlistFinButton.button addTarget:self
                                              action:@selector(SelectPlaylistFinButton)
                                    forControlEvents:UIControlEventTouchUpInside];
            break;
        }
        menuButton.frame = buttonFrame;
        [self addSubview:menuButton];
    }

    self.playListButton = [UIButton buttonWithType:UIButtonTypeCustom];
    [self.playListButton setImage:[UIImage imageWithName:kPlaylistImageName]
                         forState:UIControlStateNormal];
    [self.playListButton setImage:[UIImage imageWithName:kPlaylistSelImageName]
                         forState:UIControlStateSelected];
    // The binary wires no touch target on this button here; the playlist-edit toggle is driven
    // through the collection-view long press instead.
    [self addSubview:self.playListButton];

    self.playlistInfoView =
        [[UIImageView alloc] initWithImage:[UIImage imageWithName:kInfoPlaylistName]];
    [self addSubview:self.playlistInfoView];
    [UIView setFlashEffectView:self.playlistInfoView
                      Duration:kInfoFlashDuration
                         Start:kInfoFlashStart
                           End:kInfoFlashEnd
                        Rotate:NO];

    self.randomButton = [UIButton buttonWithType:UIButtonTypeCustom];
    [self.randomButton setImage:[UIImage imageWithName:kRandomImageName]
                       forState:UIControlStateNormal];
    [self.randomButton setImage:[UIImage imageWithName:kRandomSelImageName]
                       forState:UIControlStateSelected];
    self.randomButton.tag = kRandomButtonTag;
    [self.randomButton addTarget:self
                          action:@selector(selectRandom:)
                forControlEvents:UIControlEventTouchUpInside];
    [self addSubview:self.randomButton];

    self.randomInfoView =
        [[UIImageView alloc] initWithImage:[UIImage imageWithName:kInfoRandomName]];
    [self addSubview:self.randomInfoView];
    [UIView setFlashEffectView:self.randomInfoView
                      Duration:kInfoFlashDuration
                         Start:kInfoFlashStart
                           End:kInfoFlashEnd
                        Rotate:NO];

    self.pageLabel = [[UILabel alloc]
        initWithFrame:CGRectMake(self.frame.size.width * kPageLabelHalfWidthFactor +
                                     kPageLabelOriginXInset,
                                 0,
                                 kPageLabelWidth,
                                 kPageLabelHeight)];
    self.pageLabel.backgroundColor = UIColor.clearColor;
    self.pageLabel.font =
        [UIFont systemFontOfSize:(isFontVariant ? kPageLabelFontTall : kPageLabelFontWide)];
    if (thema == kThemaClassic) {
        self.pageLabel.textColor = UIColor.whiteColor;
    } else if (thema == kThemaWhite) {
        self.pageLabel.textColor = UIColor.blackColor;
    } else if (bgUsesEffectView) {
        self.pageLabel.textColor = UIColor.blackColor;
    }
    self.pageLabel.textAlignment = NSTextAlignmentCenter;
    self.pageLabel.userInteractionEnabled = YES;
    self.pageLabel.exclusiveTouch = YES;
    [self addSubview:self.pageLabel];

    self.layout = [RBMusicGridLayout new];
    self.collectionView = [[RBCollectionView alloc] initWithFrame:self.bounds
                                             collectionViewLayout:self.layout];
    self.collectionView.customDelegate = self;
    [self.collectionView registerClass:RBMusicCell.class
            forCellWithReuseIdentifier:NSStringFromClass(RBMusicCell.class)];
    self.collectionView.backgroundColor = UIColor.clearColor;
    self.collectionView.showsVerticalScrollIndicator = NO;
    self.collectionView.showsHorizontalScrollIndicator = NO;
    self.collectionView.pagingEnabled = YES;
    self.collectionView.delegate = self;
    self.collectionView.dataSource = self;
    [self addSubview:self.collectionView];

    // The mascot exists only when a background effect or scroll view is in use.
    if (bgUsesEffectView) {
        if ([[RBCampaignData sharedInstance] isCampaignHinabita201703]) {
            self.mascot = [[RBMenuMascot alloc]
                initWithFrame:CGRectMake(0, 0, kMascotCampaignWidth, kMascotCampaignHeight)];
        } else {
            self.mascot =
                [[RBMenuMascot alloc] initWithFrame:CGRectMake(0, 0, kMascotWidth, kMascotHeight)];
        }
        self.mascot.delegate = self;
        [self.mascot setup:NO];
        [self.collectionView addSubview:self.mascot];
    }

    // A grid long press must yield to any existing long-press recognisers.
    UILongPressGestureRecognizer *gridLongPress =
        [[UILongPressGestureRecognizer alloc] initWithTarget:self
                                                      action:@selector(handleLongPressGesture:)];
    gridLongPress.delegate = self;
    for (UIGestureRecognizer *recognizer in self.collectionView.gestureRecognizers) {
        if ([recognizer isKindOfClass:UILongPressGestureRecognizer.class]) {
            [recognizer requireGestureRecognizerToFail:gridLongPress];
        }
    }
    [self.collectionView addGestureRecognizer:gridLongPress];

    self.storeInfoView = [[UIImageView alloc] initWithImage:[UIImage imageWithName:kInfoNewName]];
    self.storeInfoView.hidden = YES;
    [self addSubview:self.storeInfoView];

    if (thema == kThemaClassic) {
        [self bringSubviewToFront:self.footerView];
    }

    // The news ticker starts parked below the bottom edge, then fills the bottom strip.
    self.newsView = [[RBMenuNewsTickerView alloc]
        initWithFrame:CGRectMake(0, self.bounds.size.height + kNewsTickerHeightInset, 0, 0)];
    self.newsView.autoresizingMask =
        UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleTopMargin;
    self.newsView.frame = CGRectMake(0,
                                     self.bounds.size.height - self.newsView.bounds.size.height,
                                     self.bounds.size.width,
                                     self.newsView.bounds.size.height);
    [self addSubview:self.newsView];
    UITapGestureRecognizer *newsTap =
        [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(TouchNews:)];
    [self.newsView addGestureRecognizer:newsTap];

    self.coverView = [[UIView alloc] initWithFrame:self.frame];
    self.coverView.autoresizingMask = kBackgroundAutoresizingMask;
    self.coverView.backgroundColor = UIColor.blackColor;
    self.coverView.hidden = YES;
    [self addSubview:self.coverView];

    // Swipe up shows the search bar, swipe down hides it.
    UISwipeGestureRecognizer *showSearch =
        [[UISwipeGestureRecognizer alloc] initWithTarget:self action:@selector(showSearchBar)];
    showSearch.numberOfTouchesRequired = 1;
    showSearch.delegate = self;
    showSearch.direction = UISwipeGestureRecognizerDirectionUp;
    [self addGestureRecognizer:showSearch];

    UISwipeGestureRecognizer *hideSearch =
        [[UISwipeGestureRecognizer alloc] initWithTarget:self action:@selector(hideSearchBar)];
    hideSearch.numberOfTouchesRequired = 1;
    hideSearch.delegate = self;
    hideSearch.direction = UISwipeGestureRecognizerDirectionDown;
    [self addGestureRecognizer:hideSearch];

    CGFloat cancelWidth = (GetFontVariantFlag() != kFontVariantDefault) ? kSearchCancelWidthTall :
                                                                          kSearchCancelWidthWide;
    self.searchCancelButton = [UIButton buttonWithType:UIButtonTypeCustom];
    self.searchCancelButton.frame = CGRectMake(
        self.frame.size.width - cancelWidth, kSearchBarOriginY, cancelWidth, kSearchBarHeight);
    // The wide layout uses the large cancel artwork, the tall/variant layout uses the small one.
    NSString *cancelName = (GetFontVariantFlag() == kFontVariantDefault) ?
                               kSearchCancelImageNameWide :
                               kSearchCancelImageNameTall;
    [self.searchCancelButton setBackgroundImage:[UIImage imageWithName:cancelName]
                                       forState:UIControlStateNormal];
    self.searchCancelButton.exclusiveTouch = YES;
    [self.searchCancelButton addTarget:self
                                action:@selector(tapSearchMusicCancel)
                      forControlEvents:UIControlEventTouchUpInside];

    self.searchBar =
        [[UISearchBar alloc] initWithFrame:CGRectMake(0,
                                                      kSearchBarOriginY,
                                                      self.frame.size.width - cancelWidth,
                                                      kSearchBarHeight)];
    self.searchBar.autocapitalizationType = UITextAutocapitalizationTypeNone;
    self.searchBar.text = @"";
    if ([AppDelegate appDelegate].searchString != nil) {
        self.searchBar.text = [AppDelegate appDelegate].searchString;
    }
    self.searchBar.delegate = self;
    [self.searchBar setBackgroundImage:[UIImage imageWithName:kSearchBackgroundName]];
    self.backUpString = @"";
    [self addSubview:self.searchBar];
    [self addSubview:self.searchCancelButton];

    if (self.searchArray == nil) {
        self.searchArray = [[NSMutableArray alloc] init];
    }

    // The pastel theme parks a mascot off the right edge (alpha 0).
    if ([RBUserSettingData sharedInstance].thema == kThemaPastel) {
        NSString *mascotPrefix = kSearchMascotDefaultPrefix;
        if ([[RBCampaignData sharedInstance] isCampaignHinabita201703]) {
            mascotPrefix = [NSString stringWithFormat:@"%@/%@",
                                                      [RBCampaignData sharedInstance].campaignName,
                                                      [RBCampaignData sharedInstance].campaignName];
        }
        if (self.searchMascotImages != nil) {
            [self.searchMascotImages removeAllObjects];
        }
        self.searchMascotImages = [[NSMutableArray alloc] init];
        for (int i = 1; i <= kSearchMascotMaxImages; ++i) {
            UIImage *image =
                [UIImage imageWithName:[NSString stringWithFormat:@"%@%02d", mascotPrefix, i]];
            if (image == nil) {
                break;
            }
            [self.searchMascotImages addObject:image];
        }
        if (self.searchMascotImages.count != 0) {
            self.searchMascot = [[UIImageView alloc] init];
            self.searchMascot.frame = CGRectMake(self.frame.size.width,
                                                 self.searchPastelPosBaseY,
                                                 [self.searchMascotImages[0] size].width,
                                                 [self.searchMascotImages[0] size].height);
            self.searchMascot.alpha = kAlphaHidden;
            if ([[RBCampaignData sharedInstance] isCampaignHinabita201703]) {
                self.searchMascot.userInteractionEnabled = YES;
                UITapGestureRecognizer *mascotTap =
                    [[UITapGestureRecognizer alloc] initWithTarget:self
                                                            action:@selector(touchMascot)];
                [self.searchMascot addGestureRecognizer:mascotTap];
            }
            [self addSubview:self.searchMascot];
        }
    }

    self.pushNotificationView =
        [[RBPushNotificationView alloc] initWithFrame:CGRectMake(0, 0, self.width, self.height)];
    [self.pushNotificationView setupViewWithDelegate:self];
    [self addSubview:self.pushNotificationView];

    UILongPressGestureRecognizer *pageSliderPress =
        [[UILongPressGestureRecognizer alloc] initWithTarget:self
                                                      action:@selector(showPageSlider:)];
    pageSliderPress.delegate = self;
    [self.pageLabel addGestureRecognizer:pageSliderPress];
}

#pragma mark - Presentation

- (void)showAnimation {
    self.showed = YES;
    [self preStartTutorial];
    [[RBBGMManager getInstance] LoadMusicSelect];
    [[AudioManager sharedManager] releaseVoice];
    LoadThemedVoiceData(GetSoundEffectManager(), 1);
    self.userInteractionEnabled = NO;
    self.hidden = NO;
    [self reloadMusicData];
    self.coverView.hidden = NO;
    self.coverView.alpha = kAlphaOpaque;
    [self.coverView SetAlphaAnimationDuration:kCoverFadeDuration End:0];
    [self startBGEffect];

    dispatch_after(
        dispatch_time(DISPATCH_TIME_NOW, kShowAnimationDelayNanos), dispatch_get_main_queue(), ^{
          /** @ghidraAddress 0xaa4dc */
          self.userInteractionEnabled = YES;
        });
}

- (void)ReplayMusic {
    // Retry on the next run-loop turn if the BGM has not finished loading yet.
    if (![[RBBGMManager getInstance] PlayMusic:1.5]) {
        [self performSelector:@selector(ReplayMusic)
                   withObject:nil
                   afterDelay:g_dMascotMoveAnimDuration];
    }
}

- (void)hideAnimation:(void (^)(void))hideAnimation {
    self.showed = NO;
    self.coverView.hidden = NO;
    [self stopNews];
    [self stopBGEffect];
    GetGameSystem()->SetMenuTutorialActive(0);

    if (self.tutorialView != nil && [RBTutorialManager isTutorialMusicselect]) {
        [self.tutorialView startTutorialWithType:kTutorialTypeMenuHide withAnimation:YES];
        [self.tutorialView hideAnimation];
        GetGameSystem()->SetMenuTutorialActive(1);
    }

    [self.coverView SetAlphaAnimationDuration:kCoverFadeDuration End:1];

    __weak RBMenuView *weakSelf = self;
    dispatch_after(
        dispatch_time(DISPATCH_TIME_NOW, kShowAnimationDelayNanos), dispatch_get_main_queue(), ^{
          /** @ghidraAddress 0xaae24 */
          // Run the caller's completion block, then tear the menu down: stop and clear the
          // show-animation timer, hide the menu and its cover, and drop the selected-music view.
          hideAnimation(); // The binary invokes the captured block unconditionally, with no nil guard.
          [weakSelf.showAnimationTimer invalidate];
          weakSelf.showAnimationTimer = nil;
          weakSelf.hidden = YES;
          weakSelf.coverView.hidden = YES;
          [weakSelf releaseSelectMusic];
        });
}

- (BOOL)isShow {
    return self.showed;
}

#pragma mark - Music selection

- (void)selectMusic:(RBMusicData *)selectMusic animated:(BOOL)animated {
    [self setSearchBarNonActive];
    [self hideSettingView];
    if (self.selectedView != nil) {
        [self.selectedView removeFromSuperview];
    }

    self.selectedView = [[RBMusicView alloc] initWithFrame:self.bounds MusicData:selectMusic];
    self.selectedView.musicMenuView = self;
    (void)[RBUserSettingData sharedInstance].gameType; // Yes, the binary discards this result.

    [self addSubview:self.newsView];
    [self addSubview:self.selectedView];
    [self addSubview:self.coverView];

    if ([[RBUserSettingData sharedInstance] getTutorialStatus:kTutorialStatusMusicSelect] == 0) {
        [self.tutorialView startTutorialWithType:kTutorialTypeMusicSelect
                                    withRootView:self.selectedView];
    }
    [self.selectedView showAnimation:animated];
    PlayThemedSoundEffect(GetSoundEffectManager(), 0);
}

- (int)getRandamInt:(int)getRandamInt max:(int)max {
    // Seed the C random generator exactly once, then map rand() into [getRandamInt, max].
    if (!g_bRandamIntSeeded) {
        srand(static_cast<unsigned int>(time(NULL)));
        g_bRandamIntSeeded = YES;
    }
    int r = rand();
    return static_cast<int>(((static_cast<double>((max - getRandamInt)) + 1.0) *
                             static_cast<double>(r) * (1.0 / 2147483648.0))) +
           getRandamInt;
}

- (void)selectRandom:(id)selectRandom {
    if ([self.viewController.playlistPopoverController isPopoverVisible]) {
        return;
    }
    if (self.musicList.count == 0) {
        return;
    }

    int index = [self getRandamInt:0 max:static_cast<int>(self.musicList.count) - 1];
    RBMusicData *music = self.musicList[index];
    self.selectedView.isRandom = YES;
    // A tag of 1 (from the random button) means animate the selection.
    [self selectMusic:music animated:([selectRandom tag] == 1)];
    self.selectedView.isRandom = YES;
    self.selectedView.randomButton.frame = self.randomButton.frame;
    if (GetFontVariantFlag() != kFontVariantDefault) {
        self.selectedView.randomButton.hidden = NO;
    }

    [RBUserSettingData sharedInstance].infoRandom = YES;
    [[RBUserSettingData sharedInstance] save];
}

- (void)releaseSelectMusic {
    if (self.selectedView != nil) {
        [self.selectedView removeFromSuperview];
        self.selectedView = nil;
    }
    [self showInfomation];
}

#pragma mark - Music list

- (void)reloadMusicData {
    [self.playlistEditSet removeAllObjects];
    [self createMusicList];
    [self.collectionView reloadData];
    self.maxPage = static_cast<long>(
        (self.collectionView.contentSize.width / self.collectionView.frame.size.width));
    if (self.musicList == nil || self.musicList.count == 0) {
        self.maxPage = 1;
    }

    if ([RBUserSettingData sharedInstance].playlistID == kPlaylistIDNone) {
        [self.playListButton setImage:[UIImage imageWithName:@"01_music_select/sel_playlist"]
                             forState:UIControlStateNormal];
    } else {
        [self.playListButton setImage:[UIImage imageWithName:@"01_music_select/sel_playlist_sel"]
                             forState:UIControlStateNormal];
    }
}

- (void)createMusicList {
    NSArray *allMusic = [[RBMusicManager getInstance] getMusicDataArray];
    NSMutableArray *musics = [NSMutableArray arrayWithArray:allMusic];
    [self createSearchDictionary];

    // Apply the search-text filter first.
    NSMutableArray *searchResult;
    if (self.searchBar != nil && self.searchArray.count != 0) {
        searchResult = [[NSMutableArray alloc] init];
        for (RBMusicData *music in musics) {
            if ([self matchTitle:music]) {
                [searchResult addObject:music];
            }
        }
    } else {
        searchResult = [musics mutableCopy];
    }

    SEL sortSelector = ([RBUserSettingData sharedInstance].menuItemSort == 1) ?
                           @selector(compareMusicNameCustom:) :
                           @selector(compareMusicName:);

    NSInteger playlistID = [RBUserSettingData sharedInstance].playlistID;
    if (playlistID == kPlaylistIDNone) {
        [searchResult sortUsingSelector:sortSelector];
        self.musicList = searchResult;
        return;
    }

    if (playlistID == kPlaylistIDHotBonus) {
        // Hot-bonus: keep only musics whose score record is flagged as hot-bonus.
        NSMutableArray *filtered = [NSMutableArray arrayWithArray:searchResult];
        NSMutableArray *ids = [NSMutableArray array];
        for (RBMusicData *music in searchResult) {
            [ids addObject:@(music.MusicID)];
        }
        if (ids.count != 0) {
            NSManagedObjectContext *context =
                [RBCoreDataManager sharedInstance].managedObjectContext;
            NSArray *scores = [ScoreData getScoreDatas:ids inManagedObjectContext:context];
            for (RBMusicData *music in searchResult) {
                BOOL keep = NO;
                for (ScoreData *score in scores) {
                    if (music.MusicID == score.MusicID.intValue) {
                        if (score.hotBonusList || score.getGameType == score.getOption) {
                            keep = YES;
                        }
                        break;
                    }
                }
                if (!keep) {
                    [filtered removeObject:music];
                }
            }
        }
        [filtered sortUsingSelector:sortSelector];
        self.musicList = filtered;
        return;
    }

    if (playlistID == kPlaylistIDLevel) {
        // Difficulty-level playlist: keep musics that have any chart at the selected level.
        NSMutableArray *filtered = [NSMutableArray array];
        NSInteger level = [RBUserSettingData sharedInstance].playlistLevel;
        for (RBMusicData *music in searchResult) {
            if (music.difficultyBasic == level || music.difficultyMedium == level ||
                music.difficultyHard == level ||
                (music.spData != nil && music.difficultySpecial == level)) {
                [filtered addObject:music];
            }
        }
        [filtered sortUsingSelector:sortSelector];
        self.musicList = filtered;
        return;
    }

    if (playlistID == kPlaylistIDCustom) {
        // Named custom playlist: keep musics whose ID is in the playlist.
        NSInteger level = [RBUserSettingData sharedInstance].playlistLevel;
        NSDictionary *playlist = [[RBPlaylistManager sharedInstance] playlistAtIndex:level];
        NSArray *listIDs = playlist[@"LIST"];
        NSMutableArray *filtered = [NSMutableArray array];
        for (RBMusicData *music in searchResult) {
            for (NSNumber *entry in listIDs) {
                if (entry.intValue == music.MusicID) {
                    [filtered addObject:music];
                    break;
                }
            }
        }
        [filtered sortUsingSelector:sortSelector];
        self.musicList = filtered;
        return;
    }

    if (playlistID == kPlaylistIDFavorite) {
        // Favourites: keep musics flagged favourite.
        NSMutableArray *filtered = [NSMutableArray array];
        for (RBMusicData *music in searchResult) {
            if (music.favorite != nil) {
                [filtered addObject:music];
            }
        }
        [filtered sortUsingSelector:sortSelector];
        self.musicList = filtered;
        return;
    }

    self.musicList = searchResult;
}

#pragma mark - Store view controller

- (void)RemoveStoreViewController {
    self.storeViewController = nil;
    if ([[RBBGMManager getInstance] isPushMusic]) {
        [[RBBGMManager getInstance] StopMusic:0.0];
        [[RBBGMManager getInstance] popMusic];
    }
    // Retry resuming the menu BGM up to 101 times until it succeeds.
    int attempt = 101;
    do {
        if ([[RBBGMManager getInstance] PlayMusic:1.5]) {
            break;
        }
        --attempt;
    } while (attempt > 0);
    [self startNews];
    [self startBGEffect];
}

#pragma mark - Setting view

- (void)SelectSettingButton {
    [self toggleSettingView];
}

- (void)hideSettingView {
    if (self.settingView != nil) {
        [self.settingView hideAnimation];
    }
}

- (void)toggleSettingView {
    [self setSearchBarNonActive];
    if (self.settingView.superview == nil) {
        CGRect buttonFrame;
        switch ([RBUserSettingData sharedInstance].thema) {
        case kThemaWhite:
            if (GetFontVariantFlag() != kFontVariantDefault) {
                // Centre a fixed-size anchor rectangle on the button's centre.
                CGPoint centre = self.settingButton.center;
                buttonFrame = CGRectMake(centre.x + kSettingAnchorOffsetX,
                                         self.settingButton.center.y + kSettingAnchorOffsetY,
                                         kSettingAnchorWidth,
                                         kSettingAnchorHeight);
                break;
            }
            buttonFrame = self.settingButton.frame;
            break;
        case kThemaClassic:
        case kThemaPastel:
        default:
            buttonFrame = self.settingButton.frame;
            break;
        }
        RBSettingView *view = [[RBSettingView alloc] initWithFrame:self.bounds
                                                       ButtonFrame:buttonFrame];
        self.settingView = view;
        self.settingView.parentView =
            reinterpret_cast<RBMusicView *>(self); // The binary treats self as RBMusicView here.
        [self addSubview:self.settingView];
        [self addSubview:self.settingButton];
        [self addSubview:self.coverView];
        if ([[RBUserSettingData sharedInstance] getTutorialStatus:kTutorialStatusSetting] == 0) {
            [[RBUserSettingData sharedInstance] updateTutorialStatus:kTutorialStatusSetting
                                                               value:1];
        }
        [self.settingButton removeFlashEffect];
        [self.settingView OpenView];
    } else {
        // Already shown: ignore the toggle while a tutorial overlay is up, else close it.
        if (self.tutorialView != nil) {
            return;
        }
        [self.settingView CloseView];
    }
}

#pragma mark - Setting sub-screens

- (void)showHowToView {
    RBHowToView *view = [[RBHowToView alloc] initWithFrame:self.bounds];
    view.settingView = self.settingView;
    view.musicMenuView = self;
    view.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [self addSubview:view];
    [view showAnimation];
    self.showView = view;
}

- (void)showCustomizeView {
    RBCustomView *view = [[RBCustomView alloc] initWithFrame:self.bounds];
    view.musicMenuView = self;
    view.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [self addSubview:view];
    [view showAnimation];
    if ([[RBUserSettingData sharedInstance] getTutorialStatus:kTutorialStatusSetting] == 0) {
        [self.tutorialView startTutorialWithType:kTutorialTypeCustomize withRootView:view];
        [[RBUserSettingData sharedInstance] updateTutorialStatus:kTutorialStatusSetting value:1];
    }
    self.showView = view;
}

- (void)showThema {
    RBThemaView *view = [[RBThemaView alloc] initWithFrame:self.bounds];
    view.musicMenuView = self;
    view.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [self addSubview:view];
    [view showAnimation];
    self.showView = view;
}

- (void)showSearchView {
    if (GetFontVariantFlag() == kFontVariantDefault) {
        // Phone build: push a full map view controller onto the navigation stack.
        self.mapViewController = [[RBSearchMapViewController alloc] init];
        [[[AppDelegate appDelegate] navigationController] pushViewController:self.mapViewController
                                                                    animated:YES];
    } else {
        // Pad build: overlay the search view in place.
        RBSearchView *view = [[RBSearchView alloc] initWithFrame:self.bounds];
        view.musicMenuView = self;
        view.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        [self addSubview:view];
        [view showAnimation];
        self.showView = view;
    }
    [[AppDelegate appDelegate] setIsShowedMap:YES];
}

- (void)showCreditView {
    RBCreditsView *view = [[RBCreditsView alloc] initWithFrame:self.bounds];
    view.musicMenuView = self;
    view.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [self addSubview:view];
    [view showAnimation];
    self.showView = view;
}

- (void)showNotificationPageView {
    if (GetFontVariantFlag() == kFontVariantDefault) {
        // Phone build: push a full web page view controller.
        self.webViewController = [[RBNotificationPagePhoneViewController alloc] init];
        [[[AppDelegate appDelegate] navigationController] pushViewController:self.webViewController
                                                                    animated:YES];
    } else {
        // Pad build: overlay the notification page in place.
        RBNotificationPageView *view = [[RBNotificationPageView alloc] initWithFrame:self.bounds];
        view.musicMenuView = self;
        view.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        [self addSubview:view];
        [view showAnimation];
        self.showView = view;
    }
}

- (void)showApplilinkView {
    RBApplilinkView *view = [[RBApplilinkView alloc] initWithFrame:self.bounds];
    view.musicMenuView = self;
    view.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [self addSubview:view];
    [view showAnimation];
    self.showView = view;
}

- (void)showTermView {
    if (GetFontVariantFlag() == kFontVariantDefault) {
        // Phone build: push a full terms-of-use view controller.
        self.termViewController = [[RBTermPhoneViewController alloc] init];
        [[[AppDelegate appDelegate] navigationController] pushViewController:self.termViewController
                                                                    animated:YES];
    } else {
        // Pad build: overlay the terms view in place.
        RBTermView *view = [[RBTermView alloc] initWithFrame:self.bounds];
        view.musicMenuView = self;
        view.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        [self addSubview:view];
        [view showAnimation];
        self.showView = view;
    }
}

- (void)closeCustomize {
    if ([self.showView respondsToSelector:@selector(hideAnimation)]) {
        [self.showView performSelector:@selector(hideAnimation)];
    }
}

#pragma mark - Background effect

- (void)startBGEffect {
    // The animated background and mascot only exist in the pastel theme.
    if ([RBUserSettingData sharedInstance].thema == kThemaPastel) {
        if (self.bgEffectView != nil) {
            [self.bgEffectView startAnimation];
        }
        if (self.mascot != nil) {
            [self.mascot startAnimation:self.storeUpdateTime];
        }
    }
}

- (void)stopBGEffect {
    if ([RBUserSettingData sharedInstance].thema == kThemaPastel) {
        if (self.bgEffectView != nil) {
            [self.bgEffectView stopAnimation];
        }
        if (self.mascot != nil) {
            [self.mascot stopAnimation];
        }
    }
}

#pragma mark - Ranking and store

- (void)SelectRankingButton {
    [self setSearchBarNonActive];
    [self hideSettingView];
    PlayThemedSoundEffect(GetSoundEffectManager(), kSoundEffectDecide);
    RBRankingView *view = [[RBRankingView alloc] initWithFrame:self.bounds];
    view.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [self addSubview:view];
    [view showAnimation];
    self.showView = view;
}

- (void)SelectStoreButton {
    [self setSearchBarNonActive];
    [self hideSettingView];
    [self releaseSelectMusic];
    if (GetFontVariantFlag() == kFontVariantDefault) {
        // Phone build: dismiss any modally-presented controller.
        [self.viewController dismissViewControllerAnimated:NO
                                                completion:^{
                                                }];
    } else {
        // Pad build: dismiss the playlist popover instead.
        [self.viewController.playlistPopoverController dismissPopoverAnimated:NO];
    }
    if (GetFontVariantFlag() == kFontVariantDefault && self.mapViewController != nil) {
        [self.mapViewController forceClose];
    }
    if (GetFontVariantFlag() == kFontVariantDefault && self.webViewController != nil) {
        [self.webViewController forceClose];
    }
    // POST the current region to the terms endpoint and check the accepted terms version.
    NSDictionary *body = @{kTermsRequestKeyTarget : GetRegionCode()};
    NSData *postData = [Downloader dictionaryToJsonData:body];
    __weak RBMenuView *weakSelf = self;
    self.termDownloader = [[Downloader alloc] initWithURL:[NetworkUtil termList]
                                                     post:postData
                                              contentType:kTermsRequestContentType];
    [weakSelf.termDownloader
        startDownloadingWithProceed:^{
          /** @ghidraAddress 0x35c040 */
          // Global no-op proceed block.
        }
        success:^{
          /** @ghidraAddress 0xad2c0 */
          [weakSelf handleTermsVersionResponse];
        }
        error:^{
          /** @ghidraAddress 0xad844 */
          [weakSelf handleTermsNetworkError];
        }];
}

- (void)StoreOpen {
    if (self.storeViewController == nil) {
        // First open: create the store tab controller and push it.
        self.storeViewController = [[RBStoreTabController alloc] init];
        self.storeViewController.musicMenuView = self;
        PlayThemedSoundEffect(GetSoundEffectManager(), kSoundEffectDecide);
        [[[AppDelegate appDelegate] navigationController]
            pushViewController:self.storeViewController
                      animated:YES];
        if (self.storeUpdateTime != nil) {
            [[RBUserSettingData sharedInstance] setLastUpdateTimeString:self.storeUpdateTime];
            [[RBUserSettingData sharedInstance] save];
        }
        [self.storeButton removeFlashEffect];
        [self.storeInfoView RemoveJumpEffect];
        self.storeInfoView.hidden = YES;
        [[RBBGMManager getInstance] PauseMusic:0.0];
        [self stopNews];
        [self stopBGEffect];
    } else {
        // Already created: only re-open if a pending store target is queued.
        if ([[AppDelegate appDelegate] getPackIDForOpenStore] == nil &&
            [[AppDelegate appDelegate] getCampaignIDForOpenStore] == nil &&
            [[AppDelegate appDelegate] getExtendNotePIDForOpenStore] == nil) {
            return;
        }
        [self.storeViewController forceOpen];
    }
}

- (void)didFinishedSendAgree {
    [self StoreOpen];
}

#pragma mark - News

- (void)TouchNews:(id)sender {
    [self setSearchBarNonActive];
    if (![self.newsView isLinkToStore]) {
        [self.newsView toLink];
        return;
    }
    if ([self.newsView getPackID] != nil) {
        [[AppDelegate appDelegate] setPackIDForOpenStore:[self.newsView getPackID]];
        [self SelectStoreButton];
    } else if ([self.newsView getCampaignID] != nil) {
        [[AppDelegate appDelegate] setCampaignIDForOpenStore:[self.newsView getCampaignID]];
        [self SelectStoreButton];
    } else if ([self.newsView getSequenceID] != nil) {
        [[AppDelegate appDelegate] setExtendNotePIDForOpenStore:[self.newsView getSequenceID]];
        [self SelectStoreButton];
    } else if ([self.newsView getWebID] != nil) {
        NSString *baseURL = [[AppDelegate appDelegate] getBaseWebInfoURL].absoluteString;
        NSString *url =
            [NSString stringWithFormat:@"%@?web_id=%@", baseURL, [self.newsView getWebID]];
        [[AppDelegate appDelegate] setWebInfoURL:url];
        [self showNotificationPageView];
    }
}

- (void)downloaderFinished:(Downloader *)downloader {
    if (self.hidden) {
        if (self.newsDownloader == downloader) {
            self.newsDownloader = nil;
        }
        return;
    }
    if (self.newsDownloader != downloader) {
        return;
    }
    self.newsGetTime = nil;
    self.newsGetTime = [[NSDate alloc] initWithTimeIntervalSinceNow:kNewsGetTimeOffset];
    NSDictionary *json = [self.newsDownloader getDataInJSON];
    NSString *updateTime = json[kNewsKeyUpdateTime];
    NSArray *updateText = json[kNewsKeyUpdateText];
    NSArray *info = json[kNewsKeyInfo];

    if (updateTime != nil && [updateTime isKindOfClass:[NSString class]]) {
        self.storeUpdateTime = nil;
        self.storeUpdateTime = [[NSString alloc] initWithString:updateTime];
        NSString *lastUpdate = [[RBUserSettingData sharedInstance] lastUpdateTimeString];
        BOOL isNew = YES;
        if (lastUpdate != nil && [lastUpdate compare:self.storeUpdateTime
                                             options:NSNumericSearch] != NSOrderedAscending) {
            isNew = NO;
        }
        if (isNew) {
            [self.storeButton setFlashEffect];
            self.storeInfoView.hidden = NO;
            // Both origin coordinates are re-read from a fresh frame call, as the binary does.
            [self.storeInfoView
                SetJumpEffectBaseX:static_cast<float>(self.storeInfoView.frame.origin.x)
                             BaseY:static_cast<float>(self.storeInfoView.frame.origin.y)];
        }
    }
    if (updateText != nil && [updateText isKindOfClass:[NSArray class]] && updateText.count != 0) {
        self.newsInfoText = updateText;
        NSUInteger seed = arc4random() & kNewsRandomMask;
        NSUInteger count = self.newsInfoText.count;
        self.newsInfoIndex =
            (count != 0) ? static_cast<int>((seed % count)) : static_cast<int>(seed);
        [self showNextNewsText];
    }
    if (info != nil && [info isKindOfClass:[NSArray class]]) {
        for (NSDictionary *entry in info) {
            if (![entry isKindOfClass:[NSDictionary class]]) {
                continue;
            }
            int informationID = kNewsInvalidInformationID;
            id idValue = entry[kNewsKeyID];
            if (idValue != nil) {
                informationID = [idValue intValue];
                if (informationID < 1) {
                    informationID = kNewsInvalidInformationID;
                }
            }
            if ([[RBUserSettingData sharedInstance] newsInfomationID] < informationID) {
                NSString *entryVer = entry[kNewsKeyVer];
                NSString *bundleVer = [NSBundle mainBundle].infoDictionary[kNewsKeyCFBundleVersion];
                if (entryVer != nil && bundleVer != nil &&
                    [bundleVer compare:entryVer options:NSNumericSearch] != NSOrderedAscending) {
                    NSString *image = entry[kNewsKeyImage];
                    RBNewsHUDView *hud = [[RBNewsHUDView alloc] initWithFrame:self.bounds];
                    // The bounds are re-read for each centre component, matching the binary.
                    hud.center = CGPointMake(self.bounds.size.width * kNewsHUDCentreScale,
                                             self.bounds.size.height * kNewsHUDCentreScale);
                    [self addSubview:hud];
                    [hud showImage:image InfomationID:informationID];
                    break;
                }
            }
        }
    }
    self.newsDownloader = nil;
}

- (void)downloaderError:(Downloader *)downloader {
    if (self.hidden) {
        if (self.newsDownloader == downloader) {
            self.newsDownloader = nil;
        }
        return;
    }
    if (self.newsDownloader == downloader) {
        self.newsDownloader = nil;
    }
    if (self.newsBannerTimer != nil) {
        [self.newsBannerTimer invalidate];
        self.newsBannerTimer = nil;
    }
    // On error, retry fetching the news banner after a fixed delay.
    self.newsBannerTimer = [NSTimer timerWithTimeInterval:kNewsBannerDefaultInterval
                                                   target:self
                                                 selector:@selector(startNewsFromTimer)
                                                 userInfo:nil
                                                  repeats:NO];
    [[NSRunLoop mainRunLoop] addTimer:self.newsBannerTimer forMode:NSRunLoopCommonModes];
}

- (void)startNews {
    if (self.newsGetTime != nil &&
        self.newsGetTime.timeIntervalSinceNow > kNewsCacheValiditySeconds) {
        // The cached news is still fresh: just advance to the next text.
        [self showNextNewsText];
        return;
    }
    [self stopNews];
    self.storeUpdateTime = nil;
    if (self.newsDownloader != nil) {
        return;
    }
    self.newsDownloader = [[Downloader alloc] initWithURL:[NetworkUtil lineMessageURL] save:NO];
    [self.newsDownloader startDownloadingWithDelegate:self];
}

- (void)startNewsFromTimer {
    if (self.newsBannerTimer != nil) {
        [self.newsBannerTimer invalidate];
        self.newsBannerTimer = nil;
    }
    [self startNews];
}

- (void)showNextNewsText {
    int index = self.newsInfoIndex;
    [self.newsView setDuration:kNewsTickerDuration];
    double interval = kNewsBannerDefaultInterval;
    do {
        ++index;
        if (static_cast<NSUInteger>(index) >= self.newsInfoText.count) {
            index = 0;
        }
        NSDictionary *entry = self.newsInfoText[index];
        if (entry != nil && entry[kNewsKeyMessage] != nil && [entry[kNewsKeyMessage] length] != 0) {
            NSString *message = entry[kNewsKeyMessage];
            NSString *link = entry[kNewsKeyLink];
            float displayTime;
            if (link == nil || link.length < 2 || [NSURL URLWithString:link] == nil) {
                displayTime = [self.newsView setText:message LINK:nil];
            } else {
                displayTime = [self.newsView setText:message LINK:[NSURL URLWithString:link]];
            }
            interval = static_cast<double>((displayTime + kNewsTickerDuration));
            break;
        }
    } while (index != self.newsInfoIndex);
    [self.newsBannerTimer invalidate];
    self.newsBannerTimer = [NSTimer timerWithTimeInterval:interval
                                                   target:self
                                                 selector:@selector(startNewsFromTimer)
                                                 userInfo:nil
                                                  repeats:NO];
    [[NSRunLoop mainRunLoop] addTimer:self.newsBannerTimer forMode:NSRunLoopCommonModes];
    self.newsInfoIndex = index;
}

- (void)stopNews {
    [self.newsView stopNews];
    [self.newsBannerTimer invalidate];
    self.newsBannerTimer = nil;
    [self.newsDownloader cancel];
}

- (void)SetServerDateYear:(int)year
                    Month:static_cast<int>(month)
                      Day:static_cast<int>(day)
                     Hour:static_cast<int>(hour)
                   Minute:static_cast<int>(minute)
                   Second:static_cast<int>(second) {
    // The binary body is empty; this is a deliberate no-op stub.
}

- (void)showInfomation {
    if ([RBUserSettingData sharedInstance].howtoFirstInfo &&
        ![RBUserSettingData sharedInstance].newCustomItem &&
        ![RBUserSettingData sharedInstance].newThema &&
        [AppDelegate appDelegate].unreadRecommendCount < 1) {
        [self.storeButton removeFlashEffect];
        return;
    }
    [self.settingButton setFlashEffect];
}

#pragma mark - Search

- (void)createSearchDictionary {
    NSArray *musicDataArray = [[RBMusicManager getInstance] getMusicDataArray];
    self.searchDictionary = [[NSMutableDictionary alloc] init];
    for (RBMusicData *musicData in musicDataArray) {
        // Normalise the name and artist: strip spaces, then fold kana and width so that
        // hiragana/katakana and full/half-width variants all match.
        NSMutableString *nameKey =
            [[musicData.musicName stringByReplacingOccurrencesOfString:@" "
                                                            withString:@""] mutableCopy];
        if (nameKey == nil) {
            nameKey = [[NSMutableString alloc] initWithString:@""];
        } else {
            CFStringTransform((__bridge CFMutableStringRef)nameKey,
                              NULL,
                              kCFStringTransformHiraganaKatakana,
                              false);
            CFStringTransform((__bridge CFMutableStringRef)nameKey,
                              NULL,
                              kCFStringTransformFullwidthHalfwidth,
                              false);
        }
        NSMutableString *artistKey =
            [[musicData.artistName stringByReplacingOccurrencesOfString:@" "
                                                             withString:@""] mutableCopy];
        if (artistKey == nil) {
            artistKey = [[NSMutableString alloc] initWithString:@""];
        } else {
            CFStringTransform((__bridge CFMutableStringRef)artistKey,
                              NULL,
                              kCFStringTransformHiraganaKatakana,
                              false);
            CFStringTransform((__bridge CFMutableStringRef)artistKey,
                              NULL,
                              kCFStringTransformFullwidthHalfwidth,
                              false);
        }
        NSMutableArray *terms = [[NSMutableArray alloc] init];
        [terms addObject:nameKey];
        [terms addObject:artistKey];

        NSString *idKey = [NSString stringWithFormat:@"%d", musicData.MusicID];
        NSDictionary *expandDictionary = [[[RBMusicSearchExpander alloc] init] getDictionary];
        if (expandDictionary != nil && expandDictionary[idKey] != nil) {
            NSArray *expanded = expandDictionary[idKey];
            for (NSString *term in expanded) {
                NSMutableString *foldedTerm = [term mutableCopy];
                CFStringTransform((__bridge CFMutableStringRef)foldedTerm,
                                  NULL,
                                  kCFStringTransformHiraganaKatakana,
                                  false);
                CFStringTransform((__bridge CFMutableStringRef)foldedTerm,
                                  NULL,
                                  kCFStringTransformFullwidthHalfwidth,
                                  false);
                [terms addObject:foldedTerm];
            }
        }
        self.searchDictionary[@(musicData.MusicID)] = terms;
    }
}

- (void)showSearchBar {
    // Only proceed while the search bar is parked off-screen (negative Y).
    if (self.searchBar.frame.origin.y >= 0.0) {
        return;
    }
    if (self.pushNotificationView != nil) {
        // Abort if the push-notification view has slid far enough to overlap.
        if (self.pushNotificationView.y >
            self.pushNotificationView.height * kSearchPushNotificationOverlapFactor) {
            return;
        }
    }
    if (self.tutorialView != nil || self.showView != nil || self.selectedView != nil ||
        self.settingView != nil || self.pageSlider != nil) {
        return;
    }
    if ([RBUserSettingData sharedInstance].thema == kThemaPastel) {
        PlayThemedSoundEffect(GetSoundEffectManager(), static_cast<int>(kSoundEffectSearchBarShow));
    }
    [self.searchBar becomeFirstResponder];
    self.searchBar.text = self.backUpString;
    [self searchBar:self.searchBar textDidChange:self.backUpString];
    if ([RBUserSettingData sharedInstance].thema == kThemaPastel) {
        if (![[RBCampaignData sharedInstance] isCampaignHinabita201703]) {
            NSUInteger index = (rand() % 100 < kSearchMascotDefaultBias) ? 0 : 1;
            [self.searchMascot setImage:self.searchMascotImages[index]];
        } else {
            int r = rand();
            NSUInteger count = self.searchMascotImages.count;
            NSUInteger index = (count != 0) ? (static_cast<NSUInteger>(r) % count) : 0;
            [self.searchMascot setImage:self.searchMascotImages[index]];
        }
    }
    [UIView animateWithDuration:g_dMascotMessageAnimDuration
                     animations:^{
                       /** @ghidraAddress 0xb0924 */
                       [self layoutSearchBarActive:YES];
                     }];
}

- (void)setSearchBarNonActive {
    if (self.searchBar != nil) {
        [self.searchBar resignFirstResponder];
    }
}

- (void)hideSearchBar {
    // Only hide while the search bar is on-screen (non-negative Y) and nothing else is shown.
    if (self.searchBar.frame.origin.y >= 0.0 && self.showView == nil && self.selectedView == nil &&
        self.settingView == nil) {
        PlayThemedSoundEffect(GetSoundEffectManager(), static_cast<int>(kSoundEffectSearchBarHide));
        [self.searchBar resignFirstResponder];
        self.backUpString = self.searchBar.text;
        [self searchBar:self.searchBar textDidChange:@""];
        [UIView animateWithDuration:g_dMascotMessageAnimDuration
            animations:^{
              /** @ghidraAddress 0xb1224 */
              [self layoutSearchBarActive:NO];
            }
            completion:^(BOOL finished) {
              /** @ghidraAddress 0xb1544 */
              [self.searchMascot setImage:nil];
            }];
    }
}

- (void)tapSearchMusicCancel {
    self.searchBar.text = @"";
    self.backUpString = @"";
    [self searchBar:self.searchBar textDidChange:@""];
    [self hideSearchBar];
}

- (BOOL)searchStringChanged:(NSString *)searchString {
    NSArray *previousArray = [NSArray arrayWithArray:self.searchArray];
    self.searchArray = [NSMutableArray arrayWithArray:[self getSearchArray:searchString]];

    // A trailing-space-only change is not a real change unless the token set actually differs.
    NSCharacterSet *spaces = [NSCharacterSet characterSetWithCharactersInString:@" "];
    if (![searchString isEqualToString:[searchString stringByTrimmingCharactersInSet:spaces]]) {
        return NO;
    }
    if (previousArray.count != self.searchArray.count) {
        return YES;
    }
    for (id token in previousArray) {
        if (![self.searchArray containsObject:token]) {
            return YES;
        }
    }
    return NO;
}

- (NSMutableArray *)getSearchArray:(NSString *)searchString {
    NSMutableString *normalised = [searchString mutableCopy];
    // Fold kana and width twice so mixed-form input collapses to a single canonical form.
    CFStringTransform(
        (__bridge CFMutableStringRef)normalised, NULL, kCFStringTransformHiraganaKatakana, false);
    CFStringTransform(
        (__bridge CFMutableStringRef)normalised, NULL, kCFStringTransformFullwidthHalfwidth, false);
    CFStringTransform(
        (__bridge CFMutableStringRef)normalised, NULL, kCFStringTransformHiraganaKatakana, false);
    CFStringTransform(
        (__bridge CFMutableStringRef)normalised, NULL, kCFStringTransformFullwidthHalfwidth, false);
    NSArray *components = [normalised componentsSeparatedByString:@" "];
    NSArray *unique = [[NSSet setWithArray:components] allObjects];
    NSMutableArray *result = [NSMutableArray arrayWithArray:unique];
    [result removeObject:@""];
    return result;
}

- (void)exeSearchPickUp {
    AppDelegate *appDelegate = [AppDelegate appDelegate];
    if (self.searchArray.count == 0) {
        appDelegate.searchString = nil;
    } else {
        appDelegate.searchString = self.searchBar.text;
    }
    [self reloadMusicData];
}

- (BOOL)matchTitle:(RBMusicData *)matchTitle {
    NSArray *terms = self.searchDictionary[@(matchTitle.MusicID)];
    // Every search token must be found somewhere in this title's term list.
    for (NSString *token in self.searchArray) {
        BOOL tokenFound = NO;
        for (NSString *term in terms) {
            if (term != nil) {
                NSRange range = [term rangeOfString:token options:NSCaseInsensitiveSearch];
                tokenFound |= (range.location != NSNotFound);
            }
        }
        if (!tokenFound) {
            return NO;
        }
    }
    return YES;
}

- (void)searchBar:(UISearchBar *)searchBar textDidChange:(NSString *)searchText {
    if ([self searchStringChanged:searchText]) {
        [self exeSearchPickUp];
    }
}

#pragma mark - Gestures and cell configuration

- (void)handleLongPressGesture:(UILongPressGestureRecognizer *)handleLongPressGesture {
    if (![RBTutorialManager isTutorialMusicselect] && ![RBTutorialManager isTutorialCustomize] &&
        handleLongPressGesture.state == UIGestureRecognizerStateBegan) {
        [self playlistEditStart];
    }
}

- (void)configureCell:(RBMusicCell *)configureCell {
    int editMode = self.playListEditMode;
    if (editMode == kMenuModePlaylistAdd) {
        configureCell.addButton.hidden =
            ![self.playlistEditSet containsObject:@(configureCell.musicData.MusicID)];
    } else if (editMode == kMenuModePlaylistDelete) {
        configureCell.removeButton.hidden =
            ![self.playlistEditSet containsObject:@(configureCell.musicData.MusicID)];
    }

    // While the grid is decelerating the artwork and score fetch is skipped.
    if (self.collectionView.isDecelerating) {
        return;
    }

    if (configureCell.musicData != nil) {
        // Kick off the artwork load off the main thread; the block fades it in once ready.
        __weak RBMusicCell *weakCell = configureCell;
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0), ^{
          /** @ghidraAddress 0xb28d0 */
          [weakCell loadArtworkAndFadeIn];
        });
    }

    NSManagedObjectContext *context = [RBCoreDataManager sharedInstance].managedObjectContext;
    ScoreData *scoreData = [ScoreData getScoreData:configureCell.musicData.MusicID
                            inManagedObjectContext:context];
    if (configureCell.musicData.ExtMusicData != nil) {
        ScoreData *extScoreData =
            [ScoreData getScoreData:configureCell.musicData.ExtMusicData.MusicID
                inManagedObjectContext:context];
        [configureCell updateScoreData:scoreData spData:extScoreData];
    } else {
        [configureCell updateScoreData:scoreData];
    }
}

#pragma mark - Scroll and collection view

- (void)scrollViewDidEndScroll:(UIScrollView *)scrollViewDidEndScroll {
    if (self.collectionView == scrollViewDidEndScroll) {
        self.currentPageIndex = static_cast<NSInteger>(
            (self.collectionView.contentOffset.x / self.collectionView.frame.size.width));
        for (RBMusicCell *cell in self.collectionView.visibleCells) {
            [self configureCell:cell];
        }
        if (self.backgroundScrollView != nil) {
            NSUInteger imageCount = self.backgroundImageCount;
            int page = 0;
            if (imageCount != 0) {
                page =
                    static_cast<int>((self.currentPageIndex % static_cast<NSInteger>(imageCount)));
            }
            NSUInteger currentBg = self.backgroundCurrentPage;
            CGFloat width = self.backgroundScrollView.width;
            if (currentBg - static_cast<NSUInteger>(page) == imageCount - 1) {
                [self.backgroundScrollView
                    setContentOffset:CGPointMake(width * static_cast<CGFloat>((imageCount + 1)),
                                                 0.0)
                            animated:YES];
            } else if (currentBg - static_cast<NSUInteger>(page) == 1 - imageCount) {
                [self.backgroundScrollView setContentOffset:CGPointZero animated:YES];
            } else {
                [self.backgroundScrollView
                    setContentOffset:CGPointMake(static_cast<CGFloat>((page + 1)) * width, 0.0)
                            animated:YES];
            }
            self.backgroundCurrentPage = static_cast<NSUInteger>(page);
        }
    } else if (self.backgroundScrollView == scrollViewDidEndScroll) {
        CGFloat width = self.backgroundScrollView.width;
        NSUInteger currentBg = self.backgroundCurrentPage;
        CGFloat offsetX = self.backgroundScrollView.contentOffset.x;
        // Snap the background back to its page origin if it drifted off by more than the epsilon.
        if (fabs(width * static_cast<CGFloat>((currentBg + 1)) - offsetX) >
            g_dMascotMoveAnimDuration) {
            [self.backgroundScrollView
                setContentOffset:CGPointMake(width * static_cast<CGFloat>((currentBg + 1)), 0.0)
                        animated:NO];
        }
    }
}

- (NSInteger)numberOfSectionsInCollectionView:(UICollectionView *)collectionView {
    return 1;
}

- (NSInteger)collectionView:(UICollectionView *)collectionView
     numberOfItemsInSection:static_cast<NSInteger>(section) {
    return self.musicList.count;
}

- (UICollectionViewCell *)collectionView:(UICollectionView *)collectionView
                  cellForItemAtIndexPath:(NSIndexPath *)indexPath {
    RBMusicCell *cell = [collectionView dequeueReusableCellWithReuseIdentifier:@"RBMusicCell"
                                                                  forIndexPath:indexPath];
    cell.menuView = self;
    cell.musicData = self.musicList[indexPath.row];
    [cell.artworkImageView setImage:nil];
    [cell updateScoreData:nil];
    cell.hidden = self.musicCellHidden;

    if (cell.musicData != nil) {
        if (cell.musicData.isArtworkCache) {
            if (cell.artworkImageView.image == nil) {
                [cell.artworkImageView setImage:cell.musicData.artwork];
                cell.artworkImageView.alpha = kArtworkFadeInStartAlpha;
                [UIView animateWithDuration:g_dAudioManagerResumeFadeInTime
                    animations:^{
                      /** @ghidraAddress 0xb3b30 */
                      cell.artworkImageView.alpha = kAlphaOpaque;
                    }
                    completion:^(BOOL finished) {
                      /** @ghidraAddress 0xb3c70 */
                      (void)finished;
                    }];
            }
        }
        cell.titleLabel.text = cell.musicData.musicName;
        if (GetFontVariantFlag() != kFontVariantDefault) {
            cell.artistLabel.text = cell.musicData.artistName;
        }
    }
    [self configureCell:cell];
    return cell;
}

- (void)collectionView:(UICollectionView *)collectionView
    didSelectItemAtIndexPath:(NSIndexPath *)indexPath {
    int editMode = self.playListEditMode;
    if (editMode == kMenuModePlaylistAdd) {
        RBMusicCell *cell =
            static_cast<RBMusicCell *>([self.collectionView cellForItemAtIndexPath:indexPath]);
        cell.addButton.hidden = !cell.addButton.isHidden;
        if (!cell.addButton.isHidden) {
            [self.playlistEditSet addObject:@(cell.musicData.MusicID)];
        } else {
            [self.playlistEditSet removeObject:@(cell.musicData.MusicID)];
        }
        [self playlistAddDelButtonUpdate];
    } else if (editMode == kMenuModePlaylistDelete) {
        RBMusicCell *cell =
            static_cast<RBMusicCell *>([self.collectionView cellForItemAtIndexPath:indexPath]);
        cell.removeButton.hidden = !cell.removeButton.isHidden;
        if (!cell.removeButton.isHidden) {
            [self.playlistEditSet addObject:@(cell.musicData.MusicID)];
        } else {
            [self.playlistEditSet removeObject:@(cell.musicData.MusicID)];
        }
        [self playlistAddDelButtonUpdate];
    } else if (editMode == kMenuModePlaylistFinished) {
        RBMusicData *musicData = self.musicList[indexPath.row];
        self.selectedView.isRandom = NO;
        [self selectMusic:musicData animated:YES];
    }
}

- (void)scrollViewWillBeginDragging:(UIScrollView *)scrollView {
    [self setSearchBarNonActive];
}

- (void)scrollViewDidEndDecelerating:(UIScrollView *)scrollView {
    [self scrollViewDidEndScroll:scrollView];
}

- (void)scrollViewDidEndDragging:(UIScrollView *)scrollView willDecelerate:(BOOL)decelerate {
    if (!decelerate) {
        [self scrollViewDidEndScroll:scrollView];
    }
}

- (void)scrollViewDidEndScrollingAnimation:(UIScrollView *)scrollView {
    [self scrollViewDidEndScroll:scrollView];
}

#pragma mark - RBCollectionView layout and touch forwarding

- (void)willLayoutSubviews:(UIView *)willLayoutSubviews {
    // The binary body is empty; this is a deliberate no-op.
}

- (void)didLayoutSubviews:(UIView *)didLayoutSubviews {
    CGSize contentSize = self.collectionView.contentSize;
    CGFloat width = self.collectionView.frame.size.width;
    NSInteger pages = static_cast<NSInteger>((contentSize.width / width));
    self.maxPage = (pages != 0) ? pages : 1;

    if (self.currentPageIndex >= self.maxPage) {
        self.currentPageIndex = self.maxPage - 1;
    }

    CGFloat offsetX = self.collectionView.contentOffset.x;
    CGFloat pageWidth = self.collectionView.frame.size.width;
    int remainder = 0;
    if (static_cast<int>(pageWidth) != 0) {
        remainder = static_cast<int>(offsetX) % static_cast<int>(pageWidth);
    }
    // If the resting offset is within the middle band of a page, snap to the nearest page.
    if (static_cast<CGFloat>((static_cast<float>(pageWidth) * kPageSnapLowFraction)) <
            static_cast<CGFloat>(remainder) &&
        static_cast<CGFloat>(remainder) <
            static_cast<CGFloat>((static_cast<float>(pageWidth) * kPageSnapHighFraction))) {
        float snapped =
            (static_cast<float>(offsetX) + static_cast<float>(pageWidth) * kPageSnapMidpoint) /
            static_cast<float>(pageWidth);
        self.currentPageIndex = static_cast<NSInteger>(snapped);
        if (self.currentPageIndex >= self.maxPage) {
            self.currentPageIndex = self.maxPage - 1;
        }
    }
    if (self.currentPageIndex >= self.maxPage) {
        self.currentPageIndex = self.maxPage - 1;
    }

    [self.mascot setLimitX:static_cast<float>(self.collectionView.contentSize.width)];
    [self.mascot setLimitY:static_cast<float>(self.collectionView.height)];
}

- (void)touchesBeganFromRBCollectionView:(NSSet *)touches withEvent:(UIEvent *)event {
    // The binary body is empty; this is a deliberate no-op.
}

- (void)touchesEndedFromRBCollectionView:(NSSet *)touches withEvent:(UIEvent *)event {
    // Dismiss the keyboard only while the search bar is on-screen (non-negative Y).
    if (self.searchBar.frame.origin.y < 0.0) {
        return;
    }
    [self.searchBar resignFirstResponder];
}

#pragma mark - Push notification

- (void)showPushNotificationView {
    if (self.selectedView != nil && !self.selectedView.isHidden) {
        return;
    }
    if (self.storeViewController == nil) {
        [self.pushNotificationView showNotification];
        __weak RBMenuView *weakSelf = self;
        [UIView animateWithDuration:g_dAudioManagerResumeFadeInTime
                         animations:^{
                           /** @ghidraAddress 0xb4a3c */
                           [weakSelf setSearchMascotsHidden:YES];
                         }];
    }
}

- (void)actionFromPushNotificationView {
    if ([[AppDelegate appDelegate] getPackIDForOpenStore] == nil &&
        [[AppDelegate appDelegate] getCampaignIDForOpenStore] == nil &&
        [[AppDelegate appDelegate] getExtendNotePIDForOpenStore] == nil) {
        if ([[AppDelegate appDelegate] getWebInfoURL] == nil) {
            if ([AppDelegate getOuterURL] == nil) {
                return;
            }
            NSURL *outerURL = [AppDelegate getOuterURL];
            [AppDelegate setOuterURL:nil];
            if ([[UIApplication sharedApplication] canOpenURL:outerURL]) {
                [[UIApplication sharedApplication] openURL:outerURL];
            }
        } else {
            NSString *baseURL = [[AppDelegate appDelegate] getBaseWebInfoURL].absoluteString;
            NSString *newURL =
                [NSString stringWithFormat:@"%@?web_id=%@", baseURL, [self.newsView getWebID]];
            [[AppDelegate appDelegate] setWebInfoURL:newURL];
        }
        return;
    }
    [self SelectStoreButton];
}

- (void)finishPushNotification {
    __weak RBMenuView *weakSelf = self;
    if (self.searchBar.frame.origin.y >= 0.0) {
        [UIView animateWithDuration:g_dAudioManagerResumeFadeInTime
                         animations:^{
                           /** @ghidraAddress 0xb505c */
                           [weakSelf setSearchMascotsHidden:NO];
                         }];
    } else {
        [UIView animateWithDuration:g_dAudioManagerResumeFadeInTime
                         animations:^{
                           /** @ghidraAddress 0xb51ac */
                           [weakSelf setSearchMascotsHidden:YES];
                         }];
    }
}

#pragma mark - Tutorial

- (void)preStartTutorial {
    if ([RBUserSettingData sharedInstance].thema != kThemaPastel) {
        return;
    }
    if (![RBTutorialManager needStartTutorialMusicselect] &&
        ![RBTutorialManager needStartTutorialCustomize]) {
        return;
    }
    if (self.tutorialView != nil) {
        [self.tutorialView removeFromSuperview];
        self.tutorialView = nil;
    }
    if (![RBTutorialManager needStartTutorialMusicselect]) {
        // Customize tutorial: skip if the customize status was already recorded as done.
        if ([[RBUserSettingData sharedInstance] getTutorialStatus:kTutorialStatusCustomize] != 0) {
            return;
        }
        RBMenuTutorialView *view = [[RBMenuTutorialView alloc] initWithFrame:self.frame];
        [view setupView];
        view.musicMenuView = self;
        view.layer.zPosition = g_dCustomizeLayoutMetric100;
        [self addSubview:view];
        self.tutorialView = view;
    } else {
        // Music-select tutorial: build the overlay and clear any active playlist selection.
        RBMenuTutorialView *view = [[RBMenuTutorialView alloc] initWithFrame:self.frame];
        [view setupView];
        view.musicMenuView = self;
        view.layer.zPosition = g_dCustomizeLayoutMetric100;
        [self addSubview:view];
        self.tutorialView = view;
        if ([RBUserSettingData sharedInstance].playlistID != kPlaylistIDNone) {
            [RBUserSettingData sharedInstance].playlistID = kPlaylistIDNone;
        }
    }
}

- (void)startTutorial {
    if ([RBUserSettingData sharedInstance].thema != kThemaPastel) {
        return;
    }
    if (![RBTutorialManager needStartTutorialMusicselect] &&
        ![RBTutorialManager needStartTutorialCustomize]) {
        return;
    }
    if ([RBTutorialManager needStartTutorialMusicselect]) {
        // Music-select tutorial: only start once a placeholder music cell is on screen.
        if ([self getTutorialMusicCell] != nil) {
            if (self.tutorialView == nil) {
                [self preStartTutorial];
            }
            [self.tutorialView showAnimationWithTutorialType:kTutorialTypeMusicSelect
                                                withRootView:nil];
        }
    } else {
        // Customize tutorial: skip if the customize status was already recorded as done.
        if ([[RBUserSettingData sharedInstance] getTutorialStatus:kTutorialStatusCustomize] != 0) {
            return;
        }
        if (self.tutorialView == nil) {
            [self preStartTutorial];
        }
        [self.tutorialView showAnimationWithTutorialType:kTutorialTypeCustomize withRootView:nil];
    }
}

- (RBMusicCell *)getTutorialMusicCell {
    NSArray<NSIndexPath *> *visible = [self.collectionView indexPathsForVisibleItems];
    if (visible == nil) {
        return nil;
    }
    for (NSIndexPath *indexPath in visible) {
        RBMusicCell *cell =
            static_cast<RBMusicCell *>([self.collectionView cellForItemAtIndexPath:indexPath]);
        if ([cell.musicData.musicName isEqualToString:kTutorialPlaceholderMusicName]) {
            return cell;
        }
    }
    return nil;
}

- (RBCollectionView *)getCollectionView {
    return self.collectionView;
}

- (RBMenuButton *)getSettingButton {
    return self.settingButton;
}

- (RBMenuButton *)getStoreButton {
    return self.storeButton;
}

- (void)setPastelForTutorialStart {
    self.mascot.alpha = kAlphaHidden;
    self.searchMascot.alpha = kAlphaHidden;
}

- (void)setPastelForTutorialEnd {
    // The mascot stays hidden while the search mascot is shown at the end of a tutorial step.
    self.mascot.alpha = kAlphaHidden;
    self.searchMascot.alpha = kAlphaOpaque;
}

- (void)closeTutorial {
    if (self.tutorialView != nil) {
        [self.tutorialView removeFromSuperview];
        self.tutorialView = nil;
    }
}

#pragma mark - Playlist editing

- (void)playlistEditStart {
    if (self.tutorialView != nil || self.showView != nil || self.selectedView != nil ||
        self.settingView != nil) {
        return;
    }
    BOOL entered;
    if ([RBUserSettingData sharedInstance].playlistID == kPlaylistIDCustom) {
        entered = [self setCurrentMenuMode:kMenuModePlaylistDelete];
    } else {
        entered = [self setCurrentMenuMode:kMenuModePlaylistAdd];
    }
    if (!entered) {
        return;
    }

    if ([RBUserSettingData sharedInstance].playlistID == kPlaylistIDCustom) {
        self.playlistDelButton.hidden = NO;
        self.playlistDelButton.enabled = NO;
        self.playlistAddButton.hidden = YES;
    } else {
        self.playlistDelButton.hidden = YES;
        self.playlistAddButton.hidden = NO;
        self.playlistAddButton.enabled = NO;
    }

    if (self.playlistEditSet == nil) {
        self.playlistEditSet = [[NSMutableSet alloc] init];
    }
    [self.playlistEditSet removeAllObjects];

    if (!self.storeInfoView.isHidden) {
        [self.storeInfoView RemoveJumpEffect];
        self.storeInfoView.alpha = kAlphaHidden;
    }

    if (self.newsView.gestureRecognizers.count == 1) {
        self.newsView.gestureRecognizers[0].enabled = NO;
    }

    [self insertSubview:self.settingButton belowSubview:self.rankButton];

    [UIView animateWithDuration:kPlaylistEditAnimationDuration
                          delay:kPlaylistEditAnimationDelay
                        options:UIViewAnimationOptionBeginFromCurrentState
                     animations:^{
                       /** @ghidraAddress 0xb6520 */
                       [self shiftMenuButtonsForPlaylistEditEntering:YES];
                     }
                     completion:nil];
}

- (void)playlistEditFinish {
    self.playListEditMode = kMenuModePlaylistFinished;
    [self.playlistEditSet removeAllObjects];

    __weak RBMenuView *weakSelf = self;
    [UIView animateWithDuration:kPlaylistEditAnimationDuration
        delay:kPlaylistEditAnimationDelay
        options:UIViewAnimationOptionBeginFromCurrentState
        animations:^{
          /** @ghidraAddress 0xb7578 */
          [weakSelf shiftMenuButtonsForPlaylistEditEntering:NO];
        }
        completion:^(BOOL finished) {
          /** @ghidraAddress 0xb8324 */
          if (weakSelf.newsView.gestureRecognizers.count == 1) {
              weakSelf.newsView.gestureRecognizers[0].enabled = YES;
          }
          if (weakSelf.storeInfoView.isHidden) {
              return;
          }
          weakSelf.storeInfoView.alpha = kAlphaOpaque;
          [weakSelf.storeInfoView
              SetJumpEffectBaseX:static_cast<float>(weakSelf.storeInfoView.frame.origin.x)
                           BaseY:static_cast<float>(weakSelf.storeInfoView.frame.origin.y)];
        }];
    [self reloadMusicData];
}

- (void)playlistAddDelButtonUpdate {
    switch (self.playListEditMode) {
    case kMenuModePlaylistAdd:
        self.playlistAddButton.enabled = (self.playlistEditSet.count != 0);
        break;
    case kMenuModePlaylistDelete:
        self.playlistDelButton.enabled = (self.playlistEditSet.count != 0);
        break;
    default:
        break;
    }
}

- (void)SelectPlaylistAddButton {
    [[AppDelegate appDelegate].viewController playListAddMusicSet:self.playlistEditSet];
}

- (void)SelectPlaylistDelButton {
    NSInteger playlistLevel = [RBUserSettingData sharedInstance].playlistLevel;
    for (NSNumber *musicID in self.playlistEditSet) {
        [[RBPlaylistManager sharedInstance] removeMusic:musicID.intValue
                                    fromPlaylistAtIndex:playlistLevel];
    }
    [[RBPlaylistManager sharedInstance] synchronize];
    [self.playlistEditSet removeAllObjects];
    [self playlistAddDelButtonUpdate];
    [self reloadMusicData];
}

- (void)SelectPlaylistFinButton {
    [[RBPlaylistManager sharedInstance] synchronize];
    [self playlistEditFinish];
}

- (BOOL)setCurrentMenuMode:(int)currentMenuMode {
    if (currentMenuMode < kMenuModePlaylistFinished) {
        // Entering add or delete requires the previous mode to be the resting mode.
        if (self.playListEditMode != kMenuModePlaylistFinished) {
            return NO;
        }
    } else if (currentMenuMode != kMenuModePlaylistFinished) {
        return NO;
    }
    self.playListEditMode = currentMenuMode;
    return YES;
}

#pragma mark - Page slider

- (void)showPageSlider:(BOOL)showPageSlider {
    // The BOOL argument is accepted but never read; the guard is the search-bar position.
    if (self.tutorialView != nil || self.showView != nil || self.selectedView != nil ||
        self.settingView != nil) {
        return;
    }
    if (self.searchBar.y >= 0.0) {
        return;
    }
    if (self.pageSlider != nil) {
        return;
    }
    RBMenuPageSliderView *slider = [[RBMenuPageSliderView alloc] initWithFrame:self.frame
                                                                      delegate:self];
    self.pageSlider = slider;
    self.pageSlider.alpha = kAlphaHidden;
    [self addSubview:self.pageSlider];
    [self.pageSlider showView:self.pageLabel.frame
                      pageMax:self.maxPage
                  currentPage:self.currentPageIndex + 1];
}

- (void)changePage:(NSArray<NSNumber *> *)changePage {
    self.currentPageIndex = changePage[0].intValue - 1;

    CGFloat pageWidth = self.collectionView.frame.size.width;
    if (changePage[2].boolValue) {
        [self.collectionView setContentOffset:CGPointMake(pageWidth * self.currentPageIndex, 0.0)
                                     animated:YES];
    } else {
        CGFloat factor = changePage[1].floatValue - 1.0;
        [self.collectionView setContentOffset:CGPointMake(pageWidth * factor, 0.0) animated:NO];
    }

    if (self.musicList != nil && self.musicList.count != 0) {
        NSInteger itemIndex = self.layout.colCount * self.layout.rowCount * self.currentPageIndex;
        RBMusicData *music = self.musicList[itemIndex];
        if ([RBUserSettingData sharedInstance].menuItemSort == kMenuItemSortArtist) {
            self.pageSlider.indexLabel = music.artistNameHira;
        } else {
            self.pageSlider.indexLabel = music.musicNameHira;
        }
    }
}

#pragma mark - Mascot

- (void)touchMascot {
    self.musicCellHidden = !self.musicCellHidden;
    for (UIView *subview in self.collectionView.subviews) {
        if ([subview class] == [RBMusicCell class]) {
            if (self.musicCellHidden) {
                [static_cast<RBMusicCell *>(subview) hide];
            } else {
                [static_cast<RBMusicCell *>(subview) show];
            }
        }
    }
}

#pragma mark - Debug

- (void)debugAlphaLog {
    for (UIView *subview in self.collectionView.subviews) {
        // Yes, the binary fetches both classes per subview and discards the results.
        (void)[subview class];
        (void)[RBMusicCell class];
    }
}

#pragma mark - Private helpers

- (void)layoutPagingBackground {
    self.backgroundScrollView.frame = self.bounds;
    // One image view per background page plus the two wrap-around pages.
    self.backgroundScrollView.contentSize =
        CGSizeMake(self.width * static_cast<double>((self.backgroundImageCount + 2)), self.height);

    int page = 0;
    for (UIView *subview in self.backgroundScrollView.subviews) {
        if ([subview class] == [UIImageView class]) {
            UIImageView *imageView = static_cast<UIImageView *>(subview);
            CGFloat scaledHeight =
                self.width / imageView.image.size.width * imageView.image.size.height;
            if (imageView.image.size.width <= imageView.image.size.height) {
                imageView.frame =
                    CGRectMake(static_cast<double>(page) * self.width, 0, self.width, scaledHeight);
            } else {
                imageView.frame = CGRectMake(static_cast<double>(page) * self.width,
                                             self.height * kBackgroundVerticalOffsetFactor,
                                             self.width,
                                             scaledHeight);
            }
            ++page;
        }
    }
}

- (void)layoutSearchBarActive:(BOOL)active {
    if (active) {
        // Show layout: dock the search bar at the top strip.
        self.searchBar.frame =
            CGRectMake(0, 0, self.searchBar.frame.size.width, self.searchBar.frame.size.height);
        CGRect cancelFrame = self.searchCancelButton.frame;
        self.searchCancelButton.frame = CGRectMake(
            self.searchBar.frame.size.width, 0, cancelFrame.size.width, cancelFrame.size.height);
        if ([RBUserSettingData sharedInstance].thema == kThemaPastel) {
            CGSize mascotSize = [self.searchMascotImages[0] size];
            self.searchMascot.frame =
                CGRectMake(self.width - mascotSize.width,
                           self.searchPastelPosBaseY + mascotSize.height * kPageSnapMidpoint,
                           mascotSize.width,
                           mascotSize.height);
            self.searchMascot.alpha = kAlphaOpaque;
        }
        self.mascot.alpha = kAlphaHidden;
    } else {
        // Hide layout: park the search bar off-screen above the top edge.
        self.searchBar.frame = CGRectMake(0,
                                          -self.searchBar.frame.size.height,
                                          self.searchBar.frame.size.width,
                                          self.searchBar.frame.size.height);
        CGRect cancelFrame = self.searchCancelButton.frame;
        self.searchCancelButton.frame = CGRectMake(self.searchBar.frame.size.width,
                                                   -cancelFrame.size.height,
                                                   cancelFrame.size.width,
                                                   cancelFrame.size.height);
        if ([RBUserSettingData sharedInstance].thema == kThemaPastel) {
            self.searchMascot.alpha = kAlphaHidden;
        }
        self.mascot.alpha = kAlphaOpaque;
    }
}

- (void)shiftMenuButtonsForPlaylistEditEntering:(BOOL)entering {
    CGFloat delta = self.height - self.pageLabel.y;
    CGFloat down = entering ? delta : -delta;

    // These controls slide down when entering edit mode and back up when leaving. The random
    // information badge is only repositioned on the way in, matching the binary's two blocks.
    NSMutableArray<UIView *> *shiftDown = [NSMutableArray arrayWithObjects:self.settingButton,
                                                                           self.rankButton,
                                                                           self.storeButton,
                                                                           self.storeInfoView,
                                                                           self.playListButton,
                                                                           self.playlistInfoView,
                                                                           self.randomButton,
                                                                           nil];
    if (entering) {
        [shiftDown addObject:self.randomInfoView];
    }
    for (UIView *view in shiftDown) {
        view.frame = CGRectMake(view.x, view.y + down, view.width, view.height);
    }

    // The playlist add, delete, and finish controls move the opposite way.
    UIView *shiftUp[] = {self.playlistAddButton, self.playlistDelButton, self.playlistFinButton};
    for (NSUInteger i = 0; i < sizeof(shiftUp) / sizeof(shiftUp[0]); ++i) {
        UIView *view = shiftUp[i];
        view.frame = CGRectMake(view.x, view.y - down, view.width, view.height);
    }
}

- (void)setSearchMascotsHidden:(BOOL)hidden {
    CGFloat alpha = hidden ? kAlphaHidden : kAlphaOpaque;
    self.searchMascot.alpha = alpha;
    self.mascot.alpha = alpha;
}

- (void)handleTermsVersionResponse {
    // Walk the terms list; for the current terms record, compare the accepted version against the
    // server version and either prompt to re-accept the updated terms or proceed to the store.
    NSArray *list = [self.termDownloader getDataInJSON][kTermsKeyList];
    __weak RBMenuView *weakSelf = self;
    for (NSDictionary *entry in list) {
        if ([entry[kTermsKeyType] integerValue] != kTermsRecordTypeCurrent) {
            continue;
        }
        NSString *accepted = [RBUserSettingData sharedInstance].termVersion;
        NSComparisonResult order = [accepted compare:entry[kTermsKeyVersion]
                                             options:NSNumericSearch];
        if (order == NSOrderedAscending) {
            dispatch_async(dispatch_get_main_queue(), ^{
              /** @ghidraAddress HandleShowTermsForUpdate */
              [weakSelf showTermView];
            });
        } else {
            dispatch_async(dispatch_get_main_queue(), ^{
              /** @ghidraAddress HandleStoreOpenAfterTerms */
              [weakSelf StoreOpen];
            });
        }
    }
}

- (void)handleTermsNetworkError {
    __weak RBMenuView *weakSelf = self;
    dispatch_async(dispatch_get_main_queue(), ^{
      /** @ghidraAddress HandleShowNetworkErrorWithDelegate */
      [[AppDelegate appDelegate] showNetworkErrorAlertWithDelegate:weakSelf];
    });
}

@end
