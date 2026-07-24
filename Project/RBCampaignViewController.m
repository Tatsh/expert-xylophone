#import "RBCampaignViewController.h"

#import <UIKit/UIKit.h>

#import "AppDelegate.h"
#import "Downloader.h"
#import "ImageDownloader.h"
#import "RBBGMManager.h"
#import "RBCampaignDetailViewController.h"
#import "RBExperienceData.h"
#import "RBMusicManager.h"
#import "RBStoreExtendPageViewController.h"
#import "RBStoreTabController.h"
#import "StoreCampaignDetailViewPad.h"
#import "StoreCampaignItemInfo.h"
#import "StoreCampaignTableViewCell.h"
#import "StoreDialogView.h"
#import "StoreDownloadManager.h"
#import "StoreDownloadTask.h"
#import "StoreMusicInfo.h"
#import "StoreUtil.h"
#import "UIAlertView+RB.h"
#import "UIImage+RB.h"
#import "deviceenvironment.h"
#import "engineglobals.h"

// The sentinel stored in workingIndex and samplePlayedIndex when no row is active.
static const int kNoActiveIndex = -1;

// The campaign tab-bar item image and the two shared cell state images.
static NSString *const kTabBarImageName = @"09_store_tab_present";
static NSString *const kDeleteImageName = @"09_store_manage_delete";
static NSString *const kDownloadImageName = @"09_store_manage_download";

// The reuse identifier for the campaign list cell.
static NSString *const kCampaignCellIdentifier = @"StoreCampaignCell";

// The campaign tab label, used for the navigation and tab-bar item titles.
static NSString *const kGiftTitle = @"Gift";
// The store back bar-button title.
static NSString *const kBackButtonTitle = @"Back";

// The maximum number of campaign items requested in one list fetch, starting at offset zero.
static const int kCampaignListOffset = 0;
static const int kCampaignListLimit = 20;

// The POST content type for the campaign JSON requests. @ghidraAddress 0x364140
static NSString *const kJSONContentType = @"application/json";

// The itunes.apple.com fallback opened when the update alert's action button is tapped.
static NSString *const kUpdateAppStoreURL =
    @"http://itunes.apple.com/WebObjects/MZStore.woa/wa/viewSoftware?id=395192484&mt=8";

// The list-item table row heights: 50 points on the phone, 60 on the pad. @ghidraAddress 0x3107b0
static const CGFloat kRowHeightPhone = 50.0;
static const CGFloat kRowHeightPad = 60.0;

// The loading-label text colour, a light grey. @ghidraAddress 0x30be90
static const CGFloat kLoadingLabelRed = 0.886274516582489;
static const CGFloat kLoadingLabelGreen = 0.8901960849761963;
static const CGFloat kLoadingLabelBlue = 0.8941176533699036;
static const CGFloat kOpaqueAlpha = 1.0;

// The label shadow white value used for the loading and error text. @ghidraAddress 0x2eecb8
static const CGFloat kLabelShadowWhite = 0.6196078658103943;
// The even-row background white value. @ghidraAddress 0x310790
static const CGFloat kAlternateRowWhite = 0.7568627595901489;
// The sample-playback BGM fade-in time.
static const float kSampleBGMFadeTime = 0.5f;
// The loading-label point size, and the error-label point sizes per device idiom.
static const CGFloat kLoadingLabelFontSize = 18.0;
static const CGFloat kErrorLabelFontSizeDefault = 16.0;
static const CGFloat kErrorLabelFontSizeWide = 18.0;
// The error label's vertical offset above the view centre. @ghidraAddress 0x301220
static const CGFloat kErrorLabelCenterYOffset = -44.0;
// The one-point drop-shadow offset shared by the loading and error labels.
static const CGFloat kLabelShadowOffset = 1.0;

// The activity-indicator container is a fixed 24-point square centred over the loading label.
static const CGFloat kActivityIndicatorSize = 24.0;
static const CGFloat kCenterScale = 0.5;

// The dimming cover behind the pad detail overlay is black at 50% opacity.
static const CGFloat kPadCoverBlackWhite = 0.0;
static const CGFloat kPadCoverAlpha = 0.5;

// The banner-artwork cross-fade duration. @ghidraAddress 0x2eece8
static const NSTimeInterval kBannerFadeDuration = 0.2;
// The pad detail open/close animation duration. @ghidraAddress 0x3010a0
static const NSTimeInterval kPadDetailAnimDuration = 0.3;
// The pad detail overlay is a fixed 650-point square. @ghidraAddress 0x2eec30
static const CGFloat kPadDetailViewSize = 650.0;

// The tag marking the on-screen serial-code input alert.
static const NSInteger kSerialCodeAlertTag = 1;
// The alert dismissal indices: 0 is the cancel/left button, 1 is the confirm/right button.
static const NSInteger kAlertCancelButtonIndex = 0;
static const NSInteger kAlertConfirmButtonIndex = 1;

// The action-button kinds carried by a campaign item's buttonType.
enum {
    kCampaignButtonInfoDownload = 0, // Download the item's info.
    kCampaignButtonTerms = 2,        // Show the unlock terms description.
    kCampaignButtonUpdate = 3,       // Prompt to update the application.
    kCampaignButtonSerialCode = 4,   // Prompt for a serial code.
};

// The hideType value that removes an item from the visible row list.
static const int kCampaignHideTypeHidden = 2;

// The itemType value identifying a downloadable tune.
static const int kCampaignItemTypeTune = 0;

// The status field value indicating a successful server response.
static const int kServerStatusSuccess = 0;

// The UTF-8 encoding constant passed to -dataUsingEncoding:.
static const NSUInteger kUTF8Encoding = NSUTF8StringEncoding;

// The serial-code input alert's single text field index.
static const NSInteger kSerialCodeTextFieldIndex = 0;

