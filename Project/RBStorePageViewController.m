#import "RBStorePageViewController.h"

#import <StoreKit/StoreKit.h>

#import "AppDelegate.h"
#import "Downloader.h"
#import "ImageDownloader.h"
#import "NSFileManager+RB.h"
#import "RBCampaignData.h"
#import "RBCampaignViewController.h"
#import "RBExtendNoteManager.h"
#import "RBMusicManager.h"
#import "RBPurchaseManager.h"
#import "RBStoreDetailViewController.h"
#import "RBStoreExtendNoteList.h"
#import "RBStoreExtendPageViewController.h"
#import "RBStoreGenreViewController.h"
#import "RBStorePackList.h"
#import "RBStoreTabController.h"
#import "RBTermView.h"
#import "RBUserSettingData.h"
#import "RBViewController.h"
#import "StoreDialogView.h"
#import "StoreDownloadManager.h"
#import "StoreDownloadTask.h"
#import "StoreExtendNoteInfo.h"
#import "StoreExtendNoteInfoDownloader.h"
#import "StoreMusicInfo.h"
#import "StorePackCell.h"
#import "StorePackDetailViewPad.h"
#import "StorePackInfo.h"
#import "StorePackInfoDownloader.h"
#import "StorePackListGenre.h"
#import "StorePackView.h"
#import "StorePromotionTableCell.h"
#import "StorePromotionView.h"
#import "StoreTableCell.h"
#import "StoreUtil.h"
#import "UIAlertView+RB.h"
#import "UIImage+RB.h"
#import "neEngineBridge.h"

// Store-page subview tags. -viewWithTag: is the single source of truth for whether a subview has
// already been built, so these are domain values rather than bare integers.
enum {
    kTagPackTable = 10000,        // The pack table view.
    kTagLoadingLabel = 10001,     // The centred "Now Loading" label.
    kTagFetchingLabel = 10002,    // The genre-fetching label.
    kTagPromotionView = 10101,    // The promotion view.
    kTagShowMoreOverlay = 100000, // The "show more" activity overlay inside the table.
    kTagInfoLabel = 100000,       // The "no packs" information label inside the table.
    kTagFunBanner = 100001,       // The "store fun" floating banner inside the table.
    kTagCampaignBanner = 100002,  // The campaign floating banner inside the table.
};

// Table sections. The phone layout has three sections; the pad collapses to a single pack-list
// section.
enum {
    kStoreSectionPromotion = 0,   // The promotion banner cell (phone).
    kStoreSectionSampleLabel = 1, // The sample-play label and button cell (phone).
    kStoreSectionPackList = 2,    // The scrolling list of packs (phone) and the whole pad table.
    kStoreSectionCountPhone = 3,
    kStoreSectionCountPad = 1,
};

// The purchase-download / restore alert-view tags, matched in -alertView:clickedButtonAtIndex:.
enum {
    kAlertTagRestoreDownload = 30,         // Confirm downloading all restored musics.
    kAlertTagRestore = 31,                 // Confirm beginning a restore.
    kAlertTagPurchaseLimitTypeSelect = 32, // Choose a purchase-limit (age) tier.
    kAlertTagDownloadRetry = 33,           // Retry a failed download.
    kAlertTagUserAgeConfirm = 34,          // Confirm the entered user age.
};

// Alert button indices. Index zero is always the cancel button.
enum {
    kAlertButtonCancel = 0,
    kAlertButtonConfirm = 1,
    // The purchase-limit sheet lists three age tiers at button indices one through three; index four
    // and above opens the help page.
    kPurchaseLimitFirstHelpIndex = 4,
};

// The unset purchase-limit type, which triggers the age-selection sheet before a purchase.
enum { kPurchaseLimitTypeUnset = 0 };

// The age-verify response reports success with a zero status.
enum { kAgeVerifyStatusOK = 0 };

// Purchase-limit thresholds (yen) indexed by RBUserSettingData.purchaseLimitType; an index past the
// end means no limit (the -1 sentinel).
static const int kPurchaseLimitAmounts[] = {5000, 5000, 20000};
static const int kPurchaseLimitNone = -1;

// Reuse identifiers for the store's table cells.
static NSString *const kStorePromotionCellID = @"StorePromotionCell";
static NSString *const kStorePromotionSampleLabelCellID = @"StorePromotionSampleLabelCell";
static NSString *const kStorePacklistCellID = @"StorePacklistCell";
static NSString *const kStorePacklistMoreCellID = @"StorePacklistMoreCell";
static NSString *const kStorePacklistCellEvenID = @"StorePacklistCellEven";
static NSString *const kStorePacklistCellOddID = @"StorePacklistCellOdd";

// Image asset names.
static NSString *const kStoreDefaultJacketImageName = @"09_store/store_jacket_64";
static NSString *const kStoreIconImageName = @"09_store/icon_store";
static NSString *const kStoreSampleBgPlayImageName = @"09_store/store_sample_bg_2";
static NSString *const kStoreSampleBgStopImageName = @"09_store/store_sample_bg_3";
static NSString *const kStoreSampleBannerImageName = @"09_store/store_sample_bg_1";
static NSString *const kStoreFunBannerImageName = @"09_store/store_fun";
static NSString *const kStorePackBg0ImageName = @"09_store/store_pack_bg_0";
static NSString *const kStorePackBg1ImageName = @"09_store/store_pack_bg_1";
static NSString *const kStoreRestoreImageName = @"09_store/store_restore";

// Localised bar-button and status strings looked up through the main bundle.
static NSString *const kStoreCategoryKey = @"Category";
static NSString *const kStoreTopKey = @"TOP ";

// The empty store-tab title and the pad pack-table title are one-off literals. The remaining
// display strings are the shared store-layer NSString globals declared in
// RBStoreExtendPageViewController.h (g_pStoreShowMoreTitle @0x3cfd70, g_pStoreLoadingTitle @0x3cfca8,
// g_pStoreBannerTitle @0x3cfd18, and the modal-dialog messages), reused here rather than redeclared.
static NSString *const kStoreEmptyTitle = @"";         // @ghidraAddress 0x3cfd90
static NSString *const kStorePackTableTitle = @"PACK"; // @ghidraAddress 0x3cfce8

// Font point sizes for the various labels and buttons.
static const CGFloat kPackTableLabelFontSize = 18.0;
static const CGFloat kSampleMusicLabelFontSizePhone = 12.0;
static const CGFloat kSampleMusicLabelFontSizePad = 14.0;
static const CGFloat kFetchingLabelFontSizePhone = 16.0;
static const CGFloat kFetchingLabelFontSizePad = 18.0;
static const CGFloat kLoadingLabelFontSize = 18.0;
static const CGFloat kInfoLabelFontSize = 15.0;
static const CGFloat kMoreCellFontSizePhone = 15.0;
static const CGFloat kMoreCellFontSizePad = 18.0;
static const CGFloat kBarButtonTitleFontSize = 14.0;

// Section heights (phone layout).
static const CGFloat kPromotionSectionHeight = 102.0;
static const CGFloat kSampleSectionHeight = 32.0;

// Pack-list row heights: index one (a real pack row) is taller than index zero (the trailing "more"
// row).
static const CGFloat kPackRowHeightPhone = 140.0;
static const CGFloat kMoreRowHeightPhone = 60.0;
static const CGFloat kPackRowHeightPad = 80.0;
static const CGFloat kMoreRowHeightPad = 60.0;

// Alternating pack-row background tints (white component).
static const CGFloat kPackRowTintEvenWhite = 0.8;
static const CGFloat kPackRowTintOddWhite = 0.7568627450980392;
static const CGFloat kPadPackRowTintWhite = 0.5;
static const CGFloat kPadMoreRowGreyWhite = 0.6;

// The "load more" row text: 0.8 white idle, 0.4 white (matching the shadow) while loading.
static const CGFloat kMoreCellTextWhiteIdle = 0.8;
static const CGFloat kMoreCellTextWhiteLoading = 0.4;
static const CGFloat kMoreCellShadowWhite = 0.4;

// The sample-label cell layout metrics: the label is inset from both edges and the play button sits
// at the trailing edge, both 32 points tall.
static const CGFloat kSampleLabelInsetLeft = 46.0;
static const CGFloat kSampleLabelInsetRight = 92.0;
static const CGFloat kSamplePlayButtonWidth = 46.0;

// The floating banner height (wider on the pad), used to keep the banner pinned to the viewport.
static const CGFloat kBannerHeightPhone = 100.0;
static const CGFloat kBannerHeightPad = 300.0;

// The empty-state overlay is inset 50 points from the table's left edge, and the right overlay is
// pulled a further 50 points in from the table's right edge; it drops below the taller of the
// table's content or bounds by this much (three times as far on the pad).
static const CGFloat kEmptyStateSideInset = 50.0;
static const CGFloat kEmptyStateDropPhone = 100.0;
static const CGFloat kEmptyStateDropPad = 300.0;

// The "show more" button is re-centred half-way across the table, 25 points below its content top.
static const CGFloat kShowMoreCentreDrop = 25.0;

// The pad table appearance.
static const CGFloat kPadTableCornerRadius = 8.0;
static const CGFloat kPadTableBorderWidth = 1.5;
static const CGFloat kPadTableWidth = 726.0;
static const CGFloat kPadTableScrollInset = 4.0;
static const CGFloat kPadTitleLabelWidth = 720.0;
static const CGFloat kPadTitleVerticalOffset = 20.0;
static const CGFloat kPadContentTop = 330.0;
static const CGFloat kPadDetailWidth = 650.0;
static const CGFloat kPadDetailCentreYOffset = -44.0;
static const CGFloat kPadTableHeightOffset = -236.0;
static const CGFloat kPadTableCentreOffset = 236.0;
static const CGFloat kPadSampleLabelX = 140.0;
static const CGFloat kPadSampleLabelY = 217.0;
static const CGFloat kPadSampleLabelWidth = 228.0;

// The sample-play button is inset from the pad banner's bottom-right corner by (11, 13) points.
static const CGFloat kSampleButtonInsetRight = 11.0;
static const CGFloat kSampleButtonInsetBottom = 13.0;

// Colour white components used for the various translucent fills.
static const CGFloat kTableBackgroundWhite = 0.186;
static const CGFloat kPadTableBorderWhite = 0.56;
static const CGFloat kLabelTextWhite = 0.62;
static const CGFloat kCoverPadAlpha = 0.5;

// The default store-page background colour (shared with loadView).
static const CGFloat kDefaultBackgroundRed = 0.882;
static const CGFloat kDefaultBackgroundGreen = 0.891;
static const CGFloat kDefaultBackgroundBlue = 0.899;

// The half-scale used to centre a view in its host's bounds.
static const CGFloat kCenterScale = 0.5;

// Alpha values used when fading the pad pack-detail panel in and out.
static const CGFloat kDetailAlphaHidden = 0.0;
static const CGFloat kDetailAlphaVisible = 1.0;

// The pad pack-detail open/close animation fades over three tenths of a second.
static const NSTimeInterval kDetailAnimDuration = 0.3;

// The stretchable pack-cell background caps.
static const int kPackBgStretchCap = 4;

// The Retina spinner size and the pack-table title label bounds constant.
static const CGFloat kSpinnerSize = 24.0;
static const CGFloat kPadTitleTagBias = 20.0;

// The currency code that counts towards the running purchase total.
static NSString *const kCurrencyCodeJPY = @"JPY";

// The KONAMI mobile help page opened from the purchase-limit sheet.
static NSString *const kKonamiHelpURLString = @"http://www.konami.jp/";

// The store's error-message format and the download-progress message format. The purchase-unavailable
// message reuses the shared purchase-failed global.
static NSString *const kStoreDownloadingFormat = @"%@"; // @ghidraAddress 0x3cfbd8
static NSString *const kStoreErrorFormat = @"%@";       // @ghidraAddress 0x3cfd08

// The modal-dialog message shown while a pack's tunes download. The binary uses a short local literal
// here rather than one of the shared store-message globals.
static NSString *const kStoreDownloadDialogMessage = @"";

// The cover-tap dismissal fade, shared with the audio-manager resume fade (a distinct 0.3 s global
// from the open/close animation duration). @ghidraAddress 0x2ec718 (g_dAudioManagerResumeFadeInTime)
static const NSTimeInterval kCoverFadeDuration = 0.3;

@interface RBStorePageViewController () {
    // Whether the wide (pad) font variant is active; cached from GetFontVariantFlag().
    BOOL m_IsPad;
    // Whether a "load more" page fetch is in flight.
    BOOL m_IsLoadingMoreList;
}

// Build the phone-layout promotion, sample controls, and pack table.
- (void)buildPhoneLayout:(CGRect)bounds;
// Build the pad-layout title, promotion banner, sample controls, pack table, cover, and detail view.
- (void)buildPadLayout:(CGRect)bounds;
// Build the pack-table auxiliary views (info label, banners, loading and fetching labels, pack-cell
// background images) shared by both layouts.
- (void)buildTableAuxiliaryViews:(CGRect)bounds;
// The trailing "load more" cell: idle "show more" text, or a spinner while a fetch is running.
- (void)configureMoreCell:(UITableViewCell *)cell;
// Look up (or lazily start) the artwork download for a pack, keyed by pack identifier.
- (nullable UIImage *)artworkImageForPackInfo:(StorePackInfo *)packInfo
                                    indexPath:(NSIndexPath *)indexPath
                             forcingNonRetina:(BOOL)forcingNonRetina;

