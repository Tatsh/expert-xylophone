#import "RBCampaignDetailViewController.h"

#import <UIKit/UIKit.h>

#import "ImageDownloader.h"
#import "RBBGMManager.h"
#import "RBCampaignViewController.h"
#import "RBMusicManager.h"
#import "StoreButtonView.h"
#import "StoreCampaignItemInfo.h"
#import "StoreImageView.h"
#import "UIAlertView+RB.h"
#import "UIImage+RB.h"
#import "engineglobals.h"

@interface NSObject (RBCampaignDetailDelegate)
- (void)alertViewClose;
- (void)detailViewClose;
@end

static const int kNoSampleIndex = -1;

enum {
    kSampleStatusIdle = 0,
    kSampleStatusDownloading = 1,
    kSampleStatusPlaying = 2,
};

enum {
    kCampaignButtonInfoDownload = 0,
    kCampaignButtonDownloading = 1,
    kCampaignButtonTerms = 2,
    kCampaignButtonUpdate = 3,
    kCampaignButtonSerialCode = 4,
};

static const int kSampleRowIndex = 1;

static const NSInteger kSerialCodeAlertTag = 1;

static const int kCampaignItemTypeTune = 0;
static const int kCampaignHideTypeLocked = 1;

// @ghidraAddress 0x310458
static const UIViewAutoresizing kAutoresizingMaskFlexibleSize =
    UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;

static NSString *const kPlaceholderJacketName = @"09_store/store_jacket_80";
static NSString *const kItemPanelBackgroundName = @"09_store/store_pack_bg_2";
static NSString *const kPlayGlyphName = @"09_store/store_play";
static const NSInteger kItemPanelCapInset = 4;

static NSString *const kLevelsFormat = @"LEVEL:  %d / %d / %d";
static NSString *const kIDFormat = @"%d";
static NSString *const kDefaultNavigationTitle = @"Gift";
static NSString *const kLockedNamePlaceholder = @"？？？？？？";
static NSString *const kLinkButtonTitle = @"詳しくはこちら";

static const float kSampleBGMFadeTime = 0.5f;
static const float kSampleBGMNoFade = 0.0f;

// The font-step arithmetic is single precision. @ghidraAddress 0xaa84
static const float kItemNameMaxFontSize = 18.0f;
static const int kItemNameFontStepCount = 9;
static const CGFloat kItemPanelHeight = 140.0; // @ghidraAddress 0x2ec6c0
static const CGFloat kArtworkOrigin = 8.0;
static const CGFloat kArtworkSize = 80.0; // @ghidraAddress 0x2ec6c8
static const CGFloat kArtworkBorderWidth = 1.0;
static const CGFloat kArtworkShadowOffset = 2.0;
static const CGFloat kArtworkShadowRadius = 2.0;
static const float kArtworkShadowOpacity = 0.6f;  // @ghidraAddress 0x2ec6b8
static const CGFloat kTextColumnLeft = 96.0;      // @ghidraAddress 0x2ec6d8
static const CGFloat kTextColumnInset = -104.0;   // @ghidraAddress 0x2ec6d0
static const CGFloat kLevelsColumnInset = -230.0; // @ghidraAddress 0x2ec6e8
static const CGFloat kItemNameTop = 8.0;
// The binary reuses this pool slot for the artist row's top and the copyright block's height.
static const CGFloat kItemNameMaxHeight = 50.0; // @ghidraAddress 0x2ec6e0
static const CGFloat kLevelsLabelTop = 70.0;    // @ghidraAddress 0x2ec6f0
static const CGFloat kSecondaryLabelRowHeight = 20.0;
static const CGFloat kTextBlockBottomInset = -80.0; // @ghidraAddress 0x2ec740
static const CGFloat kNameLabelBottomInset = -24.0;
static const CGFloat kActionButtonWidth = 104.0; // @ghidraAddress 0x2ec700
static const CGFloat kActionButtonHeight = 25.0;
static const CGFloat kActionButtonCorner = 4.0;
static const CGFloat kActionButtonFontSize = 10.0;
static const CGFloat kDownloadButtonRightInset = -8.0;
static const CGFloat kLinkButtonRightInset = -16.0;
static const CGFloat kLinkButtonInset = -208.0; // @ghidraAddress 0x2ec710
static const CGFloat kLinkButtonGreen = 0.3;    // @ghidraAddress 0x2ec718
static const CGFloat kItemNameFontSize = 18.0;
static const CGFloat kSecondaryLabelFontSize = 12.0;
static const CGFloat kSampleOverlayAlpha = 0.4; // @ghidraAddress 0x2ec720
static const CGFloat kSampleOverlayWhite = 0.0;
static const CGFloat kTransparentAlpha = 0.0;
static const CGFloat kOpaqueAlpha = 1.0;
static const CGFloat kCenterScale = 0.5;
static const CGFloat kDetailBorderWhite = 143.0f / 255.0f; // @ghidraAddress 0x2ec730
static const CGFloat kDividerWhite = 0.5;
static const CGFloat kDividerHeight = 1.0;
static const CGFloat kBannerCornerRadius = 8.0;
static const CGFloat kDetailBlockGrowth = -140.0; // @ghidraAddress 0x2ec728
static const CGFloat kDescriptionInset = 10.0;
static const CGFloat kDescriptionWidthInset = -20.0;
static const CGFloat kCopyrightGrowth = -50.0; // @ghidraAddress 0x2ec738
static const CGFloat kElementSpacing = 5.0;
static const CGFloat kDividerLift = -3.0;

