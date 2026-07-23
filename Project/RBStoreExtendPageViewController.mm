/** @file
 * The extend-note store page controller implementation. It lists the purchasable extend-note
 * packs, drives their purchase, restore, and download flows, and hosts the pad detail overlay.
 *
 * Reconstructed from Ghidra project rb458, program rb458 (class
 * @c RBStoreExtendPageViewController, image base 0x100000000). @ghidraAddress values are offsets
 * relative to the image base.
 */

#import "RBStoreExtendPageViewController.h"

#import <StoreKit/StoreKit.h>
#import <UIKit/UIKit.h>

#import "AppDelegate.h"
#import "Downloader.h"
#import "ImageDownloader.h"
#import "NSFileManager+RB.h"
#import "RBCampaignData.h"
#import "RBCampaignViewController.h"
#import "RBExtendNoteManager.h"
#import "RBMusicManager.h"
#import "RBPurchaseManager.h"
#import "RBStoreExtendNoteDetailViewController.h"
#import "RBStoreExtendNoteList.h"
#import "RBStoreTabController.h"
#import "RBTermView.h"
#import "RBUserSettingData.h"
#import "StoreDialogView.h"
#import "StoreDownloadManager.h"
#import "StoreDownloadTask.h"
#import "StoreExtendNoteCell.h"
#import "StoreExtendNoteCellPhone.h"
#import "StoreExtendNoteCellView.h"
#import "StoreExtendNoteDetailViewPad.h"
#import "StoreExtendNoteInfo.h"
#import "StoreExtendNoteInfoDownloader.h"
#import "StoreUtil.h"
#import "UIAlertView+RB.h"
#import "UIImage+RB.h"
#import "neEngineBridge.h"

// The shared translucent-panel white value used by the store manage and web screens. It is a
// file-scope global defined in another store screen, so it is declared here rather than redefined.
extern CGFloat g_dRBWebViewGrayViewWhite;

// View tags looked up with -[UIView viewWithTag:] against the page view or the pack table. The
// pack table and its banner overlays keep the tags the binary assigns in loadView.
static const NSInteger kPackTableViewTag = 10000;      // 0x2710 pack list table view.
static const NSInteger kLoadingTitleLabelTag = 10001;  // 0x2711 loading/error title label.
static const NSInteger kErrorMessageLabelTag = 10002;  // 0x2712 error message label.
static const NSInteger kBannerLabelTag = 100000;       // 0x186a0 banner title label.
static const NSInteger kBannerImageViewTag = 100001;   // 0x186a1 banner background image.
static const NSInteger kCampaignImageViewTag = 100002; // 0x186a2 campaign banner image.

// UIAlertView tags distinguishing which alert invoked a delegate callback.
enum {
    kAlertTagRestoreDownload = 0x1e,   // "Download restored notes?" prompt.
    kAlertTagRestoreConfirm = 0x1f,    // "Begin App Store restore?" confirmation.
    kAlertTagPurchaseLimitType = 0x20, // Purchase-limit-type selection.
    kAlertTagPurchasePack = 0x21,      // "Purchase this pack?" confirmation.
    kAlertTagUserAgeConfirm = 0x22,    // Age-check retry / network-error confirmation.
};

// The affirmative button index in the two-button confirmation alerts.
static const NSInteger kAlertButtonConfirm = 1;

// In the purchase-limit-type alert, button indices 1..3 select a concrete limit type; index 4 and
// above opens the external KONAMI information page instead.
static const NSInteger kPurchaseLimitTypeMaxButton = 4;

// The layout mode passed to the modal dialog: 0 = simple message, 1 = message with progress.
static const NSInteger kModalDialogLayoutMessage = 0;
static const NSInteger kModalDialogLayoutProgress = 1;

// The -moveToPackID sentinel meaning "no pending pack to open".
static const int kNoPendingPackID = -1;

// initWithCapacity: for the artwork downloader cache.
static const NSUInteger kArtworkDownloaderCapacity = 0x20;

// Purchase-limit thresholds in yen, indexed by RBUserSettingData.purchaseLimitType. A value of -1
// (index out of range) means "no limit".
static const int kPurchaseLimitYen[] = {5000, 10000, 30000};
static const int kPurchaseLimitNone = -1;

// The number of purchase-limit-type thresholds.
static const unsigned int kPurchaseLimitTypeCount = 3;

// The currency code that RBUserSettingData tracks purchase totals against.
static NSString *const kCurrencyCodeJPY = @"JPY";

// The external information page opened when the player declines the purchase-limit selection.
static NSString *const kKonamiInfoURLString = @"http://www.konami.jp/";

// The stringWithFormat: template producing the decimal pack identifier stored on the app delegate.
static NSString *const kPackIDFormat = @"%d";

// The purchase/restore error message format ("%@" over error.localizedDescription).
static NSString *const kErrorMessageFormat = @"%@";

// The StoreExtendNoteInfoDownloader age-check server "status" success value.
static const int kAgeCheckStatusOK = 0;

// Background colour of the store page (light grey), as 8-bit channel values.
static const CGFloat kStoreBackgroundRed = 226.0 / 255.0;
static const CGFloat kStoreBackgroundGreen = 227.0 / 255.0;
static const CGFloat kStoreBackgroundBlue = 228.0 / 255.0;

// The autoresizing mask that flexes in every direction so a view tracks its host's bounds.
static const UIViewAutoresizing kAutoresizingMaskFlexibleAll =
    UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleWidth |
    UIViewAutoresizingFlexibleRightMargin | UIViewAutoresizingFlexibleTopMargin |
    UIViewAutoresizingFlexibleHeight | UIViewAutoresizingFlexibleBottomMargin;

// Autoresizing-mask bitfields, named after the flag combinations the binary uses.
static const UIViewAutoresizing kMaskFlexibleWidthHeight = 0x12;          // W|H centred.
static const UIViewAutoresizing kMaskFlexibleTopWidthHeight = 0x25;       // W|H|TopMargin.
static const UIViewAutoresizing kMaskFlexibleBottomWidth = 0xd;           // W|LMargin|RMargin.
static const UIViewAutoresizing kMaskFlexibleTopBottomWidth = 0x29;       // W|Top|Bottom.
static const UIViewAutoresizing kMaskFlexibleWidthBottomMargins = 0x15;   // W|H|BottomMargin.
static const UIViewAutoresizing kMaskFlexibleTopBottomWidthHeight = 0x2d; // W|H|Top|Bottom.

// Pad-layout geometry constants (points), recovered from the disassembly float loads.
static const CGFloat kPadHeaderBaseY = 171.0;           // Baseline below which the label sits.
static const CGFloat kPadPackLabelOriginX = 27.0;       // Pack-label frame origin.x.
static const CGFloat kPadPackLabelBoundsWidth = 720.0;  // Pack-label bounds width after sizeToFit.
static const CGFloat kSliderRowHeightWide = 40.0;       // Reused engine row-height constant.
static const CGFloat kShowMoreButtonBottomInset = 12.0; // Show-more button offset from bottom.
static const CGFloat kShowMoreIndicatorSize = 24.0;     // Activity-indicator square side.
static const CGFloat kPadTableTopSpacing = 16.0;        // Padding above and below the pack table.
static const CGFloat kPadTableWidth = 728.0;            // Pack table frame width.
static const CGFloat kPadTableHeightInset = -76.0;      // Added to view height for the table.
static const CGFloat kPadTableCentreYOffset = 76.0;     // Table centre offset from half-height.
static const CGFloat kPadTableCornerRadius = 8.0;       // Rounded corner radius.
static const CGFloat kPadTableBorderWidth = 1.5;        // Border stroke width.
static const CGFloat kScrollIndicatorInset = 4.0;       // Scroll-indicator top and bottom inset.
// The detail pad view is built at the shared wide popup size: the engine's g_dPopupBaseHeightWide
// (680.0) tall by 650.0 wide (@0x2eec30). The height reuses the same engine global the music popup
// uses, quoted here as a literal until that global is recovered as a shared extern.
static const CGFloat kPadDetailBaseHeight = 680.0;
static const CGFloat kPadDetailWidth = 650.0;
static const CGFloat kPadDetailCentreYOffset = -44.0; // Detail-view centre Y offset.
static const CGFloat kBannerLabelHeight = 25.0;       // 0x186a0 banner label height.
static const CGFloat kBannerLabelFontSize = 15.0;     // 0x186a0 banner label font.
static const CGFloat kPackLabelFontSize = 18.0;       // Pack-table header label font.
static const CGFloat kErrorTitleFontSizePhone = 16.0; // Error message font (phone).
static const CGFloat kErrorTitleFontSizePad = 18.0;   // Error message font (pad).
static const CGFloat kErrorMessageTopOffset = 20.0;   // Error message label centre offset.

// Greyscale colour whites (8-bit channel values expressed as fractions).
static const CGFloat kTableBackgroundWhite = 47.0 / 255.0; // Pack table background.
static const CGFloat kTableBorderWhite = 143.0 / 255.0;    // Pack table border.
static const CGFloat kLabelTextWhite = 158.0 / 255.0;      // Label text colour.
static const CGFloat kCoverDimAlpha = 0.5;                 // Pad cover-view dim alpha.
static const CGFloat kLabelShadowAlpha = 0.3;              // Label drop-shadow alpha.

// The "show more" backing views are laid out with a fixed margin from the edges of the table, and
// their vertical origin trails the current content by a device-dependent gap.
static const CGFloat kShowMoreSideMargin = 50.0;          // Left inset and right-edge inset.
static const int kShowMoreContentGapPad = 300;            // Vertical gap below content on the pad.
static const int kShowMoreContentGapPhone = 100;          // Vertical gap below content on phone.
static const CGFloat kShowMoreButtonCentreYOffset = 25.0; // Extra drop for the button centre.

// UIView animation options and durations for the pad detail-overlay transitions.
static const UIViewAnimationOptions kDetailOpenAnimationOptions = 0x30000; // Curve ease-in-out.
static const NSTimeInterval kDetailOverlayOpenDuration = 0.3;
static const NSTimeInterval kDetailOverlayCloseDuration = 0.3;

// Row heights (points). A genuine pack row is tall; the trailing "show more"/spinner row is short.
static const CGFloat kPhonePackRowHeight = 140.0;
static const CGFloat kPhoneMoreRowHeight = 60.0;
static const CGFloat kPadPackRowHeight = 80.0;
static const CGFloat kPadMoreRowHeight = 60.0;

// The pad packs two products per table row (a left and a right cell view).
static const NSInteger kPadProductsPerRow = 2;

// This table is a single flat section.
static const NSInteger kExtendNoteSectionCount = 1;

// "More"/spinner cell label point sizes: the pad uses a larger bold system font.
static const CGFloat kMoreCellFontSizePhone = 15.0;
static const CGFloat kMoreCellFontSizePad = 18.0;

// Alternating-row background tints. A pad pack row is drawn at a flat mid-white; a phone pack row
// alternates its background colour by parity between two near-white greys.
static const CGFloat kPadEvenRowWhite = 0.5;
static const CGFloat kPhoneEvenRowWhite = 0.7563;
static const CGFloat kPhoneOddRowWhite = 0.756909012794495;

// The "more"/loading footer label white component (text and shadow).
static const CGFloat kMoreCellTextWhite = 0.4;

// The floating-banner bottom margin kept clear beneath the pinned banner while scrolling. The
// campaign banner additionally pins against half its own height rather than its full height.
static const CGFloat kBannerBottomMarginPhone = 100.0;
static const CGFloat kBannerBottomMarginPad = 300.0;
static const CGFloat kCampaignBannerAnchorFraction = 0.5;