@end

@implementation RBStorePageViewController

#pragma mark - Lifecycle

/** @ghidraAddress 0x1dcf88 */
- (instancetype)initWithParent:(RBStoreTabController *)parent {
    self = [super init];
    if (self) {
        self.parent = parent;
        self.navigationItem.title = kStoreEmptyTitle;
        self.tabBarItem.title = kStoreEmptyTitle;
        self.tabBarItem.image = [UIImage imageWithName:kStoreIconImageName];

        self.packListCtrl = [[RBStorePackList alloc] init];
        self.packListCtrl.delegate = self;

        self.artworkDownloaders = [[NSMutableDictionary alloc] initWithCapacity:32];

        m_IsPad = (BOOL)GetFontVariantFlag();
    }
    return self;
}

/** @ghidraAddress 0x1dd25c */
- (void)loadView {
    [super loadView];

    self.view.opaque = YES;

    RBCampaignData *campaign = [RBCampaignData sharedInstance];
    if (campaign.storeBaseImage != nil) {
        self.view.backgroundColor = [UIColor colorWithPatternImage:campaign.storeBaseImage];
    } else if (campaign.storeBaseColor != nil) {
        self.view.backgroundColor = campaign.storeBaseColor;
    } else {
        self.view.backgroundColor = [UIColor colorWithRed:kDefaultBackgroundRed
                                                    green:kDefaultBackgroundGreen
                                                     blue:kDefaultBackgroundBlue
                                                    alpha:1.0];
    }

    self.view.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    self.view.exclusiveTouch = YES;
}

/** @ghidraAddress 0x1dd5b0 */
- (void)viewDidLoad {
    [super viewDidLoad];

    CGRect bounds = self.view.bounds;
    if (m_IsPad == NO) {
        [self buildPhoneLayout:bounds];
    } else {
        [self buildPadLayout:bounds];
    }
    [self buildTableAuxiliaryViews:bounds];
}

- (void)buildPhoneLayout:(CGRect)bounds {
    if (self.promotionView == nil) {
        StorePromotionView *promotion = [[StorePromotionView alloc]
            initWithFrame:CGRectMake(0.0, 10.0, 300.0, kPromotionSectionHeight)];
        promotion.autoresizingMask = UIViewAutoresizingFlexibleWidth |
                                     UIViewAutoresizingFlexibleTopMargin |
                                     UIViewAutoresizingFlexibleBottomMargin;
        promotion.center = CGPointMake(150.0, 46.0);
        promotion.tag = kTagPromotionView;
        promotion.delegate = self;
        promotion.exclusiveTouch = YES;
        self.promotionView = promotion;

        self.playImage = [UIImage imageWithName:kStoreSampleBgPlayImageName];
        self.stopImage = [UIImage imageWithName:kStoreSampleBgStopImageName];
        self.samplePlayButton = [UIButton buttonWithType:UIButtonTypeCustom];
        if ([RBUserSettingData sharedInstance].refuseStoreSampleBGM) {
            [self.samplePlayButton setImage:self.stopImage forState:UIControlStateNormal];
        } else {
            [self.samplePlayButton setImage:self.playImage forState:UIControlStateNormal];
        }
        [self.samplePlayButton addTarget:self
                                  action:@selector(pushSampleButton:)
                        forControlEvents:UIControlEventTouchUpInside];
        self.samplePlayButton.exclusiveTouch = YES;
        self.samplePlayButton.userInteractionEnabled = YES;
        self.samplePlayButton.autoresizingMask = UIViewAutoresizingFlexibleWidth |
                                                 UIViewAutoresizingFlexibleTopMargin |
                                                 UIViewAutoresizingFlexibleBottomMargin;

        self.sampleMusicLabel = [[UILabel alloc] init];
        self.sampleMusicLabel.font = [UIFont systemFontOfSize:kSampleMusicLabelFontSizePhone];
        self.sampleMusicLabel.adjustsFontSizeToFitWidth = YES;
        self.sampleMusicLabel.autoresizingMask = UIViewAutoresizingFlexibleTopMargin;
        self.sampleMusicLabel.textAlignment = NSTextAlignmentCenter;
    }

    if ([self.view viewWithTag:kTagPackTable] == nil) {
        UITableView *table = [[UITableView alloc] initWithFrame:bounds style:UITableViewStylePlain];
        table.opaque = YES;
        table.tag = kTagPackTable;
        table.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        table.backgroundColor = [UIColor colorWithWhite:kTableBackgroundWhite alpha:1.0];
        table.separatorStyle = UITableViewCellSeparatorStyleNone;
        table.dataSource = self;
        table.delegate = self;
        table.exclusiveTouch = YES;
        [self.view addSubview:table];
    }
}

- (void)buildPadLayout:(CGRect)bounds {
    // The pad layout lays its content below the rotating header bar.
    CGFloat headerHeight = self.tabBarController.rotatingHeaderView.frame.size.height;
    CGFloat contentTop = kPadContentTop - headerHeight;

    self.packTableLabel = [[UILabel alloc] initWithFrame:CGRectMake(0.0, contentTop, 27.0, 0.0)];
    self.packTableLabel.textColor = [UIColor blackColor];
    self.packTableLabel.shadowColor = [UIColor lightGrayColor];
    self.packTableLabel.shadowOffset = CGSizeMake(1.0, 1.0);
    self.packTableLabel.font = [UIFont systemFontOfSize:kPackTableLabelFontSize];
    self.packTableLabel.text = kStorePackTableTitle;
    [self.packTableLabel sizeToFit];
    self.packTableLabel.bounds =
        CGRectMake(0.0, 0.0, kPadTitleLabelWidth, self.packTableLabel.bounds.size.height);
    self.packTableLabel.center =
        CGPointMake(bounds.size.width * kCenterScale,
                    self.packTableLabel.bounds.size.height * kCenterScale + kPadTitleTagBias);
    self.packTableLabel.autoresizingMask = UIViewAutoresizingFlexibleWidth |
                                           UIViewAutoresizingFlexibleTopMargin |
                                           UIViewAutoresizingFlexibleBottomMargin;
    [self.view addSubview:self.packTableLabel];

    if (self.promotionView == nil) {
        StorePromotionView *promotion = [[StorePromotionView alloc]
            initWithFrame:CGRectMake(0.0, 10.0, contentTop, kPromotionSectionHeight)];
        self.promotionView = promotion;
        self.promotionView.center =
            CGPointMake(bounds.size.width * kCenterScale,
                        kPromotionSectionHeight * kCenterScale + kPadTitleTagBias);
        self.promotionView.autoresizingMask = UIViewAutoresizingFlexibleWidth |
                                              UIViewAutoresizingFlexibleTopMargin |
                                              UIViewAutoresizingFlexibleBottomMargin;
        self.promotionView.delegate = self;
    }
    self.promotionView.exclusiveTouch = YES;

    if ([RBCampaignData sharedInstance].storeSampleColor == nil) {
        self.bannerBgView =
            [[UIImageView alloc] initWithImage:[UIImage imageWithName:kStoreSampleBannerImageName]];
    } else {
        UIImage *banner = [UIImage imageWithName:kStoreSampleBannerImageName];
        banner =
            [banner colorMatrixFilterWithColor:[RBCampaignData sharedInstance].storeSampleColor];
        self.bannerBgView = [[UIImageView alloc] initWithImage:banner];
    }
    self.bannerBgView.center = self.promotionView.center;
    self.bannerBgView.userInteractionEnabled = YES;
    [self.view addSubview:self.bannerBgView];

    self.playImage = [UIImage imageWithName:kStoreSampleBgPlayImageName];
    self.stopImage = [UIImage imageWithName:kStoreSampleBgStopImageName];
    self.samplePlayButton = [UIButton buttonWithType:UIButtonTypeCustom];
    self.samplePlayButton.frame = CGRectMake(
        self.bannerBgView.frame.size.width - self.playImage.size.width - kSampleButtonInsetRight,
        self.bannerBgView.frame.size.height - self.playImage.size.height - kSampleButtonInsetBottom,
        self.playImage.size.width,
        self.playImage.size.height);
    if ([RBUserSettingData sharedInstance].refuseStoreSampleBGM) {
        [self.samplePlayButton setImage:self.stopImage forState:UIControlStateNormal];
    } else {
        [self.samplePlayButton setImage:self.playImage forState:UIControlStateNormal];
    }
    [self.samplePlayButton addTarget:self
                              action:@selector(pushSampleButton:)
                    forControlEvents:UIControlEventTouchUpInside];
    self.samplePlayButton.exclusiveTouch = YES;
    self.samplePlayButton.userInteractionEnabled = YES;
    [self.bannerBgView addSubview:self.samplePlayButton];

    self.sampleMusicLabel = [[UILabel alloc] initWithFrame:CGRectMake(kPadSampleLabelX,
                                                                      kPadSampleLabelY,
                                                                      kPadSampleLabelWidth,
                                                                      kPackTableLabelFontSize)];
    self.sampleMusicLabel.font = [UIFont systemFontOfSize:kSampleMusicLabelFontSizePad];
    self.sampleMusicLabel.adjustsFontSizeToFitWidth = YES;
    self.sampleMusicLabel.textAlignment = NSTextAlignmentCenter;
    [self.bannerBgView addSubview:self.sampleMusicLabel];

    [self.view addSubview:self.promotionView];

    UIButton *showMore = [UIButton buttonWithType:UIButtonTypeCustom];
    [showMore setTitle:g_pStoreShowMoreTitle forState:UIControlStateNormal];
    [showMore setTitleColor:[UIColor blackColor] forState:UIControlStateNormal];
    [showMore sizeToFit];
    showMore.center =
        CGPointMake(bounds.size.width * kCenterScale,
                    bounds.size.height - self.playImage.size.height * kCenterScale - 15.0);
    showMore.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin |
                                UIViewAutoresizingFlexibleWidth |
                                UIViewAutoresizingFlexibleTopMargin;
    showMore.hidden = YES;
    [showMore addTarget:self
                  action:@selector(selectShowMore)
        forControlEvents:UIControlEventTouchUpInside];
    showMore.exclusiveTouch = YES;
    [self.view addSubview:showMore];
    self.showMoreButton = showMore;

    UIActivityIndicatorView *indicator = [[UIActivityIndicatorView alloc]
        initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleGray];
    indicator.bounds = CGRectMake(0.0, 0.0, kSpinnerSize, kSpinnerSize);
    indicator.center =
        CGPointMake(self.showMoreButton.bounds.size.width + kSpinnerSize * kCenterScale,
                    kSpinnerSize * kCenterScale);
    indicator.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin |
                                 UIViewAutoresizingFlexibleTopMargin |
                                 UIViewAutoresizingFlexibleBottomMargin;
    [indicator startAnimating];
    indicator.hidden = YES;
    [self.showMoreButton addSubview:indicator];
    self.showMoreIndicator = indicator;

    if ([self.view viewWithTag:kTagPackTable] == nil) {
        CGFloat tableHeight =
            (bounds.size.height + kPadTableHeightOffset) - (kSpinnerSize + 16.0 + 16.0);
        UITableView *table =
            [[UITableView alloc] initWithFrame:CGRectMake(0.0, 0.0, kPadTableWidth, tableHeight)
                                         style:UITableViewStylePlain];
        table.tag = kTagPackTable;
        table.center = CGPointMake(bounds.size.width * kCenterScale,
                                   tableHeight * kCenterScale + kPadTableCentreOffset);
        table.autoresizingMask = UIViewAutoresizingFlexibleWidth |
                                 UIViewAutoresizingFlexibleHeight |
                                 UIViewAutoresizingFlexibleTopMargin;
        table.opaque = YES;
        table.backgroundColor = [UIColor colorWithWhite:kTableBackgroundWhite alpha:1.0];
        table.layer.cornerRadius = kPadTableCornerRadius;
        table.layer.borderColor = [UIColor colorWithWhite:kPadTableBorderWhite alpha:1.0].CGColor;
        table.layer.borderWidth = kPadTableBorderWidth;
        table.scrollIndicatorInsets =
            UIEdgeInsetsMake(kPadTableScrollInset, 0.0, kPadTableScrollInset, 0.0);
        table.separatorStyle = UITableViewCellSeparatorStyleNone;
        table.dataSource = self;
        table.delegate = self;
        table.exclusiveTouch = YES;
        [self.view addSubview:table];
    }

    self.coverViewPad = [[UIView alloc] initWithFrame:self.view.bounds];
    self.coverViewPad.autoresizingMask =
        UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleWidth |
        UIViewAutoresizingFlexibleRightMargin | UIViewAutoresizingFlexibleTopMargin |
        UIViewAutoresizingFlexibleHeight | UIViewAutoresizingFlexibleBottomMargin;
    self.coverViewPad.opaque = NO;
    self.coverViewPad.backgroundColor = [UIColor colorWithWhite:0.0 alpha:kCoverPadAlpha];
    self.coverViewPad.userInteractionEnabled = YES;
    UITapGestureRecognizer *tap =
        [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(handleTapCoverView:)];
    [self.coverViewPad addGestureRecognizer:tap];
    self.coverViewPad.hidden = YES;
    self.coverViewPad.exclusiveTouch = YES;
    [self.view addSubview:self.coverViewPad];

    self.packDetailViewPad = [[StorePackDetailViewPad alloc]
        initWithFrame:CGRectMake(0.0, 0.0, kPadDetailWidth, kPromotionSectionHeight)];
    self.packDetailViewPad.center =
        CGPointMake((CGFloat)(int)self.coverViewPad.center.x,
                    (CGFloat)(int)(self.coverViewPad.center.y + kPadDetailCentreYOffset));
    self.packDetailViewPad.autoresizingMask =
        UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin |
        UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleBottomMargin;
    self.packDetailViewPad.delegate = self;
    self.packDetailViewPad.hidden = YES;
    self.packDetailViewPad.exclusiveTouch = YES;
    [self.view addSubview:self.packDetailViewPad];
}

