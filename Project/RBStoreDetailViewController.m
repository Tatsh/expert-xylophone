#import "RBStoreDetailViewController.h"

#import "AppDelegate.h"
#import "Downloader.h"
#import "ImageDownloader.h"
#import "RBBGMManager.h"
#import "RBPurchaseManager.h"
#import "RBTermPhoneViewController.h"
#import "RBViewController.h"
#import "StoreDetailCopyrightCell.h"
#import "StoreDetailHeaderView.h"
#import "StoreDetailMusicCell.h"
#import "StoreMusicInfo.h"
#import "StorePackInfo.h"
#import "StorePackInfoDownloader.h"
#import "StoreUtil.h"
#import "UIAlertView+RB.h"
#import "UIImage+RB.h"
#import "deviceenvironment.h"
#import "engineglobals.h"

extern const double g_dMascotMessageMaxWidthPad;  // @ghidraAddress 0x2ee930 (300.0)
extern const double g_dMascotMessageAnimDuration; // @ghidraAddress 0x2eedc0 (0.2)
extern NSString *g_pLocalizedLoadingMixed;        // @ghidraAddress 0x3cfca8

static NSString *const kMusicCellID = @"StoreDetailTableMusicCell";
static NSString *const kCopyrightCellID = @"StoreDetailTableCopyrightCell";
static NSString *const kTermCellID = @"StoreDetailTableTermCell";

static NSString *const kStoreDefaultJacketImageName = @"09_store/store_jacket_64";
static NSString *const kStorePackBg0ImageName = @"09_store/store_pack_bg_0";
static NSString *const kStorePackBg1ImageName = @"09_store/store_pack_bg_1";

static NSString *const kLevelFormat = @"LEVEL:  %d / %d / %d";

static NSString *const kEmptyCopyright = @"";
// @ghidraAddress 0x36afc0
static NSString *const kNavigationTitle = @"info";

// @ghidraAddress 0x358e20
static NSString *const kTermCellText = @"規約等および各種注意事項";

static const CGFloat kDetailHeaderHeight = 120.0;

static const CGFloat kTextMeasureMaxHeight = 9002.0;

static const CGFloat kEmptyCopyrightRowHeight = 10.0;
static const CGFloat kCopyrightRowVerticalPadding = 20.0;

static const CGFloat kLoadingLabelFontSize = 18.0;
static const CGFloat kCopyrightFontSize = 10.0;

static const CGFloat kLoadingLabelCenterDrop = 20.0;
static const CGFloat kSpinnerCenterRise = 10.0;

static const CGFloat kSpinnerSize = 24.0;

static const CGFloat kTableBackgroundWhite = 0.4;
static const CGFloat kOddRowBackgroundWhite = 0.71;

static const CGFloat kTermLinkGreen = 0.4784313725490196;

static const CGFloat kCenterScale = 0.5;

static const int kDetailSectionCount = 1;

static const int kTrailingRowCount = 2;

static const NSInteger kNoSampleRow = -1;

static const int kNoExtendNotePid = -1;

@implementation RBStoreDetailViewController {
    // The table row whose sample is currently selected, or kNoSampleRow when none.
    NSInteger rowSamplePlayed;
    BOOL isDownloadingSample;
}

#pragma mark - Lifecycle

/** @ghidraAddress 0x1d7964 */
- (instancetype)init {
    self = [super init];
    if (self) {
        self.navigationItem.title = kNavigationTitle;
    }
    return self;
}