// The dimming cover flexes in every direction so it tracks its host's bounds. @ghidraAddress
// 0x310450 (g_dwAutoresizingMaskFlexibleAll)
static const UIViewAutoresizing kAutoresizingMaskFlexibleAll =
    UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleWidth |
    UIViewAutoresizingFlexibleRightMargin | UIViewAutoresizingFlexibleTopMargin |
    UIViewAutoresizingFlexibleHeight | UIViewAutoresizingFlexibleBottomMargin;

// The table view flexes only its width and height. @ghidraAddress 0x310458
static const UIViewAutoresizing kAutoresizingMaskFlexibleSize =
    UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;

// The server unlock-list dictionary keys.
static NSString *const kJSONKeyList = @"list";
static NSString *const kJSONKeyError = @"error";
static NSString *const kJSONKeyStatus = @"status";
static NSString *const kJSONKeyURL = @"url";
static NSString *const kJSONKeyCampaignId = @"campaignId";
static NSString *const kJSONKeyUnlocked = @"unlocked";
static NSString *const kJSONKeyTrue = @"true";
// The unlock-dictionary keys carrying the granted experience type and identifier.
static NSString *const kUnlockKeyType = @"type";
static NSString *const kUnlockKeyID = @"id";
// The campaign-identifier format used to match a checked item against a list entry.
static NSString *const kCampaignIdFormat = @"%d";

@interface RBCampaignViewController () <UIAlertViewDelegate, UIGestureRecognizerDelegate> {
    // Unused by the campaign page; retained from the shared store layout.
    int infoRandomKey;
}
// Whether the pad (wide iPad idiom) layout is active.
@property(nonatomic, assign) BOOL isPad;
// The row whose action button is mid-flight, or kNoActiveIndex when none is working.
@property(nonatomic, assign) int workingIndex;
// The row whose audio sample is playing, or kNoActiveIndex when none is playing.
@property(nonatomic, assign) int samplePlayedIndex;

// The info-downloader completion branches, de-inlined from the single binary downloaderFinished:.
- (void)handleInfoDownloaderFinished:(Downloader *)downloader;
- (void)handleMusicInfoDownloaderFinished:(Downloader *)downloader;
- (void)handleTermsCheckerFinished:(Downloader *)downloader;
- (void)handleItemURLDownloaderFinished:(Downloader *)downloader;
@end

@implementation RBCampaignViewController

// The binary names these three ivars without the underscore prefix.
@synthesize isPad = isPad;
@synthesize workingIndex = workingIndex;
@synthesize samplePlayedIndex = samplePlayedIndex;

#pragma mark - Lifecycle

/** @ghidraAddress 0x1f8e2c */
- (instancetype)initWithParent:(RBStoreTabController *)parent {
    self = [super init];
    if (!self) {
        return nil;
    }

    self.parent = parent;
    self.navigationItem.title = kGiftTitle;
    self.tabBarItem.title = kGiftTitle;
    self.tabBarItem.image = [UIImage imageWithName:kTabBarImageName];
    if ([self respondsToSelector:@selector(setExtendedLayoutIncludesOpaqueBars:)]) {
        [self performSelector:@selector(setExtendedLayoutIncludesOpaqueBars:) withObject:nil];
    }

    self.imgDelete = [UIImage imageWithName:kDeleteImageName];
    self.imgDownload = [UIImage imageWithName:kDownloadImageName];

    UIBarButtonItem *back = [[UIBarButtonItem alloc] initWithTitle:kBackButtonTitle
                                                             style:UIBarButtonItemStyleBordered
                                                            target:parent
                                                            action:@selector(storeEnd:)];
    self.navigationItem.leftBarButtonItem = back;

    self.isPad = IsPad();
    self.workingIndex = kNoActiveIndex;
    self.samplePlayedIndex = kNoActiveIndex;
    self.unlockMusicCheckList = nil;
    self.firstDownloadFailed = NO;
    self.imageDownloaderList = [[NSMutableDictionary alloc] init];

    [self downloadCampaignList];
    return self;
}