// The pad packs two products per row, so a linear product index is halved (>> 1) to get the row.
static const NSInteger kPadRowShift = 1;

// setPurchaseState: argument marking a detail cell as purchased.
static const NSInteger kPurchaseStatePurchased = 1;

// Row-animation passed to reloadRowsAtIndexPaths:withRowAnimation:.
static const UITableViewRowAnimation kReloadRowAnimation = UITableViewRowAnimationNone;

// Section index of the purchased-note table. The pad packs two products per row into section zero;
// the phone (page controller) layout uses one product per row in section one.
static const NSInteger kPurchasedTableSectionPad = 0;
static const NSInteger kPurchasedTableSectionPhone = 1;

// UIActivityIndicatorViewStyleGray.
static const NSInteger kActivityIndicatorStyleGray = 1;
// NSTextAlignmentCenter.
static const NSInteger kTextAlignmentCentre = 1;
// UITableViewCellStyleDefault.
static const NSInteger kTableViewCellStyleDefault = 0;

// Forward declarations of the de-inlined helpers, defined at the bottom of the file.
static inline UIImage *StoreExtendPageArtworkForInfo(RBStoreExtendPageViewController *self,
                                                     StoreExtendNoteInfo *info,
                                                     NSIndexPath *indexPath);
static inline UIImage *StoreExtendPageArtworkForPadInfo(RBStoreExtendPageViewController *self,
                                                        StoreExtendNoteInfo *info,
                                                        int pid,
                                                        NSIndexPath *indexPath);
static inline UITableViewCell *StoreExtendPageMoreCell(UITableView *tableView,
                                                       NSString *reuseIdentifier,
                                                       BOOL isPad,
                                                       BOOL isLoadingMore);
static inline CGFloat StoreExtendPagePinnedBannerY(UIScrollView *scrollView,
                                                   UIScrollView *listView,
                                                   CGFloat bannerHeight,
                                                   CGFloat margin,
                                                   CGFloat anchorFraction);

@interface RBStoreExtendPageViewController () {
    // Set on the pad (wide-font) layout; drives the two-column pack table and detail overlay.
    BOOL m_IsPad;
    // Set while a "show more" page fetch is in flight, suppressing further fetches.
    BOOL m_IsLoadingMoreList;
}
@end

@implementation RBStoreExtendPageViewController

#pragma mark - Lifecycle

- (instancetype)initWithParent:(RBStoreTabController *)parent {
    self = [super init];
    if (self != nil) {
        self.parent = parent;
        [self.navigationItem setTitle:g_pStoreExtendTitle];
        [self.tabBarItem setTitle:g_pStoreExtendTitle];
        [self.tabBarItem setImage:[UIImage imageWithName:@"09_store/icon_append"]];
        self.extendNoteListCtrl = [[RBStoreExtendNoteList alloc] init];
        [self.extendNoteListCtrl setDelegate:self];
        self.artworkDownloaders =
            [[NSMutableDictionary alloc] initWithCapacity:kArtworkDownloaderCapacity];
        // GetFontVariantFlag() is nonzero on the pad/wide layout, zero on the phone.
        m_IsPad = GetFontVariantFlag();
        self.moveToPackID = kNoPendingPackID;
    }
    return self;
}

- (void)loadView {
    [super loadView];
    [self.view setOpaque:YES];
    [self.view setBackgroundColor:[UIColor colorWithRed:kStoreBackgroundRed
                                                  green:kStoreBackgroundGreen
                                                   blue:kStoreBackgroundBlue
                                                  alpha:1.0]];
    [self.view setAutoresizingMask:kMaskFlexibleWidthHeight];
    [self.view setExclusiveTouch:YES];
}

- (void)viewDidLoad {
    [super viewDidLoad];

    const CGRect viewBounds = self.view.bounds;

    if (!m_IsPad) {
        // Phone layout: a single full-bounds pack table view, created lazily.
        if ([self.view viewWithTag:kPackTableViewTag] == nil) {
            UITableView *tableView = [[UITableView alloc] initWithFrame:viewBounds
                                                                  style:UITableViewStylePlain];
            [tableView setOpaque:YES];
            [tableView setTag:kPackTableViewTag];
            [tableView setAutoresizingMask:kMaskFlexibleWidthHeight];
            [tableView setBackgroundColor:[UIColor colorWithWhite:kTableBackgroundWhite alpha:1.0]];
            [tableView setSeparatorStyle:UITableViewCellSeparatorStyleNone];
            [tableView setDataSource:self];
            [tableView setDelegate:self];
            [tableView setExclusiveTouch:YES];
            [self.view addSubview:tableView];
        }
    } else {
        // Pad layout: header label, "show more" control, a rounded pack table, a dimming cover
        // view, and the floating note-detail pad view.
        CGRect headerFrame = self.tabBarController.rotatingHeaderView.frame;
        CGFloat labelBaseY = kPadHeaderBaseY - headerFrame.size.height;

        self.packTableLabel =
            [[UILabel alloc] initWithFrame:CGRectMake(kPadPackLabelOriginX, labelBaseY, 0.0, 0.0)];
        [self.packTableLabel setTextColor:[UIColor blackColor]];
        [self.packTableLabel setShadowColor:[UIColor lightGrayColor]];
        [self.packTableLabel setShadowOffset:CGSizeMake(1.0, 1.0)];
        [self.packTableLabel setFont:[UIFont systemFontOfSize:kPackLabelFontSize]];
        [self.packTableLabel setText:g_pStoreExtendTitle];
        [self.packTableLabel sizeToFit];
        // Widen the label's bounds to the fixed pack-table width, keeping its fitted height.
        [self.packTableLabel setBounds:CGRectMake(0.0,
                                                  0.0,
                                                  kPadPackLabelBoundsWidth,
                                                  self.packTableLabel.bounds.size.height)];
        [self.packTableLabel setCenter:CGPointMake(viewBounds.size.width * 0.5,
                                                   self.packTableLabel.bounds.size.height * 0.5 +
                                                       kSliderRowHeightWide)];
        [self.packTableLabel setAutoresizingMask:kMaskFlexibleTopWidthHeight];
        [self.view addSubview:self.packTableLabel];

        UIButton *showMore = [UIButton buttonWithType:UIButtonTypeCustom];
        [showMore setTitle:g_pStoreShowMoreTitle forState:UIControlStateNormal];
        [showMore setTitleColor:[UIColor blackColor] forState:UIControlStateNormal];
        [showMore sizeToFit];
        // Anchor the button just above the view's bottom edge.
        [showMore setCenter:CGPointMake(viewBounds.size.width * 0.5,
                                        viewBounds.size.height - showMore.bounds.size.height * 0.5 -
                                            kShowMoreButtonBottomInset)];
        [showMore setAutoresizingMask:kMaskFlexibleBottomWidth];
        [showMore setHidden:YES];
        [showMore addTarget:self
                      action:@selector(selectShowMore:)
            forControlEvents:UIControlEventTouchUpInside];
        [showMore setExclusiveTouch:YES];
        [self.view addSubview:showMore];
        self.showMoreButton = showMore;

        UIActivityIndicatorView *moreIndicator = [[UIActivityIndicatorView alloc]
            initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleWhiteLarge];
        [moreIndicator
            setBounds:CGRectMake(0.0, 0.0, kShowMoreIndicatorSize, kShowMoreIndicatorSize)];
        // Sit the spinner to the right of the show-more button's text.
        [moreIndicator setCenter:CGPointMake(self.showMoreButton.bounds.size.width +
                                                 kShowMoreIndicatorSize * 0.5,
                                             moreIndicator.bounds.size.height * 0.5)];
        [moreIndicator setAutoresizingMask:kMaskFlexibleTopBottomWidth];
        [moreIndicator startAnimating];
        [moreIndicator setHidden:YES];
        [self.showMoreButton addSubview:moreIndicator];
        self.showMoreIndicator = moreIndicator;

        if ([self.view viewWithTag:kPackTableViewTag] == nil) {
            // Reserve room at the bottom for the show-more button plus its padding.
            CGFloat spinnerAndPadding =
                moreIndicator.bounds.size.height + kPadTableTopSpacing + kPadTableTopSpacing;
            CGFloat tableHeight = (viewBounds.size.height + kPadTableHeightInset) -
                                  static_cast<CGFloat>(static_cast<float>(spinnerAndPadding));
            CGRect packTableFrame = CGRectMake(0.0, 0.0, kPadTableWidth, tableHeight);
            UITableView *packTable = [[UITableView alloc] initWithFrame:packTableFrame
                                                                  style:UITableViewStylePlain];
            [packTable setTag:kPackTableViewTag];
            [packTable setCenter:CGPointMake(viewBounds.size.width * 0.5,
                                             tableHeight * 0.5 + kPadTableCentreYOffset)];
            [packTable setAutoresizingMask:kMaskFlexibleWidthBottomMargins];
            [packTable setOpaque:YES];
            [packTable setBackgroundColor:[UIColor colorWithWhite:kTableBackgroundWhite alpha:1.0]];
            [packTable.layer setCornerRadius:kPadTableCornerRadius];
            [packTable.layer
                setBorderColor:[UIColor colorWithWhite:kTableBorderWhite alpha:1.0].CGColor];
            [packTable.layer setBorderWidth:kPadTableBorderWidth];
            [packTable setScrollIndicatorInsets:UIEdgeInsetsMake(kScrollIndicatorInset,
                                                                 0.0,
                                                                 kScrollIndicatorInset,
                                                                 0.0)];
            [packTable setSeparatorStyle:UITableViewCellSeparatorStyleNone];
            [packTable setDataSource:self];
            [packTable setDelegate:self];
            [packTable setExclusiveTouch:YES];
            [self.view addSubview:packTable];
        }

        self.coverViewPad = [[UIView alloc] initWithFrame:self.view.bounds];
        [self.coverViewPad setAutoresizingMask:kAutoresizingMaskFlexibleAll];
        [self.coverViewPad setOpaque:NO];
        [self.coverViewPad setBackgroundColor:[UIColor colorWithWhite:0.0 alpha:kCoverDimAlpha]];
        [self.coverViewPad setUserInteractionEnabled:YES];
        [self.coverViewPad setExclusiveTouch:YES];
        UITapGestureRecognizer *coverTap =
            [[UITapGestureRecognizer alloc] initWithTarget:self
                                                    action:@selector(handleTapCoverView:)];
        [self.coverViewPad addGestureRecognizer:coverTap];
        [self.coverViewPad setHidden:YES];
        [self.coverViewPad setExclusiveTouch:YES];
        [self.view addSubview:self.coverViewPad];

        self.extendNoteDetailViewPad = [[StoreExtendNoteDetailViewPad alloc]
            initWithFrame:CGRectMake(0.0, 0.0, kPadDetailWidth, kPadDetailBaseHeight)];
        // Centre the detail view on the cover, nudged upward, snapped to whole pixels.
        CGFloat detailCentreX = static_cast<CGFloat>(static_cast<int>(self.coverViewPad.center.x));
        CGFloat detailCentreY = static_cast<CGFloat>(
            static_cast<int>(self.coverViewPad.center.y + kPadDetailCentreYOffset));
        [self.extendNoteDetailViewPad setCenter:CGPointMake(detailCentreX, detailCentreY)];
        [self.extendNoteDetailViewPad setAutoresizingMask:kMaskFlexibleTopBottomWidthHeight];
        [self.extendNoteDetailViewPad setDelegate:self];
        [self.extendNoteDetailViewPad setHidden:YES];
        [self.extendNoteDetailViewPad setExclusiveTouch:YES];
        [self.view addSubview:self.extendNoteDetailViewPad];
    }

    // Banner overlay hosted on the pack table view (shared by both layouts).
    UIView *packTableView = [self.view viewWithTag:kPackTableViewTag];
    if (packTableView != nil) {
        if ([packTableView viewWithTag:kBannerLabelTag] == nil) {
            UILabel *bannerLabel = [[UILabel alloc]
                initWithFrame:CGRectMake(0.0, 0.0, viewBounds.size.width, kBannerLabelHeight)];
            [bannerLabel setTag:kBannerLabelTag];
            [bannerLabel setBackgroundColor:[UIColor clearColor]];
            [bannerLabel setText:g_pStoreBannerTitle];
            [bannerLabel setFont:[UIFont systemFontOfSize:kBannerLabelFontSize]];
            [bannerLabel setTextColor:[UIColor whiteColor]];
            [bannerLabel setTextAlignment:NSTextAlignmentCenter];
            [bannerLabel setHidden:YES];
            [packTableView addSubview:bannerLabel];
        }

        if ([packTableView viewWithTag:kBannerImageViewTag] == nil) {
            UIImageView *bannerImage =
                [[UIImageView alloc] initWithImage:[UIImage imageWithName:@"09_store/store_fun"]];
            [bannerImage setTag:kBannerImageViewTag];
            [bannerImage setHidden:YES];
            [packTableView addSubview:bannerImage];
        }

        // The campaign banner only appears during the Hinabita 2017-03 campaign, and only when the
        // campaign-specific artwork actually exists.
        if ([[RBCampaignData sharedInstance] isCampaignHinabita201703] &&
            [packTableView viewWithTag:kCampaignImageViewTag] == nil) {
            NSString *campaignImageName =
                [[NSString alloc] initWithFormat:@"%@/%@",
                                                 @"09_store/store_fun",
                                                 [[RBCampaignData sharedInstance] campaignName]];
            if ([UIImage imageWithName:campaignImageName] != nil) {
                UIImageView *campaignImage =
                    [[UIImageView alloc] initWithImage:[UIImage imageWithName:campaignImageName]];
                [campaignImage setTag:kCampaignImageViewTag];
                [campaignImage setHidden:YES];
                [packTableView addSubview:campaignImage];
            }
        }
    }

    // Error/loading title label (tag 0x2711), created lazily on the page view.
    if ([self.view viewWithTag:kLoadingTitleLabelTag] == nil) {
        UILabel *errorTitle = [[UILabel alloc] initWithFrame:self.view.bounds];
        [errorTitle setTag:kLoadingTitleLabelTag];
        [errorTitle setBackgroundColor:[UIColor colorWithRed:kStoreBackgroundRed
                                                       green:kStoreBackgroundGreen
                                                        blue:kStoreBackgroundBlue
                                                       alpha:1.0]];
        [errorTitle setFont:[UIFont boldSystemFontOfSize:kPackLabelFontSize]];
        [errorTitle setTextColor:[UIColor colorWithWhite:kLabelTextWhite alpha:1.0]];
        [errorTitle setShadowColor:[UIColor colorWithWhite:1.0 alpha:kLabelShadowAlpha]];
        [errorTitle setShadowOffset:CGSizeMake(0.0, 1.0)];
        [errorTitle setTextAlignment:NSTextAlignmentCenter];
        [errorTitle setCenter:CGPointMake(viewBounds.size.width * 0.5,
                                          static_cast<CGFloat>(
                                              static_cast<int>(viewBounds.size.height * 0.5)))];
        [errorTitle setAutoresizingMask:kMaskFlexibleWidthHeight];
        [errorTitle setText:g_pStoreLoadingTitle];
        [errorTitle setHidden:NO];
        [self.view addSubview:errorTitle];
    }

    // A transparent container holding a spinner, centred on the loading title label.
    UILabel *errorTitleLabel =
        static_cast<UILabel *>([self.view viewWithTag:kLoadingTitleLabelTag]);
    UIView *spinnerHost = [[UIView alloc]
        initWithFrame:CGRectMake(0.0, 0.0, kSliderRowHeightWide, kSliderRowHeightWide)];
    [spinnerHost setBackgroundColor:[UIColor clearColor]];
    [spinnerHost setAutoresizingMask:kMaskFlexibleTopBottomWidthHeight];
    [spinnerHost setCenter:CGPointMake(errorTitleLabel.bounds.size.width * 0.5,
                                       errorTitleLabel.bounds.size.height * 0.5)];
    [errorTitleLabel addSubview:spinnerHost];

    UIActivityIndicatorView *spinner = [[UIActivityIndicatorView alloc]
        initWithFrame:CGRectMake(0.0, 0.0, kShowMoreIndicatorSize, kShowMoreIndicatorSize)];
    [spinner setActivityIndicatorViewStyle:UIActivityIndicatorViewStyleWhite];
    [spinner setCenter:CGPointMake(spinnerHost.bounds.size.width * 0.5,
                                   spinnerHost.bounds.size.height * 0.5)];
    [spinner setAutoresizingMask:kMaskFlexibleTopWidthHeight];
    [spinner startAnimating];
    [spinnerHost addSubview:spinner];

    // Error message label (tag 0x2712), created lazily on the page view.
    if ([self.view viewWithTag:kErrorMessageLabelTag] == nil) {
        UILabel *errorMessage = [[UILabel alloc] initWithFrame:self.view.bounds];
        [errorMessage setTag:kErrorMessageLabelTag];
        [errorMessage setBackgroundColor:self.view.backgroundColor];
        [errorMessage setFont:[UIFont boldSystemFontOfSize:(m_IsPad ? kErrorTitleFontSizePad :
                                                                      kErrorTitleFontSizePhone)]];
        [errorMessage setTextColor:[UIColor colorWithWhite:kLabelTextWhite alpha:1.0]];
        [errorMessage setTextAlignment:NSTextAlignmentCenter];
        [errorMessage setNumberOfLines:0];
        [errorMessage setCenter:CGPointMake(viewBounds.size.width * 0.5,
                                            static_cast<CGFloat>(
                                                static_cast<int>(viewBounds.size.height * 0.5) -
                                                static_cast<int>(kErrorMessageTopOffset)))];
        [errorMessage setAutoresizingMask:kAutoresizingMaskFlexibleAll];
        [errorMessage setHidden:YES];
        [self.view addSubview:errorMessage];
    }

    // Cache the stretchable pack background images once.
    if (self.packBgImage0 == nil) {
        self.packBgImage0 = [[UIImage imageWithName:@"09_store/store_pack_bg_0"]
            stretchableImageWithLeftCapWidth:4
                                topCapHeight:4];
    }
    if (self.packBgImage1 == nil) {
        self.packBgImage1 = [[UIImage imageWithName:@"09_store/store_pack_bg_1"]
            stretchableImageWithLeftCapWidth:4
                                topCapHeight:4];
    }
}