/** @ghidraAddress 0x1d7a1c */
- (void)loadView {
    [super loadView];

    self.view.opaque = YES;
    self.view.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    self.view.backgroundColor = UIColor.grayColor;

    CGRect bounds = self.view.bounds;

    UITableView *table = [[UITableView alloc] initWithFrame:bounds style:UITableViewStylePlain];
    table.opaque = YES;
    table.backgroundColor = [UIColor colorWithWhite:kTableBackgroundWhite alpha:1.0];
    table.separatorStyle = UITableViewCellSeparatorStyleNone;
    table.dataSource = self;
    table.delegate = self;
    table.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    table.hidden = YES;
    table.exclusiveTouch = YES;
    [self.view addSubview:table];
    self.packTableView = table;

    self.headerView = [[StoreDetailHeaderView alloc]
        initWithFrame:CGRectMake(
                          0.0, 0.0, self.packTableView.bounds.size.width, kDetailHeaderHeight)];
    self.headerView.autoresizingMask = UIViewAutoresizingFlexibleWidth;

    [self.headerView.buttonPurchase
        setTitle:[NSString stringWithFormat:g_pLocalizedBuyFormat, self.packInfo.priceString]
        forState:UIControlStateNormal];
    self.headerView.buttonPurchase.exclusiveTouch = YES;
    [self.headerView.buttonPurchase addTarget:self
                                       action:@selector(doPurchase:)
                             forControlEvents:UIControlEventTouchUpInside];
    [self.headerView.buttonPurchase setTitle:g_pLocalizedPurchased forState:UIControlStateDisabled];

    UILabel *loading = [[UILabel alloc] initWithFrame:bounds];
    loading.backgroundColor = UIColor.clearColor;
    loading.font = [UIFont boldSystemFontOfSize:kLoadingLabelFontSize];
    loading.textColor = [UIColor colorWithWhite:g_dMascotMessageAnimDuration alpha:1.0];
    loading.shadowColor = [UIColor colorWithWhite:1.0 alpha:g_dAudioManagerResumeFadeInTime];
    loading.shadowOffset = CGSizeMake(0.0, 1.0);
    loading.textAlignment = NSTextAlignmentCenter;
    loading.center = CGPointMake(
        bounds.size.width * kCenterScale,
        (CGFloat)((int)(bounds.size.height * kCenterScale) + (int)kLoadingLabelCenterDrop));
    loading.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    loading.text = g_pLocalizedLoadingMixed;
    loading.hidden = YES;
    [self.view addSubview:loading];
    self.accessingLabel = loading;

    UIActivityIndicatorView *spinner = [[UIActivityIndicatorView alloc]
        initWithFrame:CGRectMake(0.0, 0.0, kSpinnerSize, kSpinnerSize)];
    spinner.activityIndicatorViewStyle = UIActivityIndicatorViewStyleGray;
    spinner.center =
        CGPointMake(bounds.size.width * kCenterScale,
                    (CGFloat)((int)(bounds.size.height * kCenterScale) - (int)kSpinnerCenterRise));
    spinner.autoresizingMask =
        UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin |
        UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleBottomMargin;
    [spinner startAnimating];
    [self.accessingLabel addSubview:spinner];
    self.accessingIndicator = spinner;

    self.packBGImage0 =
        [[UIImage imageWithName:kStorePackBg0ImageName] stretchableImageWithLeftCapWidth:4
                                                                            topCapHeight:4];
    self.packBGImage1 =
        [[UIImage imageWithName:kStorePackBg1ImageName] stretchableImageWithLeftCapWidth:4
                                                                            topCapHeight:4];

    self.artworkDownloaders = [[NSMutableDictionary alloc] initWithCapacity:32];

    rowSamplePlayed = kNoSampleRow;
}

/** @ghidraAddress 0x1dc430 */
- (void)viewDidUnload {
    [super viewDidUnload];
    [self stopDownloadArtworks];
}

/** @ghidraAddress 0x1dc480 */
- (void)dealloc {
    [self.storePackInfoDownloader setDelegate:nil];
    [self.storePackInfoDownloader cancel];
    [self.sampleDownloader cancel];
    [self stopDownloadArtworks];
}

/** @ghidraAddress 0x1dc5b4 */
- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self selfCheckButtonText];
    self.closingFlag = NO;
}

/** @ghidraAddress 0x1dc610 */
- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    if (self.packTableView.isHidden) {
        [self loadInfo];
    }
}

/** @ghidraAddress 0x1dc6b4 */
- (void)viewWillDisappear:(BOOL)animated {
    self.closingFlag = YES;
    if (self.packinfoDownloadAlertView != nil) {
        [self.packinfoDownloadAlertView dismissWithClickedButtonIndex:0 animated:NO];
    }
    [super viewWillDisappear:animated];

    [self stopSample];
    if ([RBBGMManager getInstance].isPushMusic) {
        [[RBBGMManager getInstance] StopMusic:g_flFlashMinOpacity];
        [[RBBGMManager getInstance] popMusic];
    }
    [self.sampleDownloader cancel];

    if (self.storePackInfoDownloader != nil) {
        self.storePackInfoDownloader.delegate = nil;
        [self.storePackInfoDownloader cancel];
    }
}

