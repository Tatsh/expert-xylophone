#import "RBMenuView.h"

#import "AppDelegate.h"
#import "AudioManager.h"
#import "Downloader.h"
#import "MusicData.h"
#import "NetworkUtil.h"
#import "RBApplilinkView.h"
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
#import "RBMusicCell.h"
#import "RBMusicGridLayout.h"
#import "RBMusicManager.h"
#import "RBMusicSearchExpander.h"
#import "RBMusicView.h"
#import "RBNavigationController.h"
#import "RBNewsHUDView.h"
#import "RBNotificationPagePhoneViewController.h"
#import "RBNotificationPageView.h"
#import "RBPlaylistManager.h"
#import "RBPushNotificationView.h"
#import "RBRankingView.h"
#import "RBSearchMapViewController.h"
#import "RBSearchView.h"
#import "RBSettingView.h"
#import "RBStoreTabController.h"
#import "RBTermAgreeView.h"
#import "RBTermPhoneViewController.h"
#import "RBTermView.h"
#import "RBThemaView.h"
#import "RBTutorialManager.h"
#import "RBUserSettingData.h"
#import "RBViewController.h"
#import "ScoreData.h"
#import "UIImage+RB.h"
#import "UIImageView+RB.h"
#import "UIView+RB.h"
#import "deviceenvironment.h"
#import "engineglobals.h"
#import "gamesystem.h"
#import "soundeffectmanager.h"

enum {
    kPlaylistIDNone = 0,
    kPlaylistIDHotBonus = 1,
    kPlaylistIDLevel = 2,
    kPlaylistIDCustom = 3,
    kPlaylistIDSpecial = 4,
};

enum {
    kMenuModePlaylistAdd = 0,
    kMenuModePlaylistDelete = 1,
    kMenuModePlaylistFinished = 2,
};

constexpr UIViewAutoresizing kAutoresizingFull =
    UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleWidth |
    UIViewAutoresizingFlexibleRightMargin | UIViewAutoresizingFlexibleTopMargin |
    UIViewAutoresizingFlexibleHeight | UIViewAutoresizingFlexibleBottomMargin;

// The customize walkthrough checks the completion flag (0x22) but records its entry step (0x18)
// as seen.
static const int kTutorialStatusMusicSelect = 0x17;
static const int kTutorialStatusCustomize = 0x22;
static const int kTutorialStatusCustomizeStarted = 0x18;

static const NSUInteger kTutorialTypeMusicSelect = 0;
static const NSUInteger kTutorialTypeMusicFullScreen = 4;
static const NSUInteger kTutorialTypeCustomize = 0x18;
static const NSUInteger kTutorialTypeUnlock = 0x1d;
static const NSUInteger kTutorialTypeMenuHide = 10;

static const int kMenuItemSortArtist = 1;

static const int kSoundEffectDecide = 3;
static const long kSoundEffectSearchBarShow = 0x11;
static const long kSoundEffectSearchBarHide = 0x12;

static const NSTimeInterval kArtworkFadeInDuration = 0.3; // @ghidraAddress 0x2ec718

static const int kSearchMascotDefaultBias = 90;
static const float kSearchPushNotificationOverlapFactor = -0.9f;

static const CGFloat kAlphaHidden = 0.0;
static const CGFloat kAlphaOpaque = 1.0;
static const CGFloat kCoverFadeDuration = 0.5;
static const CGFloat kArtworkFadeInStartAlpha = 0.0;

static const int64_t kShowAnimationDelayNanos = 500000000;
static const NSTimeInterval kPlaylistEditAnimationDuration = 0.5;
static const NSTimeInterval kPlaylistEditAnimationDelay = 0.0;

static const float kPageSnapLowFraction = 0.3f;
static const float kPageSnapHighFraction = 0.7f;
static const float kPageSnapMidpoint = 0.5f;
static const CGFloat kBackgroundVerticalOffsetFactor = -0.4;

static const NSTimeInterval kNewsGetTimeOffset = 0.0;
static const NSTimeInterval kNewsCacheValiditySeconds = -300.0; // Fresh if fetched < 5 min ago.
static const NSTimeInterval kNewsBannerDefaultInterval = 10.8;
static const CGFloat kNewsTickerDuration = 10.7;
static const CGFloat kNewsHUDCenterScale = 0.5;
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

static NSString *const kTermsRequestKeyTarget = @"target";
static NSString *const kTermsRequestContentType = @"application/json";
static NSString *const kTermsKeyList = @"list";
static NSString *const kTermsKeyType = @"type";
static NSString *const kTermsKeyVersion = @"version";
static const NSInteger kTermsRecordTypeCurrent = 1;

static const float kSearchPastelPosBaseYWide = 85.0f;
static const float kSearchPastelPosBaseYTall = 140.0f;

static const CGFloat kSettingAnchorOffsetX = -102.0;
static const CGFloat kSettingAnchorOffsetY = -24.0;
static const CGFloat kSettingAnchorWidth = 204.0;
static const CGFloat kSettingAnchorHeight = 48.0;

static NSString *const kTutorialPlaceholderMusicName = @"威風堂々";

static const UIViewAutoresizing kBackgroundAutoresizingMask =
    UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
// @ghidraAddress 0x310450
static const UIViewAutoresizing kCampaignScrollAllFlexibleMask =
    UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleWidth |
    UIViewAutoresizingFlexibleRightMargin | UIViewAutoresizingFlexibleTopMargin |
    UIViewAutoresizingFlexibleHeight | UIViewAutoresizingFlexibleBottomMargin;

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

static NSString *const kTextureBackgroundName = @"00_texture/sel_bg";
static NSString *const kHeaderImageName = @"01_music_select/sel_header";
static NSString *const kFooterImageName = @"01_music_select/sel_footer";
static NSString *const kPlaylistImageName = @"01_music_select/sel_playlist";
static NSString *const kPlaylistSelImageName = @"01_music_select/sel_playlist_sel";
static NSString *const kRandomImageName = @"01_music_select/sel_random";
static NSString *const kRandomSelImageName = @"01_music_select/sel_random_sel";
static NSString *const kInfoPlaylistName = @"11_info/info_playlist";
static NSString *const kInfoRandomName = @"11_info/info_random";
static NSString *const kInfoNewName = @"11_info/info_new";
static NSString *const kSearchBackgroundName = @"01_music_select/search_bg";
static NSString *const kSearchMascotDefaultPrefix = @"01_music_select/search_mascot_";
static NSString *const kSearchCancelImageNameWide = @"01_music_select/search_cancel_btn_pn2";
static NSString *const kSearchCancelImageNameTall = @"01_music_select/search_cancel_btn";