static const CGFloat kDisabledButtonWhite = 0.6f; // @ghidraAddress 0x2ec708

@interface RBCampaignDetailViewController () {
    int sampleStatus;
    BOOL isDownloadingSample;
    BOOL downloadFlag;
    int buttonType;
    BOOL bUnlock;
    int hideType;
}
@end

@implementation RBCampaignDetailViewController

#pragma mark - Lifecycle

/** @ghidraAddress 0x58fc */
- (instancetype)initWithItemInfo:(StoreCampaignItemInfo *)itemInfo {
    self = [super init];
    if (!self) {
        return nil;
    }
    self.navigationItem.title = kDefaultNavigationTitle;
    self.itemInfo = itemInfo;
    if (self.itemInfo.campaignName != nil) {
        self.navigationItem.title = self.itemInfo.campaignName;
    }
    return self;
}

/** @ghidraAddress 0x5b00 */
- (void)loadView {
    [super loadView];
}

/**
 * The binary's dealloc cancels the sample downloader and clears the artwork downloaders before
 * chaining to super. @ghidraAddress 0x7e88
 */
- (void)dealloc {
    [self.sampleDownloader cancel];
    [self stopDownloadArtworks];
}

#pragma mark - View lifecycle

/** @ghidraAddress 0x7f4c */
- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    _closingFlag = NO;

    if ([self.artworkView loadedImage]) {
        [self updateLayout];
        return;
    }

    self.view.opaque = YES;
    self.view.autoresizingMask = kAutoresizingMaskFlexibleSize;
    self.view.backgroundColor = UIColor.grayColor;

    UIScrollView *scroll = [[UIScrollView alloc] initWithFrame:self.view.bounds];
    self.mainView = scroll;
    self.mainView.scrollEnabled = YES;
    self.mainView.autoresizingMask = kAutoresizingMaskFlexibleSize;
    [self.view addSubview:self.mainView];

    UIImage *panelImage = [UIImage imageWithName:kItemPanelBackgroundName];
    UIView *item = [[UIView alloc]
        initWithFrame:CGRectMake(0, 0, self.view.bounds.size.width, kItemPanelHeight)];
    self.itemView = item;
    self.itemView.autoresizingMask = UIViewAutoresizingFlexibleWidth;

    UIImageView *panel = [[UIImageView alloc]
        initWithFrame:CGRectMake(0, 0, self.view.bounds.size.width, kItemPanelHeight)];
    panel.image = [panelImage stretchableImageWithLeftCapWidth:kItemPanelCapInset
                                                  topCapHeight:kItemPanelCapInset];
    panel.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [self.itemView addSubview:panel];

    StoreImageView *artwork = [[StoreImageView alloc]
        initWithFrame:CGRectMake(kArtworkOrigin, kArtworkOrigin, kArtworkSize, kArtworkSize)];
    self.artworkView = artwork;
    self.artworkView.layer.borderWidth = kArtworkBorderWidth;
    self.artworkView.layer.borderColor = UIColor.whiteColor.CGColor;
    self.artworkView.backgroundColor = UIColor.whiteColor;
    self.artworkView.layer.shadowOffset = CGSizeMake(kArtworkShadowOffset, kArtworkShadowOffset);
    self.artworkView.layer.shadowColor = UIColor.blackColor.CGColor;
    self.artworkView.layer.shadowOpacity = kArtworkShadowOpacity;
    self.artworkView.layer.shadowRadius = kArtworkShadowRadius;
    self.artworkView.layer.shouldRasterize = YES;
    [self.itemView addSubview:self.artworkView];

    UILabel *name =
        [[UILabel alloc] initWithFrame:CGRectMake(kTextColumnLeft,
                                                  kItemNameTop,
                                                  self.view.bounds.size.width + kTextColumnInset,
                                                  kItemNameMaxHeight)];
    self.labelItemName = name;
    self.labelItemName.numberOfLines = 2;
    self.labelItemName.lineBreakMode = NSLineBreakByWordWrapping;
    self.labelItemName.font = [UIFont boldSystemFontOfSize:kItemNameFontSize];
    self.labelItemName.autoresizingMask =
        UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleBottomMargin;
    [self.itemView addSubview:self.labelItemName];

    UILabel *artist =
        [[UILabel alloc] initWithFrame:CGRectMake(kTextColumnLeft,
                                                  kItemNameMaxHeight,
                                                  self.view.bounds.size.width + kTextColumnInset,
                                                  kSecondaryLabelRowHeight)];
    self.labelArtistName = artist;
    self.labelArtistName.font = [UIFont systemFontOfSize:kSecondaryLabelFontSize];
    self.labelArtistName.adjustsFontSizeToFitWidth = YES;
    self.labelArtistName.autoresizingMask =
        UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleBottomMargin;
    [self.itemView addSubview:self.labelArtistName];

    UILabel *levels =
        [[UILabel alloc] initWithFrame:CGRectMake(kTextColumnLeft,
                                                  kLevelsLabelTop,
                                                  self.view.bounds.size.width + kLevelsColumnInset,
                                                  kSecondaryLabelRowHeight)];
    self.labelLevels = levels;
    self.labelLevels.font = [UIFont boldSystemFontOfSize:kSecondaryLabelFontSize];
    self.labelLevels.adjustsFontSizeToFitWidth = YES;
    self.labelLevels.autoresizingMask =
        UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleBottomMargin;
    [self.itemView addSubview:self.labelLevels];

    StoreButtonView *download = [[StoreButtonView alloc]
        initWithFrame:CGRectMake(self.view.bounds.size.width + kDownloadButtonRightInset +
                                     kTextColumnInset,
                                 g_dCustomizeLayoutMetric100,
                                 kActionButtonWidth,
                                 kActionButtonHeight)];
    self.downloadBtn = download;
    self.downloadBtn.disabledColor = [UIColor colorWithWhite:kDisabledButtonWhite
                                                       alpha:kOpaqueAlpha];
    [self.downloadBtn setCornerRadius:kActionButtonCorner];
    self.downloadBtn.exclusiveTouch = YES;
    self.downloadBtn.titleLabel.font = [UIFont boldSystemFontOfSize:kActionButtonFontSize];
    [self.downloadBtn
        setButtonColor:[StoreCampaignItemInfo getButtonColor:self.itemInfo.buttonType]];
    [self.downloadBtn setTitle:[StoreCampaignItemInfo getButtonName:self.itemInfo.buttonType]
                      forState:UIControlStateNormal];
    [self.downloadBtn addTarget:self.delegate
                         action:@selector(pushCellButton:)
               forControlEvents:UIControlEventTouchUpInside];
    self.downloadBtn.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin;
    [self.itemView addSubview:self.downloadBtn];

    StoreButtonView *link = [[StoreButtonView alloc]
        initWithFrame:CGRectMake(self.view.bounds.size.width + kLinkButtonRightInset +
                                     kLinkButtonInset,
                                 g_dCustomizeLayoutMetric100,
                                 kActionButtonWidth,
                                 kActionButtonHeight)];
    self.linkBtn = link;
    self.linkBtn.disabledColor = [UIColor colorWithWhite:kDisabledButtonWhite alpha:kOpaqueAlpha];
    [self.linkBtn setButtonColor:[UIColor colorWithRed:g_dTranslucentAlpha
                                                 green:kLinkButtonGreen
                                                  blue:g_dTranslucentAlpha
                                                 alpha:kOpaqueAlpha]];
    [self.linkBtn setCornerRadius:kActionButtonCorner];
    self.linkBtn.exclusiveTouch = YES;
    self.linkBtn.titleLabel.font = [UIFont boldSystemFontOfSize:kActionButtonFontSize];
    [self.linkBtn setTitle:kLinkButtonTitle forState:UIControlStateNormal];
    [self.linkBtn addTarget:self
                     action:@selector(pushLink:)
           forControlEvents:UIControlEventTouchUpInside];
    self.linkBtn.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin;
    [self.itemView addSubview:self.linkBtn];
    [self.mainView addSubview:self.itemView];

    UIView *sample = [[UIView alloc] initWithFrame:CGRectMake(0,
                                                              0,
                                                              self.artworkView.frame.size.width,
                                                              self.artworkView.frame.size.height)];
    self.sampleView = sample;
    self.sampleView.opaque = YES;
    self.sampleView.alpha = kTransparentAlpha;
    self.sampleView.backgroundColor = [UIColor colorWithWhite:kSampleOverlayWhite
                                                        alpha:kSampleOverlayAlpha];

    // The centre is halved once in single precision. @ghidraAddress 0x95e8
    float sampleCenterX = self.sampleView.frame.size.width * kCenterScale;
    float sampleCenterY = self.sampleView.frame.size.height * kCenterScale;
    UIActivityIndicatorView *sampleIndicator = [[UIActivityIndicatorView alloc]
        initWithFrame:CGRectMake(0, 0, sampleCenterX, sampleCenterY)];
    self.indicatorSample = sampleIndicator;
    self.indicatorSample.activityIndicatorViewStyle = UIActivityIndicatorViewStyleWhiteLarge;
    self.indicatorSample.hidesWhenStopped = YES;
    self.indicatorSample.center = CGPointMake(sampleCenterX, sampleCenterY);
    [self.sampleView addSubview:self.indicatorSample];

    UIImageView *playing =
        [[UIImageView alloc] initWithImage:[UIImage imageWithName:kPlayGlyphName]];
    self.playingView = playing;
    self.playingView.center = CGPointMake(sampleCenterX, sampleCenterY);
    self.playingView.hidden = YES;
    [self.sampleView addSubview:self.playingView];
    [self.artworkView addSubview:self.sampleView];

    UITapGestureRecognizer *tap =
        [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(handleTapArtworkView)];
    [self.artworkView addGestureRecognizer:tap];

    CGFloat detailHeight = self.view.bounds.size.height + kDetailBlockGrowth;
    UIView *detail = [[UIView alloc]
        initWithFrame:CGRectMake(0, kItemPanelHeight, self.view.bounds.size.width, detailHeight)];
    self.detailView = detail;
    self.detailView.opaque = YES;
    self.detailView.backgroundColor = [UIColor colorWithRed:g_dTranslucentAlpha
                                                      green:g_dTranslucentAlpha
                                                       blue:g_dTranslucentAlpha
                                                      alpha:kOpaqueAlpha];
    self.detailView.layer.borderColor =
        [UIColor colorWithWhite:kDetailBorderWhite alpha:kOpaqueAlpha].CGColor;
    self.detailView.autoresizingMask = UIViewAutoresizingFlexibleWidth;

    StoreImageView *banner = [[StoreImageView alloc] initWithFrame:CGRectZero];
    self.bannerView = banner;
    self.bannerView.layer.shouldRasterize = YES;
    self.bannerView.layer.cornerRadius = kBannerCornerRadius;
    self.bannerView.clipsToBounds = YES;
    [self.detailView addSubview:self.bannerView];

    // The banner is still zero-sized here, so the description sits one inset below its height.
    CGFloat descriptionWidth = self.view.bounds.size.width + kDescriptionWidthInset;
    CGFloat descriptionHeight = detailHeight + kCopyrightGrowth;
    UITextView *description = [[UITextView alloc]
        initWithFrame:CGRectMake(kDescriptionInset,
                                 self.bannerView.frame.size.height + kDescriptionInset,
                                 descriptionWidth,
                                 descriptionHeight)];
    self.descriptionTextView = description;
    self.bannerView.autoresizingMask =
        UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleBottomMargin;
    self.descriptionTextView.backgroundColor = UIColor.clearColor;
    self.descriptionTextView.editable = NO;
    self.descriptionTextView.scrollEnabled = NO;
    self.descriptionTextView.font = [UIFont systemFontOfSize:kSecondaryLabelFontSize];
    self.descriptionTextView.autoresizingMask =
        UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleBottomMargin;
    [self.detailView addSubview:self.descriptionTextView];

    UIView *line = [[UIView alloc]
        initWithFrame:CGRectMake(0, 0, self.view.bounds.size.width, kDividerHeight)];
    self.lineView = line;
    self.lineView.backgroundColor = [UIColor colorWithRed:kDividerWhite
                                                    green:kDividerWhite
                                                     blue:kDividerWhite
                                                    alpha:kOpaqueAlpha];
    self.lineView.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    [self.detailView addSubview:self.lineView];

    UITextView *copyright = [[UITextView alloc] initWithFrame:CGRectMake(kDescriptionInset,
                                                                         descriptionHeight,
                                                                         descriptionWidth,
                                                                         kItemNameMaxHeight)];
    self.copyrightView = copyright;
    self.copyrightView.backgroundColor = UIColor.clearColor;
    self.copyrightView.editable = NO;
    self.copyrightView.font = [UIFont systemFontOfSize:kSecondaryLabelFontSize];
    self.copyrightView.autoresizingMask =
        UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleBottomMargin;
    [self.detailView addSubview:self.copyrightView];
    [self.mainView addSubview:self.detailView];

    [self setInfo:self.itemInfo];
}