- (void)buildTableAuxiliaryViews:(CGRect)bounds {
    UIView *table = [self.view viewWithTag:kTagPackTable];
    if (table != nil) {
        if ([table viewWithTag:kTagInfoLabel] == nil) {
            UILabel *info =
                [[UILabel alloc] initWithFrame:CGRectMake(0.0, 0.0, bounds.size.width, 25.0)];
            info.tag = kTagInfoLabel;
            info.backgroundColor = [UIColor clearColor];
            info.text = g_pStoreBannerTitle;
            info.font = [UIFont systemFontOfSize:kInfoLabelFontSize];
            info.textColor = [UIColor whiteColor];
            info.textAlignment = NSTextAlignmentCenter;
            info.hidden = YES;
            [table addSubview:info];
        }
        if ([table viewWithTag:kTagFunBanner] == nil) {
            UIImageView *fun = [[UIImageView alloc]
                initWithImage:[UIImage imageWithName:kStoreFunBannerImageName]];
            fun.tag = kTagFunBanner;
            fun.hidden = YES;
            [table addSubview:fun];
        }
        if ([RBCampaignData sharedInstance].isCampaignHinabita201703 &&
            [table viewWithTag:kTagCampaignBanner] == nil) {
            NSString *name = [RBCampaignData sharedInstance].campaignName;
            if ([UIImage imageWithName:name] != nil) {
                UIImageView *campaignBanner =
                    [[UIImageView alloc] initWithImage:[UIImage imageWithName:name]];
                campaignBanner.tag = kTagCampaignBanner;
                campaignBanner.hidden = YES;
                [table addSubview:campaignBanner];
            }
        }
    }

    if ([self.view viewWithTag:kTagLoadingLabel] == nil) {
        UILabel *loading = [[UILabel alloc] initWithFrame:self.view.bounds];
        loading.tag = kTagLoadingLabel;
        loading.backgroundColor = [UIColor colorWithRed:kDefaultBackgroundRed
                                                  green:kDefaultBackgroundGreen
                                                   blue:kDefaultBackgroundBlue
                                                  alpha:1.0];
        loading.font = [UIFont boldSystemFontOfSize:kLoadingLabelFontSize];
        loading.textColor = [UIColor colorWithWhite:kLabelTextWhite alpha:1.0];
        loading.shadowColor = [UIColor colorWithWhite:1.0 alpha:kDetailAnimDuration];
        loading.shadowOffset = CGSizeMake(0.0, 1.0);
        loading.textAlignment = NSTextAlignmentCenter;
        loading.center = CGPointMake(bounds.size.width * kCenterScale,
                                     (CGFloat)(int)(bounds.size.height * kCenterScale));
        loading.autoresizingMask =
            UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        loading.text = g_pStoreLoadingTitle;
        loading.hidden = NO;
        [self.view addSubview:loading];

        UIView *spinnerHost = [[UIView alloc] init];
        spinnerHost.backgroundColor = [UIColor clearColor];
        spinnerHost.autoresizingMask =
            UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin |
            UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleBottomMargin;
        [loading addSubview:spinnerHost];

        UIActivityIndicatorView *spinner = [[UIActivityIndicatorView alloc] init];
        spinner.activityIndicatorViewStyle = UIActivityIndicatorViewStyleWhite;
        [spinner startAnimating];
        [spinnerHost addSubview:spinner];
    }

    if ([self.view viewWithTag:kTagFetchingLabel] == nil) {
        UILabel *fetching = [[UILabel alloc] initWithFrame:self.view.bounds];
        fetching.tag = kTagFetchingLabel;
        fetching.backgroundColor = self.view.backgroundColor;
        CGFloat fontSize = m_IsPad ? kFetchingLabelFontSizePad : kFetchingLabelFontSizePhone;
        fetching.font = [UIFont boldSystemFontOfSize:fontSize];
        fetching.textColor = [UIColor colorWithWhite:kLabelTextWhite alpha:1.0];
        fetching.textAlignment = NSTextAlignmentCenter;
        fetching.numberOfLines = 0;
        fetching.center = CGPointMake(bounds.size.width * kCenterScale,
                                      (CGFloat)((int)(bounds.size.height * kCenterScale) - 20));
        fetching.autoresizingMask =
            UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleWidth |
            UIViewAutoresizingFlexibleRightMargin | UIViewAutoresizingFlexibleTopMargin |
            UIViewAutoresizingFlexibleHeight | UIViewAutoresizingFlexibleBottomMargin;
        fetching.hidden = YES;
        [self.view addSubview:fetching];
    }

    if (self.packBgImage0 == nil) {
        self.packBgImage0 = [[UIImage imageWithName:kStorePackBg0ImageName]
            stretchableImageWithLeftCapWidth:kPackBgStretchCap
                                topCapHeight:kPackBgStretchCap];
        if ([RBCampaignData sharedInstance].storeColorPackA != nil) {
            self.packBgImage0 = [[self.packBgImage0
                colorMatrixFilterWithColor:[RBCampaignData sharedInstance].storeColorPackA]
                stretchableImageWithLeftCapWidth:kPackBgStretchCap
                                    topCapHeight:kPackBgStretchCap];
        }
    }
    if (self.packBgImage1 == nil) {
        self.packBgImage1 = [[UIImage imageWithName:kStorePackBg1ImageName]
            stretchableImageWithLeftCapWidth:kPackBgStretchCap
                                topCapHeight:kPackBgStretchCap];
        if ([RBCampaignData sharedInstance].storeColorPackB != nil) {
            self.packBgImage1 = [[self.packBgImage1
                colorMatrixFilterWithColor:[RBCampaignData sharedInstance].storeColorPackB]
                stretchableImageWithLeftCapWidth:kPackBgStretchCap
                                    topCapHeight:kPackBgStretchCap];
        }
    }
}

/** @ghidraAddress 0x1ecd54 */
- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];

    if (self.promotionView != nil) {
        if (GetFontVariantFlag() == kFontVariantDefault) {
            self.promotionView.isSamplePlayable = YES;
        } else if (self.packDetailViewPad.isHidden) {
            self.promotionView.isSamplePlayable = YES;
        }
    }

    UITableView *table = (UITableView *)[self.view viewWithTag:kTagPackTable];
    if (m_IsPad == NO && !table.isHidden) {
        NSIndexPath *selected = table.indexPathForSelectedRow;
        if (selected != nil) {
            [table reloadRowsAtIndexPaths:@[ selected ]
                         withRowAnimation:UITableViewRowAnimationMiddle];
            [table deselectRowAtIndexPath:selected animated:animated];
        }
        if (m_IsPad == NO) {
            [self.promotionView scrollViewDidRotate:(float)self.view.frame.size.width];
        }
    }

    UIView *fetching = [self.view viewWithTag:kTagFetchingLabel];
    if (fetching != nil && !fetching.isHidden) {
        fetching.frame = self.view.bounds;
    }

    if (GetFontVariantFlag() != kFontVariantDefault && !self.packDetailViewPad.isHidden) {
        [self.packDetailViewPad selfCheckButtonText];
    }

    if (GetFontVariantFlag() == kFontVariantDefault) {
        self.navigationController.navigationBar.tintColor = nil;
        self.navigationController.navigationBar.barTintColor = [UIColor whiteColor];
        if ([self.navigationController.navigationBar
                respondsToSelector:@selector(setBackgroundImage:forBarMetrics:)]) {
            [self.navigationController.navigationBar setBackgroundImage:nil
                                                          forBarMetrics:UIBarMetricsDefault];
        }
    }
}

/** @ghidraAddress 0x1ed380 */
- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];

    if (self.currentGenre.packIDList.count == 0 && !self.packListCtrl.isFetching) {
        [self.view viewWithTag:kTagFetchingLabel].hidden = YES;
        [self.view viewWithTag:kTagPackTable].hidden = YES;
        self.currentGenre = [self.packListCtrl packListForGenreIndex:0];
        [self.packListCtrl startFetchGenre:self.currentGenre];
        return;
    }

    [self.promotionView startAnimation];
    [self packListDownloadSuccess:self.packListCtrl];
}

/** @ghidraAddress 0x1ed6e4 */
- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];

    self.promotionView.isSamplePlayable = NO;
    [self.promotionView stopAnimation];
    [self.promotionView stopSamplePlay];

    if (m_IsPad) {
        [self.packDetailViewPad cancelLoading];
        [self.packDetailViewPad stopSample];
    }

    if (self.packListCtrl.isFetching) {
        m_IsLoadingMoreList = NO;
        UITableView *table = (UITableView *)[self.view viewWithTag:kTagPackTable];
        table.allowsSelection = YES;
        [table reloadData];
    }

    if (self.storePackInfoDownloader != nil) {
        self.storePackInfoDownloader.delegate = nil;
        [self.storePackInfoDownloader cancel];
        self.storePackInfoDownloader = nil;
    }

    [self.packListCtrl cancelFetching];
}

/** @ghidraAddress 0x1edae8 */
- (void)didReceiveMemoryWarning {
    // The artwork dictionary is emptied before the super call, matching the binary's ordering.
    [self.artworkDownloaders removeAllObjects];
    [super didReceiveMemoryWarning];
}

/** @ghidraAddress 0x1edb6c */
- (void)dealloc {
    // ARC synthesises the ivar releases and the destructor; only the non-generated teardown is
    // reproduced here.
    if (self.storePackInfoDownloader != nil) {
        self.storePackInfoDownloader.delegate = nil;
        [self.storePackInfoDownloader cancel];
    }

    if (self.promotionView != nil) {
        UITableView *table = (UITableView *)[self.view viewWithTag:kTagPackTable];
        table.delegate = nil;
        table.dataSource = nil;
        [self stopDownloadArtworks];
        [self.downloadManager cancel];
        self.promotionView.delegate = nil;
        [self.promotionView cancel];
        self.packDetailViewPad.delegate = nil;
    }
}

#pragma mark - Pack list callbacks