#pragma mark - Error display

- (void)showError:(NSString *)message {
    // Hide the pack table and loading title, then reveal the error message.
    [[self.view viewWithTag:kPackTableViewTag] setHidden:YES];
    [[self.view viewWithTag:kLoadingTitleLabelTag] setHidden:YES];
    UILabel *errorMessage = static_cast<UILabel *>([self.view viewWithTag:kErrorMessageLabelTag]);
    [errorMessage setText:message];
    [errorMessage setHidden:NO];
}

#pragma mark - Restore and terms

- (void)pushBarBtnRestore:(id)sender {
    [[UIAlertView showRestoreMessageWithDelegate:self] setTag:kAlertTagRestoreConfirm];
}

- (void)showTerms {
    RBTermView *termView = [[RBTermView alloc] initWithFrame:self.view.bounds];
    [termView setViewTypeStore];
    [termView setAutoresizingMask:kAutoresizingMaskFlexibleAll];
    [self.view addSubview:termView];
    [termView showAnimation];
}

#pragma mark - Age check

- (void)sendUserAge {
    // Build the age-check request payload from the current region, build version, user id, and the
    // configured purchase-limit type, then POST it to the server.
    NSArray *serverData = [AppDelegate getServerData];
    NSDictionary *params = @{
        @"target" : GetRegionCode(),
        @"app_ver" : GetBundleVersionString(),
        @"user_id" : serverData[0],
        @"type" :
            [NSString stringWithFormat:@"%d", [RBUserSettingData sharedInstance].purchaseLimitType],
    };
    NSData *jsonBody = [Downloader dictionaryToJsonData:params];

    self.userAgeSender = [[Downloader alloc] initWithURL:[StoreUtil userAgeURL]
                                                    post:jsonBody
                                             contentType:nil];

    __weak __typeof__(self) weakSelf = self;
    [self.userAgeSender
        startDownloadingWithProceed:^{
          /** @ghidraAddress 0x15ce0c */
          // No-op proceed handler.
        }
        success:^(Downloader *response) {
          /** @ghidraAddress 0x15ce10 */
          __typeof__(self) strongSelf = weakSelf;
          NSDictionary *json = [response getDataInJSON];
          if (json[@"status"] != nil && [json[@"status"] intValue] == kAgeCheckStatusOK) {
              [strongSelf performSelectorOnMainThread:@selector(startPurchase:)
                                           withObject:strongSelf.purchasingExtendNoteInfo
                                        waitUntilDone:NO];
          } else {
              dispatch_async(dispatch_get_main_queue(), ^{
                /** @ghidraAddress 0x15d024 */
                [[UIAlertView showNetworkErrorWithDelegate:weakSelf]
                    setTag:kAlertTagUserAgeConfirm];
              });
          }
          [strongSelf setUserAgeSender:nil];
        }
        failure:^{
          /** @ghidraAddress 0x15d0e0 */
          dispatch_async(dispatch_get_main_queue(), ^{
            /** @ghidraAddress 0x15d1a4 */
            [[UIAlertView showNetworkErrorWithDelegate:weakSelf] setTag:kAlertTagUserAgeConfirm];
          });
          [weakSelf setUserAgeSender:nil];
        }];
}

#pragma mark - Deep-link open

- (void)forceOpenExtendNoteDetailView {
    // Only act when the application has a queued extend-note PID to open from an external launch.
    if ([[AppDelegate appDelegate] getExtendNotePIDForOpenStore] == nil) {
        return;
    }
    int productID = [[[AppDelegate appDelegate] getExtendNotePIDForOpenStore] intValue];
    StoreExtendNoteInfo *info = [self.extendNoteListCtrl getExtendNoteInfoWithProductID:productID];
    if (info == nil) {
        // Not loaded yet; kick off the optional-products request instead.
        [self.extendNoteListCtrl optionalProductsRequest];
        return;
    }

    if (m_IsPad) {
        // Tear down any in-flight pad detail view before reopening for the requested pack.
        [self.extendNoteDetailViewPad cancelLoading];
        [self.extendNoteDetailViewPad stopSample];
        [self.coverViewPad setAlpha:0.0];
        [self.extendNoteDetailViewPad setAlpha:0.0];
        [self.coverViewPad setHidden:YES];
        [self.extendNoteDetailViewPad setHidden:YES];
        [self.extendNoteDetailViewPad removeNoteInfo];
        [self openExtendNoteDetailViewWithPID:productID];
    } else {
        [self.navigationController popViewControllerAnimated:NO];
        [self showDetailViewForPhone:productID];
    }
}

#pragma mark - Extend-note list delegate