/** @ghidraAddress 0xa70c */
- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    if (self.itemInfo != nil) {
        [self loadInfo];
    }
}

/** @ghidraAddress 0xa780 */
- (void)viewWillDisappear:(BOOL)animated {
    _closingFlag = YES;
    if (_packinfoDownloadAlertView != nil) {
        [_packinfoDownloadAlertView dismissWithClickedButtonIndex:0 animated:NO];
    }
    [super viewWillDisappear:animated];

    [self sampleStop];
    if ([[RBBGMManager getInstance] isPushMusic]) {
        [[RBBGMManager getInstance] StopMusic:g_flFlashMinOpacity];
        [[RBBGMManager getInstance] popMusic];
    }
    [self.sampleDownloader cancel];
    if (self.delegate != nil) {
        [self.delegate alertViewClose];
    }
}

/** @ghidraAddress 0xb370 */
- (void)viewDidDisappear:(BOOL)animated {
    [super viewDidDisappear:animated];
}

/** @ghidraAddress 0x7e04 */
- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
}

/** @ghidraAddress 0x7e38 */
- (void)viewDidUnload {
    [super viewDidUnload];
    [self stopDownloadArtworks];
}

/** @ghidraAddress 0x7df4 */
- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
    return interfaceOrientation == UIInterfaceOrientationPortrait ||
           interfaceOrientation == UIInterfaceOrientationPortraitUpsideDown;
}