/** @ghidraAddress 0x1e156c */
- (void)packListDownloadSuccess:(RBStorePackList *)packList {
    UITableView *table = (UITableView *)[self.view viewWithTag:kTagPackTable];
    UIView *loadingLabel = [self.view viewWithTag:kTagLoadingLabel];
    table.hidden = NO;
    loadingLabel.hidden = YES;
    if (self.packTableLabel != nil) {
        self.packTableLabel.hidden = NO;
    }
    m_IsLoadingMoreList = NO;
    table.allowsSelection = YES;
    [table reloadData];

    if (self.restoreButton == nil) {
        UIImage *image = [UIImage imageWithName:kStoreRestoreImageName];
        self.restoreButton = [[UIBarButtonItem alloc] initWithImage:image
                                                              style:UIBarButtonItemStyleDone
                                                             target:self
                                                             action:@selector(pushBarBtnRestore:)];
    }
    if (self.genreButton == nil) {
        NSString *title = [[NSBundle mainBundle] localizedStringForKey:kStoreCategoryKey
                                                                 value:kStoreEmptyTitle
                                                                 table:nil];
        self.genreButton = [[UIBarButtonItem alloc] initWithTitle:title
                                                            style:UIBarButtonItemStylePlain
                                                           target:self
                                                           action:@selector(presentGenreSelect:)];
        NSDictionary *attrs =
            @{NSFontAttributeName : [UIFont systemFontOfSize:kBarButtonTitleFontSize]};
        [self.genreButton setTitleTextAttributes:attrs forState:UIControlStateNormal];
        if (GetFontVariantFlag() == kFontVariantDefault) {
            self.navigationItem.title = kStoreEmptyTitle;
        }
    }
    if (self.topButton == nil) {
        NSString *title = [[NSBundle mainBundle] localizedStringForKey:kStoreTopKey
                                                                 value:kStoreEmptyTitle
                                                                 table:nil];
        self.topButton = [[UIBarButtonItem alloc] initWithTitle:title
                                                          style:UIBarButtonItemStylePlain
                                                         target:self
                                                         action:@selector(goToTop:)];
        NSDictionary *attrs =
            @{NSFontAttributeName : [UIFont systemFontOfSize:kBarButtonTitleFontSize]};
        [self.topButton setTitleTextAttributes:attrs forState:UIControlStateNormal];
    }
    self.navigationItem.rightBarButtonItems =
        @[ self.restoreButton, self.genreButton, self.topButton ];

    for (UIView *barSubview in self.navigationController.navigationBar.subviews) {
        barSubview.exclusiveTouch = YES;
    }

    CGFloat tableContentBottom = (table.contentSize.height > table.bounds.size.height) ?
                                     table.contentSize.height :
                                     table.bounds.size.height;

    UIView *leftEmpty = [table viewWithTag:kTagFunBanner];
    CGFloat drop = m_IsPad ? kEmptyStateDropPad : kEmptyStateDropPhone;
    CGRect leftFrame = leftEmpty.frame;
    leftEmpty.frame = CGRectMake(kEmptyStateSideInset,
                                 drop + tableContentBottom,
                                 leftFrame.size.width,
                                 leftFrame.size.height);
    leftEmpty.hidden = NO;

    UIView *rightEmpty = [table viewWithTag:kTagCampaignBanner];
    if (rightEmpty != nil) {
        drop = m_IsPad ? kEmptyStateDropPad : kEmptyStateDropPhone;
        CGRect rightFrame = rightEmpty.frame;
        CGFloat rightX = table.bounds.size.width - rightFrame.size.width - kEmptyStateSideInset;
        rightEmpty.frame = CGRectMake(
            rightX, drop + tableContentBottom, rightFrame.size.width, rightFrame.size.height);
        rightEmpty.hidden = NO;
    }

    if (self.showMoreIndicator != nil) {
        self.showMoreIndicator.hidden = YES;
    }

    if (self.packListCtrl.packlistContinued) {
        if (self.showMoreButton != nil) {
            self.showMoreButton.hidden = NO;
            [self.showMoreButton setTitle:g_pStoreShowMoreTitle forState:UIControlStateNormal];
            CGPoint centre = self.showMoreButton.center;
            [self.showMoreButton sizeToFit];
            self.showMoreButton.center = centre;
        }
        UIView *overlay = [table viewWithTag:kTagShowMoreOverlay];
        overlay.hidden = NO;
        overlay.center = CGPointMake(table.bounds.size.width * kCenterScale,
                                     table.contentSize.height + kShowMoreCentreDrop);
    } else {
        if (self.showMoreButton != nil) {
            self.showMoreButton.hidden = YES;
        }
        [table viewWithTag:kTagShowMoreOverlay].hidden = YES;
    }

    if (self.promotionView != nil) {
        self.promotionView.hidden = NO;
        [self.promotionView setImageURLs:self.packListCtrl.promotionList];
    }

    if (self.packListCtrl.numGenres > 1 && self.genreViewCtrl == nil) {
        self.genreViewCtrl = [[RBStoreGenreViewController alloc] init];
        self.genreViewCtrl.packListCtrl = self.packListCtrl;
        self.genreViewCtrl.storeViewCtrl = self;
        self.genreNavCtrl =
            [[UINavigationController alloc] initWithRootViewController:self.genreViewCtrl];
        if (GetFontVariantFlag() != kFontVariantDefault) {
            self.genrePopoverCtrl =
                [[UIPopoverController alloc] initWithContentViewController:self.genreNavCtrl];
            self.genrePopoverCtrl.delegate = self;
        }
    }

    [self forceOpenPackDetailView];
}

/** @ghidraAddress 0x1e2a6c */
- (void)packListDownloadError:(RBStorePackList *)packList errorMessage:(NSString *)errorMessage {
    if (errorMessage == nil) {
        errorMessage = g_pStoreServerConnectFailed;
    }
    UITableView *table = (UITableView *)[self.view viewWithTag:kTagPackTable];
    if (!table.isHidden) {
        [UIAlertView showWithErrorMessage:errorMessage delegate:nil];
        if (self.showMoreButton != nil) {
            self.showMoreButton.hidden = NO;
            [self.showMoreButton setTitle:g_pStoreShowMoreTitle forState:UIControlStateNormal];
            CGPoint centre = self.showMoreButton.center;
            [self.showMoreButton sizeToFit];
            self.showMoreButton.center = centre;
        }
        if (self.showMoreIndicator != nil) {
            self.showMoreIndicator.hidden = NO;
        }
        m_IsLoadingMoreList = NO;
        table.allowsSelection = YES;
        [table reloadData];
    } else {
        [self showError:errorMessage];
        if (self.restoreButton != nil) {
            self.restoreButton.enabled = NO;
        }
        if (self.genreButton != nil) {
            if (self.genrePopoverCtrl.isPopoverVisible) {
                [self.genrePopoverCtrl dismissPopoverAnimated:YES];
            }
            self.genreButton.enabled = NO;
        }
        if (self.topButton != nil) {
            self.topButton.enabled = NO;
        }
    }
}

/** @ghidraAddress 0x1e2f24 */
- (void)packListDownloadNothing:(RBStorePackList *)packList {
    UITableView *table = (UITableView *)[self.view viewWithTag:kTagPackTable];
    if (!table.isHidden) {
        m_IsLoadingMoreList = NO;
        table.allowsSelection = YES;
        [table reloadData];
    } else {
        [self showError:g_pStoreBannerTitle];
    }
}

/** @ghidraAddress 0x1e3018 */
- (void)packViewSelected:(StorePackView *)packView {
    UITableView *table = (UITableView *)[self.view viewWithTag:kTagPackTable];
    if (table.allowsSelection) {
        int packID = self.currentGenre.packIDList[packView.index].intValue;
        [self openPackDetailViewWithPackId:packID];
    }
}

#pragma mark - Table view data source and delegate

/** @ghidraAddress 0x1e9628 */
- (NSInteger)numPackRows {
    NSInteger packCount = self.currentGenre.packCount;
    if (GetFontVariantFlag() == kFontVariantDefault) {
        return packCount;
    }
    // The pad packs two packs per row, so it needs half as many rows (rounded up).
    return (packCount + 1) >> 1;
}

/** @ghidraAddress 0x1e96b4 */
- (UITableViewCell *)tableView:(UITableView *)tableView
         cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    NSArray<NSNumber *> *packIDList = self.currentGenre.packIDList;

    if (GetFontVariantFlag() == kFontVariantDefault) {
        if (indexPath.section == kStoreSectionPromotion) {
            StorePromotionTableCell *cell =
                [tableView dequeueReusableCellWithIdentifier:kStorePromotionCellID];
            if (cell == nil) {
                cell = [[StorePromotionTableCell alloc] initWithStyle:UITableViewCellStyleDefault
                                                      reuseIdentifier:kStorePromotionCellID];
            }
            [cell.contentView addSubview:self.promotionView];
            return cell;
        }

        if (indexPath.section == kStoreSectionSampleLabel) {
            StorePromotionTableCell *cell =
                [tableView dequeueReusableCellWithIdentifier:kStorePromotionSampleLabelCellID];
            if (cell == nil) {
                cell = [[StorePromotionTableCell alloc]
                      initWithStyle:UITableViewCellStyleDefault
                    reuseIdentifier:kStorePromotionSampleLabelCellID];
            }
            [cell.contentView addSubview:self.sampleMusicLabel];
            self.sampleMusicLabel.frame = CGRectMake(kSampleLabelInsetLeft,
                                                     0.0,
                                                     cell.frame.size.width - kSampleLabelInsetRight,
                                                     kSampleSectionHeight);
            [cell.contentView addSubview:self.samplePlayButton];
            self.samplePlayButton.frame = CGRectMake(cell.frame.size.width - kSamplePlayButtonWidth,
                                                     0.0,
                                                     kSamplePlayButtonWidth,
                                                     kSampleSectionHeight);
            return cell;
        }

        if (indexPath.row < [self numPackRows]) {
            UIImage *placeholder = [UIImage imageWithName:kStoreDefaultJacketImageName];
            StorePackCell *cell =
                [tableView dequeueReusableCellWithIdentifier:kStorePacklistCellID];
            if (cell == nil) {
                cell = [[StorePackCell alloc] initWithStyle:UITableViewCellStyleDefault
                                            reuseIdentifier:kStorePacklistCellID];
            }
            int packID = packIDList[indexPath.row].intValue;
            StorePackInfo *packInfo = [self.packListCtrl getPackInfo:packID];
            [cell loadPackInfo:packInfo];
            UIImage *artwork = [self artworkImageForPackInfo:packInfo
                                                   indexPath:indexPath
                                            forcingNonRetina:YES];
            cell.artworkView.contents =
                (__bridge id)(artwork != nil ? artwork.CGImage : placeholder.CGImage);
            return cell;
        }

        UITableViewCell *cell =
            [tableView dequeueReusableCellWithIdentifier:kStorePacklistMoreCellID];
        if (cell == nil) {
            cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault
                                          reuseIdentifier:kStorePacklistMoreCellID];
            CGFloat fontSize = (GetFontVariantFlag() == kFontVariantDefault) ?
                                   kMoreCellFontSizePhone :
                                   kMoreCellFontSizePad;
            cell.textLabel.font = [UIFont boldSystemFontOfSize:fontSize];
            cell.textLabel.textAlignment = NSTextAlignmentCenter;
        }
        [self configureMoreCell:cell];
        return cell;
    }

    // Pad layout: a single section, two packs per row.
    if (indexPath.row < [self numPackRows]) {
        NSString *reuseID =
            (indexPath.row & 1) ? kStorePacklistCellOddID : kStorePacklistCellEvenID;
        StoreTableCell *cell = [tableView dequeueReusableCellWithIdentifier:reuseID];
        if (cell == nil) {
            cell = [[StoreTableCell alloc] initWithStyle:UITableViewCellStyleDefault
                                         reuseIdentifier:reuseID];
            cell.leftPackView.delegate = self;
            cell.rightPackView.delegate = self;
            cell.leftPackView.bgImage = (indexPath.row & 1) ? self.packBgImage1 : self.packBgImage0;
            cell.rightPackView.bgImage =
                (indexPath.row & 1) ? self.packBgImage1 : self.packBgImage0;
        }

        int leftPackID = packIDList[indexPath.row << 1].intValue;
        StorePackInfo *leftInfo = [self.packListCtrl getPackInfo:leftPackID];
        [cell.leftPackView loadPackInfo:leftInfo index:(indexPath.row << 1)];
        NSIndexPath *leftIndexPath = [NSIndexPath indexPathForRow:(indexPath.row << 1)
                                                        inSection:indexPath.section];
        cell.leftPackView.artwork = [self artworkImageForPackInfo:leftInfo
                                                        indexPath:leftIndexPath
                                                 forcingNonRetina:NO];

        if ((NSInteger)((indexPath.row << 1) | 1) < (NSInteger)packIDList.count) {
            cell.rightPackView.hidden = NO;
            int rightPackID = packIDList[(indexPath.row << 1) | 1].intValue;
            StorePackInfo *rightInfo = [self.packListCtrl getPackInfo:rightPackID];
            [cell.rightPackView loadPackInfo:rightInfo index:((indexPath.row << 1) | 1)];
            NSIndexPath *rightIndexPath = [NSIndexPath indexPathForRow:((indexPath.row << 1) | 1)
                                                             inSection:indexPath.section];
            cell.rightPackView.artwork = [self artworkImageForPackInfo:rightInfo
                                                             indexPath:rightIndexPath
                                                      forcingNonRetina:NO];
        } else {
            cell.rightPackView.hidden = YES;
        }
        return cell;
    }

    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:kStorePacklistMoreCellID];
    if (cell == nil) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault
                                      reuseIdentifier:kStorePacklistMoreCellID];
        CGFloat fontSize = (GetFontVariantFlag() == kFontVariantDefault) ? kMoreCellFontSizePhone :
                                                                           kMoreCellFontSizePad;
        cell.textLabel.font = [UIFont boldSystemFontOfSize:fontSize];
        cell.textLabel.textAlignment = NSTextAlignmentCenter;
    }
    [self configureMoreCell:cell];
    return cell;
}

- (UIImage *)artworkImageForPackInfo:(StorePackInfo *)packInfo
                           indexPath:(NSIndexPath *)indexPath
                    forcingNonRetina:(BOOL)forcingNonRetina {
    ImageDownloader *downloader = self.artworkDownloaders[@(packInfo.packID)];
    if (downloader != nil) {
        return [downloader getImage];
    }
    if (packInfo.artworkURL == nil) {
        return nil;
    }
    ImageDownloader *newDownloader = [[ImageDownloader alloc] init];
    newDownloader.imageURL = packInfo.artworkURL;
    newDownloader.indexPathInTableView = indexPath;
    newDownloader.delegate = self;
    // The phone single-pack path forces non-Retina artwork; the pad two-up path does not.
    if (forcingNonRetina) {
        newDownloader.unUseRetina = YES;
    }
    self.artworkDownloaders[@(packInfo.packID)] = newDownloader;
    [newDownloader startDownload];
    return nil;
}

- (void)configureMoreCell:(UITableViewCell *)cell {
    if (!m_IsLoadingMoreList) {
        cell.accessoryView = nil;
        cell.textLabel.textColor = [UIColor colorWithWhite:kMoreCellTextWhiteIdle alpha:1.0];
        cell.textLabel.shadowColor = [UIColor colorWithWhite:kMoreCellShadowWhite alpha:1.0];
        cell.textLabel.text = g_pStoreShowMoreTitle;
    } else {
        UIActivityIndicatorView *indicator =
            [[UIActivityIndicatorView alloc] initWithFrame:CGRectZero];
        indicator.activityIndicatorViewStyle = UIActivityIndicatorViewStyleGray;
        cell.accessoryView = indicator;
        [indicator startAnimating];
        cell.textLabel.textColor = [UIColor colorWithWhite:kMoreCellTextWhiteLoading alpha:1.0];
        cell.textLabel.shadowColor = nil;
        cell.textLabel.text = g_pStoreLoadingTitle;
    }
}