/** @ghidraAddress 0x1f9220 */
- (void)loadView {
    [super loadView];

    self.view.opaque = YES;
    self.view.backgroundColor = [UIColor colorWithRed:kLoadingLabelRed
                                                green:kLoadingLabelGreen
                                                 blue:kLoadingLabelBlue
                                                alpha:kOpaqueAlpha];
    self.view.autoresizesSubviews = YES;
    self.view.autoresizingMask = kAutoresizingMaskFlexibleSize;
    self.view.exclusiveTouch = YES;

    UITableView *table = [[UITableView alloc] initWithFrame:self.view.bounds
                                                      style:UITableViewStylePlain];
    self.tableView = table;
    self.tableView.autoresizingMask = kAutoresizingMaskFlexibleSize;
    self.tableView.rowHeight = self.isPad ? kRowHeightPad : kRowHeightPhone;
    self.tableView.delegate = self;
    self.tableView.dataSource = self;
    self.tableView.allowsSelection = YES;
    self.tableView.separatorStyle = UITableViewCellSeparatorStyleNone;
    self.tableView.backgroundColor = UIColor.clearColor;
    [self.view addSubview:self.tableView];

    if (self.unlockMusicCheckList != nil) {
        self.loadingLabel.hidden = YES;
        [self refreshMusicList];
    } else {
        [self downloadCampaignList];
    }

    if (self.isPad) {
        UIView *cover = [[UIView alloc] initWithFrame:self.view.bounds];
        self.coverViewPad = cover;
        self.coverViewPad.autoresizingMask = kAutoresizingMaskFlexibleAll;
        self.coverViewPad.opaque = NO;
        self.coverViewPad.backgroundColor = [UIColor colorWithWhite:kPadCoverBlackWhite
                                                              alpha:kPadCoverAlpha];
        self.coverViewPad.userInteractionEnabled = YES;
        self.coverViewPad.exclusiveTouch = YES;
        UITapGestureRecognizer *tap =
            [[UITapGestureRecognizer alloc] initWithTarget:self
                                                    action:@selector(handleTapCoverView:)];
        [self.coverViewPad addGestureRecognizer:tap];
        self.coverViewPad.hidden = YES;
        [self.view addSubview:self.coverViewPad];

        StoreCampaignDetailViewPad *detail = [[StoreCampaignDetailViewPad alloc]
            initWithFrame:CGRectMake(0, 0, kPadDetailViewSize, kPadDetailViewSize)];
        self.itemDetailViewPad = detail;
        self.itemDetailViewPad.center =
            CGPointMake(self.coverViewPad.center.x, self.coverViewPad.center.y);
        self.itemDetailViewPad.autoresizingMask = kAutoresizingMaskFlexibleAll;
        self.itemDetailViewPad.delegate = self;
        self.itemDetailViewPad.hidden = YES;
        [self.view addSubview:self.itemDetailViewPad];
    }

    if (self.loadingLabel == nil) {
        UILabel *loading = [[UILabel alloc] initWithFrame:self.view.bounds];
        self.loadingLabel = loading;
        self.loadingLabel.backgroundColor = [UIColor colorWithRed:kLoadingLabelRed
                                                            green:kLoadingLabelGreen
                                                             blue:kLoadingLabelBlue
                                                            alpha:kOpaqueAlpha];
        self.loadingLabel.font = [UIFont boldSystemFontOfSize:kLoadingLabelFontSize];
        self.loadingLabel.textColor = [UIColor colorWithWhite:kLabelShadowWhite alpha:kOpaqueAlpha];
        // The binary reuses the resume-fade-in time (0.3) as the shadow alpha here.
        self.loadingLabel.shadowColor = [UIColor colorWithWhite:kOpaqueAlpha
                                                          alpha:g_dAudioManagerResumeFadeInTime];
        self.loadingLabel.shadowOffset = CGSizeMake(0, kLabelShadowOffset);
        self.loadingLabel.textAlignment = NSTextAlignmentCenter;
        self.loadingLabel.center = CGPointMake(self.view.bounds.size.width * kCenterScale,
                                               self.view.bounds.size.height * kCenterScale);
        self.loadingLabel.autoresizingMask = kAutoresizingMaskFlexibleSize;
        self.loadingLabel.text = g_pStoreLoadingTitle;
        self.loadingLabel.hidden = NO;
        [self.view addSubview:self.loadingLabel];

        UIView *indicatorHost = [[UIView alloc] initWithFrame:self.view.bounds];
        indicatorHost.backgroundColor = UIColor.clearColor;
        indicatorHost.autoresizingMask = kAutoresizingMaskFlexibleSize;
        indicatorHost.center = CGPointMake(self.loadingLabel.bounds.size.width * kCenterScale,
                                           self.loadingLabel.bounds.size.height * kCenterScale);
        [self.loadingLabel addSubview:indicatorHost];

        UIActivityIndicatorView *indicator = [[UIActivityIndicatorView alloc]
            initWithFrame:CGRectMake(0, 0, kActivityIndicatorSize, kActivityIndicatorSize)];
        indicator.activityIndicatorViewStyle = UIActivityIndicatorViewStyleWhite;
        indicator.center = CGPointMake(indicatorHost.bounds.size.width * kCenterScale,
                                       indicatorHost.bounds.size.height * kCenterScale);
        indicator.autoresizingMask =
            UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin |
            UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleBottomMargin;
        [indicator startAnimating];
        [indicatorHost addSubview:indicator];
    }

    if (self.unlockMusicCheckList != nil) {
        self.loadingLabel.hidden = YES;
    }

    if (self.errorLabel == nil) {
        UILabel *error = [[UILabel alloc] initWithFrame:self.view.bounds];
        self.errorLabel = error;
        self.errorLabel.backgroundColor = self.view.backgroundColor;
        CGFloat errorFontSize = !IsPad() ? kErrorLabelFontSizeDefault : kErrorLabelFontSizeWide;
        self.errorLabel.font = [UIFont boldSystemFontOfSize:errorFontSize];
        self.errorLabel.textColor = [UIColor colorWithWhite:kLabelShadowWhite alpha:kOpaqueAlpha];
        self.errorLabel.textAlignment = NSTextAlignmentCenter;
        self.errorLabel.numberOfLines = 0;
        self.errorLabel.center =
            CGPointMake(self.view.bounds.size.width * kCenterScale,
                        self.view.bounds.size.height * kCenterScale + kErrorLabelCenterYOffset);
        self.errorLabel.autoresizingMask = kAutoresizingMaskFlexibleAll;
        self.errorLabel.hidden = YES;
        [self.view addSubview:self.errorLabel];
    }
}

/**
 * The binary's dealloc only chains to super; under ARC that chaining is implicit, so the body is
 * empty. @ghidraAddress 0x1ffff4
 */
- (void)dealloc {
}

#pragma mark - View lifecycle

/** @ghidraAddress 0x1ff728 */
- (void)viewWillAppear:(BOOL)animated {
    if (self.unlockMusicCheckList != nil) {
        [self refreshUnlockTable];
        [self refreshMusicList];
    }
    [super viewWillAppear:animated];
}

/** @ghidraAddress 0x1ff7bc */
- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    [self.tableView flashScrollIndicators];
    if ([[AppDelegate appDelegate] getCampaignIDForOpenStore] != nil &&
        self.downloadMusicList.count != 0) {
        [self forceOpenCampaignDetailView];
    }
    [self.tableView reloadData];
}

/** @ghidraAddress 0x1ff91c */
- (void)viewWillDisappear:(BOOL)animated {
    if (self.isPad) {
        [self.itemDetailViewPad sampleStop];
    }
    [self alertViewClose];
    [super viewWillDisappear:animated];
}