/** @ghidraAddress 0xb3a4 */
- (void)willAnimateRotationToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
                                         duration:(NSTimeInterval)duration {
    [super willAnimateRotationToInterfaceOrientation:interfaceOrientation duration:duration];
    [self updateLayout];
}

#pragma mark - Item binding

/** @ghidraAddress 0x5b34 */
- (void)setInfo:(StoreCampaignItemInfo *)info {
    if (info == nil) {
        self.labelItemName.text = nil;
        self.labelArtistName.text = nil;
        self.labelLevels.text = nil;
        self.artworkView.image = [UIImage imageWithName:kPlaceholderJacketName];
        return;
    }

    self.itemInfo = info;
    bUnlock = info.bUnlock;
    hideType = info.hideType;
    _campaignID = info.campaignID;
    buttonType = info.buttonType;

    [self.artworkView setImageURL:info.artworkURL];
    self.labelItemName.text = info.name;
    self.labelArtistName.text = info.artist;
    self.labelLevels.text =
        [NSString stringWithFormat:kLevelsFormat, info.lvBasic, info.lvMedium, info.lvHard];
    self.labelID.text = [NSString stringWithFormat:kIDFormat, info.campaignID];

    downloadFlag = [self hasItem:info.itemType itemID:info.itemID];
    [self setDownloadFlag:downloadFlag];
    [self.downloadBtn setButtonColor:[StoreCampaignItemInfo getButtonColor:buttonType]];
    [self.downloadBtn setTitle:[StoreCampaignItemInfo getButtonName:buttonType]
                      forState:UIControlStateNormal];
    self.downloadBtn.tag = self.workingIndex;

    if (info.linkURL == nil) {
        self.linkBtn.alpha = kTransparentAlpha;
        self.linkBtn.hidden = YES;
    } else {
        self.linkBtn.alpha = kOpaqueAlpha;
        self.linkBtn.hidden = NO;
    }

    if (info.itemType == kCampaignItemTypeTune && hideType == kCampaignHideTypeLocked) {
        self.labelItemName.text = kLockedNamePlaceholder;
        self.labelID.text = nil;
    }

    self.bannerView.image = nil;
    [self.bannerView setImageURL:info.campaignBannerURL];
    self.descriptionTextView.text = info.campaignDescription;
    self.copyrightView.text = self.itemInfo.copyright;
    [self updateLayout];
}