/** @ghidraAddress 0x1eb708 */
- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    if (GetFontVariantFlag() == kFontVariantDefault) {
        return kStoreSectionCountPhone;
    }
    return kStoreSectionCountPad;
}

/** @ghidraAddress 0x1eb728 */
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    if (GetFontVariantFlag() == kFontVariantDefault) {
        if (section < kStoreSectionPackList) {
            return 1;
        }
    }
    return [self numPackRows] + (self.packListCtrl.packlistContinued ? 1 : 0);
}

/** @ghidraAddress 0x1eb838 */
- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    if (GetFontVariantFlag() == kFontVariantDefault) {
        if (indexPath.section == kStoreSectionPromotion) {
            return kPromotionSectionHeight;
        }
        if (indexPath.section == kStoreSectionSampleLabel) {
            return kSampleSectionHeight;
        }
        return (indexPath.row < [self numPackRows]) ? kPackRowHeightPhone : kMoreRowHeightPhone;
    }
    return (indexPath.row < [self numPackRows]) ? kPackRowHeightPad : kMoreRowHeightPad;
}

/** @ghidraAddress 0x1eb954 */
- (void)tableView:(UITableView *)tableView
      willDisplayCell:(UITableViewCell *)cell
    forRowAtIndexPath:(NSIndexPath *)indexPath {
    if (GetFontVariantFlag() == kFontVariantDefault) {
        if (indexPath.section == kStoreSectionPromotion ||
            indexPath.section == kStoreSectionSampleLabel) {
            return;
        }
        if (indexPath.row < [self numPackRows]) {
            StorePackCell *packCell = (StorePackCell *)cell;
            packCell.bgImage = (indexPath.row & 1) ? self.packBgImage1 : self.packBgImage0;
            CGFloat white = (indexPath.row & 1) ? kPackRowTintOddWhite : kPackRowTintEvenWhite;
            packCell.bgColor = [UIColor colorWithRed:white green:white blue:white alpha:1.0];
        } else {
            cell.backgroundColor = [UIColor colorWithWhite:kPadMoreRowGreyWhite alpha:1.0];
        }
        return;
    }
    if (indexPath.row < [self numPackRows]) {
        cell.backgroundColor = [UIColor colorWithWhite:kPadPackRowTintWhite alpha:1.0];
    } else {
        cell.backgroundColor = [UIColor colorWithWhite:kPadMoreRowGreyWhite alpha:1.0];
    }
}

/** @ghidraAddress 0x1ebc90 */
- (NSIndexPath *)tableView:(UITableView *)tableView
    willSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    if (indexPath.section == kStoreSectionSampleLabel) {
        return nil;
    }
    return indexPath;
}

/** @ghidraAddress 0x1ebcfc */
- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    // The guard is an exact equality against numPackRows (the trailing "more" row), not a >=.
    if (indexPath.row == [self numPackRows]) {
        return;
    }
    if (GetFontVariantFlag() != kFontVariantDefault) {
        return;
    }
    if (indexPath.section == kStoreSectionSampleLabel) {
        return;
    }
    int packID = self.currentGenre.packIDList[indexPath.row].intValue;
    [self showDetailViewForPhone:packID];
}

/** @ghidraAddress 0x1ec078 */
- (void)selectShowMore {
    if (m_IsLoadingMoreList) {
        return;
    }
    m_IsLoadingMoreList = YES;

    [self.showMoreButton setTitle:g_pStoreLoadingTitle forState:UIControlStateNormal];
    CGPoint centre = self.showMoreButton.center;
    [self.showMoreButton sizeToFit];
    self.showMoreButton.center = centre;

    self.showMoreIndicator.hidden = NO;
    [self.view viewWithTag:kTagShowMoreOverlay].hidden = YES;

    [self.packListCtrl startFetchGenre:self.currentGenre];
}

/** @ghidraAddress 0x1ec5f0 */
- (void)scrollViewDidScroll:(UIScrollView *)scrollView {
    // Kick off the next-page fetch when the list is scrolled near its content bottom and more is
    // available.
    if (!m_IsLoadingMoreList && (int)self.packListCtrl.packlistContinued != 0) {
        CGFloat offsetY = scrollView.contentOffset.y;
        CGFloat boundsHeight = scrollView.bounds.size.height;
        CGFloat contentHeight = scrollView.contentSize.height;
        if (offsetY < contentHeight + boundsHeight) {
            [self selectShowMore];
        }
    }

    // Pin the first floating banner inside the visible region as the user scrolls.
    CGFloat bannerHeight =
        (GetFontVariantFlag() == kFontVariantDefault) ? kBannerHeightPhone : kBannerHeightPad;
    UIView *bannerContainer = [self.view viewWithTag:kTagPackTable];
    UIView *firstBanner = [bannerContainer viewWithTag:kTagFunBanner];
    CGRect bannerFrame = firstBanner.frame;
    CGFloat contentBottom = bannerContainer.contentSize.height;
    CGFloat containerOriginY = bannerContainer.bounds.origin.y;
    CGFloat newY;
    if (containerOriginY <= contentBottom) {
        CGFloat offsetY = scrollView.contentOffset.y;
        CGFloat viewportHeight = scrollView.bounds.size.height;
        newY = contentBottom + bannerHeight;
        if (bannerFrame.size.height + newY < containerOriginY + offsetY) {
            newY = (newY + offsetY) - viewportHeight;
        }
    } else {
        CGFloat offsetY = scrollView.contentOffset.y;
        newY = contentBottom + bannerHeight;
        if (bannerFrame.size.height + newY < offsetY + containerOriginY) {
            newY = (newY + containerOriginY) - contentBottom;
        }
    }
    bannerFrame.origin.y = newY;
    firstBanner.frame = bannerFrame;

    // The second floating banner only exists during the March-2017 Hinabita campaign.
    if (![RBCampaignData sharedInstance].isCampaignHinabita201703) {
        return;
    }
    UIView *container2 = [self.view viewWithTag:kTagPackTable];
    UIView *secondBanner = [container2 viewWithTag:kTagCampaignBanner];
    CGFloat bannerHeight2 =
        (GetFontVariantFlag() == kFontVariantDefault) ? kBannerHeightPhone : kBannerHeightPad;
    CGRect frame2 = secondBanner.frame;
    CGFloat contentBottom2 = container2.contentSize.height;
    CGFloat containerOriginY2 = container2.bounds.origin.y;
    CGFloat newY2;
    if (frame2.origin.y <= contentBottom2) {
        newY2 = contentBottom2 + bannerHeight2;
        if (frame2.size.height + containerOriginY2 <=
            newY2 + scrollView.bounds.size.height * kCenterScale) {
            secondBanner.frame = frame2;
            return;
        }
        newY2 = (newY2 + containerOriginY2) - scrollView.bounds.size.height * kCenterScale;
    } else {
        CGFloat offsetY = scrollView.contentOffset.y;
        newY2 = frame2.origin.y + bannerHeight2;
        if (contentBottom2 + offsetY <= newY2 + scrollView.bounds.size.height * kCenterScale) {
            secondBanner.frame = frame2;
            return;
        }
        newY2 = (newY2 + contentBottom2) - scrollView.bounds.size.height * kCenterScale;
    }
    frame2.origin.y = newY2;
    secondBanner.frame = frame2;
}

#pragma mark - Detail view

/** @ghidraAddress 0x1e26d0 */
- (void)forceOpenPackDetailView {
    if ([AppDelegate appDelegate].packIDForOpenStore == nil) {
        return;
    }
    int packId = [AppDelegate appDelegate].packIDForOpenStore.intValue;
    StorePackInfo *packInfo = [self.packListCtrl getPackInfo:packId];
    if (packInfo == nil) {
        [self.packListCtrl optionalProductsRequest];
        return;
    }
    if (GetFontVariantFlag() != kFontVariantDefault) {
        [self.packDetailViewPad cancelLoading];
        [self.packDetailViewPad stopSample];
        self.coverViewPad.alpha = kDetailAlphaHidden;
        self.packDetailViewPad.alpha = kDetailAlphaHidden;
        self.coverViewPad.hidden = YES;
        self.packDetailViewPad.hidden = YES;
        [self.packDetailViewPad removePackInfo];
        [self openPackDetailViewWithPackId:packId];
    } else {
        [self.navigationController popViewControllerAnimated:NO];
        [self showDetailViewForPhone:packId];
    }
}

/** @ghidraAddress 0x1e31ac */
- (void)openPackDetailViewWithPackId:(int)packId {
    if (self.promotionView != nil) {
        [self.promotionView stopAnimation];
        [self.promotionView stopSamplePlay];
        self.promotionView.isSamplePlayable = NO;
    }
    if (self.restoreButton != nil) {
        self.restoreButton.enabled = NO;
    }
    if (self.genreButton != nil) {
        if (self.genrePopoverCtrl.isPopoverVisible) {
            [self dismissViewControllerAnimated:YES completion:nil];
        }
        self.genreButton.enabled = NO;
    }
    if (self.topButton != nil) {
        self.topButton.enabled = NO;
    }
    [[UIApplication sharedApplication] beginIgnoringInteractionEvents];
    self.coverViewPad.alpha = kDetailAlphaHidden;
    self.packDetailViewPad.alpha = kDetailAlphaHidden;
    self.coverViewPad.hidden = NO;
    self.packDetailViewPad.hidden = NO;
    [UIView animateWithDuration:kDetailAnimDuration
        delay:0.0
        options:UIViewAnimationOptionCurveEaseInOut
        animations:^{
          /** @ghidraAddress 0x1e35fc */
          self.coverViewPad.alpha = kDetailAlphaVisible;
          self.packDetailViewPad.alpha = kDetailAlphaVisible;
        }
        completion:^(BOOL finished) {
          /** @ghidraAddress 0x1e36b4 */
          self.packDetailViewPad.packInfo = [self.packListCtrl getPackInfo:packId];
          [self.packDetailViewPad loadInfo];
          [AppDelegate appDelegate].packIDForOpenStore = nil;
          [[UIApplication sharedApplication] endIgnoringInteractionEvents];
        }];
}

/** @ghidraAddress 0x1e3848 */
- (void)openDetailAnimStop:(NSString *)animationID
                  finished:(NSNumber *)finished
                   context:(void *)context {
    // The animation context is the tapped cell, which carries the list index of the pack.
    NSInteger index = [(__bridge StorePackView *)context index];
    int packId = self.currentGenre.packIDList[index].intValue;
    self.packDetailViewPad.packInfo = [self.packListCtrl getPackInfo:packId];
    [self.packDetailViewPad loadInfo];
    [[UIApplication sharedApplication] endIgnoringInteractionEvents];
}

/** @ghidraAddress 0x1e41a8 */
- (void)openDetailAnimStopFromPromotion:(NSString *)animationID
                               finished:(NSNumber *)finished
                                context:(void *)context {
    int packId = [self.promotionView getPackID];
    self.packDetailViewPad.packInfo = [self.packListCtrl getPackInfo:packId];
    [self.packDetailViewPad loadInfo];
    [[UIApplication sharedApplication] endIgnoringInteractionEvents];
}

/** @ghidraAddress 0x1ebe6c */
- (void)showDetailViewForPhone:(int)packID {
    RBStoreDetailViewController *detail = [[RBStoreDetailViewController alloc] init];
    detail.delegate = self;
    detail.packInfo = [self.packListCtrl getPackInfo:packID];

    [AppDelegate appDelegate].packIDForOpenStore = nil;

    self.promotionView.isSamplePlayable = NO;
    [self.promotionView stopSamplePlay];
    [self.promotionView stopAnimation];

    [self.navigationController pushViewController:detail animated:YES];
}

/** @ghidraAddress 0x1e55cc */
- (void)detailViewClose {
    if (m_IsPad) {
        [self handleTapCoverView:nil];
        return;
    }
    [self.navigationController popViewControllerAnimated:YES];
}

#pragma mark - Promotion and cover

/** @ghidraAddress 0x1e3a48 */
- (void)storePromotionViewTaped:(StorePromotionView *)promotionView PackID:(int)packId {
    if (packId < 0) {
        return;
    }
    if (GetFontVariantFlag() == kFontVariantDefault) {
        [self showDetailViewForPhone:packId];
        return;
    }
    [promotionView stopAnimation];
    [promotionView stopSamplePlay];
    promotionView.isSamplePlayable = YES;
    if (self.restoreButton != nil) {
        self.restoreButton.enabled = NO;
    }
    if (self.genreButton != nil) {
        if (self.genrePopoverCtrl.isPopoverVisible) {
            [self.genrePopoverCtrl dismissPopoverAnimated:YES];
        }
        self.genreButton.enabled = NO;
    }
    if (self.topButton != nil) {
        self.topButton.enabled = NO;
    }
    UITableView *table = (UITableView *)[self.view viewWithTag:kTagPackTable];
    if (table.allowsSelection) {
        [[UIApplication sharedApplication] beginIgnoringInteractionEvents];
        self.coverViewPad.alpha = kDetailAlphaHidden;
        self.packDetailViewPad.alpha = kDetailAlphaHidden;
        self.coverViewPad.hidden = NO;
        self.packDetailViewPad.hidden = NO;
        [UIView beginAnimations:nil context:nullptr];
        [UIView setAnimationCurve:UIViewAnimationCurveEaseInOut];
        [UIView setAnimationDuration:kDetailAnimDuration];
        [UIView setAnimationDelegate:self];
        SEL didStop = @selector(openDetailAnimStopFromPromotion:finished:context:);
        [UIView setAnimationDidStopSelector:didStop];
        self.coverViewPad.alpha = kDetailAlphaVisible;
        self.packDetailViewPad.alpha = kDetailAlphaVisible;
        [UIView commitAnimations];
    }
}