/** @ghidraAddress 0x1dc8e0 */
- (void)viewDidDisappear:(BOOL)animated {
    [super viewDidDisappear:animated];
}

/** @ghidraAddress 0x1dc3fc */
- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
}

/** @ghidraAddress 0x1dc3ec */
- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)orientation {
    return orientation == UIInterfaceOrientationPortrait ||
           orientation == UIInterfaceOrientationPortraitUpsideDown;
}

#pragma mark - Detail loading

/** @ghidraAddress 0x1d88a4 */
- (void)loadInfo {
    if (self.packInfo == nil) {
        return;
    }
    if (self.packInfo.musicInfos != nil) {
        [self showPackInfo];
        return;
    }
    if (self.storePackInfoDownloader == nil) {
        self.storePackInfoDownloader =
            [[StorePackInfoDownloader alloc] initWithStorePackInfo:self.packInfo];
        self.storePackInfoDownloader.delegate = self;
        [self.storePackInfoDownloader downloadDetail:YES];
    }
}

/** @ghidraAddress 0x1d8510 */
- (void)showPackInfo {
    self.headerView.bounds =
        CGRectMake(0.0, 0.0, self.packTableView.bounds.size.width, kDetailHeaderHeight);
    [self.headerView loadPackInfo:self.packInfo];
    [self selfCheckButtonText];
    self.packTableView.tableHeaderView = self.headerView;

    NSIndexPath *headerIndexPath = [NSIndexPath indexPathForRow:0 inSection:1];
    ImageDownloader *downloader = [[ImageDownloader alloc] init];
    downloader.imageURL = self.packInfo.artworkURL;
    downloader.indexPathInTableView = headerIndexPath;
    downloader.delegate = self;
    if (!IsPad()) {
        downloader.unUseRetina = YES;
    }
    self.artworkDownloaders[headerIndexPath] = downloader;
    [downloader startDownload];

    self.packTableView.hidden = NO;
    [self.packTableView reloadData];
}

#pragma mark - Purchase button state

/** @ghidraAddress 0x1d90f4 */
- (BOOL)allDownloaded {
    if (self.packInfo != nil && self.packInfo.musicInfos != nil &&
        self.packInfo.musicInfos.count != 0) {
        return self.packInfo.allDownloaded;
    }
    return NO;
}

/** @ghidraAddress 0x1d9290 */
- (void)selfCheckButtonText {
    if (self.packInfo != nil) {
        NSString *productID = [StoreUtil productIDForPackID:self.packInfo.packID];
        if ([[RBPurchaseManager sharedManager] isPurchased:productID]) {
            if ([self allDownloaded]) {
                [self setButtonTextInstalled];
            } else {
                [self setButtonTextInstall];
            }
            return;
        }
    }
    [self setButtonTextBuy];
}

/** @ghidraAddress 0x1d9408 */
- (void)setButtonTextBuy {
    [self.headerView.buttonPurchase
        setTitle:[NSString stringWithFormat:g_pLocalizedBuyFormat, self.packInfo.priceString]
        forState:UIControlStateNormal];
    self.headerView.buttonPurchase.enabled = YES;
}

/** @ghidraAddress 0x1d95d8 */
- (void)setButtonTextInstall {
    [self.headerView.buttonPurchase setTitle:g_pLocalizedInstall forState:UIControlStateNormal];
    self.headerView.buttonPurchase.enabled = YES;
}

/** @ghidraAddress 0x1d96e8 */
- (void)setButtonTextInstalling {
    [self.headerView.buttonPurchase setTitle:g_pLocalizedInstalling
                                    forState:UIControlStateDisabled];
    self.headerView.buttonPurchase.enabled = NO;
}

/** @ghidraAddress 0x1d97f8 */
- (void)setButtonTextInstalled {
    [self.headerView.buttonPurchase setTitle:g_pLocalizedInstalled forState:UIControlStateDisabled];
    self.headerView.buttonPurchase.enabled = NO;
}