- (void)extendNoteListDownloadSuccess:(id)downloader {
    UITableView *packTable = static_cast<UITableView *>([self.view viewWithTag:kPackTableViewTag]);
    UIView *coverView = [self.view viewWithTag:kLoadingTitleLabelTag];
    [packTable setHidden:NO];
    [coverView setHidden:YES];
    if (self.packTableLabel != nil) {
        [self.packTableLabel setHidden:NO];
    }
    m_IsLoadingMoreList = NO;
    [packTable setAllowsSelection:YES];
    [packTable reloadData];

    // Reinstate the restore button as the sole right-hand navigation-bar item. The binary uses a
    // nil-terminated array, so a nil button yields an empty array rather than throwing.
    self.navigationItem.rightBarButtonItems = [NSArray arrayWithObjects:self.restoreButton, nil];

    // Allow simultaneous exclusive touch on every navigation-bar subview.
    for (UIView *barSubview in self.navigationController.navigationBar.subviews) {
        [barSubview setExclusiveTouch:YES];
    }

    // Reposition and reveal the first "show more" backing view. Its vertical origin trails the
    // greater of the table's content height and its bounds height, dropped by the device-dependent
    // gap; its x origin is a fixed left margin.
    const int contentGap = m_IsPad ? kShowMoreContentGapPad : kShowMoreContentGapPhone;
    UIView *showMoreBg1 = [packTable viewWithTag:kBannerImageViewTag];
    CGRect frame1 = showMoreBg1.frame;
    CGFloat originY1;
    if (packTable.contentSize.height > packTable.bounds.size.height) {
        originY1 = static_cast<CGFloat>(contentGap) + packTable.contentSize.height;
    } else {
        originY1 = static_cast<CGFloat>(contentGap) + packTable.bounds.size.height;
    }
    [showMoreBg1
        setFrame:CGRectMake(kShowMoreSideMargin, originY1, frame1.size.width, frame1.size.height)];
    [showMoreBg1 setHidden:NO];

    // Reposition and reveal the second "show more" backing view, right-aligned within the table
    // with the same margin.
    UIView *showMoreBg2 = [packTable viewWithTag:kCampaignImageViewTag];
    if (showMoreBg2 != nil) {
        const int contentGap2 = m_IsPad ? kShowMoreContentGapPad : kShowMoreContentGapPhone;
        CGRect frame2 = showMoreBg2.frame;
        CGFloat originY2;
        if (packTable.contentSize.height > packTable.bounds.size.height) {
            originY2 = static_cast<CGFloat>(contentGap2) + packTable.contentSize.height;
        } else {
            originY2 = static_cast<CGFloat>(contentGap2) + packTable.bounds.size.height;
        }
        CGFloat originX2 = packTable.bounds.size.width - frame2.size.width - kShowMoreSideMargin;
        [showMoreBg2
            setFrame:CGRectMake(originX2, originY2, frame2.size.width, frame2.size.height)];
        [showMoreBg2 setHidden:NO];
    }

    if (self.showMoreIndicator != nil) {
        [self.showMoreIndicator setHidden:YES];
    }

    if ([self.extendNoteListCtrl extendNoteListContinued]) {
        // There are further packs to load: show the "show more" button, re-centre it, and hide the
        // first backing view.
        if (self.showMoreButton != nil) {
            [self.showMoreButton setHidden:NO];
            [self.showMoreButton setTitle:g_pStoreShowMoreTitle forState:UIControlStateNormal];
            CGPoint buttonCentre = self.showMoreButton.center;
            [self.showMoreButton sizeToFit];
            [self.showMoreButton setCenter:buttonCentre];
        }
        UIView *showMoreBg0 = [packTable viewWithTag:kBannerLabelTag];
        [showMoreBg0 setHidden:NO];
        [showMoreBg0
            setCenter:CGPointMake(packTable.bounds.size.width * 0.5,
                                  packTable.contentSize.height + kShowMoreButtonCentreYOffset)];
    } else {
        // No more packs: hide the "show more" button and its first backing view.
        if (self.showMoreButton != nil) {
            [self.showMoreButton setHidden:YES];
        }
        UIView *showMoreBg0 = [packTable viewWithTag:kBannerLabelTag];
        [showMoreBg0 setHidden:YES];
    }

    [self forceOpenExtendNoteDetailView];
}

- (void)extendNoteListDownloadError:(id)downloader errorMessage:(NSString *)errorMessage {
    if (errorMessage == nil) {
        errorMessage = g_pStoreServerConnectFailed;
    }
    UITableView *packTable = static_cast<UITableView *>([self.view viewWithTag:kPackTableViewTag]);
    if (![packTable isHidden]) {
        // The pack table is already populated; surface the error inline and restore the
        // "show more" affordance rather than replacing the whole page.
        [UIAlertView showWithErrorMessage:errorMessage delegate:nil];
        if (self.showMoreButton != nil) {
            [self.showMoreButton setHidden:NO];
            [self.showMoreButton setTitle:g_pStoreShowMoreTitle forState:UIControlStateNormal];
            CGPoint buttonCentre = self.showMoreButton.center;
            [self.showMoreButton sizeToFit];
            [self.showMoreButton setCenter:buttonCentre];
        }
        if (self.showMoreIndicator != nil) {
            [self.showMoreIndicator setHidden:NO];
        }
        m_IsLoadingMoreList = NO;
        [packTable setAllowsSelection:YES];
        [packTable reloadData];
    } else {
        // Nothing has loaded yet; show the error as the page's own state.
        [self showError:errorMessage];
    }
}

- (void)extendNoteListDownloadNothing:(id)downloader {
    UITableView *packTable = static_cast<UITableView *>([self.view viewWithTag:kPackTableViewTag]);
    if (![packTable isHidden]) {
        m_IsLoadingMoreList = NO;
        [packTable setAllowsSelection:YES];
        [packTable reloadData];
    } else {
        [self showError:g_pStoreNoExtendNotes];
    }
    [[AppDelegate appDelegate] setExtendNotePIDForOpenStore:0];
}

#pragma mark - Cell selection

- (void)cellViewSelected:(id)cellView {
    UITableView *packTable = static_cast<UITableView *>([self.view viewWithTag:kPackTableViewTag]);
    if (packTable.allowsSelection) {
        NSArray *productIDs = [self.extendNoteListCtrl extendNoteProductIDList];
        StoreExtendNoteCellView *view = static_cast<StoreExtendNoteCellView *>(cellView);
        NSNumber *productID = productIDs[view.index];
        [self openExtendNoteDetailViewWithPID:productID.intValue];
    }
}

- (void)selectButton:(NSNumber *)productIDNumber {
    StoreExtendNoteInfo *info =
        [self.extendNoteListCtrl getExtendNoteInfoWithProductID:productIDNumber.intValue];
    if (info == nil) {
        return;
    }
    switch (info.getButtonState) {
    case 0: {
        // The pack must be selected before its individual notes can be bought.
        self.moveToPackID = info.packID;
        UIAlertView *alert = [UIAlertView showPurchasePack:info.packName delegate:self];
        [alert setTag:kAlertTagPurchasePack];
        [alert show];
        break;
    }
    case 1:
        [self startPurchase:info];
        break;
    case 2:
        [self startDownloadExtendNote:info];
        break;
    case 3:
        [self startDownloadExtendNote:info];
        break;
    }
}

#pragma mark - Pad detail overlay

- (void)openExtendNoteDetailViewWithPID:(int)productID {
    [[UIApplication sharedApplication] beginIgnoringInteractionEvents];
    [self.coverViewPad setAlpha:0.0];
    [self.extendNoteDetailViewPad setAlpha:0.0];
    [self.coverViewPad setHidden:NO];
    [self.extendNoteDetailViewPad setHidden:NO];
    __weak RBStoreExtendPageViewController *weakSelf = self;
    [UIView animateWithDuration:kDetailOverlayOpenDuration
        delay:0
        options:kDetailOpenAnimationOptions
        animations:^{
          /** @ghidraAddress 0x15e924 */
          [weakSelf.coverViewPad setAlpha:1.0];
          [weakSelf.extendNoteDetailViewPad setAlpha:1.0];
        }
        completion:^(BOOL finished) {
          /** @ghidraAddress 0x15e9dc */
          StoreExtendNoteInfo *info =
              [weakSelf.extendNoteListCtrl getExtendNoteInfoWithProductID:productID];
          [weakSelf.extendNoteDetailViewPad setInfo:info];
          [weakSelf.extendNoteDetailViewPad showNoteInfo];
          [[AppDelegate appDelegate] setExtendNotePIDForOpenStore:0];
          [[UIApplication sharedApplication] endIgnoringInteractionEvents];
        }];
}

- (void)openDetailAnimStop:(NSString *)animationID
                  finished:(NSNumber *)finished
                   context:(void *)context {
    // Intentionally empty: retained as a UIView animation-stop callback hook.
}

- (void)pushSampleButton:(id)sender {
    if ([[RBUserSettingData sharedInstance] refuseStoreSampleBGM]) {
        // Sample BGM was suppressed; re-enable it and restore the "play" glyph.
        [[RBUserSettingData sharedInstance] setRefuseStoreSampleBGM:NO];
        [self.samplePlayButton setImage:self.playImage forState:UIControlStateNormal];
    } else {
        // Suppress sample BGM, show the "stop" glyph, and blank the sample-music label.
        [[RBUserSettingData sharedInstance] setRefuseStoreSampleBGM:YES];
        [self.samplePlayButton setImage:self.stopImage forState:UIControlStateNormal];
        [self.sampleMusicLabel setText:g_pStoreSampleStoppedMessage];
    }
}

- (void)handleTapCoverView:(id)sender {
    [[UIApplication sharedApplication] beginIgnoringInteractionEvents];
    [self.extendNoteDetailViewPad cancelLoading];
    [self.extendNoteDetailViewPad stopSample];
    __weak RBStoreExtendPageViewController *weakSelf = self;
    [UIView animateWithDuration:kDetailOverlayCloseDuration
        animations:^{
          /** @ghidraAddress 0x15ef10 */
          [weakSelf.coverViewPad setAlpha:0.0];
          [weakSelf.extendNoteDetailViewPad setAlpha:0.0];
        }
        completion:^(BOOL finished) {
          /** @ghidraAddress 0x15efc8 */
          [weakSelf.coverViewPad setHidden:YES];
          [weakSelf.extendNoteDetailViewPad setHidden:YES];
          [weakSelf.extendNoteDetailViewPad removeNoteInfo];
          [[UIApplication sharedApplication] endIgnoringInteractionEvents];
          if (weakSelf.restoreButton != nil) {
              [weakSelf.restoreButton setEnabled:YES];
          }
        }];
}

#pragma mark - Download and purchase