// In these names "Pastel" is the Colette theme and "White" is Limelight; the "wide" set applies
// when the iPad idiom flag is clear and the "tall" set when it is set.
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
// @ghidraAddress 0x300ff8
static const CGFloat kLayoutWideCollectionHeight = 797.0;

static const CGFloat kLayoutTallBoundsInset8 = -8.0;
static const CGFloat kLayoutTallBoundsInset16 = -16.0;
static const CGFloat kLayoutTallHeightExtra60 = -60.0; // @0x100300fc8
static const CGFloat kLayoutTallHeightExtra64 = -64.0; // @0x100300fc0
static const CGFloat kLayoutTallThemaClassicFooterYExtra = 7.0;
static const CGFloat kLayoutTallThemaCampaignFooterYExtra = 6.0;
static const CGFloat kLayoutTallThemaWhiteFooterYExtra = 4.0;

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

static const int kLayoutSideButtonSizeWide = 0x2c;
static const int kLayoutSideButtonSizeTall = 0x1e;
static const int kLayoutWideCampaignHorizontalMargin = 0x28;

static const CGFloat kLayoutWideThemaClassicSettingX = 20.0;
// @ghidraAddress 0xa2e20
static const CGFloat kLayoutWideWhiteCollectionOriginX = 22.0;

static const CGFloat kLayoutTallRowHalfHeightFactor = -0.5;
static const CGFloat kLayoutTallRowBaseBias = -4.0;
static const CGFloat kLayoutTallCol2BiasClassic = -4.0;
static const CGFloat kLayoutTallCol2BiasWhite = -12.0;
static const int kLayoutTallPlaylistXBiasClassic = -11;
static const int kLayoutTallPlaylistXBiasWhite = -3;
static const int kLayoutTallRandomXBias = -15;
static const int kLayoutTallBaseInsetPastel = -2;
static const CGFloat kLayoutTallWhiteStoreInfoInset = -3.0;
static const CGFloat kLayoutTallWhiteWidthExtra = -22.0;
// @ghidraAddress 0xa2f50
static const CGFloat kLayoutTallWhiteCollectionOriginXExtra = 3.0;
static const CGFloat kLayoutTallSettingXClassicPastel = 4.0;
static const CGFloat kLayoutTallSettingXWhite = 12.0;

static BOOL g_bRandamIntSeeded = NO;

// The binary passes self as both delegates, but neither protocol appears in the class's public
// conformance list.
@interface RBMenuView () <UIAlertViewDelegate, RBMenuPageSliderDelegate>

/** Build the tall-layout header and the theme 0/1 footer. */
- (void)buildHeaderAndFooter:(NSInteger)thema;
/** Build the campaign paging background; returns whether the effect view was used. */
- (BOOL)buildCampaignBackground:(BOOL)isPad;
/** Build the button bar, grid, mascot, search UI, news ticker, cover, and gestures. */
- (void)buildMenuBarWithThema:(NSInteger)thema
                        isPad:(BOOL)isPad
     backgroundUsesEffectView:(BOOL)bgUsesEffectView;
/** Re-lay the wrapping paging background scroll view and its image pages. */
- (void)layoutPagingBackground;
/** Lay out the search bar, cancel button, and Colette mascot for the search state. */
- (void)layoutSearchBarActive:(BOOL)active;
/** Slide the menu buttons to reveal or hide the playlist-edit controls. */
- (void)shiftMenuButtonsForPlaylistEditEntering:(BOOL)entering;

@end

@implementation RBMenuView

#pragma mark - Rotation