/** @ghidraAddress 0x64f8 */
- (void)setDownloadFlag:(BOOL)flag {
    downloadFlag = flag;
    if (flag) {
        buttonType = kCampaignButtonDownloading;
    }
    [self.downloadBtn setButtonColor:[StoreCampaignItemInfo getButtonColor:buttonType]];
    [self.downloadBtn setTitle:[StoreCampaignItemInfo getButtonName:buttonType]
                      forState:UIControlStateNormal];
    self.downloadBtn.enabled = !downloadFlag;
}

/** @ghidraAddress 0x6684 */
- (BOOL)hasItem:(int)hasItem itemID:(int)itemID {
    if (hasItem != kCampaignItemTypeTune) {
        return NO;
    }
    if ([[RBMusicManager getInstance] getMusicData:itemID] == nil) {
        return NO;
    }
    NSString *path = [RBMusicManager getPathFromPurchesed:itemID];
    return [[NSFileManager defaultManager] fileExistsAtPath:path];
}

#pragma mark - Detail presentation

/** @ghidraAddress 0x6798 */
- (void)showItemInfo {
    self.downloadBtn.hidden = NO;
    self.linkBtn.hidden = NO;
    self.itemView.hidden = NO;
    self.detailView.hidden = NO;
    if ([self.artworkView loadedImage]) {
        return;
    }
    [self.artworkView startDownloadImage];
}