/** @ghidraAddress 0x1ff9d4 */
- (void)viewDidDisappear:(BOOL)animated {
    if (self.samplePlayedIndex != kNoActiveIndex) {
        [self sampleStop];
    }
    [super viewDidDisappear:animated];
}

/** @ghidraAddress 0x1ff6a0 */
- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
}

/** @ghidraAddress 0x1ff6d4 */
- (void)viewDidUnload {
    [super viewDidUnload];
    self.tableView = nil;
}

/** @ghidraAddress 0x1ffc30 */
- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
    return YES;
}

/** @ghidraAddress 0x1ffc38 */
- (void)willAnimateRotationToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
                                         duration:(NSTimeInterval)duration {
    [super willAnimateRotationToInterfaceOrientation:interfaceOrientation duration:duration];
}

#pragma mark - Campaign list download

/** @ghidraAddress 0x1fa700 */
- (void)downloadCampaignList {
    NSString *json = [StoreUtil createCampaignListJSON:kCampaignListOffset
                                                 limit:kCampaignListLimit];
    self.infoDownloader = [[Downloader alloc] initWithURL:[StoreUtil campaignListURL]
                                                     post:[json dataUsingEncoding:kUTF8Encoding]
                                              contentType:kJSONContentType];
    [self.infoDownloader startDownloadingWithDelegate:self];
}

/** @ghidraAddress 0x1ffe00 */
- (void)itemInfoDownload {
    NSURL *url = [StoreUtil campaignItemInfoURL];
    StoreCampaignItemInfo *item = self.downloadMusicList[self.workingIndex];
    NSString *json = [StoreUtil createCampaignItemInfoJSON:item.campaignID];
    self.itemURLDownloader = [[Downloader alloc] initWithURL:url
                                                        post:[json dataUsingEncoding:kUTF8Encoding]
                                                 contentType:kJSONContentType];
    [self.itemURLDownloader startDownloadingWithDelegate:self];
}

#pragma mark - Table view data source and delegate

/** @ghidraAddress 0x1fb0dc */
- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}

/** @ghidraAddress 0x1faf5c */
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    if (self.downloadMusicList != nil) {
        return self.downloadMusicList.count;
    }
    return 0;
}

/** @ghidraAddress 0x1fb0e4 */
- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    return [StoreCampaignTableViewCell cellHeight:self.isPad];
}

/** @ghidraAddress 0x1fa878 */
- (UITableViewCell *)tableView:(UITableView *)tableView
         cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    StoreCampaignTableViewCell *cell =
        [self.tableView dequeueReusableCellWithIdentifier:kCampaignCellIdentifier];
    StoreCampaignItemInfo *item = self.downloadMusicList[indexPath.row];
    if (cell == nil) {
        cell = [[StoreCampaignTableViewCell alloc] initWithDeviceType:self.isPad
                                                      reuseIdentifier:kCampaignCellIdentifier
                                                                  tag:(int)indexPath.row];
    } else {
        cell.tag = indexPath.row;
    }
    [cell setInfo:item tag:(int)indexPath.row];

    NSIndexPath *cellIndexPath = [NSIndexPath indexPathForRow:indexPath.row
                                                    inSection:indexPath.section];
    ImageDownloader *banner = self.imageDownloaderList[@(item.campaignID)];
    if (banner == nil) {
        if (item.campaignBannerURL != nil) {
            banner = [[ImageDownloader alloc] init];
            banner.imageURL = item.campaignBannerURL;
            banner.indexPathInTableView = cellIndexPath;
            banner.delegate = self;
            self.imageDownloaderList[@(item.campaignID)] = banner;
            [banner startDownload];
        }
    } else if (banner.getImage != nil) {
        CGSize size = [cell getItemSize:self.isPad];
        cell.artworkView.frame = CGRectMake(0, 0, size.width, size.height);
        cell.artworkView.image = banner.getImage;
        // The artwork fades in; the completion block sets the view's alpha back to one.
        __weak UIImageView *weakArtwork = cell.artworkView;
        [UIView animateWithDuration:kBannerFadeDuration
                         animations:^{
                           /** @ghidraAddress 0x1fa878 (block invoke) */
                           weakArtwork.alpha = kOpaqueAlpha;
                         }];
    }
    return cell;
}

/** @ghidraAddress 0x1faf90 */
- (void)tableView:(UITableView *)tableView
      willDisplayCell:(UITableViewCell *)cell
    forRowAtIndexPath:(NSIndexPath *)indexPath {
    // Alternate rows carry a slightly different translucent background.
    CGFloat white = (indexPath.row & 1) == 0 ? kAlternateRowWhite : g_dTranslucentAlpha;
    cell.backgroundColor = [UIColor colorWithWhite:white alpha:kOpaqueAlpha];
}

/** @ghidraAddress 0x1fb118 */
- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    if (self.isPad) {
        [self showDetailView:indexPath.row];
    } else {
        [self showDetailViewForPhone:self.downloadMusicList[indexPath.row]];
    }
}

#pragma mark - Detail presentation

/** @ghidraAddress 0x1ffa44 */
- (void)showDetailViewForPhone:(id)item {
    RBCampaignDetailViewController *detail =
        [[RBCampaignDetailViewController alloc] initWithItemInfo:item];
    [detail setDelegate:self];
    [[AppDelegate appDelegate] setCampaignIDForOpenStore:nil];
    for (NSUInteger i = 0; i < self.downloadMusicList.count; ++i) {
        StoreCampaignItemInfo *candidate = self.downloadMusicList[i];
        if (candidate.campaignID == [item campaignID]) {
            [detail setWorkingIndex:(int)i];
            break;
        }
    }
    [self.navigationController pushViewController:detail animated:YES];
}