/** @ghidraAddress 0x1d9028 */
- (void)setPurchaseState:(BOOL)state {
    if (self.headerView != nil) {
        self.headerView.buttonPurchase.enabled = !state;
    }
}

#pragma mark - Purchase and terms actions

/** @ghidraAddress 0x1d8d84 */
- (void)doPurchase:(id)sender {
    NSString *productID = [StoreUtil productIDForPackID:self.packInfo.packID];
    if ([[RBPurchaseManager sharedManager] isPurchased:productID]) {
        if ([self.delegate respondsToSelector:@selector(reDownloadPackMusics:)]) {
            [self.delegate performSelector:@selector(reDownloadPackMusics:)
                                withObject:self.packInfo];
        }
        return;
    }
    [self stopSample];
    if ([self.delegate respondsToSelector:@selector(detailViewStartPurchase:)]) {
        [self.delegate performSelector:@selector(detailViewStartPurchase:)
                            withObject:self.packInfo];
    }
}

/** @ghidraAddress 0x1dc914 */
- (void)storeDetailViewOpenItunesWithURL:(NSURL *)url {
    if (url != nil) {
        [[AppDelegate appDelegate].viewController openItunesWithURL:url];
    }
}

/** @ghidraAddress 0x1dc9d8 */
- (void)switchToSpecialStore:(NSNumber *)pid {
    [self stopSample];
    [AppDelegate appDelegate].extendNotePIDForOpenStore =
        [NSString stringWithFormat:@"%d", pid.intValue];
    [self.delegate performSelector:@selector(switchToSpecialStore)];
}

#pragma mark - Sample playback

/** @ghidraAddress 0x1d8aa0 */
- (void)stopSample {
    if ([RBBGMManager getInstance].isPushMusic) {
        [[RBBGMManager getInstance] StopMusic:g_flFlashMinOpacity];
        [[RBBGMManager getInstance] popMusic];
    }
    [self.sampleDownloader cancel];
    self.sampleDownloader = nil;
    rowSamplePlayed = kNoSampleRow;
    [self.packTableView reloadData];
}

/** @ghidraAddress 0x1d8c18 */
- (void)finishBgm:(id)sender {
    if (rowSamplePlayed >= 0 && (NSUInteger)rowSamplePlayed < self.packInfo.musicInfos.count) {
        NSIndexPath *indexPath = [NSIndexPath indexPathForRow:rowSamplePlayed inSection:0];
        StoreDetailMusicCell *cell =
            (StoreDetailMusicCell *)[self.packTableView cellForRowAtIndexPath:indexPath];
        [cell sampleStop];
    }
    rowSamplePlayed = kNoSampleRow;
}

#pragma mark - Table view data source and delegate

/** @ghidraAddress 0x1d9f50 */
- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return kDetailSectionCount;
}

/** @ghidraAddress 0x1d9f58 */
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.packInfo.musicInfos.count + kTrailingRowCount;
}

/** @ghidraAddress 0x1daeec */
- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    NSInteger tuneCount = self.packInfo.musicInfos.count;
    if (indexPath.row < tuneCount) {
        return [StoreDetailMusicCell cellHeight];
    }

    NSString *copyright = nil;
    if (indexPath.row == tuneCount) {
        copyright = self.packInfo.copyright;
        if (copyright == nil) {
            return kEmptyCopyrightRowHeight;
        }
    } else {
        copyright = kTermCellText;
    }

    CGSize measured =
        [copyright sizeWithFont:[UIFont systemFontOfSize:kCopyrightFontSize]
              constrainedToSize:CGSizeMake(g_dMascotMessageMaxWidthPad, kTextMeasureMaxHeight)
                  lineBreakMode:NSLineBreakByWordWrapping];
    return measured.height + kCopyrightRowVerticalPadding;
}