/** @ghidraAddress 0x6924 */
- (void)loadInfo {
    if (self.itemInfo != nil) {
        [self showItemInfo];
    }
}

/** @ghidraAddress 0xa970 */
- (void)updateLayout {
    if (self.itemInfo == nil) {
        return;
    }

    NSString *nameText = self.labelItemName.text;
    CGFloat columnWidth =
        self.view.bounds.size.width + kNameLabelBottomInset + kTextBlockBottomInset;
    UIFont *nameFont = nil;
    for (int step = 0; step < kItemNameFontStepCount; ++step) {
        nameFont = [UIFont boldSystemFontOfSize:(kItemNameMaxFontSize - (float)step)];
        CGSize measured = [nameText sizeWithFont:nameFont
                               constrainedToSize:CGSizeMake(columnWidth, MAXFLOAT)
                                   lineBreakMode:NSLineBreakByWordWrapping];
        if (measured.width <= columnWidth && measured.height <= kItemNameMaxHeight) {
            break;
        }
    }
    self.labelItemName.font = nameFont;

    self.labelItemName.frame =
        CGRectMake(self.labelItemName.frame.origin.x,
                   self.labelItemName.frame.origin.y,
                   self.view.bounds.size.width + kNameLabelBottomInset + kTextBlockBottomInset,
                   kItemNameMaxHeight);
    [self.labelItemName sizeToFit];

    CGRect bannerFrame = self.bannerView.frame;
    CGFloat descriptionLeft = self.descriptionTextView.frame.origin.x;
    CGFloat copyrightLeft = self.copyrightView.frame.origin.x;
    CGFloat copyrightWidth = self.copyrightView.frame.size.width;
    [self.descriptionTextView sizeToFit];
    [self.copyrightView sizeToFit];

    CGFloat descriptionHeight = CGRectGetHeight(self.descriptionTextView.frame);
    CGFloat descriptionTop = CGRectGetMaxY(bannerFrame) + kElementSpacing;
    CGFloat descriptionWidth = self.view.bounds.size.width + kDescriptionWidthInset;
    self.descriptionTextView.frame =
        CGRectMake(descriptionLeft, descriptionTop, descriptionWidth, descriptionHeight);

    CGFloat copyrightHeight = CGRectGetHeight(self.copyrightView.frame);
    CGFloat copyrightTop = descriptionTop + descriptionHeight + kElementSpacing;
    CGFloat detailHeight;
    if (copyrightTop + copyrightHeight >= self.view.bounds.size.height + kDetailBlockGrowth) {
        detailHeight = copyrightTop + copyrightHeight;
    } else {
        copyrightTop = (self.view.bounds.size.height + kDetailBlockGrowth) - copyrightHeight;
        detailHeight = self.view.bounds.size.height + kDetailBlockGrowth;
    }
    // The copyright keeps its own width here; only the description takes the inset column width.
    self.copyrightView.frame =
        CGRectMake(copyrightLeft, copyrightTop, copyrightWidth, copyrightHeight);
    self.detailView.frame = CGRectMake(self.detailView.frame.origin.x,
                                       self.detailView.frame.origin.y,
                                       self.view.bounds.size.width,
                                       detailHeight);

    self.lineView.frame = CGRectMake(0.0,
                                     copyrightTop + kDividerLift,
                                     self.lineView.frame.size.width,
                                     self.lineView.frame.size.height);

    self.mainView.contentSize =
        CGSizeMake(self.mainView.frame.size.width,
                   self.itemView.frame.size.height + self.detailView.frame.size.height);
}