- (void)willRotate {
    self.prevIndex = 0;
    [self debugAlphaLog];
    if (self.currentPageIndex != 0) {
        // didRotate restores the equivalent page from this item once the geometry changes.
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
                       /** @ghidraAddress 0xa1cfc */
                       [self debugAlphaLog];
                       self.collectionView.alpha = kAlphaOpaque;
                       [self debugAlphaLog];
                       if (self.backgroundScrollView != nil) {
                           self.backgroundScrollView.alpha = kAlphaOpaque;
                       }
                     }];

    if (self.backgroundScrollView != nil && !IsPad()) {
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
    BOOL isPad = IsPad();
    CGSize bounds = self.bounds.size;

    int footerY = 0;
    int menuButtonWidth = 0;
    int settingRowY = 0;
    int playlistRowY = 0;
    int col1 = 0, col2 = 0;
    int playlistX = 0, randomX = 0;
    int pageLabelInnerY = 0;
    int sideButtonSize = kLayoutSideButtonSizeTall;
    CGFloat settingColX = 0.0;
    CGFloat collectionOriginX = 0.0;
    CGFloat collectionOriginY = 0.0;
    // Zero means keep the size the view was built with.
    CGFloat collectionHeight = 0.0;
    CGFloat collectionWidth = 0.0;
    CGFloat sideButtonRowY = 0.0;
    CGFloat storeInfoInsetWidth = 0.0;
    int editMode = self.playListEditMode;

    if (isPad) {
        if (thema == RBUserSettingDataThemeClassic) {
            footerY = static_cast<int>((bounds.height - self.footerView.frame.size.height));
            menuButtonWidth =
                static_cast<int>((bounds.width + kLayoutWideThemaClassicWidthDelta)) / 3;
            if (editMode == kMenuModePlaylistFinished) {
                playlistRowY = static_cast<int>((self.height + kLayoutWideThemaClassicHeightDelta +
                                                 kLayoutWideThemaClassicFooterEdit));
                sideButtonRowY = kLayoutWideThemaClassicCol0;
                settingRowY = kLayoutWideThemaClassicPlaylistFinX;
            } else {
                sideButtonRowY =
                    static_cast<int>((self.height + kLayoutWideThemaClassicHeightDelta +
                                      kLayoutWideThemaClassicFooterNormal));
                settingRowY = static_cast<int>((self.height + kLayoutWideThemaClassicHeightDelta +
                                                kLayoutWideThemaClassicFooterEdit));
                playlistRowY = kLayoutWideThemaClassicPlaylistFinX;
            }
            settingColX = kLayoutWideThemaClassicSettingX;
            col1 = kLayoutWideThemaClassicCol1;
            col2 = kLayoutWideThemaClassicCol2;
            playlistX = kLayoutWideThemaClassicPlaylistX;
            randomX = kLayoutWideThemaClassicRandomX;
            pageLabelInnerY = kLayoutWideThemaClassicCol0;
            collectionOriginX = 0.0;
            collectionOriginY = kLayoutWideCollectionOriginY;
            collectionWidth = bounds.width;
            collectionHeight = kLayoutWideCollectionHeight;
            storeInfoInsetWidth = bounds.width;
            sideButtonSize = kLayoutSideButtonSizeWide;
        } else if (thema == RBUserSettingDataThemeColette) {
            menuButtonWidth =
                (static_cast<int>((bounds.width + kLayoutWideThemaCampaignWidthDelta)) -
                 kLayoutWideCampaignHorizontalMargin) /
                3;
            if (editMode == kMenuModePlaylistFinished) {
                playlistRowY = static_cast<int>((self.height + kLayoutWideThemaCampaignHeightDelta +
                                                 kLayoutWideThemaCampaignFooterEdit));
                sideButtonRowY = kLayoutWideThemaOtherCol0;
                settingRowY = kLayoutWideThemaOtherPlaylistFinX;
            } else {
                sideButtonRowY =
                    static_cast<int>((self.height + kLayoutWideThemaCampaignHeightDelta +
                                      kLayoutWideThemaCampaignFooterNormal));
                settingRowY = static_cast<int>((self.height + kLayoutWideThemaCampaignHeightDelta +
                                                kLayoutWideThemaCampaignFooterEdit));
                playlistRowY = kLayoutWideThemaOtherPlaylistFinX;
            }
            col1 = kLayoutWideThemaOtherCol1;
            col2 = kLayoutWideThemaOtherCol2;
            playlistX = kLayoutWideThemaOtherPlaylistX;
            randomX = kLayoutWideThemaOtherRandomX;
            settingColX = kLayoutWidePastelWhiteSettingX;
            pageLabelInnerY = kLayoutWideThemaOtherCol0;
            collectionOriginX = 0.0;
            collectionOriginY = kLayoutWideCollectionOriginY;
            collectionWidth = bounds.width;
            collectionHeight = kLayoutWideCollectionHeight;
            storeInfoInsetWidth = bounds.width;
            sideButtonSize = kLayoutSideButtonSizeWide;
        } else if (thema == RBUserSettingDataThemeLimelight) {
            menuButtonWidth =
                (static_cast<int>((bounds.width + kLayoutWideThemaCampaignWidthDelta)) -
                 kLayoutWideCampaignHorizontalMargin) /
                3;
            if (editMode == kMenuModePlaylistFinished) {
                playlistRowY = static_cast<int>((self.height + kLayoutWideThemaCampaignHeightDelta +
                                                 kLayoutWideThemaCampaignFooterEdit));
                sideButtonRowY = kLayoutWideThemaOtherCol0;
                settingRowY = kLayoutWideThemaOtherPlaylistFinX;
            } else {
                sideButtonRowY =
                    static_cast<int>((self.height + kLayoutWideThemaCampaignHeightDelta +
                                      kLayoutWideThemaCampaignFooterNormal));
                settingRowY = static_cast<int>((self.height + kLayoutWideThemaCampaignHeightDelta +
                                                kLayoutWideThemaCampaignFooterEdit));
                playlistRowY = kLayoutWideThemaOtherPlaylistFinX;
            }
            settingColX = kLayoutWidePastelWhiteSettingX;
            col1 = kLayoutWideThemaOtherCol1;
            col2 = kLayoutWideThemaOtherCol2;
            playlistX = kLayoutWideThemaOtherPlaylistX;
            randomX = kLayoutWideThemaOtherRandomX;
            pageLabelInnerY = kLayoutWideThemaOtherCol0;
            collectionOriginX = kLayoutWideWhiteCollectionOriginX;
            collectionWidth = bounds.width - kLayoutWideWhiteCollectionOriginX;
            collectionHeight = kLayoutWideCollectionHeight;
            collectionOriginY = kLayoutWideCollectionOriginY;
            storeInfoInsetWidth = bounds.width + kLayoutTallWhiteWidthExtra;
            sideButtonSize = kLayoutSideButtonSizeWide;
        }
    } else {
        if (thema == RBUserSettingDataThemeClassic || thema == RBUserSettingDataThemeColette) {
            int base;
            int rowBase;
            if (thema == RBUserSettingDataThemeClassic) {
                footerY = static_cast<int>(((bounds.height - self.footerView.frame.size.height) +
                                            kLayoutTallThemaClassicFooterYExtra));
                base = static_cast<int>((bounds.width + kLayoutTallBoundsInset8));
                rowBase = static_cast<int>((bounds.height + kLayoutTallHeightExtra60));
                settingColX = kLayoutTallSettingXClassicPastel;
                collectionOriginX = 0.0;
            } else {
                footerY = 0; // The tall Colette theme has no footer.
                base = static_cast<int>((bounds.width + kLayoutTallBoundsInset8)) +
                       kLayoutTallBaseInsetPastel;
                rowBase = static_cast<int>((bounds.height + kLayoutTallHeightExtra64 +
                                            kLayoutTallThemaCampaignFooterYExtra));
                settingColX = kLayoutTallSettingXClassicPastel;
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
        } else if (thema == RBUserSettingDataThemeLimelight) {
            // The tall Limelight theme fills the footer slot from CreateView, not here.
            footerY = 0;
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
            settingColX = kLayoutTallSettingXWhite;
            collectionOriginX = kLayoutTallWhiteCollectionOriginXExtra;
            collectionOriginY = 0.0;
            storeInfoInsetWidth = bounds.width + kLayoutTallWhiteStoreInfoInset;
            sideButtonSize = kLayoutSideButtonSizeTall;
        }
    }

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
    self.collectionView.frame = CGRectMake(
        collectionOriginX,
        collectionOriginY,
        collectionWidth > 0.0 ? collectionWidth : self.collectionView.frame.size.width,
        collectionHeight > 0.0 ? collectionHeight : self.collectionView.frame.size.height);

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

    self.searchBar.frame = CGRectMake(0,
                                      self.searchBar.frame.origin.y,
                                      bounds.width - self.searchCancelButton.frame.size.width,
                                      self.searchBar.frame.size.height);
    self.searchCancelButton.frame =
        CGRectMake(bounds.width - self.searchCancelButton.frame.size.width,
                   self.searchCancelButton.frame.origin.y,
                   self.searchCancelButton.frame.size.width,
                   self.searchCancelButton.frame.size.height);

    if ([RBUserSettingData sharedInstance].thema == RBUserSettingDataThemeColette &&
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

    if (!isPad) {
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
    if (self.currentPageIndex == currentPageIndex) {
        return;
    }
    _currentPageIndex = currentPageIndex;
    self.pageLabel.text =
        [NSString stringWithFormat:@"%zd / %zd", self.currentPageIndex + 1, self.maxPage];
}

- (void)setMaxPage:(NSInteger)maxPage {
    _maxPage = (maxPage != 0) ? maxPage : 1;
    self.pageLabel.text =
        [NSString stringWithFormat:@"%zd / %zd", self.currentPageIndex + 1, self.maxPage];
}

- (void)setShowView:(UIView *)showView {
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
        self.searchPastelPosBaseY =
            (!IsPad()) ? kSearchPastelPosBaseYWide : kSearchPastelPosBaseYTall;
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
    BOOL isPad = IsPad();
    BOOL bgUsesEffectView = NO;

    if (thema == RBUserSettingDataThemeColette) {
        self.backgroundColor = UIColor.whiteColor;
        if ([[RBCampaignData sharedInstance] isCampaignHinabita201703]) {
            bgUsesEffectView = [self buildCampaignBackground:isPad];
        } else if (isPad) {
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
        if (thema == RBUserSettingDataThemeClassic) {
            self.backgroundColor = UIColor.blackColor;
        } else if (thema == RBUserSettingDataThemeLimelight) {
            self.backgroundColor = UIColor.whiteColor;
        }
        UIImage *bgImage = [UIImage imageWithName:kTextureBackgroundName];
        self.backgroundView = [[UIImageView alloc] initWithImage:bgImage];
        self.backgroundView.frame = self.bounds;
        self.backgroundView.autoresizingMask = kBackgroundAutoresizingMask;
        self.backgroundView.contentMode = UIViewContentModeCenter;
        [self addSubview:self.backgroundView];
    }

    if (isPad) {
        [self buildHeaderAndFooter:thema];
    } else if (thema == RBUserSettingDataThemeClassic) {
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
    } else if (thema == RBUserSettingDataThemeLimelight) {
        self.footerView =
            [[UIImageView alloc] initWithImage:[UIImage imageWithName:kFooterImageName]];
        self.footerView.frame = CGRectMake(0, 0, 0, kFooterLightWideHeight);
        self.footerView.autoresizingMask =
            UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleBottomMargin;
        [self addSubview:self.footerView];
    }

    [self buildMenuBarWithThema:thema isPad:isPad backgroundUsesEffectView:bgUsesEffectView];
}

- (void)buildHeaderAndFooter:(NSInteger)thema {
    /** @ghidraAddress 0xa5040 */
    self.headerView = [[UIImageView alloc] initWithImage:[UIImage imageWithName:kHeaderImageName]];
    self.headerView.frame =
        CGRectMake(0, 0, self.frame.size.width, self.headerView.frame.size.height);
    [self addSubview:self.headerView];

    if (thema > RBUserSettingDataThemeLimelight) {
        return; // The Colette theme has no footer in the tall layout.
    }

    self.footerView = [[UIImageView alloc] initWithImage:[UIImage imageWithName:kFooterImageName]];
    if (thema == RBUserSettingDataThemeClassic) {
        self.footerView.frame =
            CGRectMake(0,
                       self.bounds.size.height - self.footerView.bounds.size.height,
                       self.frame.size.width,
                       self.footerView.frame.size.height);
    } else if (thema == RBUserSettingDataThemeLimelight) {
        self.footerView.frame = CGRectMake(0, 0, self.frame.size.width, kFooterLightTallHeight);
    }
    [self addSubview:self.footerView];
}

- (BOOL)buildCampaignBackground:(BOOL)isPad {
    /** @ghidraAddress 0xa4f58 */
    NSMutableArray *images = [NSMutableArray array];
    for (int i = 1; i <= kCampaignBackgroundMaxImages; ++i) {
        NSString *name = [NSString stringWithFormat:@"%@/%@%d",
                                                    [RBCampaignData sharedInstance].campaignName,
                                                    kTextureBackgroundName,
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
        isPad ? kCampaignScrollAllFlexibleMask : UIViewAutoresizingFlexibleWidth;
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
        if (isPad) {
            imageView.frame = CGRectMake(
                static_cast<int>(page) * pageWidth, 0, image.size.width, image.size.height);
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
    return YES;
}

- (void)buildMenuBarWithThema:(NSInteger)thema
                        isPad:(BOOL)isPad
     backgroundUsesEffectView:(BOOL)bgUsesEffectView {
    /** @ghidraAddress 0xa5380 */
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
    // No touch target here; the playlist-edit toggle comes from the collection view's long press.
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
                       forState:UIControlStateHighlighted];
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
        [UIFont systemFontOfSize:(isPad ? kPageLabelFontTall : kPageLabelFontWide)];
    if (thema == RBUserSettingDataThemeClassic) {
        self.pageLabel.textColor = UIColor.whiteColor;
    } else if (thema == RBUserSettingDataThemeLimelight) {
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

    if (thema == RBUserSettingDataThemeClassic) {
        [self bringSubviewToFront:self.footerView];
    }

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

    UISwipeGestureRecognizer *showSearch =
        [[UISwipeGestureRecognizer alloc] initWithTarget:self action:@selector(showSearchBar)];
    showSearch.numberOfTouchesRequired = 1;
    showSearch.delegate = self;
    showSearch.direction = UISwipeGestureRecognizerDirectionDown;
    [self addGestureRecognizer:showSearch];

    UISwipeGestureRecognizer *hideSearch =
        [[UISwipeGestureRecognizer alloc] initWithTarget:self action:@selector(hideSearchBar)];
    hideSearch.numberOfTouchesRequired = 1;
    hideSearch.delegate = self;
    hideSearch.direction = UISwipeGestureRecognizerDirectionUp;
    [self addGestureRecognizer:hideSearch];

    CGFloat cancelWidth = (IsPad()) ? kSearchCancelWidthTall : kSearchCancelWidthWide;
    self.searchCancelButton = [UIButton buttonWithType:UIButtonTypeCustom];
    self.searchCancelButton.frame = CGRectMake(
        self.frame.size.width - cancelWidth, kSearchBarOriginY, cancelWidth, kSearchBarHeight);
    NSString *cancelName = (!IsPad()) ? kSearchCancelImageNameWide : kSearchCancelImageNameTall;
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
    self.searchBar.backgroundColor = UIColor.whiteColor;
    self.searchBar.barStyle = UIBarStyleDefault;
    self.searchBar.keyboardType = UIKeyboardTypeDefault;
    [self.searchBar setBackgroundImage:[UIImage imageWithName:kSearchBackgroundName]];
    self.searchBar.placeholder = g_pLocalizedSearchMusic;
#ifdef ENABLE_PATCHES
    // iOS 13 moved the search bar's editable field into a UISearchTextField, so the binary's
    // -setBackgroundColor: no longer reaches it and the field renders grey.
    if (@available(iOS 13.0, *)) {
        self.searchBar.searchTextField.backgroundColor = UIColor.whiteColor;
    }
#endif
    self.backUpString = @"";
    [self addSubview:self.searchBar];
    [self addSubview:self.searchCancelButton];

    if (self.searchArray == nil) {
        self.searchArray = [[NSMutableArray alloc] init];
    }

    if ([RBUserSettingData sharedInstance].thema == RBUserSettingDataThemeColette) {
        NSString *mascotPrefix = kSearchMascotDefaultPrefix;
        if ([[RBCampaignData sharedInstance] isCampaignHinabita201703]) {
            mascotPrefix = [NSString stringWithFormat:@"%@/%@",
                                                      [RBCampaignData sharedInstance].campaignName,
                                                      kSearchMascotDefaultPrefix];
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
    SoundEffectManager::GetInstance()->LoadThemedVoiceData(1);
    self.userInteractionEnabled = NO;
    self.hidden = NO;
    [self reloadMusicData];
    self.coverView.hidden = NO;
    self.coverView.alpha = kAlphaOpaque;
    [self.coverView SetAlphaAnimationDuration:kCoverFadeDuration End:0];
    [self startBGEffect];

    __weak RBMenuView *weakSelf = self;
    dispatch_after(
        dispatch_time(DISPATCH_TIME_NOW, kShowAnimationDelayNanos), dispatch_get_main_queue(), ^{
          /** @ghidraAddress 0xaa4f8 */
          [weakSelf.showAnimationTimer invalidate];
          weakSelf.showAnimationTimer = nil;
          [weakSelf.coverView RemoveAlphaAnimation];
          weakSelf.coverView.hidden = YES;
          weakSelf.userInteractionEnabled = YES;
          [weakSelf startNews];

          if (![[RBBGMManager getInstance] PlayMusic:1.5]) {
              [weakSelf performSelector:@selector(ReplayMusic)
                             withObject:nil
                             afterDelay:g_dMascotMoveAnimDuration];
          }
          SoundEffectManager::GetInstance()->PlayThemedVoice(1);
          [weakSelf showInfomation];

          if ([RBUserSettingData sharedInstance].thema == RBUserSettingDataThemeColette &&
              ([RBTutorialManager needStartTutorialMusicselect] ||
               [RBTutorialManager needStartTutorialCustomize])) {
              [weakSelf startTutorial];
          } else if ([[AppDelegate appDelegate] getPackIDForOpenStore] != nil ||
                     [[AppDelegate appDelegate] getCampaignIDForOpenStore] != nil ||
                     [[AppDelegate appDelegate] getExtendNotePIDForOpenStore] != nil) {
              [weakSelf SelectStoreButton];
          } else if ([AppDelegate getPushNotificationData] != nil &&
                     [AppDelegate getPushNotificationData].count != 0) {
              [weakSelf showPushNotificationView];
          } else if ([[AppDelegate appDelegate] getWebInfoURL] != nil) {
              [weakSelf showNotificationPageView];
          }
        });
}

- (void)ReplayMusic {
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
    GameSystem::GetGameSystem()->SetMenuTutorialActive(false);

    if (self.tutorialView != nil && [RBTutorialManager isTutorialMusicselect]) {
        [self.tutorialView startTutorialWithType:kTutorialTypeMenuHide withAnimation:YES];
        [self.tutorialView hideAnimation];
        GameSystem::GetGameSystem()->SetMenuTutorialActive(true);
    }

    [self.coverView SetAlphaAnimationDuration:kCoverFadeDuration End:1];

    __weak RBMenuView *weakSelf = self;
    dispatch_after(
        dispatch_time(DISPATCH_TIME_NOW, kShowAnimationDelayNanos), dispatch_get_main_queue(), ^{
          /** @ghidraAddress 0xaae24 */
          hideAnimation(); // The binary invokes the captured block with no nil guard.
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

- (void)selectMusic:(MusicData *)selectMusic animated:(BOOL)animated {
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
        [self.tutorialView startTutorialWithType:kTutorialTypeMusicFullScreen
                                    withRootView:self.selectedView];
    }
    [self.selectedView showAnimation:animated];
    SoundEffectManager::GetInstance()->PlayThemedSoundEffect(0);
}

- (int)getRandamInt:(int)getRandamInt max:(int)max {
    if (!g_bRandamIntSeeded) {
        srand(static_cast<unsigned int>(time(nullptr)));
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
    MusicData *music = self.musicList[index];
    self.selectedView.isRandom = YES;
    // A tag of 1 (from the random button) means animate the selection.
    [self selectMusic:music animated:([selectRandom tag] == 1)];
    self.selectedView.isRandom = YES;
    self.selectedView.randomButton.frame = self.randomButton.frame;
    if (IsPad()) {
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

    NSMutableArray *searchResult;
    if (self.searchBar != nil && self.searchArray.count != 0) {
        searchResult = [[NSMutableArray alloc] init];
        for (MusicData *music in musics) {
            if ([self matchTitle:music]) {
                [searchResult addObject:music];
            }
        }
    } else {
        searchResult = [musics mutableCopy];
    }

    // @ghidraAddress 0xa939c
    SEL sortSelector = ([RBUserSettingData sharedInstance].menuItemSort == 1) ?
                           @selector(compareArtistNameCustom:) :
                           @selector(compareMusicNameCustom:);

    NSInteger playlistID = [RBUserSettingData sharedInstance].playlistID;
    if (playlistID == kPlaylistIDNone) {
        [searchResult sortUsingSelector:sortSelector];
        self.musicList = searchResult;
        return;
    }

    if (playlistID == kPlaylistIDHotBonus) {
        NSMutableArray *filtered = [NSMutableArray arrayWithArray:searchResult];
        NSMutableArray *ids = [NSMutableArray array];
        for (MusicData *music in searchResult) {
            [ids addObject:@(music.MusicID)];
        }
        if (ids.count != 0) {
            NSManagedObjectContext *context =
                [RBCoreDataManager sharedInstance].managedObjectContext;
            NSArray *scores = [ScoreData getScoreDatas:ids inManagedObjectContext:context];
            for (MusicData *music in searchResult) {
                for (ScoreData *score in scores) {
                    if (music.MusicID == score.tuneID.intValue) {
                        if (score.pcBas.intValue != 0 || score.pcMed.intValue != 0 ||
                            score.pcHar.intValue != 0) {
                            [filtered removeObject:music];
                        }
                        break;
                    }
                }
            }
        }
        [filtered sortUsingSelector:sortSelector];
        self.musicList = filtered;
        return;
    }

    if (playlistID == kPlaylistIDLevel) {
        NSMutableArray *filtered = [NSMutableArray array];
        NSInteger level = [RBUserSettingData sharedInstance].playlistLevel;
        for (MusicData *music in searchResult) {
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
        NSInteger level = [RBUserSettingData sharedInstance].playlistLevel;
        NSDictionary *playlist = [[RBPlaylistManager sharedInstance] playlistAtIndex:level];
        NSArray *listIDs = playlist[@"LIST"];
        NSMutableArray *filtered = [NSMutableArray array];
        for (MusicData *music in searchResult) {
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

    if (playlistID == kPlaylistIDSpecial) {
        NSMutableArray *filtered = [NSMutableArray array];
        for (MusicData *music in searchResult) {
            if (music.spData != nil) {
                [filtered addObject:music];
            }
        }
        [filtered sortUsingSelector:sortSelector];
        self.musicList = filtered;
    }
    // A playlist id past the special list matches no branch, leaving the previous list in place.
}

#pragma mark - Store view controller

- (void)RemoveStoreViewController {
    self.storeViewController = nil;
    if ([[RBBGMManager getInstance] isPushMusic]) {
        // @ghidraAddress 0x2ec6b4
        [[RBBGMManager getInstance] StopMusic:0.2f];
        [[RBBGMManager getInstance] popMusic];
    }
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
        case RBUserSettingDataThemeLimelight:
            if (IsPad()) {
                CGPoint center = self.settingButton.center;
                buttonFrame = CGRectMake(center.x + kSettingAnchorOffsetX,
                                         self.settingButton.center.y + kSettingAnchorOffsetY,
                                         kSettingAnchorWidth,
                                         kSettingAnchorHeight);
                break;
            }
            buttonFrame = self.settingButton.frame;
            break;
        case RBUserSettingDataThemeClassic:
        case RBUserSettingDataThemeColette:
            buttonFrame = self.settingButton.frame;
            break;
        default:
            buttonFrame = CGRectZero;
            break;
        }
        RBSettingView *view = [[RBSettingView alloc] initWithFrame:self.bounds
                                                       ButtonFrame:buttonFrame];
        self.settingView = view;
        self.settingView.parentView = self;
        [self addSubview:self.settingView];
        [self addSubview:self.settingButton];
        [self addSubview:self.coverView];
        if ([[RBUserSettingData sharedInstance] getTutorialStatus:kTutorialStatusCustomize] == 0) {
            [[RBUserSettingData sharedInstance] updateTutorialStatus:kTutorialStatusCustomizeStarted
                                                               value:1];
        }
        [self.settingButton removeFlashEffect];
        [self.settingView OpenView];
    } else {
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
    view.autoresizingMask = kAutoresizingFull;
    [self addSubview:view];
    [view showAnimation];
    self.showView = view;
}

- (void)showCustomizeView {
    RBCustomView *view = [[RBCustomView alloc] initWithFrame:self.bounds];
    view.musicMenuView = self;
    view.autoresizingMask = kAutoresizingFull;
    [self addSubview:view];
    [view showAnimation];
    if ([[RBUserSettingData sharedInstance] getTutorialStatus:kTutorialStatusCustomize] == 0) {
        [self.tutorialView startTutorialWithType:kTutorialTypeUnlock withRootView:view];
        [[RBUserSettingData sharedInstance] updateTutorialStatus:kTutorialStatusCustomizeStarted
                                                           value:1];
    }
    self.showView = view;
}

- (void)showThema {
    RBThemaView *view = [[RBThemaView alloc] initWithFrame:self.bounds];
    view.musicMenuView = self;
    view.autoresizingMask = kAutoresizingFull;
    [self addSubview:view];
    [view showAnimation];
    self.showView = view;
}

- (void)showSearchView {
    if (!IsPad()) {
        self.mapViewController = [[RBSearchMapViewController alloc] init];
        [[[AppDelegate appDelegate] navigationController] pushViewController:self.mapViewController
                                                                    animated:YES];
    } else {
        RBSearchView *view = [[RBSearchView alloc] initWithFrame:self.bounds];
        view.musicMenuView = self;
        view.autoresizingMask = kAutoresizingFull;
        [self addSubview:view];
        [view showAnimation];
        self.showView = view;
    }
    [[AppDelegate appDelegate] setIsShowedMap:YES];
}

- (void)showCreditView {
    RBCreditsView *view = [[RBCreditsView alloc] initWithFrame:self.bounds];
    view.musicMenuView = self;
    view.autoresizingMask = kAutoresizingFull;
    [self addSubview:view];
    [view showAnimation];
    self.showView = view;
}

- (void)showNotificationPageView {
    if (!IsPad()) {
        self.webViewController = [[RBNotificationPagePhoneViewController alloc] init];
        [[[AppDelegate appDelegate] navigationController] pushViewController:self.webViewController
                                                                    animated:YES];
    } else {
        RBNotificationPageView *view = [[RBNotificationPageView alloc] initWithFrame:self.bounds];
        view.musicMenuView = self;
        view.autoresizingMask = kAutoresizingFull;
        [self addSubview:view];
        [view showAnimation];
        self.showView = view;
    }
}

- (void)showApplilinkView {
    RBApplilinkView *view = [[RBApplilinkView alloc] initWithFrame:self.bounds];
    view.musicMenuView = self;
    view.autoresizingMask = kAutoresizingFull;
    [self addSubview:view];
    [view showAnimation];
    self.showView = view;
}

- (void)showTermView {
    if (!IsPad()) {
        self.termViewController = [[RBTermPhoneViewController alloc] init];
        [[[AppDelegate appDelegate] navigationController] pushViewController:self.termViewController
                                                                    animated:YES];
    } else {
        RBTermView *view = [[RBTermView alloc] initWithFrame:self.bounds];
        view.musicMenuView = self;
        view.autoresizingMask = kAutoresizingFull;
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
    if ([RBUserSettingData sharedInstance].thema == RBUserSettingDataThemeColette) {
        if (self.bgEffectView != nil) {
            [self.bgEffectView startAnimation];
        }
        if (self.mascot != nil) {
            [self.mascot startAnimation:self.storeUpdateTime];
        }
    }
}

- (void)stopBGEffect {
    if ([RBUserSettingData sharedInstance].thema == RBUserSettingDataThemeColette) {
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
    SoundEffectManager::GetInstance()->PlayThemedSoundEffect(kSoundEffectDecide);
    RBRankingView *view = [[RBRankingView alloc] initWithFrame:self.bounds];
    view.autoresizingMask = kAutoresizingFull;
    [self addSubview:view];
    [view showAnimation];
    self.showView = view;
}

- (void)SelectStoreButton {
    [self setSearchBarNonActive];
    [self hideSettingView];
    [self releaseSelectMusic];
    if (!IsPad()) {
        [self.viewController dismissViewControllerAnimated:NO
                                                completion:^{
                                                }];
    } else {
        [self.viewController.playlistPopoverController dismissPopoverAnimated:NO];
    }
    if (!IsPad() && self.mapViewController != nil) {
        [self.mapViewController forceClose];
    }
    if (!IsPad() && self.webViewController != nil) {
        [self.webViewController forceClose];
    }
#ifdef ENABLE_PATCHES
    // The terms request below only compares versions and a patched build ignores the result, so
    // skipping it keeps the store reachable offline.
    [self StoreOpen];
    return;
#else
    NSDictionary *body = @{kTermsRequestKeyTarget : GetRegionCode()};
    NSData *postData = [Downloader dictionaryToJsonData:body];
    __weak RBMenuView *weakSelf = self;
    self.termDownloader = [[Downloader alloc] initWithURL:[NetworkUtil termList]
                                                     post:postData
                                              contentType:kTermsRequestContentType];
    [weakSelf.termDownloader
        startDownloadingWithProceed:^(Downloader *downloader) {
          /** @ghidraAddress 0x35c040 */
        }
        success:^(Downloader *downloader) {
          /** @ghidraAddress 0xad2c0 */
          for (NSDictionary *entry in [downloader getDataInJSON][kTermsKeyList]) {
              if ([entry[kTermsKeyType] integerValue] != 1) {
                  continue;
              }
              NSString *accepted = [RBUserSettingData sharedInstance].termVersion;
              if ([accepted compare:entry[kTermsKeyVersion]
                            options:NSNumericSearch] == NSOrderedAscending) {
                  dispatch_async(dispatch_get_main_queue(), ^{
                    /** @ghidraAddress 0xad6e4 */
                    [weakSelf.viewController showTermsWithDelegate:weakSelf];
                  });
              } else {
                  dispatch_async(dispatch_get_main_queue(), ^{
                    /** @ghidraAddress 0xad7a4 */
                    [weakSelf StoreOpen];
                  });
              }
          }
        }
        failure:^(Downloader *downloader) {
          /** @ghidraAddress 0xad844 */
          dispatch_async(dispatch_get_main_queue(), ^{
            /** @ghidraAddress 0xad8bc */
            [UIAlertView showNetworkErrorWithDelegate:weakSelf];
          });
        }];
#endif
}

- (void)StoreOpen {
    if (self.storeViewController == nil) {
        self.storeViewController = [[RBStoreTabController alloc] init];
        self.storeViewController.musicMenuView = self;
        SoundEffectManager::GetInstance()->PlayThemedSoundEffect(kSoundEffectDecide);
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
                    hud.center = CGPointMake(self.bounds.size.width * kNewsHUDCenterScale,
                                             self.bounds.size.height * kNewsHUDCenterScale);
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
        [self showNextNewsText];
        return;
    }
    [self stopNews];
    self.storeUpdateTime = nil;
    if (self.newsDownloader != nil) {
        return;
    }
    self.newsDownloader = [[Downloader alloc] initWithURL:[NetworkUtil lineMessageURL] save:nil];
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
                    Month:(int)month
                      Day:(int)day
                     Hour:(int)hour
                   Minute:(int)minute
                   Second:(int)second {
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
    for (MusicData *musicData in musicDataArray) {
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
        if (self.pushNotificationView.y >
            self.pushNotificationView.height * kSearchPushNotificationOverlapFactor) {
            return;
        }
    }
    if (self.tutorialView != nil || self.showView != nil || self.selectedView != nil ||
        self.settingView != nil || self.pageSlider != nil) {
        return;
    }
    if ([RBUserSettingData sharedInstance].thema == RBUserSettingDataThemeColette) {
        SoundEffectManager::GetInstance()->PlayThemedSoundEffect(
            static_cast<int>(kSoundEffectSearchBarShow));
    }
    [self.searchBar becomeFirstResponder];
    self.searchBar.text = self.backUpString;
    [self searchBar:self.searchBar textDidChange:self.backUpString];
    if ([RBUserSettingData sharedInstance].thema == RBUserSettingDataThemeColette) {
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
    if (self.searchBar.frame.origin.y >= 0.0 && self.showView == nil && self.selectedView == nil &&
        self.settingView == nil) {
        SoundEffectManager::GetInstance()->PlayThemedSoundEffect(
            static_cast<int>(kSoundEffectSearchBarHide));
        [self.searchBar resignFirstResponder];
        self.backUpString = self.searchBar.text;
        [self searchBar:self.searchBar textDidChange:@""];
        [UIView animateWithDuration:g_dMascotMessageAnimDuration
            animations:^{
              /** @ghidraAddress 0xb1150 */
              [self layoutSearchBarActive:NO];
            }
            completion:^(BOOL finished) {
              /** @ghidraAddress 0xb1670 */
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

- (BOOL)matchTitle:(MusicData *)matchTitle {
    NSArray *terms = self.searchDictionary[@(matchTitle.MusicID)];
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

    if (self.collectionView.isDecelerating) {
        return;
    }

    if (configureCell.musicData != nil) {
        __weak RBMusicCell *weakCell = configureCell;
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0), ^{
          /** @ghidraAddress 0xb28d0 */
          UIImage *artwork = weakCell.musicData.artwork;
          if (artwork == nil) {
              return;
          }
          dispatch_async(dispatch_get_main_queue(), ^{
            /** @ghidraAddress 0xb2a04 */
            // Guards against dropping stale artwork onto a reused cell.
            if (!self.collectionView.isDecelerating &&
                [weakCell.titleLabel.text isEqualToString:weakCell.musicData.musicName] &&
                weakCell.artworkImageView.image == nil) {
                weakCell.artworkImageView.image = artwork;
                weakCell.artworkImageView.alpha = 0.0;
                [UIView animateWithDuration:kArtworkFadeInDuration
                    animations:^{
                      /** @ghidraAddress 0xb2e00 */
                      weakCell.artworkImageView.alpha = 1.0;
                    }
                    completion:^(BOOL finished) {
                      /** @ghidraAddress 0xb2e98 */
                      weakCell.artworkImageView.alpha = 1.0;
                    }];
            }
          });
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
     numberOfItemsInSection:(NSInteger)section {
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
                      /** @ghidraAddress 0xb3c04 */
                      cell.artworkImageView.alpha = kAlphaOpaque;
                    }
                    completion:^(BOOL finished) {
                      /** @ghidraAddress 0xb3c70 */
                      (void)finished;
                    }];
            }
        }
        cell.titleLabel.text = cell.musicData.musicName;
        if (IsPad()) {
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
        MusicData *musicData = self.musicList[indexPath.row];
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
                           /** @ghidraAddress 0xb49f4 */
                           weakSelf.searchMascot.alpha = kAlphaHidden;
                           weakSelf.mascot.alpha = kAlphaHidden;
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
                           /** @ghidraAddress 0xb50b8 */
                           weakSelf.searchMascot.alpha = kAlphaOpaque;
                           weakSelf.mascot.alpha = kAlphaOpaque;
                         }];
    } else {
        [UIView animateWithDuration:g_dAudioManagerResumeFadeInTime
                         animations:^{
                           /** @ghidraAddress 0xb51ac */
                           weakSelf.searchMascot.alpha = kAlphaHidden;
                           weakSelf.mascot.alpha = kAlphaHidden;
                         }];
    }
}

#pragma mark - Tutorial

- (void)preStartTutorial {
    if ([RBUserSettingData sharedInstance].thema != RBUserSettingDataThemeColette) {
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
    if ([RBUserSettingData sharedInstance].thema != RBUserSettingDataThemeColette) {
        return;
    }
    if (![RBTutorialManager needStartTutorialMusicselect] &&
        ![RBTutorialManager needStartTutorialCustomize]) {
        return;
    }
    if ([RBTutorialManager needStartTutorialMusicselect]) {
        if ([self getTutorialMusicCell] != nil) {
            if (self.tutorialView == nil) {
                [self preStartTutorial];
            }
            [self.tutorialView showAnimationWithTutorialType:kTutorialTypeMusicSelect
                                                withRootView:nil];
        }
    } else {
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
    // The bound test is unsigned in the binary, so a negative mode is rejected by the second arm.
    if (static_cast<unsigned int>(currentMenuMode) <
        static_cast<unsigned int>(kMenuModePlaylistFinished)) {
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
        MusicData *music = self.musicList[itemIndex];
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
        self.searchBar.frame =
            CGRectMake(0, 0, self.searchBar.frame.size.width, self.searchBar.frame.size.height);
        CGRect cancelFrame = self.searchCancelButton.frame;
        self.searchCancelButton.frame = CGRectMake(
            self.searchBar.frame.size.width, 0, cancelFrame.size.width, cancelFrame.size.height);
        if ([RBUserSettingData sharedInstance].thema == RBUserSettingDataThemeColette) {
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
        self.searchBar.frame = CGRectMake(0,
                                          -self.searchBar.frame.size.height,
                                          self.searchBar.frame.size.width,
                                          self.searchBar.frame.size.height);
        CGRect cancelFrame = self.searchCancelButton.frame;
        self.searchCancelButton.frame = CGRectMake(self.searchBar.frame.size.width,
                                                   -cancelFrame.size.height,
                                                   cancelFrame.size.width,
                                                   cancelFrame.size.height);
        if ([RBUserSettingData sharedInstance].thema == RBUserSettingDataThemeColette) {
            CGSize mascotSize = [self.searchMascotImages[0] size];
            self.searchMascot.frame =
                CGRectMake(self.width + mascotSize.width,
                           self.searchPastelPosBaseY - mascotSize.height * kPageSnapMidpoint,
                           mascotSize.width,
                           mascotSize.height);
            self.searchMascot.alpha = kAlphaHidden;
        }
        self.mascot.alpha = kAlphaOpaque;
    }
}

- (void)shiftMenuButtonsForPlaylistEditEntering:(BOOL)entering {
    CGFloat delta = self.height - self.pageLabel.y;
    CGFloat down = entering ? delta : -delta;

    // The random information badge is only repositioned on the way in, matching the binary.
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

    UIView *shiftUp[] = {self.playlistAddButton, self.playlistDelButton, self.playlistFinButton};
    for (NSUInteger i = 0; i < sizeof(shiftUp) / sizeof(shiftUp[0]); ++i) {
        UIView *view = shiftUp[i];
        view.frame = CGRectMake(view.x, view.y - down, view.width, view.height);
    }
}

@end