/** @ghidraAddress 0x1fb934 */
- (void)showDetailView:(NSInteger)index {
    StoreCampaignItemInfo *item = self.downloadMusicList[index];
    if (!self.isPad) {
        return;
    }

    [[UIApplication sharedApplication] beginIgnoringInteractionEvents];
    self.coverViewPad.alpha = kPadCoverBlackWhite;
    self.itemDetailViewPad.alpha = kPadCoverBlackWhite;
    self.coverViewPad.hidden = NO;
    self.itemDetailViewPad.hidden = NO;
    [self.itemDetailViewPad setInfo:item tag:index];

    __weak RBCampaignViewController *weakSelf = self;
    [UIView animateWithDuration:kPadDetailAnimDuration
        delay:0
        options:UIViewAnimationOptionCurveLinear
        animations:^{
          /** @ghidraAddress 0x1fbc14 (animation block) */
          weakSelf.coverViewPad.alpha = kOpaqueAlpha;
          weakSelf.itemDetailViewPad.alpha = kOpaqueAlpha;
        }
        completion:^(BOOL finished) {
          /** @ghidraAddress 0x1fbccc (completion block) */
          [weakSelf.itemDetailViewPad showItemInfo];
          [[AppDelegate appDelegate] setCampaignIDForOpenStore:nil];
          [[UIApplication sharedApplication] endIgnoringInteractionEvents];
        }];
}

/** @ghidraAddress 0x1fbdac */
- (void)handleTapCoverView:(id)sender {
    [[UIApplication sharedApplication] beginIgnoringInteractionEvents];
    [self.itemDetailViewPad cancelLoading];
    [self.itemDetailViewPad sampleStop];

    __weak RBCampaignViewController *weakSelf = self;
    [UIView animateWithDuration:g_dAudioManagerResumeFadeInTime
        animations:^{
          /** @ghidraAddress 0x1fbf44 (animation block) */
          weakSelf.coverViewPad.alpha = kPadCoverBlackWhite;
          weakSelf.itemDetailViewPad.alpha = kPadCoverBlackWhite;
        }
        completion:^(BOOL finished) {
          /** @ghidraAddress 0x1fbffc (completion block) */
          weakSelf.coverViewPad.hidden = YES;
          weakSelf.itemDetailViewPad.hidden = YES;
          [weakSelf.itemDetailViewPad removeItemInfo];
          [[UIApplication sharedApplication] endIgnoringInteractionEvents];
        }];
}

/** @ghidraAddress 0x1fe4fc */
- (void)forceOpenCampaignDetailView {
    if (self.alertView != nil) {
        return;
    }
    if ([[AppDelegate appDelegate] getCampaignIDForOpenStore] == nil) {
        return;
    }

    BOOL found = NO;
    for (NSUInteger i = 0; i < self.downloadMusicList.count; ++i) {
        StoreCampaignItemInfo *item = self.downloadMusicList[i];
        int wantedID = [[[AppDelegate appDelegate] getCampaignIDForOpenStore] intValue];
        if (item.campaignID == wantedID) {
            found = YES;
        }
    }

    if (!found) {
        [[AppDelegate appDelegate] setCampaignIDForOpenStore:nil];
        return;
    }

    if (IsPad()) {
        [self.itemDetailViewPad cancelLoading];
        [self.itemDetailViewPad sampleStop];
        self.coverViewPad.alpha = kPadCoverBlackWhite;
        self.itemDetailViewPad.alpha = kPadCoverBlackWhite;
        self.coverViewPad.hidden = YES;
        self.itemDetailViewPad.hidden = YES;
        [self.itemDetailViewPad removeItemInfo];
        for (NSUInteger i = 0; i < self.downloadMusicList.count; ++i) {
            StoreCampaignItemInfo *item = self.downloadMusicList[i];
            int wantedID = [[[AppDelegate appDelegate] getCampaignIDForOpenStore] intValue];
            if (item.campaignID == wantedID) {
                [self.itemDetailViewPad setInfo:item tag:i];
                [self showDetailView:i];
                return;
            }
        }
        return;
    }

    [self.navigationController popViewControllerAnimated:NO];
    for (NSUInteger i = 0; i < self.downloadMusicList.count; ++i) {
        StoreCampaignItemInfo *item = self.downloadMusicList[i];
        int wantedID = [[[AppDelegate appDelegate] getCampaignIDForOpenStore] intValue];
        if (item.campaignID == wantedID) {
            [self showDetailViewForPhone:item];
            return;
        }
    }
}

#pragma mark - Sample playback

/** @ghidraAddress 0x1fb228 */
- (void)sampleStart {
    if (self.sampleDownloader == nil) {
        return;
    }
    NSData *data = [self.sampleDownloader getData];
    [[RBBGMManager getInstance] LoadMusicWithPush:data Loop:YES];
    [[RBBGMManager getInstance] PlayMusic:kSampleBGMFadeTime];

    NSIndexPath *indexPath = [NSIndexPath indexPathForRow:self.samplePlayedIndex inSection:0];
    if (indexPath != nil) {
        [self.tableView cellForRowAtIndexPath:indexPath];
    }
}

/** @ghidraAddress 0x1fb410 */
- (void)sampleStop {
    if (self.samplePlayedIndex == kNoActiveIndex) {
        return;
    }
    if ([[RBBGMManager getInstance] isPushMusic]) {
        [[RBBGMManager getInstance] StopMusic:g_flFlashMinOpacity];
        [[RBBGMManager getInstance] popMusic];
    }
    NSIndexPath *indexPath = [NSIndexPath indexPathForRow:self.samplePlayedIndex inSection:0];
    if (indexPath != nil) {
        if ([self.tableView cellForRowAtIndexPath:indexPath] != nil) {
            self.samplePlayedIndex = kNoActiveIndex;
        }
    }
}

#pragma mark - Cell actions