#pragma mark - Sample playback

/** @ghidraAddress 0x6978 */
- (void)sampleStart {
    if (self.sampleDownloader == nil) {
        return;
    }
    NSData *data = [self.sampleDownloader getData];
    [[RBBGMManager getInstance] LoadMusicWithPush:data Loop:YES];
    [[RBBGMManager getInstance] PlayMusic:kSampleBGMFadeTime];
    [self sampleViewPlaying];
}

/** @ghidraAddress 0x6ad4 */
- (void)sampleStop {
    if (self.samplePlayedIndex != kNoSampleIndex) {
        if ([[RBBGMManager getInstance] isPushMusic]) {
            [[RBBGMManager getInstance] StopMusic:g_flFlashMinOpacity];
            [[RBBGMManager getInstance] popMusic];
        }
        [self sampleViewStop];
        self.samplePlayedIndex = kNoSampleIndex;
    }
    sampleStatus = kSampleStatusIdle;
}

/** @ghidraAddress 0x6fdc */
- (void)sampleViewStop {
    self.sampleView.alpha = kTransparentAlpha;
    [self.indicatorSample stopAnimating];
    self.playingView.hidden = YES;
    sampleStatus = kSampleStatusIdle;
}

/** @ghidraAddress 0x70b4 */
- (void)sampleViewDownloading {
    self.sampleView.alpha = kOpaqueAlpha;
    [self.indicatorSample startAnimating];
    self.playingView.hidden = YES;
    sampleStatus = kSampleStatusDownloading;
}

/** @ghidraAddress 0x7198 */
- (void)sampleViewPlaying {
    self.sampleView.alpha = kOpaqueAlpha;
    [self.indicatorSample stopAnimating];
    self.playingView.hidden = NO;
    sampleStatus = kSampleStatusPlaying;
}

/** @ghidraAddress 0x7274 */
- (void)handleTapArtworkView {
    switch (sampleStatus) {
    case kSampleStatusIdle: {
        self.sampleDownloader =
            [[Downloader alloc] initWithURL:[NSURL URLWithString:self.itemInfo.thumbnailURL]
                                       save:nil];
        [self.sampleDownloader startDownloadingWithDelegate:self];
        [self sampleViewDownloading];
        return;
    }
    case kSampleStatusDownloading:
        if (self.sampleDownloader != nil) {
            [self.sampleDownloader cancel];
            self.sampleDownloader = nil;
        }
        break;
    case kSampleStatusPlaying:
        if (self.sampleDownloader != nil) {
            [self.sampleDownloader cancel];
            self.sampleDownloader = nil;
        }
        break;
    default:
        return;
    }
    [self sampleStop];
}

/** @ghidraAddress 0x74ec */
- (void)finishBgm:(id)notification {
    [self sampleStop];
}

#pragma mark - Cell actions