- (void)startDownloadExtendNote:(StoreExtendNoteInfo *)info {
    if (info == nil) {
        return;
    }
    if (info.extendURL == nil) {
        // No detail URL yet: fetch the extend-note detail before downloading.
        [self.parent showModalDialog:self];
        StoreExtendNoteInfoDownloader *downloader =
            [[StoreExtendNoteInfoDownloader alloc] initWithStoreExtendNoteInfo:info];
        self.storeExtendNoteInfoDownloader = downloader;
        [downloader setDelegate:self];
        self.purchasingExtendNoteInfo = info;
        [downloader downloadDetail:YES];
        return;
    }

    // Build the list of files that still need downloading.
    [self.parent showModalDialog:self];
    NSMutableArray *tasks = [[NSMutableArray alloc] init];

    // Reflect the "installing" state in whichever detail UI is on screen.
    if (m_IsPad) {
        [self.extendNoteDetailViewPad setButtonTextInstalling];
    } else {
        UIViewController *top = self.navigationController.topViewController;
        if ([top isKindOfClass:[RBStoreExtendNoteDetailViewController class]]) {
            [static_cast<RBStoreExtendNoteDetailViewController *>(top) setButtonTextInstalling];
        }
    }

    // Queue the music file if it is not already present on disk.
    NSString *musicPath = [RBMusicManager getPathFromPurchesed:info.musicID];
    if (![NSFileManager isFileExist:musicPath]) {
        StoreDownloadTask *task = [[StoreDownloadTask alloc] initWithURL:info.itemURL
                                                                    path:musicPath
                                                               AddObject:info.name];
        [tasks addObject:task];
    }

    // Queue the extend-note file if it is not already present on disk.
    NSString *extendPath = [RBExtendNoteManager getPathFromPurchased:info.extMusicID];
    if (![NSFileManager isFileExist:extendPath]) {
        StoreDownloadTask *task = [[StoreDownloadTask alloc] initWithURL:info.extendURL
                                                                    path:extendPath
                                                               AddObject:info.name];
        [tasks addObject:task];
    }

    if (tasks.count == 0) {
        // Everything is already installed; reflect that state and dismiss the dialog.
        if (m_IsPad) {
            [self.extendNoteDetailViewPad setButtonTextInstalled];
        } else {
            UIViewController *top = self.navigationController.topViewController;
            if ([top isKindOfClass:[RBStoreExtendNoteDetailViewController class]]) {
                [static_cast<RBStoreExtendNoteDetailViewController *>(top) setButtonTextInstalled];
            }
        }
        [self.parent hideModalDialog];
    } else {
        StoreDownloadManager *manager = [[StoreDownloadManager alloc] initWithTasks:tasks
                                                                           delegate:self];
        self.downloadManager = manager;
        StoreDialogView *dialog = self.parent.modalDialog;
        [dialog layout:kModalDialogLayoutMessage];
        [dialog.labelMessage setText:g_pStoreInstallingMessage];
        [self.downloadManager start];
    }
}

- (BOOL)checkAttainLimitPurchase:(SKProduct *)product {
    int total = [[RBUserSettingData sharedInstance] totalPurchase];
    unsigned int limitType = [[RBUserSettingData sharedInstance] purchaseLimitType];
    int limitYen =
        (limitType < kPurchaseLimitTypeCount) ? kPurchaseLimitYen[limitType] : kPurchaseLimitNone;

    // Only yen-priced products contribute to the running purchase total.
    NSString *currencyCode = [product.priceLocale objectForKey:NSLocaleCurrencyCode];
    if ([currencyCode isEqualToString:kCurrencyCodeJPY]) {
        total = product.price.integerValue + total;
    }

    BOOL attained = NO;
    if (limitYen >= 0 && limitYen < total) {
        if (limitType == 0) {
            // No limit type has been chosen yet: prompt the player to pick one.
            self.purchaseLimitTypeSelectView =
                [UIAlertView showSelectPurchaseLimitTypeWithDelegate:self];
            [self.purchaseLimitTypeSelectView setTag:kAlertTagPurchaseLimitType];
        } else {
            [UIAlertView showPurchaseOverMessageWithDelegate:self];
        }
        attained = YES;
    }
    return attained;
}

- (void)startPurchase:(StoreExtendNoteInfo *)info {
    if (![RBPurchaseManager isPurchasable] || info.product == nil) {
        [UIAlertView showWithErrorMessage:g_pStorePurchaseFailedMessage delegate:nil];
        return;
    }

    self.purchasingExtendNoteInfo = info;
    if ([self checkAttainLimitPurchase:info.product]) {
        // A spending-limit alert was raised; the purchase does not proceed.
        return;
    }

    StoreDialogView *dialog = self.parent.modalDialog;
    [dialog layout:kModalDialogLayoutProgress];
    [dialog.labelMessage setText:g_pStorePurchasingMessage];
    [self.parent showModalDialog:self];
    [[RBPurchaseManager sharedManager] setDelegate:self];
    [[RBPurchaseManager sharedManager] beginPurchase:info.product];
}

- (void)detailViewClose {
    if (m_IsPad) {
        // On the pad the detail view is an overlay dismissed via the cover view's tap handler
        // rather than a navigation pop.
        [self handleTapCoverView:nil];
        return;
    }
    [self.navigationController popViewControllerAnimated:YES];
}

- (void)storeDialogCancel:(id)sender {
    if (self.downloadManager != nil) {
        [self.downloadManager cancel];
        self.downloadManager = nil;
    }
    [self.parent hideModalDialog];

    if (m_IsPad) {
        [self.extendNoteDetailViewPad selfCheckButtonText];
    } else {
        // Only refresh the detail controller's button text when the top view controller actually
        // is the note-detail screen.
        UIViewController *top = self.navigationController.topViewController;
        if ([top isKindOfClass:[RBStoreExtendNoteDetailViewController class]]) {
            [static_cast<RBStoreExtendNoteDetailViewController *>(top) selfCheckButtonText];
        }
    }

    [[RBMusicManager getInstance] savePurchasedMusics];
    [[RBExtendNoteManager getInstance] savePurchasedNotes];
}

#pragma mark - NSURLConnection delegate

- (void)connectionDidFinishLoading:(NSURLConnection *)connection {
    // Intentionally empty: NSURLConnection completion is unused here.
}

- (void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)error {
    // Intentionally empty: NSURLConnection failure is unused here.
}

#pragma mark - Purchased-cell updates

- (void)updateExtendNoteInfo:(StoreExtendNoteInfo *)info Save:(BOOL)save {
    if (info == nil) {
        return;
    }
    RBExtendNoteManager *mgr = [RBExtendNoteManager getInstance];
    [mgr addPurchasedExtendNote:info];
    if (save) {
        [[RBExtendNoteManager getInstance] savePurchasedNotes];
    }
}

- (void)updatePurchasedTableCell:(StoreExtendNoteInfo *)info {
    if (m_IsPad) {
        // Pad: locate the product's position in the flat product-ID list and reload the matching
        // row of section 0.
        NSArray *productIDList = [self.extendNoteListCtrl extendNoteProductIDList];
        for (NSUInteger i = 0; i < productIDList.count; ++i) {
            int listPid = [productIDList[i] intValue];
            if (listPid == [info pid]) {
                UITableView *table =
                    static_cast<UITableView *>([self.view viewWithTag:kPackTableViewTag]);
                // Two products share a row on the pad, so halve the index. The (index < 0) bump
                // mirrors the compiler's arithmetic-shift rounding fix-up for a signed halving;
                // the index is always non-negative in practice.
                int index = static_cast<int>(i);
                if (index < 0) {
                    index += 1;
                }
                NSIndexPath *path = [NSIndexPath indexPathForRow:(index >> kPadRowShift)
                                                       inSection:kPurchasedTableSectionPad];
                [table reloadRowsAtIndexPaths:@[ path ] withRowAnimation:kReloadRowAnimation];
                return;
            }
        }
        return;
    }

    // Phone: if the note-detail controller is on top, just flip its purchase state. Otherwise, if
    // this page controller is on top, find the product's row and reload it in section 1.
    UIViewController *top = self.navigationController.topViewController;
    if ([top isKindOfClass:[RBStoreExtendNoteDetailViewController class]]) {
        [static_cast<RBStoreExtendNoteDetailViewController *>(top)
            setPurchaseState:kPurchaseStatePurchased];
        return;
    }

    if (![self.navigationController.topViewController
            isKindOfClass:[RBStoreExtendPageViewController class]]) {
        return;
    }

    NSArray *productIDList = [self.extendNoteListCtrl extendNoteProductIDList];
    NSInteger row = -1;
    while (true) {
        // Faithful to the binary: the count is re-read each iteration and the row index is
        // pre-incremented before the bounds check.
        if (static_cast<NSInteger>(productIDList.count) <= row + 1) {
            return;
        }
        int listPid = [productIDList[row + 1] intValue];
        ++row;
        if (listPid == [info pid]) {
            break;
        }
    }

    UITableView *table = static_cast<UITableView *>([self.view viewWithTag:kPackTableViewTag]);
    NSIndexPath *path = [NSIndexPath indexPathForRow:row inSection:kPurchasedTableSectionPhone];
    [table reloadRowsAtIndexPaths:@[ path ] withRowAnimation:kReloadRowAnimation];
}

- (void)reDownloadPackMusics:(StoreExtendNoteInfo *)info {
    [self updateExtendNoteInfo:info Save:YES];
    [self startDownloadExtendNote:info];
}

#pragma mark - Purchase manager delegate

- (void)purchaseSucceeded:(NSString *)productID {
    int pid = [StoreUtil productIDToPid:productID];
    if (pid != [self.purchasingExtendNoteInfo pid]) {
        return;
    }

    [self updateExtendNoteInfo:self.purchasingExtendNoteInfo Save:YES];
    [[RBPurchaseManager sharedManager] addProductID:productID Save:YES];
    [[RBPurchaseManager sharedManager] setDelegate:nil];
    [self updatePurchasedTableCell:self.purchasingExtendNoteInfo];

    // Accumulate the JPY spend total only when the product is priced in yen.
    NSString *currencyCode =
        [self.purchasingExtendNoteInfo.product.priceLocale objectForKey:NSLocaleCurrencyCode];
    if ([currencyCode isEqualToString:kCurrencyCodeJPY]) {
        int price = [self.purchasingExtendNoteInfo.product.price intValue];
        int total = [[RBUserSettingData sharedInstance] totalPurchase];
        [[RBUserSettingData sharedInstance] setTotalPurchase:(total + price)];
    }
    [[RBUserSettingData sharedInstance] save];

    [self.parent.campaignViewCtrl refreshUnlockTable];
    [self startDownloadExtendNote:self.purchasingExtendNoteInfo];
}

- (void)purchaseFailed:(NSString *)productID error:(NSError *)error {
    [[RBPurchaseManager sharedManager] setDelegate:nil];
    self.purchasingExtendNoteInfo = nil;
    [self.parent hideModalDialog];

    NSString *message =
        [[NSString alloc] initWithFormat:kErrorMessageFormat, [error localizedDescription]];
    [UIAlertView showWithErrorMessage:message delegate:nil];
}

#pragma mark - Restore

- (void)addRestoreExtendNoteInfo:(StoreExtendNoteInfo *)info {
    [self.restoreExtendNoteInfo addObject:info];
    // The corresponding product ID has now been resolved, so drop it from the pending
    // restore-product set.
    NSString *productID = [StoreUtil pidToProductID:[info pid]];
    if ([self.restoreProductID containsObject:productID]) {
        [self.restoreProductID removeObject:productID];
    }
}

- (BOOL)nextRestoreExtendNoteInfo {
    // Snapshot the pending restore-product IDs. If there are none, report that there was nothing
    // to process.
    NSArray *pending = [self.restoreProductID copy];
    if (pending.count == 0) {
        return NO;
    }

    // Resolve every pending product ID synchronously: reuse the cached info if the list already
    // has it, otherwise fetch it from the product ID. Each resolved info is appended via
    // -addRestoreExtendNoteInfo: (which also removes the ID from the pending set).
    for (NSString *productID in pending) {
        int pid = [StoreUtil productIDToPid:productID];
        StoreExtendNoteInfo *info = [self.extendNoteListCtrl getExtendNoteInfoWithProductID:pid];
        if (info == nil) {
            int pid2 = [StoreUtil productIDToPid:productID];
            info = [self.extendNoteListCtrl addExtendNoteInfoFromProductID:pid2];
        }
        [self addRestoreExtendNoteInfo:info];
    }
    return YES;
}