/** @ghidraAddress 0x1fb5c0 */
- (void)pushExternalLink:(id)sender {
    NSInteger row = [sender tag];
    if (row < 0) {
        return;
    }
    if (self.samplePlayedIndex != kNoActiveIndex) {
        [self sampleStop];
    }
    StoreCampaignItemInfo *item = self.downloadMusicList[row];
    if (item != nil && item.linkURL != nil) {
        [[UIApplication sharedApplication] openURL:[NSURL URLWithString:item.linkURL]];
    }
}

/** @ghidraAddress 0x1fb72c */
- (void)pushCellButton:(id)sender {
    if (self.workingIndex != kNoActiveIndex) {
        return;
    }
    if (self.samplePlayedIndex != kNoActiveIndex) {
        [self sampleStop];
    }
    self.workingIndex = (int)[sender tag];
    StoreCampaignItemInfo *item = self.downloadMusicList[self.workingIndex];
    if (item == nil) {
        return;
    }

    switch (item.buttonType) {
    case kCampaignButtonInfoDownload:
        [self itemInfoDownload];
        return;
    case kCampaignButtonTerms:
        [UIAlertView showUnlockTermsDescription2:item];
        break;
    case kCampaignButtonUpdate:
        [UIAlertView showAlertUpdateForUnlock:self];
        break;
    case kCampaignButtonSerialCode: {
        UIAlertView *alert = [UIAlertView showSerialcodeDialog:self];
        alert.alertViewStyle = UIAlertViewStylePlainTextInput;
        alert.tag = kSerialCodeAlertTag;
        [alert show];
        self.alertView = alert;
        return;
    }
    default:
        break;
    }
    self.workingIndex = kNoActiveIndex;
}

#pragma mark - Alert view delegate

/** @ghidraAddress 0x1fc3fc */
- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex {
    if (buttonIndex == kAlertConfirmButtonIndex) {
        if (alertView.tag == kSerialCodeAlertTag) {
            NSString *code = [alertView textFieldAtIndex:kSerialCodeTextFieldIndex].text;
            if (code.length != 0) {
                StoreCampaignItemInfo *item = self.downloadMusicList[self.workingIndex];
                NSString *json = [StoreUtil createCampaignSerialCheckJSON:item.campaignID
                                                                     code:code];
                self.termsChecker =
                    [[Downloader alloc] initWithURL:[StoreUtil campaignSerialCheckURL]
                                               post:[json dataUsingEncoding:kUTF8Encoding]
                                        contentType:kJSONContentType];
                [self.termsChecker startDownloadingWithDelegate:self];
                return;
            }
        } else {
            if (alertView.tag != 0) {
                return;
            }
            [[UIApplication sharedApplication] openURL:[NSURL URLWithString:kUpdateAppStoreURL]];
        }
        self.workingIndex = kNoActiveIndex;
    } else if (buttonIndex == kAlertCancelButtonIndex) {
        self.workingIndex = kNoActiveIndex;
        self.alertView = nil;
    }
}

/** @ghidraAddress 0x1fc74c */
- (void)alertView:(UIAlertView *)alertView didDismissWithButtonIndex:(NSInteger)buttonIndex {
}

/** @ghidraAddress 0x1fc750 */
- (void)alertView:(UIAlertView *)alertView willDismissWithButtonIndex:(NSInteger)buttonIndex {
}

/** @ghidraAddress 0x1fc754 */
- (void)alertViewCancel:(UIAlertView *)alertView {
}

/** @ghidraAddress 0x1fc758 */
- (void)didPresentAlertView:(UIAlertView *)alertView {
    [UIAlertView setExclusiveTouchForView:[[[[[UIApplication sharedApplication] keyWindow]
                                              rootViewController] presentedViewController] view]];
}

/** @ghidraAddress 0x1fc898 */
- (void)alertViewClose {
    if (self.alertView != nil) {
        self.alertView.delegate = nil;
        [self.alertView dismissWithClickedButtonIndex:0 animated:NO];
        self.alertView = nil;
        self.workingIndex = kNoActiveIndex;
    }
}

#pragma mark - Downloader delegate

/** @ghidraAddress 0x1fc988 */
- (void)downloaderFinished:(Downloader *)downloader {
    if (self.infoDownloader == downloader) {
        [self handleInfoDownloaderFinished:downloader];
    }
    if (self.musicInfoDownloader == downloader) {
        [self handleMusicInfoDownloaderFinished:downloader];
    }
    if (self.termsChecker == downloader) {
        [self handleTermsCheckerFinished:downloader];
    }
    if (self.itemURLDownloader == downloader) {
        [self handleItemURLDownloaderFinished:downloader];
    }
    if (self.sampleDownloader == downloader) {
        if (self.samplePlayedIndex >= 0) {
            [self sampleStart];
        }
        self.sampleDownloader = nil;
    }
}

/** @ghidraAddress 0x1fc988 (info-downloader branch) */
- (void)handleInfoDownloaderFinished:(Downloader *)downloader {
    self.loadingLabel.hidden = YES;
    NSDictionary *json = [downloader getDataInJSON];
    if (json == nil || ![downloader hashChecked]) {
        [self showError:g_pLocalizedServerConnectFailed];
        return;
    }

    NSArray *list = json[kJSONKeyList];
    if (list.count == 0) {
        NSString *error = json[kJSONKeyError];
        if (error == nil || error.length == 0) {
            [self showError:g_pLocalizedServerConnectFailed];
        } else {
            [self showError:error];
        }
    } else {
        self.unlockMusicCheckList = [NSArray arrayWithArray:list];
        [self refreshUnlockTable];
        [self refreshMusicList];
    }

    if ([[AppDelegate appDelegate] getCampaignIDForOpenStore] != nil &&
        self.downloadMusicList.count != 0) {
        [self forceOpenCampaignDetailView];
    }
}