/** @ghidraAddress 0x1d9ffc */
- (UITableViewCell *)tableView:(UITableView *)tableView
         cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    NSInteger tuneCount = self.packInfo.musicInfos.count;

    if (indexPath.row < tuneCount) {
        // The binary discards the dequeued cell and always allocates a fresh one.
        (void)[tableView dequeueReusableCellWithIdentifier:kMusicCellID];
        StoreDetailMusicCell *cell =
            [[StoreDetailMusicCell alloc] initWithStyle:UITableViewCellStyleDefault
                                        reuseIdentifier:kMusicCellID];
        cell.parent = self;
        cell.pid = kNoExtendNotePid;

        StoreMusicInfo *info = self.packInfo.musicInfos[indexPath.row];
        if (info != nil) {
            cell.labelName.text = info.name;
            cell.labelArtist.text = info.artist;
            cell.labelLevels.text =
                [NSString stringWithFormat:kLevelFormat, info.lvBasic, info.lvMedium, info.lvHard];
            cell.link = info.itunesURL;
            cell.iconSp.hidden = (info.extIDList.count == 0);
            if (info.extIDList.count != 0) {
                cell.pid = [info.extIDList[0] intValue];
            }

            UIImage *artwork = nil;
            ImageDownloader *existing = self.artworkDownloaders[indexPath];
            if (existing != nil) {
                artwork = [existing getImage];
            } else if (info.artworkURL != nil) {
                ImageDownloader *downloader = [[ImageDownloader alloc] init];
                downloader.imageURL = info.artworkURL;
                downloader.indexPathInTableView = indexPath;
                downloader.delegate = self;
                if (!IsPad()) {
                    downloader.unUseRetina = YES;
                }
                self.artworkDownloaders[indexPath] = downloader;
                [downloader startDownload];
            }
            if (artwork == nil) {
                artwork = [UIImage imageWithName:kStoreDefaultJacketImageName];
            }
            cell.artworkView.image = artwork;
        }

        if (rowSamplePlayed == indexPath.row) {
            if (isDownloadingSample) {
                [cell sampleDownloading];
            } else {
                [cell samplePlaying];
            }
        } else {
            [cell sampleStop];
        }
        return cell;
    }

    if (indexPath.row == tuneCount) {
        StoreDetailCopyrightCell *cell =
            [tableView dequeueReusableCellWithIdentifier:kCopyrightCellID];
        if (cell == nil) {
            cell = [[StoreDetailCopyrightCell alloc] initWithStyle:UITableViewCellStyleDefault
                                                   reuseIdentifier:kCopyrightCellID];
            cell.labelCopyright.font = [UIFont systemFontOfSize:kCopyrightFontSize];
        }
        if (self.packInfo.copyright == nil) {
            cell.labelCopyright.text = kEmptyCopyright;
        } else {
            CGSize measured = [self.packInfo.copyright
                     sizeWithFont:[UIFont systemFontOfSize:kCopyrightFontSize]
                constrainedToSize:CGSizeMake(g_dMascotMessageMaxWidthPad, kTextMeasureMaxHeight)
                    lineBreakMode:NSLineBreakByWordWrapping];
            cell.labelCopyright.frame =
                CGRectMake(kCopyrightFontSize, kCopyrightFontSize, measured.width, measured.height);
            cell.labelCopyright.text = self.packInfo.copyright;
        }
        return cell;
    }

    StoreDetailCopyrightCell *cell = [tableView dequeueReusableCellWithIdentifier:kTermCellID];
    if (cell == nil) {
        cell = [[StoreDetailCopyrightCell alloc] initWithStyle:UITableViewCellStyleDefault
                                               reuseIdentifier:kTermCellID];
        cell.labelCopyright.font = [UIFont systemFontOfSize:kCopyrightFontSize];
        cell.labelCopyright.textColor = [UIColor colorWithRed:0.0
                                                        green:kTermLinkGreen
                                                         blue:1.0
                                                        alpha:1.0];
    }
    CGSize measured =
        [kTermCellText sizeWithFont:[UIFont systemFontOfSize:kCopyrightFontSize]
                  constrainedToSize:CGSizeMake(g_dMascotMessageMaxWidthPad, kTextMeasureMaxHeight)
                      lineBreakMode:NSLineBreakByWordWrapping];
    cell.labelCopyright.frame =
        CGRectMake(kCopyrightFontSize, kCopyrightFontSize, measured.width, measured.height);
    cell.labelCopyright.text = kTermCellText;
    return cell;
}