- (void)askDownloadAllNotes {
    // Register every restored note as purchased (without saving each), then persist once.
    for (StoreExtendNoteInfo *info in self.restoreExtendNoteInfo) {
        [self updateExtendNoteInfo:info Save:NO];
    }
    [[RBExtendNoteManager getInstance] savePurchasedNotes];

    [[RBPurchaseManager sharedManager] addProductFromPurchaseCheckedProducts];
    [[RBPurchaseManager sharedManager] clearPurchaseCheckedProducts];
    [self.restoreProductID removeAllObjects];

    // Refresh the purchased-cell UI for each restored note.
    for (StoreExtendNoteInfo *info in self.restoreExtendNoteInfo) {
        [self updatePurchasedTableCell:info];
    }

    // Count how many restored notes are not yet present on disk.
    int missingCount = 0;
    for (StoreExtendNoteInfo *info in self.restoreExtendNoteInfo) {
        NSString *path = [RBExtendNoteManager getPathFromPurchased:[info extMusicID]];
        if (![NSFileManager isFileExist:path]) {
            ++missingCount;
        }
    }

    if (missingCount > 0) {
        // Some assets are missing: prompt the user to download them.
        UIAlertView *alert = [UIAlertView showRestoreDownloadWithDelegate:self];
        [alert setTag:kAlertTagRestoreDownload];
        return;
    }

    // Everything is already downloaded: clear the working set and dismiss.
    [self.restoreExtendNoteInfo removeAllObjects];
    [self.parent hideModalDialog];
}

- (void)restoreDownloadAllNotes {
    NSMutableArray *tasks = [NSMutableArray arrayWithCapacity:0];

    // Build a download task for each restored note whose file is missing.
    for (StoreExtendNoteInfo *info in self.restoreExtendNoteInfo) {
        NSString *path = [RBExtendNoteManager getPathFromPurchased:[info extMusicID]];
        if (![NSFileManager isFileExist:path]) {
            StoreDownloadTask *task =
                [[StoreDownloadTask alloc] initWithURL:[info extendURL]
                                                  path:path
                                             AddObject:[NSString stringWithString:[info name]]];
            [tasks addObject:task];
        }
    }

    [self.restoreExtendNoteInfo removeAllObjects];
    self.restoreExtendNoteInfo = nil;

    if (tasks == nil) {
        // Faithful to the binary: tasks is never nil here (it was just allocated), so this branch
        // is effectively dead; the download branch always runs.
        [self.parent hideModalDialog];
    } else {
        StoreDownloadManager *mgr = [[StoreDownloadManager alloc] initWithTasks:tasks
                                                                       delegate:self];
        self.downloadManager = mgr;

        StoreDialogView *dialog = self.parent.modalDialog;
        [dialog layout:kModalDialogLayoutMessage];
        [dialog.labelMessage setText:g_pStoreDownloadInProgressMessage];

        [self.downloadManager start];
    }
}

#pragma mark - Alert view delegate

- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex {
    switch ([alertView tag]) {
    case kAlertTagRestoreDownload:
        if (buttonIndex == kAlertButtonConfirm) {
            [self restoreDownloadAllNotes];
        } else {
            [self.restoreExtendNoteInfo removeAllObjects];
            self.restoreExtendNoteInfo = nil;
            [self.parent hideModalDialog];
        }
        break;

    case kAlertTagRestoreConfirm:
        if (buttonIndex == kAlertButtonConfirm) {
            StoreDialogView *dialog = self.parent.modalDialog;
            [dialog layout:kModalDialogLayoutProgress];
            [dialog.labelMessage setText:g_pStoreRestoreInProgressMessage];
            [self.parent showModalDialog:self];

            [[RBPurchaseManager sharedManager] setDelegate:self];
            [[RBPurchaseManager sharedManager] beginRestore];
        }
        break;

    case kAlertTagPurchaseLimitType:
        if (buttonIndex != 0) {
            if (buttonIndex < kPurchaseLimitTypeMaxButton) {
                [[RBUserSettingData sharedInstance]
                    setPurchaseLimitType:static_cast<int>(buttonIndex)];
                [self sendUserAge];
            } else {
                NSURL *url = [NSURL URLWithString:kKonamiInfoURLString];
                [[UIApplication sharedApplication] openURL:url];
            }
        }
        break;

    case kAlertTagPurchasePack:
        if (buttonIndex == kAlertButtonConfirm && [self moveToPackID] > 0) {
            NSString *packID = [NSString stringWithFormat:kPackIDFormat, [self moveToPackID]];
            [[AppDelegate appDelegate] setPackIDForOpenStore:packID];
            self.moveToPackID = kNoPendingPackID;
            [self.parent forceOpen];
        }
        break;

    case kAlertTagUserAgeConfirm:
        if (buttonIndex == kAlertButtonConfirm) {
            [self sendUserAge];
        } else {
            [[RBUserSettingData sharedInstance] setPurchaseLimitType:0];
        }
        break;
    }
}

- (void)alertViewCancel:(UIAlertView *)alertView {
    if ([alertView tag] == kAlertTagPurchasePack) {
        self.moveToPackID = kNoPendingPackID;
    }
}

- (void)didPresentAlertView:(UIAlertView *)alertView {
    // Route touches exclusively to the alert while a modal view controller is being presented
    // above the root.
    UIView *view =
        [UIApplication sharedApplication].keyWindow.rootViewController.presentedViewController.view;
    [UIAlertView setExclusiveTouchForView:view];
}

- (void)restoreSucceeded {
    if (self.restoreExtendNoteInfo != nil) {
        [self.restoreExtendNoteInfo removeAllObjects];
    }
    self.restoreExtendNoteInfo = [[NSMutableArray alloc] initWithCapacity:0];

    if (self.restoreProductID != nil) {
        [self.restoreProductID removeAllObjects];
    }
    self.restoreProductID = [[NSMutableArray alloc]
        initWithArray:[[RBPurchaseManager sharedManager] purchaseCheckedProducts]];

    // If there were no pending products to resolve, proceed straight to the download prompt.
    // (-nextRestoreExtendNoteInfo resolves all pending products synchronously and returns whether
    // any existed.)
    if (![self nextRestoreExtendNoteInfo]) {
        [self askDownloadAllNotes];
    }

    [self.parent.campaignViewCtrl refreshUnlockTable];
}

- (void)restoreFailed:(NSError *)error {
    [self.parent hideModalDialog];
    NSString *message =
        [[NSString alloc] initWithFormat:kErrorMessageFormat, [error localizedDescription]];
    [UIAlertView showWithErrorMessage:message delegate:nil];
}

- (void)restoreNothing {
    [self.parent hideModalDialog];
}

#pragma mark - Extend-note info downloader delegate

- (void)storeExtendNoteInfoDownloaderFinished:(StoreExtendNoteInfoDownloader *)downloader {
    [self addRestoreExtendNoteInfo:[downloader getExtendNoteInfo]];

    if (self.storeExtendNoteInfoDownloader != nil) {
        [self.storeExtendNoteInfoDownloader setDelegate:nil];
        self.storeExtendNoteInfoDownloader = nil;
    }

    // If more pending products remain to be resolved, advance to the download prompt. (Faithful
    // polarity: here YES triggers -askDownloadAllNotes, whereas -restoreSucceeded triggers it on
    // NO.)
    if ([self nextRestoreExtendNoteInfo]) {
        [self askDownloadAllNotes];
    }
}

- (void)storeExtendNoteInfoDownloaderError:(StoreExtendNoteInfoDownloader *)downloader {
    if (self.storeExtendNoteInfoDownloader != nil) {
        [self.storeExtendNoteInfoDownloader setDelegate:nil];
        self.storeExtendNoteInfoDownloader = nil;
    }
    [self.parent hideModalDialog];
}

#pragma mark - Download manager delegate

- (void)downloadManagerStartTask:(StoreDownloadManager *)manager {
    // Fetch the display name of the task about to start (the -addObject accessor returns the name
    // passed to the task's initWithURL:path:AddObject: initialiser), then show it in the parent's
    // modal-dialog message label through the download-progress format string.
    StoreDownloadTask *currentTask = manager.tasks[manager.currentIndex];
    NSString *taskName = [currentTask addObject];
    NSString *message = [NSString stringWithFormat:g_pDownloadingMessageFormat, taskName];
    self.parent.modalDialog.labelMessage.text = message;
}

- (void)downloadManagerCompleted:(StoreDownloadManager *)manager {
    self.downloadManager = nil;
    self.purchasingExtendNoteInfo = nil;

    if (!m_IsPad) {
        // On the phone the detail controller, if it is on top, refreshes its buy button to the
        // "installed" state.
        UIViewController *top = self.navigationController.topViewController;
        if ([top isKindOfClass:[RBStoreExtendNoteDetailViewController class]]) {
            [static_cast<RBStoreExtendNoteDetailViewController *>(top) setButtonTextInstalled];
        }
    } else {
        [self.extendNoteDetailViewPad setButtonTextInstalled];
    }

    [[RBMusicManager getInstance] savePurchasedMusics];
    [[RBExtendNoteManager getInstance] savePurchasedNotes];
    [self.parent hideModalDialog];
}

- (void)downloadManagerFailed:(StoreDownloadManager *)manager {
    self.downloadManager = nil;
    [self.parent hideModalDialog];

    NSString *failed = [[NSString alloc] initWithString:g_pStoreDownloadFailedMessage];
    [UIAlertView showWithErrorMessage:failed delegate:nil];

    if (!m_IsPad) {
        UIViewController *top = self.navigationController.topViewController;
        if ([top isKindOfClass:[RBStoreExtendNoteDetailViewController class]]) {
            [static_cast<RBStoreExtendNoteDetailViewController *>(top) selfCheckButtonText];
        }
    } else {
        [self.extendNoteDetailViewPad selfCheckButtonText];
    }

    [[RBMusicManager getInstance] savePurchasedMusics];
    [[RBExtendNoteManager getInstance] savePurchasedNotes];
}

- (void)downloadManagerProceed:(StoreDownloadManager *)manager {
    // Mirror the aggregate download progress into the parent's modal progress bar. The manager
    // argument is ignored in favour of the retained ivar.
    self.parent.modalDialog.progressView.progress = self.downloadManager.overallProgress;
}

#pragma mark - Table view data source and delegate

- (NSInteger)numPackRows {
    NSInteger count = self.extendNoteListCtrl.extendNoteProductIDList.count;
    if (!m_IsPad) {
        return count;
    }
    // Two products per pad row, rounded up.
    return (count + 1) >> 1;
}