/** @ghidraAddress 0x1e432c */
- (void)handleTapCoverView:(UIGestureRecognizer *)sender {
    [[UIApplication sharedApplication] beginIgnoringInteractionEvents];
    [self.packDetailViewPad cancelLoading];
    [self.packDetailViewPad stopSample];
    [UIView animateWithDuration:kCoverFadeDuration
        animations:^{
          /** @ghidraAddress 0x1e44c4 */
          self.coverViewPad.alpha = kDetailAlphaHidden;
          self.packDetailViewPad.alpha = kDetailAlphaHidden;
        }
        completion:^(BOOL finished) {
          /** @ghidraAddress 0x1e457c */
          self.coverViewPad.hidden = YES;
          self.packDetailViewPad.hidden = YES;
          [self.packDetailViewPad removePackInfo];
          [[UIApplication sharedApplication] endIgnoringInteractionEvents];
          if (self.promotionView != nil) {
              self.promotionView.isSamplePlayable = YES;
              [self.promotionView startAnimation];
          }
          if (self.restoreButton != nil) {
              self.restoreButton.enabled = YES;
          }
          if (self.genreButton != nil) {
              self.genreButton.enabled = YES;
          }
          if (self.topButton != nil) {
              self.topButton.enabled = YES;
          }
        }];
}

/** @ghidraAddress 0x1eec14 */
- (void)stopPromotion {
    if (self.promotionView != nil) {
        [self.promotionView cancel];
    }
}

/** @ghidraAddress 0x1ef76c */
- (void)switchToSpecialStore {
    [self.parent forceOpen];
}

#pragma mark - Sample playback

/** @ghidraAddress 0x1e3f3c */
- (void)pushSampleButton:(id)sender {
    if ([RBUserSettingData sharedInstance].refuseStoreSampleBGM) {
        [RBUserSettingData sharedInstance].refuseStoreSampleBGM = NO;
        [self.samplePlayButton setImage:self.stopImage forState:UIControlStateNormal];
        self.sampleMusicLabel.text = kStoreEmptyTitle;
        [self.promotionView stopSamplePlay];
    } else {
        [RBUserSettingData sharedInstance].refuseStoreSampleBGM = YES;
        [self.samplePlayButton setImage:self.playImage forState:UIControlStateNormal];
        [self.promotionView startSamplePlay];
    }
}

/** @ghidraAddress 0x1eeb58 */
- (void)setPlaySampleName:(NSString *)name {
    if (name == nil) {
        self.sampleMusicLabel.text = kStoreEmptyTitle;
    } else {
        self.sampleMusicLabel.text = name;
    }
}

#pragma mark - Genre select

/** @ghidraAddress 0x1ede24 */
- (void)switchToGenre:(NSNumber *)genreIndexNumber {
    NSUInteger genreIndex = genreIndexNumber.unsignedIntegerValue;
    if (self.packDetailViewPad.packInfo != nil) {
        [self handleTapCoverView:nil];
    }
    StorePackListGenre *genre = [self.packListCtrl packListForGenreIndex:genreIndex];
    UITableView *tableView = (UITableView *)[self.view viewWithTag:kTagPackTable];
    if (self.currentGenre == genre) {
        if (self.currentGenre.packCount == 0 && !self.packListCtrl.isFetching) {
            [self showLoadingView];
            [self.packListCtrl startFetchGenre:self.currentGenre];
        }
    } else {
        [self.packListCtrl cancelFetching];
        self.currentGenre = genre;
        if (self.currentGenre.packCount == 0) {
            [self showLoadingView];
            [self.packListCtrl startFetchGenre:self.currentGenre];
        } else {
            [tableView reloadData];
            [tableView scrollRectToVisible:CGRectMake(0.0, 0.0, tableView.frame.size.width, 0.0)
                                  animated:NO];
        }
        if (genreIndex == 0) {
            self.genreButton.title = [[NSBundle mainBundle] localizedStringForKey:kStoreCategoryKey
                                                                            value:kStoreEmptyTitle
                                                                            table:nil];
        } else {
            self.genreButton.title = genre.genreName;
        }
    }
}

/** @ghidraAddress 0x1ee3ac */
- (void)presentGenreSelect:(id)sender {
    if (GetFontVariantFlag() == kFontVariantDefault) {
        [self.navigationController pushViewController:self.genreViewCtrl animated:YES];
    } else {
        if (self.genrePopoverCtrl.isPopoverVisible) {
            [self.genrePopoverCtrl dismissPopoverAnimated:YES];
        } else {
            [self.genrePopoverCtrl presentPopoverFromBarButtonItem:sender
                                          permittedArrowDirections:UIPopoverArrowDirectionUp
                                                          animated:YES];
            self.navigationItem.leftBarButtonItem.enabled = NO;
            self.restoreButton.enabled = NO;
            self.topButton.enabled = NO;
        }
    }
}

/** @ghidraAddress 0x1ee610 */
- (void)hideGenreSelect:(id)sender {
    if (GetFontVariantFlag() == kFontVariantDefault) {
        [self.navigationController popViewControllerAnimated:YES];
    } else {
        [self.genrePopoverCtrl dismissPopoverAnimated:YES];
    }
    self.navigationItem.leftBarButtonItem.enabled = YES;
    self.restoreButton.enabled = YES;
    self.topButton.enabled = YES;
}

/** @ghidraAddress 0x1eeca8 */
- (void)popoverControllerDidDismissPopover:(UIPopoverController *)popoverController {
    self.navigationItem.leftBarButtonItem.enabled = YES;
    self.restoreButton.enabled = YES;
    self.topButton.enabled = YES;
}

/** @ghidraAddress 0x1ee7a4 */
- (void)showLoadingView {
    UITableView *tableView = (UITableView *)[self.view viewWithTag:kTagPackTable];
    UIView *loadingLabel = [self.view viewWithTag:kTagLoadingLabel];
    UIView *loadingSpinnerHost = [tableView viewWithTag:kTagShowMoreOverlay];
    if (tableView != nil) {
        tableView.hidden = YES;
        tableView.allowsSelection = NO;
        [tableView scrollRectToVisible:CGRectMake(0.0, 0.0, tableView.frame.size.width, 0.0)
                              animated:NO];
    }
    if (loadingLabel != nil) {
        loadingLabel.hidden = NO;
    }
    if (loadingSpinnerHost != nil) {
        loadingSpinnerHost.hidden = YES;
    }
    if (self.packTableLabel != nil) {
        self.packTableLabel.hidden = YES;
    }
    m_IsLoadingMoreList = NO;
    if (self.restoreButton != nil) {
        self.restoreButton.enabled = NO;
    }
    if (self.topButton != nil) {
        self.topButton.enabled = NO;
    }
    if (self.showMoreButton != nil) {
        self.showMoreButton.hidden = YES;
    }
    if (self.showMoreIndicator != nil) {
        self.showMoreIndicator.hidden = YES;
    }
}

/** @ghidraAddress 0x1ef324 */
- (void)goToTop:(id)sender {
    UITableView *table = (UITableView *)[self.view viewWithTag:kTagPackTable];
    if (table != nil) {
        NSIndexPath *top = [NSIndexPath indexPathForRow:0 inSection:0];
        [table scrollToRowAtIndexPath:top
                     atScrollPosition:UITableViewScrollPositionTop
                             animated:YES];
    }
}

#pragma mark - Purchase

/** @ghidraAddress 0x1e50ac */
- (BOOL)checkAttainLimitPurchase:(SKProduct *)product {
    int total = [RBUserSettingData sharedInstance].totalPurchase;
    int limitType = [RBUserSettingData sharedInstance].purchaseLimitType;
    int limit = (limitType < 3) ? kPurchaseLimitAmounts[limitType] : kPurchaseLimitNone;
    // Only JPY prices are added to the running total; other currencies never trip the limit.
    if ([product.priceLocale[NSLocaleCurrencyCode] isEqualToString:kCurrencyCodeJPY]) {
        total += product.price.intValue;
    }
    BOOL limited = NO;
    if (limit >= 0 && limit < total) {
        if (limitType == kPurchaseLimitTypeUnset) {
            self.purchaseLimitTypeSelectView =
                [UIAlertView showSelectPurchaseLimitTypeWithDelegate:self];
            self.purchaseLimitTypeSelectView.tag = kAlertTagPurchaseLimitTypeSelect;
        } else {
            [UIAlertView showPurchaseOverMessageWithDelegate:self];
        }
        limited = YES;
    }
    return limited;
}

/** @ghidraAddress 0x1e52f8 */
- (void)detailViewStartPurchase:(StorePackInfo *)packInfo {
    if (![RBPurchaseManager isPurchasable] || packInfo.product == nil) {
        [UIAlertView showWithErrorMessage:g_pStorePurchaseFailedMessage delegate:nil];
        return;
    }
    self.purchasingPackInfo = packInfo;
    if (![self checkAttainLimitPurchase:packInfo.product]) {
        StoreDialogView *dialog = self.parent.modalDialog;
        [dialog layout:YES];
        dialog.labelMessage.text = g_pStorePurchasingMessage;
        [self.parent showModalDialog:self];
        [RBPurchaseManager sharedManager].delegate = self;
        [[RBPurchaseManager sharedManager] beginPurchase:packInfo.product];
    }
}

/** @ghidraAddress 0x1e0c40 */
- (void)sendUserAge {
    NSArray *serverData = [AppDelegate getServerData];
    NSDictionary *body = @{
        @"target" : GetRegionCode(),
        @"app_ver" : GetBundleVersionString(),
        @"user_id" : serverData[0],
        @"type" :
            [NSString stringWithFormat:@"%d", [RBUserSettingData sharedInstance].purchaseLimitType],
    };
    NSData *json = [Downloader dictionaryToJsonData:body];
    self.userAgeSender = [[Downloader alloc] initWithURL:[StoreUtil userAgeURL]
                                                    post:json
                                             contentType:nil];

    __weak RBStorePageViewController *weakSelf = self;
    [self.userAgeSender
        startDownloadingWithProceed:^(Downloader *downloader) {
          /** @ghidraAddress 0x10035f6c0 */
          // The proceed callback is the shared empty global block; nothing to do.
        }
        success:^(Downloader *downloader) {
          /** @ghidraAddress 0x1e10ac */
          RBStorePageViewController *strongSelf = weakSelf;
          id response = [downloader getDataInJSON];
          NSNumber *status = response[@"status"];
          if (status != nil && status.intValue == kAgeVerifyStatusOK) {
              [strongSelf performSelectorOnMainThread:@selector(detailViewStartPurchase:)
                                           withObject:strongSelf.purchasingPackInfo
                                        waitUntilDone:NO];
          } else {
              dispatch_async(dispatch_get_main_queue(), ^{
                /** @ghidraAddress 0x1e12c0 */
                UIAlertView *alert = [UIAlertView showNetworkErrorWithDelegate:weakSelf];
                alert.tag = kAlertTagUserAgeConfirm;
              });
          }
          strongSelf.userAgeSender = nil;
        }
        failure:^(Downloader *downloader) {
          /** @ghidraAddress 0x1e137c */
          dispatch_async(dispatch_get_main_queue(), ^{
            /** @ghidraAddress 0x1e12c0 */
            UIAlertView *alert = [UIAlertView showNetworkErrorWithDelegate:weakSelf];
            alert.tag = kAlertTagUserAgeConfirm;
          });
          weakSelf.userAgeSender = nil;
        }];
}

#pragma mark - Purchase result

/** @ghidraAddress 0x1e60c4 */
- (void)purchaseSucceeded:(NSString *)productID {
    int packID = [StoreUtil packIDForProductID:productID];
    if (packID != self.purchasingPackInfo.packID) {
        return;
    }
    [self updateMusicInfo:self.purchasingPackInfo Save:YES];
    [[RBPurchaseManager sharedManager] addProductID:productID Save:YES];
    [RBPurchaseManager sharedManager].delegate = nil;
    [self updatePurchasedTableCell:self.purchasingPackInfo];

    SKProduct *product = self.purchasingPackInfo.product;
    if ([product.priceLocale[NSLocaleCurrencyCode] isEqualToString:kCurrencyCodeJPY]) {
        int price = product.price.intValue;
        int total = [RBUserSettingData sharedInstance].totalPurchase;
        [RBUserSettingData sharedInstance].totalPurchase = total + price;
    }
    [[RBUserSettingData sharedInstance] save];
    [self.parent.campaignViewCtrl refreshUnlockTable];
    [self startDownloadPackMusics:self.purchasingPackInfo];
}