/** @ghidraAddress 0x6c08 */
- (void)pushExternalLink:(id)sender {
    if ([sender tag] < 0) {
        return;
    }
    if (self.samplePlayedIndex != kNoSampleIndex) {
        [self sampleStop];
    }
    if (self.itemInfo != nil && self.itemInfo.linkURL != nil) {
        [[UIApplication sharedApplication] openURL:self.itemInfo.linkURL];
    }
}

/** @ghidraAddress 0x7508 */
- (void)pushLink:(id)sender {
    if (self.itemInfo.linkURL != nil) {
        [[UIApplication sharedApplication] openURL:self.itemInfo.linkURL];
    }
}

/** @ghidraAddress 0x6dac */
- (void)pushButton:(id)sender {
    if (self.samplePlayedIndex != kNoSampleIndex) {
        [self sampleStop];
    }
    if (self.itemInfo == nil) {
        return;
    }

    switch (self.itemInfo.buttonType) {
    case kCampaignButtonInfoDownload:
        [self itemInfoDownload];
        return;
    case kCampaignButtonTerms:
        [UIAlertView showUnlockTermsDescription2:self.itemInfo];
        break;
    case kCampaignButtonUpdate:
        [UIAlertView showAlertUpdateForUnlock:self];
        break;
    case kCampaignButtonSerialCode: {
        UIAlertView *alert = [UIAlertView showSerialcodeDialog:self];
        alert.alertViewStyle = UIAlertViewStylePlainTextInput;
        alert.tag = kSerialCodeAlertTag;
        [self.delegate setAlertView:alert];
        [alert show];
        break;
    }
    default:
        break;
    }
}

/** @ghidraAddress 0x78b8 */
- (void)itemInfoDownload {
}

#pragma mark - Alert view delegate

/** @ghidraAddress 0x78bc */
- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex {
}

/** @ghidraAddress 0x78c0 */
- (void)alertView:(UIAlertView *)alertView didDismissWithButtonIndex:(NSInteger)buttonIndex {
    if (!self.closingFlag && [self.delegate respondsToSelector:@selector(detailViewClose)]) {
        [self.delegate performSelector:@selector(detailViewClose)];
    }
}

/** @ghidraAddress 0x79b0 */
- (void)alertView:(UIAlertView *)alertView willDismissWithButtonIndex:(NSInteger)buttonIndex {
}

/** @ghidraAddress 0x79b4 */
- (void)alertViewCancel:(UIAlertView *)alertView {
    if (self.closingFlag && [self.delegate respondsToSelector:@selector(detailViewClose)]) {
        [self.delegate performSelector:@selector(detailViewClose)];
    }
}

/** @ghidraAddress 0x7aac */
- (void)didPresentAlertView:(UIAlertView *)alertView {
    [UIAlertView setExclusiveTouchForView:[[[[[UIApplication sharedApplication] keyWindow]
                                              rootViewController] presentedViewController] view]];
}

#pragma mark - Downloader delegate

/** @ghidraAddress 0x7648 */
- (void)downloaderFinished:(Downloader *)downloader {
    if (self.sampleDownloader != downloader) {
        return;
    }
    if (sampleStatus == kSampleStatusDownloading) {
        NSData *data = [self.sampleDownloader getData];
        [[RBBGMManager getInstance] LoadMusicWithPush:data Loop:YES];
        [[RBBGMManager getInstance] PlayMusic:kSampleBGMNoFade];
        [self sampleViewPlaying];
        self.samplePlayedIndex = kSampleRowIndex;
    }
    self.sampleDownloader = nil;
}

/** @ghidraAddress 0x77fc */
- (void)downloaderError:(Downloader *)downloader {
    if (self.sampleDownloader != downloader) {
        return;
    }
    [self sampleStop];
    self.sampleDownloader = nil;
    [UIAlertView showNetworkErrorWithDelegate:nil];
}

/** @ghidraAddress 0x78b4 */
- (void)downloaderProceed:(Downloader *)downloader {
}

#pragma mark - Artwork downloaders

/** @ghidraAddress 0x7bec */
- (void)stopDownloadArtworks {
    if (self.artworkDownloaders.count == 0) {
        return;
    }
    for (ImageDownloader *downloader in [self.artworkDownloaders objectEnumerator]) {
        [downloader cancelDownload];
        downloader.delegate = nil;
    }
    [self.artworkDownloaders removeAllObjects];
}

@end