- (UITableViewCell *)tableView:(UITableView *)tableView
         cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    NSArray *productIDList = self.extendNoteListCtrl.extendNoteProductIDList;

    if (!m_IsPad) {
        if (indexPath.row < [self numPackRows]) {
            // Phone pack cell: one product per row.
            UIImage *placeholder = [UIImage imageWithName:@"09_store/store_jacket_64"];
            StoreExtendNoteCellPhone *cell =
                [tableView dequeueReusableCellWithIdentifier:@"StoreExtendNotelistCell"];
            if (cell == nil) {
                cell = [[StoreExtendNoteCellPhone alloc] initWithStyle:UITableViewCellStyleDefault
                                                       reuseIdentifier:@"StoreExtendNotelistCell"];
            }
            int pid = [productIDList[indexPath.row] intValue];
            StoreExtendNoteInfo *info =
                [self.extendNoteListCtrl getExtendNoteInfoWithProductID:pid];
            [cell loadExtendNoteInfo:info index:indexPath.row];

            UIImage *artwork = StoreExtendPageArtworkForInfo(self, info, indexPath);
            cell.artworkLayer.contents =
                (artwork != nil) ? (__bridge id)artwork.CGImage : (__bridge id)placeholder.CGImage;
            return cell;
        }
        // Phone "show more"/loading footer cell.
        return StoreExtendPageMoreCell(
            tableView, @"StorePacklistMoreCell", m_IsPad, m_IsLoadingMoreList);
    }

    // iPad: two products per table row, split across the cell's left/right views.
    if (indexPath.row < [self numPackRows]) {
        NSString *reuseIdentifier =
            (indexPath.row & 1) ? @"StoreExtendNotelistCellOdd" : @"StoreExtendNotelistCellEven";
        StoreExtendNoteCell *cell = [tableView dequeueReusableCellWithIdentifier:reuseIdentifier];
        if (cell == nil) {
            cell = [[StoreExtendNoteCell alloc] initWithStyle:UITableViewCellStyleDefault
                                              reuseIdentifier:reuseIdentifier];
            [cell.leftView setDelegate:self];
            [cell.rightView setDelegate:self];
            UIImage *bg = (indexPath.row & 1) ? self.packBgImage1 : self.packBgImage0;
            [cell.leftView setBgImage:bg];
            [cell.rightView setBgImage:bg];
        }

        // Left half: product at (row * 2).
        NSInteger leftIndex = indexPath.row * kPadProductsPerRow;
        int leftPID = [productIDList[leftIndex] intValue];
        StoreExtendNoteInfo *leftInfo =
            [self.extendNoteListCtrl getExtendNoteInfoWithProductID:leftPID];
        [cell.leftView loadExtendNoteInfo:leftInfo index:leftIndex];
        NSIndexPath *leftPath = [NSIndexPath indexPathForRow:leftIndex inSection:indexPath.section];
        UIImage *leftArtwork = StoreExtendPageArtworkForPadInfo(self, leftInfo, leftPID, leftPath);
        [cell.leftView setArtwork:leftArtwork];

        // Right half: product at (row * 2 + 1), present only if it exists.
        NSInteger rightIndex = indexPath.row * kPadProductsPerRow + 1;
        if (rightIndex < static_cast<NSInteger>(productIDList.count)) {
            cell.rightView.hidden = NO;
            int rightPID = [productIDList[rightIndex] intValue];
            StoreExtendNoteInfo *rightInfo =
                [self.extendNoteListCtrl getExtendNoteInfoWithProductID:rightPID];
            [cell.rightView loadExtendNoteInfo:rightInfo index:rightIndex];
            NSIndexPath *rightPath = [NSIndexPath indexPathForRow:rightIndex
                                                        inSection:indexPath.section];
            UIImage *rightArtwork =
                StoreExtendPageArtworkForPadInfo(self, rightInfo, rightPID, rightPath);
            [cell.rightView setArtwork:rightArtwork];
        } else {
            cell.rightView.hidden = YES;
        }
        return cell;
    }
    // iPad "show more"/loading footer cell.
    return StoreExtendPageMoreCell(
        tableView, @"StoreExtendNotelistMoreCell", m_IsPad, m_IsLoadingMoreList);
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return kExtendNoteSectionCount;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    // Pack rows plus one trailing "show more" row when the list can continue. The pad and phone
    // arms are identical in the binary.
    return [self numPackRows] + (self.extendNoteListCtrl.extendNoteListContinued ? 1 : 0);
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    BOOL isPackRow = indexPath.row < [self numPackRows];
    if (!m_IsPad) {
        return isPackRow ? kPhonePackRowHeight : kPhoneMoreRowHeight;
    }
    return isPackRow ? kPadPackRowHeight : kPadMoreRowHeight;
}

- (void)tableView:(UITableView *)tableView
      willDisplayCell:(StoreExtendNoteCell *)cell
    forRowAtIndexPath:(NSIndexPath *)indexPath {
    BOOL isPackRow = indexPath.row < [self numPackRows];

    if (!m_IsPad) {
        if (isPackRow) {
            // Alternate the pack background image and its tint per row parity.
            UIImage *bg = (indexPath.row & 1) ? self.packBgImage1 : self.packBgImage0;
            [cell setBgImage:bg];
            UIColor *tint = (indexPath.row & 1) ? [UIColor colorWithRed:kPhoneOddRowWhite
                                                                  green:kPhoneOddRowWhite
                                                                   blue:kPhoneOddRowWhite
                                                                  alpha:1.0] :
                                                  [UIColor colorWithRed:kPhoneEvenRowWhite
                                                                  green:kPhoneEvenRowWhite
                                                                   blue:kPhoneEvenRowWhite
                                                                  alpha:1.0];
            [cell setBgColor:tint];
        } else {
            [cell setBackgroundColor:[UIColor colorWithWhite:g_dRBWebViewGrayViewWhite alpha:1.0]];
        }
    } else {
        if (isPackRow) {
            [cell setBackgroundColor:[UIColor colorWithWhite:kPadEvenRowWhite alpha:1.0]];
        } else {
            [cell setBackgroundColor:[UIColor colorWithWhite:g_dRBWebViewGrayViewWhite alpha:1.0]];
        }
    }
}

- (NSIndexPath *)tableView:(UITableView *)tableView
    willSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    return indexPath;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    // Only phone pack rows are tappable; the trailing "more" row and every pad row are inert (pad
    // selection is driven through the embedded cell views).
    if (indexPath.row != [self numPackRows] && !m_IsPad) {
        int pid = [self.extendNoteListCtrl.extendNoteProductIDList[indexPath.row] intValue];
        [self showDetailViewForPhone:pid];
    }
}

- (void)showDetailViewForPhone:(int)pid {
    RBStoreExtendNoteDetailViewController *detail =
        [[RBStoreExtendNoteDetailViewController alloc] init];
    [detail setDelegate:self];
    [detail setInfo:[self.extendNoteListCtrl getExtendNoteInfoWithProductID:pid]];
    // Clear any pending deep-link so the store does not re-open this detail.
    [AppDelegate appDelegate].extendNotePIDForOpenStore = 0;
    [self.navigationController pushViewController:detail animated:YES];
}

- (void)selectShowMore {
    if (m_IsLoadingMoreList) {
        return;
    }
    m_IsLoadingMoreList = YES;
    // Blank the button title, recentre it after a sizeToFit, reveal the spinner, hide the footer
    // spinner view, then fetch the next page.
    [self.showMoreButton setTitle:g_pStoreLoadingTitle forState:UIControlStateNormal];
    CGPoint centre = self.showMoreButton.center;
    [self.showMoreButton sizeToFit];
    [self.showMoreButton setCenter:centre];
    self.showMoreIndicator.hidden = NO;
    [self.view viewWithTag:kBannerLabelTag].hidden = YES;
    [self.extendNoteListCtrl startFetching];
}

#pragma mark - Image downloader delegate

- (void)imageDownloader:(ImageDownloader *)downloader didLoad:(NSIndexPath *)indexPath {
    UITableView *listView = static_cast<UITableView *>([self.view viewWithTag:kPackTableViewTag]);

    if (!m_IsPad) {
        StoreExtendNoteCellPhone *cell =
            static_cast<StoreExtendNoteCellPhone *>([listView cellForRowAtIndexPath:indexPath]);
        UIImage *image = downloader.getImage;
        if (cell != nil && image != nil) {
            cell.artworkLayer.contents = (__bridge id)image.CGImage;
        }
    } else {
        // The pad packs two products per row, so map the product-list row back to the table row
        // (row / 2) and pick the left or right embedded view by parity. The division rounds
        // towards zero for negatives.
        NSInteger row = indexPath.row;
        if (row < 0) {
            row += 1;
        }
        NSIndexPath *cellPath = [NSIndexPath indexPathForRow:(row >> 1)
                                                   inSection:indexPath.section];
        StoreExtendNoteCell *cell =
            static_cast<StoreExtendNoteCell *>([listView cellForRowAtIndexPath:cellPath]);
        UIImage *image = downloader.getImage;
        if (cell != nil && image != nil) {
            if ((indexPath.row & 1) == 0) {
                [cell.leftView setArtwork:image];
            } else {
                [cell.rightView setArtwork:image];
            }
        }
    }
}

- (void)imageDownloaderDidFail:(ImageDownloader *)downloader didLoad:(NSIndexPath *)indexPath {
    // Deliberately empty: a failed artwork download leaves the placeholder in place.
}

#pragma mark - Scroll view delegate

- (void)scrollViewDidScroll:(UIScrollView *)scrollView {
    // Auto-load the next page once the user scrolls past the content bottom.
    if (!m_IsLoadingMoreList && self.extendNoteListCtrl.extendNoteListContinued) {
        if (scrollView.contentOffset.y + scrollView.bounds.size.height >
            scrollView.contentSize.height) {
            [self selectShowMore];
        }
    }

    UIScrollView *listView = static_cast<UIScrollView *>([self.view viewWithTag:kPackTableViewTag]);

    // Pin the floating banner to the bottom of the visible content, clamped so it never floats
    // past the true content bottom by more than its own height plus the platform margin.
    UIView *banner = [listView viewWithTag:kBannerImageViewTag];
    CGFloat margin = m_IsPad ? kBannerBottomMarginPad : kBannerBottomMarginPhone;
    CGRect bannerFrame = banner.frame;
    bannerFrame.origin.y =
        StoreExtendPagePinnedBannerY(scrollView, listView, bannerFrame.size.height, margin, 1.0);
    [banner setFrame:bannerFrame];

    // A campaign-period banner (tag 0x186a2) is pinned the same way but anchored against half of
    // its own height.
    if ([[RBCampaignData sharedInstance] isCampaignHinabita201703]) {
        UIView *campaignBanner = [listView viewWithTag:kCampaignImageViewTag];
        CGFloat campaignMargin = m_IsPad ? kBannerBottomMarginPad : kBannerBottomMarginPhone;
        CGRect campaignFrame = campaignBanner.frame;
        campaignFrame.origin.y = StoreExtendPagePinnedBannerY(scrollView,
                                                              listView,
                                                              campaignFrame.size.height,
                                                              campaignMargin,
                                                              kCampaignBannerAnchorFraction);
        [campaignBanner setFrame:campaignFrame];
    }
}

- (void)stopDownloadArtworks {
    if (self.artworkDownloaders.count == 0) {
        return;
    }
    for (ImageDownloader *downloader in self.artworkDownloaders.allValues) {
        [downloader setDelegate:nil];
        [downloader cancelDownload];
    }
    [self.artworkDownloaders removeAllObjects];
}