/** @ghidraAddress 0x1e6564 */
- (void)purchaseFailed:(NSString *)productID error:(NSError *)error {
    // The productID argument is ignored; only the error message is used.
    [RBPurchaseManager sharedManager].delegate = nil;
    self.purchasingPackInfo = nil;
    [self.parent hideModalDialog];
    NSString *message =
        [[NSString alloc] initWithFormat:kStoreErrorFormat, error.localizedDescription];
    [UIAlertView showWithErrorMessage:message delegate:nil];
}

#pragma mark - Download

/** @ghidraAddress 0x1e4858 */
- (void)startDownloadPackMusics:(StorePackInfo *)packInfo {
    NSArray<StoreMusicInfo *> *musicInfos = packInfo.musicInfos;
    if (packInfo == nil || musicInfos == nil || musicInfos.count == 0) {
        return;
    }
    [self.parent showModalDialog:self];
    if (m_IsPad) {
        [self.packDetailViewPad setButtonTextInstalling];
    } else if ([self.navigationController.topViewController
                   isKindOfClass:[RBStoreDetailViewController class]]) {
        [(RBStoreDetailViewController *)
                self.navigationController.topViewController setButtonTextInstalling];
    }

    NSMutableArray<StoreDownloadTask *> *tasks =
        [NSMutableArray arrayWithCapacity:musicInfos.count];
    for (StoreMusicInfo *info in musicInfos) {
        NSString *destPath = [RBMusicManager getPathFromPurchesed:info.musicID];
        if (![NSFileManager isFileExist:destPath]) {
            StoreDownloadTask *task =
                [[StoreDownloadTask alloc] initWithURL:info.itemURL
                                                  path:destPath
                                             AddObject:[NSString stringWithString:info.name]];
            [tasks addObject:task];
        }
    }

    if (tasks.count == 0) {
        if (m_IsPad) {
            [self.packDetailViewPad setButtonTextInstalled];
        } else if ([self.navigationController.topViewController
                       isKindOfClass:[RBStoreDetailViewController class]]) {
            [(RBStoreDetailViewController *)
                    self.navigationController.topViewController setButtonTextInstalled];
        }
        [self.parent hideModalDialog];
    } else {
        self.downloadManager = [[StoreDownloadManager alloc] initWithTasks:tasks delegate:self];
        StoreDialogView *dialog = self.parent.modalDialog;
        [dialog layout:NO];
        dialog.labelMessage.text = kStoreDownloadDialogMessage;
        [self.downloadManager start];
    }
}

/** @ghidraAddress 0x1e6058 */
- (void)reDownloadPackMusics:(StorePackInfo *)packInfo {
    [self updateMusicInfo:packInfo Save:YES];
    [self startDownloadPackMusics:packInfo];
}

#pragma mark - Music info bookkeeping

/** @ghidraAddress 0x1e5890 */
- (void)updateMusicInfo:(StorePackInfo *)packInfo Save:(BOOL)save {
    NSArray<StoreMusicInfo *> *musicInfos = packInfo.musicInfos;
    if (packInfo == nil || musicInfos == nil || musicInfos.count == 0) {
        return;
    }
    for (StoreMusicInfo *info in musicInfos) {
        [[RBMusicManager getInstance] addPurchasedMusic:info];
    }
    if (save) {
        [[RBMusicManager getInstance] savePurchasedMusics];
    }
}

/** @ghidraAddress 0x1ef7c0 */
- (void)updateExtendNoteInfo:(StoreExtendNoteInfo *)info Save:(BOOL)save {
    if (info == nil) {
        return;
    }
    [[RBExtendNoteManager getInstance] addPurchasedExtendNote:info];
    if (save) {
        [[RBExtendNoteManager getInstance] savePurchasedNotes];
    }
}

/** @ghidraAddress 0x1e5ad8 */
- (void)updatePurchasedTableCell:(StorePackInfo *)packInfo {
    NSArray<NSNumber *> *packIDList = self.currentGenre.packIDList;
    if (m_IsPad) {
        // Pad: single-section pack table; two packs share a row, so row = packIndex / 2.
        for (NSUInteger i = 0; i < packIDList.count; ++i) {
            if (packIDList[i].intValue == packInfo.packID) {
                UITableView *table = (UITableView *)[self.view viewWithTag:kTagPackTable];
                NSIndexPath *indexPath = [NSIndexPath indexPathForRow:((int)i >> 1)
                                                            inSection:kStoreSectionPromotion];
                [table reloadRowsAtIndexPaths:@[ indexPath ]
                             withRowAnimation:UITableViewRowAnimationNone];
                return;
            }
        }
        return;
    }

    UIViewController *top = self.navigationController.topViewController;
    if ([top isKindOfClass:[RBStoreDetailViewController class]]) {
        [(RBStoreDetailViewController *)top setPurchaseState:1];
        return;
    }
    if (![top isKindOfClass:[RBStorePageViewController class]]) {
        return;
    }
    for (NSUInteger i = 0; i < packIDList.count; ++i) {
        if (packIDList[i].intValue == packInfo.packID) {
            UITableView *table = (UITableView *)[self.view viewWithTag:kTagPackTable];
            NSIndexPath *indexPath = [NSIndexPath indexPathForRow:i
                                                        inSection:kStoreSectionPackList];
            [table reloadRowsAtIndexPaths:@[ indexPath ]
                         withRowAnimation:UITableViewRowAnimationNone];
            return;
        }
    }
}

#pragma mark - Restore

/** @ghidraAddress 0x1e14fc */
- (void)pushBarBtnRestore:(id)sender {
    UIAlertView *alert = [UIAlertView showRestoreMessageWithDelegate:self];
    alert.tag = kAlertTagRestore;
}

/** @ghidraAddress 0x1e66f8 */
- (void)addRestorePackInfo:(StorePackInfo *)packInfo {
    [self.restorePackInfo addObject:packInfo];
    NSString *productID = [StoreUtil productIDForPackID:packInfo.packID];
    if ([self.restoreProductID containsObject:productID]) {
        [self.restoreProductID removeObject:productID];
    }
}

/** @ghidraAddress 0x1ef40c */
- (void)addRestoreExtendNoteInfo:(StoreExtendNoteInfo *)info {
    [self.restoreExtendNoteInfo addObject:info];
    NSString *productID = [StoreUtil pidToProductID:info.pid];
    if ([self.restoreProductID containsObject:productID]) {
        [self.restoreProductID removeObject:productID];
    }
}

/** @ghidraAddress 0x1e6860 */
- (BOOL)nextRestorePackInfo {
    // A snapshot of restoreProductID is iterated because the add… helpers below mutate the live
    // array. YES is returned the moment an async detail download is started (or one entry is handled)
    // so the caller stops and waits for the downloader callback.
    NSArray<NSString *> *productIDs = [NSArray arrayWithArray:self.restoreProductID];
    if (productIDs.count == 0) {
        return NO;
    }
    for (NSString *productID in productIDs) {
        int packID = [StoreUtil packIDForProductID:productID];
        if (packID == -1) {
            // Not a pack; treat it as an extend note.
            StoreExtendNoteInfo *extendInfo = [self.parent.extendNotePageViewCtrl.extendNoteListCtrl
                getExtendNoteInfoWithProductID:[StoreUtil productIDToPid:productID]];
            if (extendInfo == nil) {
                extendInfo = [self.parent.extendNotePageViewCtrl.extendNoteListCtrl
                    addExtendNoteInfoFromProductID:[StoreUtil productIDToPid:productID]];
            }
            if (extendInfo.extendURL != nil) {
                [self addRestoreExtendNoteInfo:extendInfo];
            } else if (self.storeExtendNoteInfoDownloader == nil) {
                StoreExtendNoteInfoDownloader *downloader =
                    [[StoreExtendNoteInfoDownloader alloc] initWithStoreExtendNoteInfo:extendInfo];
                self.storeExtendNoteInfoDownloader = downloader;
                downloader.delegate = self;
                [downloader downloadDetail:NO];
            }
            return YES;
        }

        StorePackInfo *packInfo = [self.packListCtrl getPackInfo:packID];
        if (packInfo == nil) {
            packInfo = [self.packListCtrl addPackInfoFromID:packID];
        }
        if (packInfo.musicInfos == nil) {
            if (self.storePackInfoDownloader == nil) {
                StorePackInfoDownloader *downloader =
                    [[StorePackInfoDownloader alloc] initWithStorePackInfo:packInfo];
                self.storePackInfoDownloader = downloader;
                downloader.delegate = self;
                [downloader downloadDetail:NO];
            }
            return YES;
        }
        [self addRestorePackInfo:packInfo];
    }
    return NO;
}

/** @ghidraAddress 0x1e6f30 */
- (void)askDownloadAllMusics {
    for (StorePackInfo *packInfo in self.restorePackInfo) {
        [self updateMusicInfo:packInfo Save:NO];
    }
    [[RBMusicManager getInstance] savePurchasedMusics];
    [[RBPurchaseManager sharedManager] addProductFromPurchaseCheckedProducts];
    [[RBPurchaseManager sharedManager] clearPurchaseCheckedProducts];
    [self.restoreProductID removeAllObjects];

    for (StorePackInfo *packInfo in self.restorePackInfo) {
        [self updatePurchasedTableCell:packInfo];
    }

    // Count how many restored files are still missing on disk (packs plus extend notes).
    NSInteger missingCount = 0;
    for (StorePackInfo *packInfo in self.restorePackInfo) {
        for (StoreMusicInfo *info in packInfo.musicInfos) {
            NSString *path = [RBMusicManager getPathFromPurchesed:info.musicID];
            if (![NSFileManager isFileExist:path]) {
                ++missingCount;
            }
        }
    }

    for (StoreExtendNoteInfo *info in self.restoreExtendNoteInfo) {
        [self updateExtendNoteInfo:info Save:NO];
    }
    [[RBExtendNoteManager getInstance] savePurchasedNotes];

    for (StoreExtendNoteInfo *info in self.restoreExtendNoteInfo) {
        NSString *path = [RBExtendNoteManager getPathFromPurchased:info.extMusicID];
        if (![NSFileManager isFileExist:path]) {
            ++missingCount;
        }
    }

    if (missingCount < 1) {
        [self.restorePackInfo removeAllObjects];
        [self.restoreExtendNoteInfo removeAllObjects];
        [self.parent hideModalDialog];
    } else {
        UIAlertView *alert = [UIAlertView showRestoreDownloadWithDelegate:self];
        alert.tag = kAlertTagRestoreDownload;
    }
}

/** @ghidraAddress 0x1e7788 */
- (void)restoreDownloadAllMusics {
    NSMutableArray<StoreDownloadTask *> *tasks = [NSMutableArray arrayWithCapacity:0];

    for (StorePackInfo *packInfo in self.restorePackInfo) {
        for (StoreMusicInfo *info in packInfo.musicInfos) {
            NSString *destPath = [RBMusicManager getPathFromPurchesed:info.musicID];
            if (![NSFileManager isFileExist:destPath]) {
                StoreDownloadTask *task =
                    [[StoreDownloadTask alloc] initWithURL:info.itemURL
                                                      path:destPath
                                                 AddObject:[NSString stringWithString:info.name]];
                [tasks addObject:task];
            }
        }
    }
    [self.restorePackInfo removeAllObjects];
    self.restorePackInfo = nil;

    for (StoreExtendNoteInfo *info in self.restoreExtendNoteInfo) {
        NSString *destPath = [RBExtendNoteManager getPathFromPurchased:info.extMusicID];
        if (![NSFileManager isFileExist:destPath]) {
            StoreDownloadTask *task =
                [[StoreDownloadTask alloc] initWithURL:info.extendURL
                                                  path:destPath
                                             AddObject:[NSString stringWithString:info.name]];
            [tasks addObject:task];
        }
    }
    [self.restoreExtendNoteInfo removeAllObjects];
    self.restoreExtendNoteInfo = nil;

    if (tasks.count == 0) {
        [self.parent hideModalDialog];
        [self.promotionView startAnimation];
    } else {
        self.downloadManager = [[StoreDownloadManager alloc] initWithTasks:tasks delegate:self];
        StoreDialogView *dialog = self.parent.modalDialog;
        [dialog layout:NO];
        dialog.labelMessage.text = kStoreDownloadDialogMessage;
        [self.downloadManager start];
    }
}

/** @ghidraAddress 0x1e942c */
- (void)restoreDownloadCancel {
    self.downloadManager = nil;
    [self.parent hideModalDialog];
    [self.promotionView startAnimation];
    if (m_IsPad) {
        [self.packDetailViewPad selfCheckButtonText];
    } else if ([self.navigationController.topViewController
                   isKindOfClass:[RBStoreDetailViewController class]]) {
        [(RBStoreDetailViewController *)
                self.navigationController.topViewController selfCheckButtonText];
    }
}

#pragma mark - Restore result

/** @ghidraAddress 0x1e8748 */
- (void)restoreSucceeded {
    if (self.restorePackInfo != nil) {
        [self.restorePackInfo removeAllObjects];
    }
    self.restorePackInfo = [[NSMutableArray alloc] initWithCapacity:0];
    if (self.restoreExtendNoteInfo != nil) {
        [self.restoreExtendNoteInfo removeAllObjects];
    }
    self.restoreExtendNoteInfo = [[NSMutableArray alloc] initWithCapacity:0];
    if (self.restoreProductID != nil) {
        [self.restoreProductID removeAllObjects];
    }
    self.restoreProductID = [[NSMutableArray alloc]
        initWithArray:[RBPurchaseManager sharedManager].purchaseCheckedProducts];

    if (![self nextRestorePackInfo]) {
        [self askDownloadAllMusics];
        [self.promotionView startAnimation];
    }
    [self.parent.campaignViewCtrl refreshUnlockTable];
}