/** @ghidraAddress 0x1db224 */
- (void)tableView:(UITableView *)tableView
      willDisplayCell:(UITableViewCell *)cell
    forRowAtIndexPath:(NSIndexPath *)indexPath {
    NSInteger tuneCount = self.packInfo.musicInfos.count;
    if (indexPath.row < tuneCount) {
        UIImage *background = (indexPath.row & 1) ? self.packBGImage0 : self.packBGImage1;
        [(StoreDetailMusicCell *)cell setBgImage:background];
    } else if (indexPath.row == tuneCount) {
        cell.backgroundColor = [UIColor colorWithWhite:g_dTranslucentAlpha alpha:1.0];
    } else {
        cell.backgroundColor = [UIColor colorWithWhite:kOddRowBackgroundWhite alpha:1.0];
    }
}

/** @ghidraAddress 0x1db51c */
- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    NSInteger tuneCount = self.packInfo.musicInfos.count;
    if (indexPath.row == tuneCount) {
        return;
    }

    if (indexPath.row > tuneCount) {
        RBTermPhoneViewController *term = [[RBTermPhoneViewController alloc] init];
        [term setViewTypeStore];
        [self.navigationController pushViewController:term animated:YES];
        return;
    }

    if (indexPath.row == rowSamplePlayed) {
        if ([RBBGMManager getInstance].isPushMusic) {
            [[RBBGMManager getInstance] StopMusic:g_flFlashMinOpacity];
            [[RBBGMManager getInstance] popMusic];
        }
        NSIndexPath *playingIndexPath = [NSIndexPath indexPathForRow:rowSamplePlayed inSection:0];
        [[tableView cellForRowAtIndexPath:playingIndexPath] sampleStop];
        rowSamplePlayed = kNoSampleRow;
        [tableView reloadData];
        return;
    }

    if (rowSamplePlayed >= 0 && (NSUInteger)rowSamplePlayed < self.packInfo.musicInfos.count) {
        if ([RBBGMManager getInstance].isPushMusic) {
            [[RBBGMManager getInstance] StopMusic:g_flFlashMinOpacity];
            [[RBBGMManager getInstance] popMusic];
        }
        NSIndexPath *playingIndexPath = [NSIndexPath indexPathForRow:rowSamplePlayed inSection:0];
        [[tableView cellForRowAtIndexPath:playingIndexPath] sampleStop];
    }

    StoreMusicInfo *info = self.packInfo.musicInfos[indexPath.row];
    if (info.sampleURL != nil) {
        StoreDetailMusicCell *cell =
            (StoreDetailMusicCell *)[tableView cellForRowAtIndexPath:indexPath];
        rowSamplePlayed = indexPath.row;
        isDownloadingSample = YES;
        [cell sampleDownloading];
        self.sampleDownloader = [[Downloader alloc] initWithURL:[NSURL URLWithString:info.sampleURL]
                                                           save:nil];
        [self.sampleDownloader startDownloadingWithDelegate:self];
    }
}

#pragma mark - Store pack info downloader delegate

/** @ghidraAddress 0x1d9908 */
- (void)storePackInfoDownloaderFinished:(StorePackInfoDownloader *)downloader {
    if ([downloader getErrorMessage] != nil) {
        [self storePackInfoDownloaderError:downloader];
        return;
    }
    [self showPackInfo];
    self.accessingLabel.hidden = YES;
    if (self.storePackInfoDownloader == downloader) {
        self.storePackInfoDownloader.delegate = nil;
        self.storePackInfoDownloader = nil;
    }
}

/** @ghidraAddress 0x1d9a50 */
- (void)storePackInfoDownloaderError:(StorePackInfoDownloader *)downloader {
    self.accessingLabel.hidden = YES;
    self.packinfoDownloadAlertView = [UIAlertView showNetworkErrorWithDelegate:self];
    if (self.storePackInfoDownloader == downloader) {
        self.storePackInfoDownloader.delegate = nil;
        self.storePackInfoDownloader = nil;
    }
}

#pragma mark - Sample downloader delegate