#pragma mark - Appearance

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];

    // On the phone, re-highlight and then clear the row that was selected before the push, so the
    // list returns to an unselected state when the user comes back.
    UITableView *listTable = static_cast<UITableView *>([self.view viewWithTag:kPackTableViewTag]);
    if (!m_IsPad && !listTable.isHidden) {
        NSIndexPath *selected = listTable.indexPathForSelectedRow;
        if (selected != nil) {
            [listTable reloadRowsAtIndexPaths:@[ selected ]
                             withRowAnimation:UITableViewRowAnimationNone];
            [listTable deselectRowAtIndexPath:selected animated:animated];
        }
    }

    // Keep the error-message label sized to the view when it is showing.
    UILabel *errorLabel = static_cast<UILabel *>([self.view viewWithTag:kErrorMessageLabelTag]);
    if (errorLabel != nil && !errorLabel.isHidden) {
        errorLabel.frame = self.view.bounds;
    }

    // On the pad, refresh the detail overlay's action button while it is visible.
    if (GetFontVariantFlag() != kFontVariantDefault) {
        if (!self.extendNoteDetailViewPad.isHidden) {
            [self.extendNoteDetailViewPad selfCheckButtonText];
        }
    }

    // On the phone, reset the navigation bar to a plain white bar.
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

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];

    // If the list has never been fetched and no fetch is in flight, show the loading state and
    // kick off the first fetch; otherwise treat the already-loaded list as a completed download.
    if (self.extendNoteListCtrl.extendNoteProductIDList.count == 0 &&
        !self.extendNoteListCtrl.isFetching) {
        [self.view viewWithTag:kErrorMessageLabelTag].hidden = YES;
        [self.view viewWithTag:kPackTableViewTag].hidden = NO;
        [self.extendNoteListCtrl startFetching];
        return;
    }
    [self extendNoteListDownloadSuccess:self.extendNoteListCtrl];
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];

    // Tear down the pad detail overlay's in-flight work as the page leaves the screen.
    if (m_IsPad) {
        [self.extendNoteDetailViewPad cancelLoading];
        [self.extendNoteDetailViewPad stopSample];
    }

    // If a "show more" page fetch is running, cancel the loading state and re-enable the list.
    if (self.extendNoteListCtrl.isFetching) {
        m_IsLoadingMoreList = NO;
        UITableView *listTable =
            static_cast<UITableView *>([self.view viewWithTag:kPackTableViewTag]);
        listTable.allowsSelection = YES;
        [listTable reloadData];
    }

    // Drop the info downloader and stop any list fetch.
    if (self.storeExtendNoteInfoDownloader != nil) {
        self.storeExtendNoteInfoDownloader.delegate = nil;
        [self.storeExtendNoteInfoDownloader cancel];
        self.storeExtendNoteInfoDownloader = nil;
    }
    [self.extendNoteListCtrl cancelFetching];
}

#pragma mark - Rotation

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
    return YES;
}

- (void)willAnimateRotationToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
                                         duration:(NSTimeInterval)duration {
    [super willAnimateRotationToInterfaceOrientation:interfaceOrientation duration:duration];
}

- (void)didRotateFromInterfaceOrientation:(UIInterfaceOrientation)fromInterfaceOrientation {
}

#pragma mark - Memory

- (void)didReceiveMemoryWarning {
    [self.artworkDownloaders removeAllObjects];
    [super didReceiveMemoryWarning];
}

- (void)dealloc {
    // The info downloader retains a delegate back to this controller, so detach and cancel it
    // before the controller is torn down.
    if (self.storeExtendNoteInfoDownloader != nil) {
        self.storeExtendNoteInfoDownloader.delegate = nil;
        [self.storeExtendNoteInfoDownloader cancel];
    }
}

#pragma mark - Loading state

- (void)showLoadingView {
    // Put the list into its loading state: hide and lock the list, scroll it back to the top, show
    // the banner container, and hide the error label, the pack-section label, the "show more"
    // button, and its spinner.
    UITableView *listTable = static_cast<UITableView *>([self.view viewWithTag:kPackTableViewTag]);
    UIView *bannerContainer = [self.view viewWithTag:kLoadingTitleLabelTag];
    UIView *loadingHost = [listTable viewWithTag:kBannerLabelTag];

    if (listTable != nil) {
        listTable.hidden = YES;
        listTable.allowsSelection = NO;
        // Scroll the list's own size rectangle, anchored at the origin, back into view.
        CGRect visibleRect =
            CGRectMake(0, 0, listTable.frame.size.width, listTable.frame.size.height);
        [listTable scrollRectToVisible:visibleRect animated:NO];
    }
    if (bannerContainer != nil) {
        bannerContainer.hidden = NO;
    }
    if (loadingHost != nil) {
        loadingHost.hidden = YES;
    }
    if (self.packTableLabel != nil) {
        self.packTableLabel.hidden = YES;
    }
    m_IsLoadingMoreList = NO;
    if (self.restoreButton != nil) {
        self.restoreButton.enabled = NO;
    }
    if (self.showMoreButton != nil) {
        self.showMoreButton.hidden = YES;
    }
    if (self.showMoreIndicator != nil) {
        self.showMoreIndicator.hidden = YES;
    }
}

#pragma mark - Popover delegate

- (void)popoverControllerDidDismissPopover:(UIPopoverController *)popoverController {
    // Re-enable the navigation bar's back button and the restore button once the popover closes.
    self.navigationItem.leftBarButtonItem.enabled = YES;
    self.restoreButton.enabled = YES;
}

#pragma mark - iTunes product page

- (void)storeDetailViewOpenItunesWithURL:(NSString *)url {
    if (url != nil) {
        [[AppDelegate appDelegate].viewController openItunesWithURL:url];
    }
}

- (void)openItunesWithURL:(NSString *)url {
    if (url == nil) {
        return;
    }

    // When the URL carries affiliate parameters, present the in-app StoreKit product page seeded
    // with them; otherwise fall back to opening the URL in Safari.
    NSDictionary *affiliateParameters = [StoreUtil affiliateParametersFromURL:url];
    if (affiliateParameters == nil) {
        [[UIApplication sharedApplication] openURL:[NSURL URLWithString:url]];
        return;
    }

    self.itunesViewCtrl = [[SKStoreProductViewController alloc] init];
    self.itunesViewCtrl.delegate = self;
    UIViewController *presenter = self.view.window.rootViewController;
    [presenter presentViewController:self.itunesViewCtrl
                            animated:YES
                          completion:^{
                            /** @ghidraAddress 0x1676c8 */
                            // Once the product page is on screen, load the affiliate product.
                            [self.itunesViewCtrl loadProductWithParameters:affiliateParameters
                                                           completionBlock:nil];
                          }];
}

- (void)closeItunesWithURL {
    [self productViewControllerDidFinish:self.itunesViewCtrl];
}

- (void)productViewControllerDidFinish:(SKStoreProductViewController *)viewController {
    if (self.itunesViewCtrl != nil) {
        [self dismissViewControllerAnimated:YES
                                 completion:^{
                                   /** @ghidraAddress 0x167890 */
                                   self.itunesViewCtrl = nil;
                                 }];
    }
}

@end

#pragma mark - De-inlined helpers

// The following helpers fold the repeated cell-configuration and banner-pin arithmetic that the
// compiler inlined four times across the two device arms.

// Resolve or kick off the artwork download for a phone pack cell. Returns the cached image, or nil
// while a fresh download is in flight (indexed by product ID via a boxed NSNumber).
static inline UIImage *StoreExtendPageArtworkForInfo(RBStoreExtendPageViewController *self,
                                                     StoreExtendNoteInfo *info,
                                                     NSIndexPath *indexPath) {
    ImageDownloader *existing = self.artworkDownloaders[@(info.pid)];
    if (existing != nil) {
        return existing.getImage;
    }
    if (info.artworkURL == nil) {
        return nil;
    }
    ImageDownloader *downloader = [[ImageDownloader alloc] init];
    [downloader setImageURL:info.artworkURL];
    [downloader setIndexPathInTableView:indexPath];
    [downloader setDelegate:self];
    [downloader setUnUseRetina:YES];
    self.artworkDownloaders[@(info.pid)] = downloader;
    [downloader startDownload];
    return nil;
}

// Pad variant: keyed by product ID via numberWithInteger: on lookup and numberWithInt: on insert
// (faithful to the binary's mismatched key encodings), with no unUseRetina override.
static inline UIImage *StoreExtendPageArtworkForPadInfo(RBStoreExtendPageViewController *self,
                                                        StoreExtendNoteInfo *info,
                                                        int pid,
                                                        NSIndexPath *indexPath) {
    ImageDownloader *existing = self.artworkDownloaders[[NSNumber numberWithInteger:pid]];
    if (existing != nil) {
        return existing.getImage;
    }
    if (info.artworkURL == nil) {
        return nil;
    }
    ImageDownloader *downloader = [[ImageDownloader alloc] init];
    [downloader setImageURL:info.artworkURL];
    [downloader setIndexPathInTableView:indexPath];
    [downloader setDelegate:self];
    self.artworkDownloaders[@(pid)] = downloader;
    [downloader startDownload];
    return nil;
}

// Build the trailing "show more"/loading footer cell, identical apart from the reuse identifier
// per device arm.
static inline UITableViewCell *StoreExtendPageMoreCell(UITableView *tableView,
                                                       NSString *reuseIdentifier,
                                                       BOOL isPad,
                                                       BOOL isLoadingMore) {
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:reuseIdentifier];
    if (cell == nil) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault
                                      reuseIdentifier:reuseIdentifier];
        CGFloat fontSize = isPad ? kMoreCellFontSizePad : kMoreCellFontSizePhone;
        cell.textLabel.font = [UIFont boldSystemFontOfSize:fontSize];
        cell.textLabel.textAlignment = static_cast<NSTextAlignment>(kTextAlignmentCentre);
    }

    if (!isLoadingMore) {
        cell.accessoryView = nil;
        cell.textLabel.textColor = [UIColor colorWithWhite:g_dTranslucentAlpha alpha:1.0];
        cell.textLabel.shadowColor = [UIColor colorWithWhite:kMoreCellTextWhite alpha:1.0];
        cell.textLabel.text = g_pStoreShowMoreTitle;
    } else {
        UIActivityIndicatorView *spinner =
            [[UIActivityIndicatorView alloc] initWithFrame:CGRectZero];
        [spinner setActivityIndicatorViewStyle:static_cast<UIActivityIndicatorViewStyle>(
                                                   kActivityIndicatorStyleGray)];
        cell.accessoryView = spinner;
        [spinner startAnimating];
        cell.textLabel.textColor = [UIColor colorWithWhite:kMoreCellTextWhite alpha:1.0];
        cell.textLabel.shadowColor = nil;
        cell.textLabel.text = g_pStoreLoadingTitle;
    }
    return cell;
}

// Compute the pinned Y for a floating banner. The banner tracks the bottom of the visible content:
// it sits at min(contentSize.height, bounds.height) but, once the user scrolls far enough that the
// banner would fall short of contentOffset.y + bounds.height, it snaps to
// (contentOffset.y + bounds.height) - bannerHeight * anchorFraction. The full-height floating
// banner uses anchorFraction 1.0; the campaign banner uses 0.5. margin is the platform slack (100
// phone / 300 pad).
static inline CGFloat StoreExtendPagePinnedBannerY(UIScrollView *scrollView,
                                                   UIScrollView *listView,
                                                   CGFloat bannerHeight,
                                                   CGFloat margin,
                                                   CGFloat anchorFraction) {
    CGFloat visibleExtent;
    CGFloat scrollOffsetY = scrollView.contentOffset.y;
    CGFloat scrollBoundsH = scrollView.bounds.size.height;
    CGFloat anchoredHeight = bannerHeight * anchorFraction;

    if (listView.contentSize.height > listView.bounds.size.height) {
        visibleExtent = scrollView.contentSize.height;
    } else {
        visibleExtent = scrollView.bounds.size.height;
    }

    CGFloat baseY = margin + visibleExtent;
    if (anchoredHeight + baseY < scrollOffsetY + scrollBoundsH) {
        return (baseY + scrollOffsetY) - anchoredHeight;
    }
    return baseY;
}