/** @ghidraAddress 0x1e8a80 */
- (void)restoreFailed:(NSError *)error {
    [self.parent hideModalDialog];
    NSString *message =
        [[NSString alloc] initWithFormat:kStoreErrorFormat, error.localizedDescription];
    [UIAlertView showWithErrorMessage:message delegate:nil];
    [self.promotionView startAnimation];
}

/** @ghidraAddress 0x1e8c00 */
- (void)restoreNothing {
    [self.parent hideModalDialog];
    [self.promotionView startAnimation];
}

#pragma mark - NSURLConnection delegate

/** @ghidraAddress 0x1e5888 */
- (void)connectionDidFinishLoading:(NSURLConnection *)connection {
    // Intentionally empty: a legacy NSURLConnectionDataDelegate stub.
}

/** @ghidraAddress 0x1e588c */
- (void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)error {
    // Intentionally empty: a legacy NSURLConnectionDelegate stub.
}

#pragma mark - Store info downloader delegates

/** @ghidraAddress 0x1e8c9c */
- (void)storePackInfoDownloaderFinished:(StorePackInfoDownloader *)downloader {
    [self addRestorePackInfo:[downloader getPackInfo]];
    if (self.storePackInfoDownloader != nil) {
        self.storePackInfoDownloader.delegate = nil;
        self.storePackInfoDownloader = nil;
    }
    if (![self nextRestorePackInfo]) {
        [self askDownloadAllMusics];
    }
}

/** @ghidraAddress 0x1e8dbc */
- (void)storePackInfoDownloaderError:(StorePackInfoDownloader *)downloader {
    if (self.storePackInfoDownloader != nil) {
        self.storePackInfoDownloader.delegate = nil;
        self.storePackInfoDownloader = nil;
    }
}

/** @ghidraAddress 0x1ef574 */
- (void)storeExtendNoteInfoDownloaderFinished:(StoreExtendNoteInfoDownloader *)downloader {
    [self addRestoreExtendNoteInfo:[downloader getExtendNoteInfo]];
    if (self.storeExtendNoteInfoDownloader != nil) {
        self.storeExtendNoteInfoDownloader.delegate = nil;
        self.storeExtendNoteInfoDownloader = nil;
    }
    if (![self nextRestorePackInfo]) {
        [self askDownloadAllMusics];
    }
}

/** @ghidraAddress 0x1ef694 */
- (void)storeExtendNoteInfoDownloaderError:(StoreExtendNoteInfoDownloader *)downloader {
    if (self.storeExtendNoteInfoDownloader != nil) {
        self.storeExtendNoteInfoDownloader.delegate = nil;
        self.storeExtendNoteInfoDownloader = nil;
    }
    [self.parent hideModalDialog];
}

#pragma mark - Store download manager delegate

/** @ghidraAddress 0x1e8e64 */
- (void)downloadManagerStartTask:(StoreDownloadManager *)manager {
    StoreDownloadTask *task = manager.tasks[manager.currentIndex];
    (void)
        task.addObject; // The binary reads -addObject once for effect, then again for the argument.
    self.parent.modalDialog.labelMessage.text =
        [NSString stringWithFormat:kStoreDownloadingFormat, task.addObject];
}

/** @ghidraAddress 0x1e9058 */
- (void)downloadManagerCompleted:(StoreDownloadManager *)manager {
    self.downloadManager = nil;
    self.purchasingPackInfo = nil;
    if (!m_IsPad) {
        if ([self.navigationController.topViewController
                isKindOfClass:[RBStoreDetailViewController class]]) {
            [(RBStoreDetailViewController *)
                    self.navigationController.topViewController setButtonTextInstalled];
        }
    } else {
        [self.packDetailViewPad setButtonTextInstalled];
    }
    [self.parent hideModalDialog];
    [self.promotionView startAnimation];
}

/** @ghidraAddress 0x1e925c */
- (void)downloadManagerFailed:(StoreDownloadManager *)manager {
    NSString *message = [[NSString alloc] initWithString:g_pStoreDownloadFailedMessage];
    UIAlertView *alert = [UIAlertView showConnectRetryWithErrorMessage:message delegate:self];
    alert.tag = kAlertTagDownloadRetry;
}

/** @ghidraAddress 0x1e931c */
- (void)downloadManagerProceed:(StoreDownloadManager *)manager {
    // The manager argument is ignored; the progress is read from the retained ivar.
    self.parent.modalDialog.progressView.progress = self.downloadManager.overallProgress;
}

#pragma mark - Image downloader delegate

/** @ghidraAddress 0x1ec2e8 */
- (void)imageDownloader:(ImageDownloader *)downloader didLoad:(NSIndexPath *)indexPath {
    UITableView *table = (UITableView *)[self.view viewWithTag:kTagPackTable];
    if (!m_IsPad) {
        StorePackCell *cell = (StorePackCell *)[table cellForRowAtIndexPath:indexPath];
        UIImage *image = [downloader getImage];
        if (cell != nil && image != nil) {
            cell.artworkView.contents = (__bridge id)image.CGImage;
        }
    } else {
        NSIndexPath *cellPath = [NSIndexPath indexPathForRow:(indexPath.row >> 1)
                                                   inSection:indexPath.section];
        StoreTableCell *cell = (StoreTableCell *)[table cellForRowAtIndexPath:cellPath];
        UIImage *image = [downloader getImage];
        if (cell != nil && image != nil) {
            if ((indexPath.row & 1) == 0) {
                cell.leftPackView.artwork = image;
            } else {
                cell.rightPackView.artwork = image;
            }
        }
    }
}

/** @ghidraAddress 0x1ec5ec */
- (void)imageDownloaderDidFail:(ImageDownloader *)downloader didLoad:(NSIndexPath *)indexPath {
    // Intentionally empty: a failed artwork download is left as the cell's placeholder.
}

/** @ghidraAddress 0x1ecb34 */
- (void)stopDownloadArtworks {
    if (self.artworkDownloaders.count != 0) {
        for (ImageDownloader *downloader in self.artworkDownloaders.allValues) {
            downloader.delegate = nil;
            [downloader cancelDownload];
        }
        [self.artworkDownloaders removeAllObjects];
    }
}

#pragma mark - Alert view delegate

/** @ghidraAddress 0x1e8110 */
- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex {
    switch (alertView.tag) {
    case kAlertTagRestoreDownload:
        if (buttonIndex == kAlertButtonConfirm) {
            [self restoreDownloadAllMusics];
        } else {
            [self.restorePackInfo removeAllObjects];
            self.restorePackInfo = nil;
            [self.restoreExtendNoteInfo removeAllObjects];
            self.restoreExtendNoteInfo = nil;
            [self.parent hideModalDialog];
            [self.promotionView startAnimation];
        }
        break;
    case kAlertTagRestore:
        if (buttonIndex == kAlertButtonConfirm) {
            StoreDialogView *dialog = self.parent.modalDialog;
            [dialog layout:YES];
            dialog.labelMessage.text = g_pStoreRestoreInProgressMessage;
            [self.parent showModalDialog:self];
            [RBPurchaseManager sharedManager].delegate = self;
            [[RBPurchaseManager sharedManager] beginRestore];
            [self.promotionView stopAnimation];
            [self.promotionView stopSamplePlay];
        }
        break;
    case kAlertTagPurchaseLimitTypeSelect:
        if (buttonIndex != kAlertButtonCancel) {
            if (buttonIndex < kPurchaseLimitFirstHelpIndex) {
                [RBUserSettingData sharedInstance].purchaseLimitType = (int)buttonIndex;
                [self sendUserAge];
            } else {
                [[UIApplication sharedApplication]
                    openURL:[NSURL URLWithString:kKonamiHelpURLString]];
            }
        }
        break;
    case kAlertTagDownloadRetry:
        if (buttonIndex == kAlertButtonConfirm) {
            [self.downloadManager restart];
        } else {
            [self restoreDownloadCancel];
        }
        break;
    case kAlertTagUserAgeConfirm:
        if (buttonIndex == kAlertButtonConfirm) {
            [self sendUserAge];
        } else {
            [RBUserSettingData sharedInstance].purchaseLimitType = 0;
        }
        break;
    default:
        break;
    }
}

/** @ghidraAddress 0x1e8604 */
- (void)alertViewCancel:(UIAlertView *)alertView {
    // Intentionally empty: the cancel path takes no action.
}

/** @ghidraAddress 0x1e8608 */
- (void)didPresentAlertView:(UIAlertView *)alertView {
    // -setExclusiveTouchForView: is a UIAlertView class method (a category helper).
    UIView *presentedView =
        [UIApplication sharedApplication].keyWindow.rootViewController.presentedViewController.view;
    [UIAlertView setExclusiveTouchForView:presentedView];
}

#pragma mark - iTunes

/** @ghidraAddress 0x1eedb0 */
- (void)storeDetailViewOpenItunesWithURL:(NSURL *)url {
    if (url != nil) {
        // Forwards to the application's RBViewController, not to self.
        [[AppDelegate appDelegate].viewController openItunesWithURL:url];
    }
}

/** @ghidraAddress 0x1eee74 */
- (void)openItunesWithURL:(NSURL *)url {
    if (url == nil) {
        return;
    }
    NSDictionary *parameters = [StoreUtil affiliateParametersFromURL:url.absoluteString];
    // The binary passes the URL object straight to affiliateParametersFromURL:; the committed
    // StoreUtil header types that parameter as an NSString, so the absolute string is passed here.
    if (parameters == nil) {
        [[UIApplication sharedApplication] openURL:url];
    } else {
        self.itunesViewCtrl = [[SKStoreProductViewController alloc] init];
        self.itunesViewCtrl.delegate = self;
        UIViewController *root = self.view.window.rootViewController;
        [root presentViewController:self.itunesViewCtrl
                           animated:YES
                         completion:^{
                           /** @ghidraAddress 0x1ef138 */
                           [self.itunesViewCtrl loadProductWithParameters:parameters
                                                          completionBlock:nil];
                         }];
    }
}

/** @ghidraAddress 0x1ef1ec */
- (void)closeItunesWithURL {
    [self productViewControllerDidFinish:self.itunesViewCtrl];
}

/** @ghidraAddress 0x1ef24c */
- (void)productViewControllerDidFinish:(SKStoreProductViewController *)viewController {
    if (self.itunesViewCtrl != nil) {
        [self dismissViewControllerAnimated:YES
                                 completion:^{
                                   /** @ghidraAddress 0x1ef300 */
                                   self.itunesViewCtrl = nil;
                                 }];
    }
}

#pragma mark - Terms and errors

/** @ghidraAddress 0x1ef8a0 */
- (void)showTerms {
    RBTermView *termView = [[RBTermView alloc] initWithFrame:self.view.bounds];
    [termView setViewTypeStore];
    termView.autoresizingMask =
        UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleWidth |
        UIViewAutoresizingFlexibleRightMargin | UIViewAutoresizingFlexibleTopMargin |
        UIViewAutoresizingFlexibleHeight | UIViewAutoresizingFlexibleBottomMargin;
    [self.view addSubview:termView];
    [termView showAnimation];
}

/** @ghidraAddress 0x1e5658 */
- (void)storeDialogCancel:(id)sender {
    if (self.downloadManager != nil) {
        [self.downloadManager cancel];
        self.downloadManager = nil;
    }
    [self.parent hideModalDialog];
    if (GetFontVariantFlag() == kFontVariantDefault) {
        UIViewController *top = self.navigationController.topViewController;
        if (![top isKindOfClass:[RBStoreDetailViewController class]]) {
            return;
        }
        [(RBStoreDetailViewController *)top selfCheckButtonText];
    } else {
        [self.packDetailViewPad selfCheckButtonText];
    }
}

/** @ghidraAddress 0x1e0a90 */
- (void)showError:(NSString *)message {
    [self.view viewWithTag:kTagPackTable].hidden = YES;
    [self.view viewWithTag:kTagLoadingLabel].hidden = YES;
    UILabel *errorLabel = (UILabel *)[self.view viewWithTag:kTagFetchingLabel];
    errorLabel.text = message;
    errorLabel.hidden = NO;
}

#pragma mark - Rotation

/** @ghidraAddress 0x1ed9f0 */
- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
    // Overrides the base class's music-gated rule: the store page always permits rotation.
    return YES;
}

/** @ghidraAddress 0x1ed9f8 */
- (void)willAnimateRotationToInterfaceOrientation:(UIInterfaceOrientation)orientation
                                         duration:(NSTimeInterval)duration {
    [self.promotionView scrollViewDidRotate:(float)self.view.bounds.size.width];
    [super willAnimateRotationToInterfaceOrientation:orientation duration:duration];
}

/** @ghidraAddress 0x1edae4 */
- (void)didRotateFromInterfaceOrientation:(UIInterfaceOrientation)fromInterfaceOrientation {
    // Intentionally empty override.
}

@end