/** @ghidraAddress 0x1fc988 (music-info-downloader branch) */
- (void)handleMusicInfoDownloaderFinished:(Downloader *)downloader {
    NSDictionary *json = [downloader getDataInJSON];
    if (json == nil) {
        return;
    }
    StoreMusicInfo *musicInfo = [[StoreMusicInfo alloc] initWithDictionary:json];
    if (musicInfo == nil) {
        return;
    }

    StoreDialogView *dialog = self.parent.modalDialog;
    [dialog layout:NO];
    dialog.labelMessage.text =
        [NSString stringWithFormat:g_pDownloadingMessageFormat, musicInfo.name];
    dialog.progressView.progress = 0;
    [self.parent showModalDialog:self];

    if ([[RBMusicManager getInstance] addPurchasedMusic:musicInfo]) {
        [[RBMusicManager getInstance] savePurchasedMusics];
    }
    [self.downloadMusicList[self.workingIndex] termCheck];
    [self refreshUnlockBadge];
    [self updateExperienceData];

    NSString *path = [RBMusicManager getPathFromPurchesed:musicInfo.musicID];
    StoreDownloadTask *task = [[StoreDownloadTask alloc] initWithURL:musicInfo.itemURL
                                                                path:path
                                                           AddObject:nil];
    self.dlManager = [[StoreDownloadManager alloc] initWithTasks:@[ task ] delegate:self];
    [self.dlManager start];
}

/** @ghidraAddress 0x1fc988 (terms-checker branch) */
- (void)handleTermsCheckerFinished:(Downloader *)downloader {
    NSDictionary *json = [downloader getDataInJSON];
    if (json != nil) {
        if ([json[kJSONKeyStatus] intValue] == kServerStatusSuccess) {
            StoreCampaignItemInfo *item = self.downloadMusicList[self.workingIndex];
            for (NSMutableDictionary *checkItem in self.unlockMusicCheckList) {
                NSString *checkID = checkItem[kJSONKeyCampaignId];
                NSString *itemID = [NSString stringWithFormat:kCampaignIdFormat, item.campaignID];
                if ([checkID isEqualToString:itemID]) {
                    [checkItem setValue:kJSONKeyTrue forKey:kJSONKeyUnlocked];
                    StoreCampaignItemInfo *unlocked =
                        [[StoreCampaignItemInfo alloc] initWithDictionary:checkItem];
                    [unlocked termCheck];
                    self.downloadMusicList[self.workingIndex] = unlocked;
                    NSIndexPath *indexPath = [NSIndexPath indexPathForRow:self.workingIndex
                                                                inSection:0];
                    StoreCampaignTableViewCell *cell =
                        [self.tableView cellForRowAtIndexPath:indexPath];
                    [cell setInfo:unlocked tag:self.workingIndex];
                    [self updateExperienceData];
                    break;
                }
            }
            [self.tableView reloadData];
            [self itemInfoDownload];
        } else {
            [UIAlertView showWithErrorMessage:json[kJSONKeyError] delegate:nil];
            self.workingIndex = kNoActiveIndex;
        }
    }
    self.termsChecker = nil;
}

/** @ghidraAddress 0x1fc988 (item-url-downloader branch) */
- (void)handleItemURLDownloaderFinished:(Downloader *)downloader {
    NSDictionary *json = [downloader getDataInJSON];
    if (json != nil) {
        if ([json[kJSONKeyStatus] intValue] == kServerStatusSuccess) {
            StoreCampaignItemInfo *item = self.downloadMusicList[self.workingIndex];
            if (item.itemType == kCampaignItemTypeTune && json[kJSONKeyURL] != nil) {
                NSURL *url = [StoreUtil musicInfoURL:item.itemID];
                self.musicInfoDownloader = [[Downloader alloc] initWithURL:url save:nil];
                [self.musicInfoDownloader startDownloadingWithDelegate:self];
            }
        } else {
            [UIAlertView showWithErrorMessage:json[kJSONKeyError] delegate:nil];
            self.workingIndex = kNoActiveIndex;
        }
    }
    self.itemURLDownloader = nil;
}

/** @ghidraAddress 0x1fda70 */
- (void)downloaderError:(Downloader *)downloader {
    if (self.infoDownloader == downloader) {
        if (!self.firstDownloadFailed) {
            self.firstDownloadFailed = YES;
        } else {
            self.infoDownloader = nil;
            [self showError:g_pLocalizedServerConnectFailed];
        }
        return;
    }
    if (self.musicInfoDownloader == downloader) {
        // The binary clears infoDownloader here, not musicInfoDownloader.
        self.infoDownloader = nil;
        [UIAlertView showNetworkErrorWithDelegate:nil];
        self.workingIndex = kNoActiveIndex;
        return;
    }
    if (self.termsChecker == downloader) {
        self.termsChecker = nil;
        self.workingIndex = kNoActiveIndex;
        return;
    }
    if (self.itemURLDownloader == downloader) {
        self.itemURLDownloader = nil;
        self.workingIndex = kNoActiveIndex;
        return;
    }
    if (self.sampleDownloader == downloader) {
        self.sampleDownloader = nil;
        [self sampleStop];
        self.samplePlayedIndex = kNoActiveIndex;
        [UIAlertView showNetworkErrorWithDelegate:nil];
    }
}

/** @ghidraAddress 0x1fddf4 */
- (void)storeDialogCancel:(id)sender {
    if (self.infoDownloader != nil) {
        [self.infoDownloader cancel];
        self.infoDownloader = nil;
    }
    if (self.dlManager != nil) {
        [self.dlManager cancel];
        self.dlManager = nil;
    }
    [self.downloadMusicList[self.workingIndex] termCheck];
    [self.parent hideModalDialog];
    self.workingIndex = kNoActiveIndex;
}

#pragma mark - Image downloader delegate