/** @ghidraAddress 0x1d9b88 */
- (void)downloaderFinished:(Downloader *)downloader {
    if (self.sampleDownloader != downloader) {
        return;
    }
    if (rowSamplePlayed >= 0) {
        NSData *data = [self.sampleDownloader getData];
        [[RBBGMManager getInstance] LoadMusicWithPush:data Loop:YES];
        [[RBBGMManager getInstance] PlayMusic:0.0];
        NSIndexPath *indexPath = [NSIndexPath indexPathForRow:rowSamplePlayed inSection:0];
        StoreDetailMusicCell *cell =
            (StoreDetailMusicCell *)[self.packTableView cellForRowAtIndexPath:indexPath];
        [cell samplePlaying];
        isDownloadingSample = NO;
    }
    self.sampleDownloader = nil;
}

/** @ghidraAddress 0x1d9dd4 */
- (void)downloaderError:(Downloader *)downloader {
    if (self.sampleDownloader != downloader) {
        return;
    }
    if (rowSamplePlayed >= 0) {
        NSIndexPath *indexPath = [NSIndexPath indexPathForRow:rowSamplePlayed inSection:0];
        StoreDetailMusicCell *cell =
            (StoreDetailMusicCell *)[self.packTableView cellForRowAtIndexPath:indexPath];
        [cell sampleStop];
        rowSamplePlayed = kNoSampleRow;
    }
    self.sampleDownloader = nil;
    [UIAlertView showNetworkErrorWithDelegate:nil];
}

/** @ghidraAddress 0x1d9f4c */
- (void)downloaderProceed:(Downloader *)downloader {
    // The binary provides no incremental-progress handling.
}

#pragma mark - Image downloader delegate

/** @ghidraAddress 0x1dbca0 */
- (void)imageDownloader:(ImageDownloader *)downloader didLoad:(NSIndexPath *)indexPath {
    if (indexPath.section == 0) {
        StoreDetailMusicCell *cell =
            (StoreDetailMusicCell *)[self.packTableView cellForRowAtIndexPath:indexPath];
        UIImage *image = [downloader getImage];
        if (cell != nil && image != nil) {
            cell.artworkView.image = image;
        }
    } else if (indexPath.section == 1 && indexPath.row == 0) {
        [self.headerView setArtwork:[downloader getImage]];
    }
}

/** @ghidraAddress 0x1dbeb0 */
- (void)imageDownloaderDidFail:(ImageDownloader *)downloader didLoad:(NSIndexPath *)indexPath {
    // The binary ignores artwork-download failures.
}

/** @ghidraAddress 0x1dc1e4 */
- (void)stopDownloadArtworks {
    if (self.artworkDownloaders.count != 0) {
        for (ImageDownloader *downloader in [self.artworkDownloaders objectEnumerator]) {
            [downloader cancelDownload];
            downloader.delegate = nil;
        }
        [self.artworkDownloaders removeAllObjects];
    }
}

#pragma mark - Alert view delegate

/** @ghidraAddress 0x1dbfac */
- (void)alertViewCancel:(UIAlertView *)alertView {
    if (self.closingFlag) {
        if ([self.delegate respondsToSelector:@selector(detailViewClose)]) {
            [self.delegate performSelector:@selector(detailViewClose)];
        }
    }
}

/** @ghidraAddress 0x1dbeb4 */
- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex {
    // The binary takes no action on a button click.
}

/** @ghidraAddress 0x1dbfa8 */
- (void)alertView:(UIAlertView *)alertView willDismissWithButtonIndex:(NSInteger)buttonIndex {
    // The binary takes no action on dismissal.
}

/** @ghidraAddress 0x1dbeb8 */
- (void)alertView:(UIAlertView *)alertView didDismissWithButtonIndex:(NSInteger)buttonIndex {
    if (!self.closingFlag) {
        if ([self.delegate respondsToSelector:@selector(detailViewClose)]) {
            [self.delegate performSelector:@selector(detailViewClose)];
        }
    }
}

/** @ghidraAddress 0x1dc0a4 */
- (void)didPresentAlertView:(UIAlertView *)alertView {
    [UIAlertView
        setExclusiveTouchForView:[UIApplication sharedApplication]
                                     .keyWindow.rootViewController.presentedViewController.view];
}

@end