/** @ghidraAddress 0x1ffc6c */
- (void)imageDownloader:(ImageDownloader *)downloader didLoad:(NSIndexPath *)indexPath {
    NSIndexPath *cellIndexPath = [NSIndexPath indexPathForRow:indexPath.row
                                                    inSection:indexPath.section];
    if (cellIndexPath != nil) {
        StoreCampaignTableViewCell *cell = [self.tableView cellForRowAtIndexPath:cellIndexPath];
        if (cell != nil) {
            [cell setArtwork:[downloader getImage]];
        }
    }
}

/** @ghidraAddress 0x1ffdfc */
- (void)imageDownloaderDidFail:(ImageDownloader *)downloader didLoad:(NSIndexPath *)indexPath {
}

#pragma mark - Store download manager delegate

/** @ghidraAddress 0x1fdfb8 */
- (void)downloadManagerCompleted:(StoreDownloadManager *)manager {
    self.dlManager = nil;
    [self.parent hideModalDialog];
    [[RBMusicManager getInstance] createMusicDataArray];
    [[RBMusicManager getInstance] setMusicDataArrayDirty];
    StoreCampaignItemInfo *item = self.downloadMusicList[self.workingIndex];
    [item termCheck];

    if (!self.isPad) {
        NSInteger count = self.navigationController.viewControllers.count;
        if (count > 1) {
            id top = self.navigationController.viewControllers[count - 1];
            if (top != nil) {
                [top setInfo:item];
            }
        }
    } else {
        [self.itemDetailViewPad setDownloadFlag:YES];
    }
    [self refreshUnlockBadge];
    self.workingIndex = kNoActiveIndex;
}

/** @ghidraAddress 0x1fe2bc */
- (void)downloadManagerFailed:(StoreDownloadManager *)manager {
    self.dlManager = nil;
    [UIAlertView showDownloadErrorWithDelegate:nil];
    [self.parent hideModalDialog];
    self.workingIndex = kNoActiveIndex;
}

/** @ghidraAddress 0x1fe368 */
- (void)downloadManagerProceed:(StoreDownloadManager *)manager {
    StoreCampaignItemInfo *item = self.downloadMusicList[self.workingIndex];
    StoreDialogView *dialog = self.parent.modalDialog;
    if (item.itemType == kCampaignItemTypeTune) {
        dialog.progressView.progress = self.dlManager.overallProgress;
    }
}

#pragma mark - Unlock table and badge

/** @ghidraAddress 0x1ff038 */
- (void)refreshUnlockTable {
    if (self.unlockMusicCheckList == nil) {
        return;
    }
    self.downloadMusicList = nil;
    self.downloadMusicList = [[NSMutableArray alloc] init];

    int badgeCount = 0;
    for (NSDictionary *rawItem in self.unlockMusicCheckList) {
        NSMutableDictionary *itemDict = [NSMutableDictionary dictionaryWithDictionary:rawItem];
        StoreCampaignItemInfo *item = [[StoreCampaignItemInfo alloc] initWithDictionary:itemDict];
        BOOL isNewUnlock = [item checkNewUnlock] != 0;
        if (item.hideType != kCampaignHideTypeHidden) {
            BOOL alreadyPresent = NO;
            for (StoreCampaignItemInfo *existing in self.downloadMusicList) {
                if (item.campaignID == existing.campaignID) {
                    alreadyPresent = YES;
                    break;
                }
            }
            if (!alreadyPresent) {
                [self.downloadMusicList addObject:item];
            }
        }
        badgeCount += isNewUnlock ? 1 : 0;
    }
    [self setBadgeCnt:badgeCount];
}

/** @ghidraAddress 0x1ff470 */
- (void)refreshUnlockBadge {
    int badgeCount = 0;
    for (StoreCampaignItemInfo *item in self.downloadMusicList) {
        if (item != nil) {
            badgeCount += [item checkNewUnlock];
        }
    }
    [self setBadgeCnt:badgeCount];
}

/** @ghidraAddress 0x1ff5cc */
- (void)setBadgeCnt:(int)badgeCnt {
    if (badgeCnt < 1) {
        self.tabBarItem.badgeValue = nil;
    } else {
        self.tabBarItem.badgeValue = [NSString stringWithFormat:kCampaignIdFormat, badgeCnt];
    }
}

/** @ghidraAddress 0x1fec00 */
- (void)reloadUnlockList {
    [self refreshUnlockTable];
    [self refreshMusicList];
}

/** @ghidraAddress 0x1fec34 */
- (void)refreshMusicList {
    for (NSUInteger i = 0; i < self.downloadMusicList.count; ++i) {
        StoreCampaignItemInfo *item = self.downloadMusicList[i];
        for (id key in [self.imageDownloaderList keyEnumerator]) {
            ImageDownloader *banner = self.imageDownloaderList[key];
            if ([item.campaignBannerURL isEqualToString:banner.imageURL]) {
                (void)[banner getImage]; // The binary discards this result.
                break;
            }
        }
    }
    [self.tableView reloadData];
}

#pragma mark - Experience data

/** @ghidraAddress 0x1fc128 */
- (void)updateExperienceData {
    StoreCampaignItemInfo *item = self.downloadMusicList[self.workingIndex];
    if (item.unlockDict == nil) {
        return;
    }
    if (item.unlockDict[kUnlockKeyType] == nil) {
        return;
    }
    if (item.unlockDict[kUnlockKeyID] == nil) {
        return;
    }
    int type = [item.unlockDict[kUnlockKeyType] intValue];
    int itemID = [item.unlockDict[kUnlockKeyID] intValue];
    [[RBExperienceData sharedInstance] addItem:type ID:itemID];
}

/** @ghidraAddress 0x1fdcb4 */
- (void)showError:(NSString *)message {
    self.loadingLabel.hidden = YES;
    self.tableView.hidden = YES;
    self.errorLabel.text = message;
    self.errorLabel.hidden = NO;
}

/** @ghidraAddress 0x1fe4f8 */
- (void)storeClose {
    // The store-close hook is intentionally empty.
}

@end
