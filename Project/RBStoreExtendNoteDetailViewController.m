#import "RBStoreExtendNoteDetailViewController.h"

#import <UIKit/UIKit.h>

#import "ImageDownloader.h"
#import "NSFileManager+RB.h"
#import "RBBGMManager.h"
#import "RBMusicManager.h"
#import "RBTermPhoneViewController.h"
#import "StoreButtonView.h"
#import "StoreExtendNoteInfo.h"
#import "StoreImageView.h"
#import "UIAlertView+RB.h"
#import "UIImage+RB.h"
#import "UIView+RB.h"
#import "engineglobals.h"

// @ghidraAddress 0x3cfc10 "installing" title.

static NSString *const kDetailNavigationTitle = @"info";

static NSString *const kLevelLabelFormat = @"LEVEL %d";

static NSString *const kTermsLinkText = @"規約等および各種注意事項";

static NSString *const kArtworkPlaceholderImageName = @"09_store/store_jacket_80";
static NSString *const kSamplePlayGlyphImageName = @"09_store/store_play";
static NSString *const kNewBadgeImageName = @"09_store/store_new";
static NSString *const kDetailBackgroundImageName = @"09_store/store_pack_bg_2";

static const int kNoSamplePlayedIndex = -1;

typedef NS_ENUM(NSInteger, SampleStatus) {
    SampleStatusIdle = 0,        /*!< No sample is loaded. */
    SampleStatusDownloading = 1, /*!< The sample is being downloaded. */
    SampleStatusPlaying = 2,     /*!< The sample is playing. */
};

static const NSUInteger kControlStateNormal = 0;
static const NSUInteger kControlStateDisabled = 2;

// The valid autorotation orientations: portrait (1) and portrait-upside-down (2) only.
static const NSInteger kFirstSupportedOrientation = 1;
static const NSInteger kSupportedOrientationCount = 2;

static const CGFloat kArtworkOrigin = 8.0;
static const CGFloat kArtworkSide = 80.0;            // @ghidraAddress 0x2ec6c8
static const CGFloat kItemViewHeight = 140.0;        // @ghidraAddress 0x2ec6c0
static const CGFloat kLabelBlockRightInset = -104.0; // @ghidraAddress 0x2ec6d0
static const CGFloat kLabelBlockOriginX = 96.0;      // @ghidraAddress 0x2ec6d8
static const CGFloat kMusicLabelHeight = 50.0;       // @ghidraAddress 0x2ec6e0
static const CGFloat kArtistLabelOriginY = 50.0;
static const CGFloat kLabelRowHeight = 20.0;
static const CGFloat kLevelLabelWidthInset = -230.0; // @ghidraAddress 0x2ec6e8
static const CGFloat kLevelLabelOriginY = 70.0;      // @ghidraAddress 0x2ec6f0
static const CGFloat kButtonOriginXInset = -8.0;
static const CGFloat kButtonOriginY = 100.0; // @ghidraAddress 0x2ec6f8
static const CGFloat kButtonWidth = 104.0;   // @ghidraAddress 0x2ec700
static const CGFloat kDetailWidthInset = -20.0;
static const CGFloat kDetailHeightInset = -140.0; // @ghidraAddress 0x2ec728
static const CGFloat kDescriptionInsetX = 10.0;
static const CGFloat kDescriptionHeightInset = -30.0;
static const CGFloat kArtworkBorderWidth = 1.0;
static const CGFloat kArtworkShadowOffset = 2.0;
static const CGFloat kArtworkShadowOpacity = 0.6f; // @ghidraAddress 0x2ec6b8 (a float slot).
static const CGFloat kArtworkShadowRadius = 2.0;
static const CGFloat kMusicLabelFontSize = 18.0;
static const CGFloat kArtistLabelFontSize = 12.0;
static const CGFloat kLevelLabelFontSize = 12.0;
static const CGFloat kButtonFontSize = 10.0;
static const CGFloat kDescriptionFontSize = 12.0;
static const CGFloat kBannerCornerRadius = 8.0;
static const CGFloat kButtonCornerRadius = 4.0;
static const CGFloat kSampleViewAlpha = 0.4f;         // @ghidraAddress 0x2ec720
static const CGFloat kBorderWhite = 143.0 / 255.0;    // @ghidraAddress 0x2ec730
static const CGFloat kLineViewWhite = 0.71f;          // @ghidraAddress 0x2eecc0
static const CGFloat kTermsTextWhite = 122.0 / 255.0; // @ghidraAddress 0x2eecc8
static const CGFloat kDividerHeight = 30.0;
static const CGFloat kSeparatorTop = 5.0;
static const CGFloat kTermsLinkFontSize = 10.0;
static const CGFloat kButtonHeight = 25.0;

static const int kMusicLabelFitAttempts = 9;

static const UIViewAutoresizing kMaskFlexibleWidthHeight = 0x12;
static const UIViewAutoresizing kMaskFlexibleWidthTopBottom = 0x22;
static const UIViewAutoresizing kMaskFlexibleWidth = 0x2;
static const UIViewAutoresizing kMaskFlexibleLeftMargin = 0x1;

@interface RBStoreExtendNoteDetailViewController () <UIAlertViewDelegate> {
    int sampleStatus;
    BOOL isDownloadingSample; // The shipped build never reads it.
    BOOL downloadFlag;
}
@end

@implementation RBStoreExtendNoteDetailViewController

#pragma mark - Lifecycle

- (instancetype)initWithExtendNoteInfo:(StoreExtendNoteInfo *)info {
    self = [super init];
    if (self != nil) {
        [self.navigationItem setTitle:kDetailNavigationTitle];
        self.info = info;
        if (self.info.name != nil) {
            [self.navigationItem setTitle:self.info.name];
        }
    }
    return self;
}

- (void)loadView {
    [super loadView];
}

- (void)dealloc {
    [self.sampleDownloader cancel];
    [self stopDownloadArtworks];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
}

- (void)viewDidUnload {
    [super viewDidUnload];
    [self stopDownloadArtworks];
}

#pragma mark - View construction

- (void)buildArtworkAndSampleOverlay {
    self.artworkView = [[StoreImageView alloc]
        initWithFrame:CGRectMake(kArtworkOrigin, kArtworkOrigin, kArtworkSide, kArtworkSide)];
    [self.artworkView.layer setBorderWidth:kArtworkBorderWidth];
    [self.artworkView.layer setBorderColor:UIColor.whiteColor.CGColor];
    [self.artworkView setBackgroundColor:UIColor.whiteColor];
    [self.artworkView.layer setShadowOffset:CGSizeMake(kArtworkShadowOffset, kArtworkShadowOffset)];
    [self.artworkView.layer setShadowColor:UIColor.blackColor.CGColor];
    [self.artworkView.layer setShadowOpacity:kArtworkShadowOpacity];
    [self.artworkView.layer setShadowRadius:kArtworkShadowRadius];
    [self.artworkView.layer setShouldRasterize:YES];
    [self.itemView addSubview:self.artworkView];
}

- (void)buildItemLabels {
    const CGFloat viewWidth = self.view.bounds.size.width;

    self.labelMusicName =
        [[UILabel alloc] initWithFrame:CGRectMake(kLabelBlockOriginX,
                                                  kArtworkOrigin,
                                                  viewWidth + kLabelBlockRightInset,
                                                  kMusicLabelHeight)];
    [self.labelMusicName setNumberOfLines:2];
    [self.labelMusicName setLineBreakMode:NSLineBreakByWordWrapping];
    [self.labelMusicName setFont:[UIFont boldSystemFontOfSize:kMusicLabelFontSize]];
    [self.labelMusicName setAutoresizingMask:kMaskFlexibleWidthTopBottom];
    [self.itemView addSubview:self.labelMusicName];

    self.labelArtistName =
        [[UILabel alloc] initWithFrame:CGRectMake(kLabelBlockOriginX,
                                                  kArtistLabelOriginY,
                                                  viewWidth + kLabelBlockRightInset,
                                                  kLabelRowHeight)];
    [self.labelArtistName setFont:[UIFont systemFontOfSize:kArtistLabelFontSize]];
    [self.labelArtistName setAdjustsFontSizeToFitWidth:YES];
    [self.labelArtistName setAutoresizingMask:kMaskFlexibleWidthTopBottom];
    [self.itemView addSubview:self.labelArtistName];

    self.labelLevel = [[UILabel alloc] initWithFrame:CGRectMake(kLabelBlockOriginX,
                                                                kLevelLabelOriginY,
                                                                viewWidth + kLevelLabelWidthInset,
                                                                kLabelRowHeight)];
    [self.labelLevel setFont:[UIFont boldSystemFontOfSize:kLevelLabelFontSize]];
    [self.labelLevel setAdjustsFontSizeToFitWidth:YES];
    [self.labelLevel setAutoresizingMask:kMaskFlexibleWidthTopBottom];
    [self.itemView addSubview:self.labelLevel];
}

- (void)buildActionButton {
    const CGFloat buttonOriginX =
        self.view.bounds.size.width + kButtonOriginXInset + kLabelBlockRightInset;
    self.downloadBtn = [[StoreButtonView alloc]
        initWithFrame:CGRectMake(buttonOriginX, kButtonOriginY, kButtonWidth, kButtonHeight)];
    [self.downloadBtn setDisabledColor:[UIColor colorWithWhite:g_dRBWebViewGrayViewWhite
                                                         alpha:1.0]];
    [self.downloadBtn.layer setCornerRadius:kButtonCornerRadius];
    [self.downloadBtn setExclusiveTouch:YES];
    [self.downloadBtn.titleLabel setFont:[UIFont boldSystemFontOfSize:kButtonFontSize]];
    [self.downloadBtn setButtonColor:self.info.getButtonColor];
    [self.downloadBtn setTitle:self.info.getButtonName forState:kControlStateNormal];
    [self.downloadBtn addTarget:self
                         action:@selector(selectButton)
               forControlEvents:UIControlEventTouchUpInside];
    [self.downloadBtn setAutoresizingMask:kMaskFlexibleLeftMargin];
    [self.itemView addSubview:self.downloadBtn];
}

- (void)buildSampleOverlay {
    self.sampleView = [[UIView alloc] initWithFrame:CGRectMake(0.0,
                                                               0.0,
                                                               self.artworkView.frame.size.width,
                                                               self.artworkView.frame.size.height)];
    [self.sampleView setOpaque:YES];
    [self.sampleView setAlpha:0.0];
    [self.sampleView setBackgroundColor:[UIColor colorWithWhite:0.0 alpha:kSampleViewAlpha]];

    // The binary rounds through float, so the centre lands on a single-precision value.
    const CGFloat centreX = (CGFloat)(float)(self.sampleView.frame.size.width * 0.5);
    const CGFloat centreY = (CGFloat)(float)(self.sampleView.frame.size.height * 0.5);

    self.indicatorSample =
        [[UIActivityIndicatorView alloc] initWithFrame:CGRectMake(0.0, 0.0, centreX, centreY)];
    [self.indicatorSample setActivityIndicatorViewStyle:UIActivityIndicatorViewStyleWhiteLarge];
    [self.indicatorSample setHidesWhenStopped:YES];
    [self.indicatorSample setCenter:CGPointMake(centreX, centreY)];
    [self.sampleView addSubview:self.indicatorSample];

    self.playingView =
        [[UIImageView alloc] initWithImage:[UIImage imageWithName:kSamplePlayGlyphImageName]];
    [self.playingView setCenter:CGPointMake(centreX, centreY)];
    [self.playingView setHidden:YES];
    [self.sampleView addSubview:self.playingView];
    [self.artworkView addSubview:self.sampleView];

    UITapGestureRecognizer *tap =
        [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(handleTapArtworkView)];
    [self.artworkView addGestureRecognizer:tap];
}

- (CGFloat)buildDetailCardBelow:(CGFloat)contentBottom {
    const CGFloat viewWidth = self.view.bounds.size.width;
    self.detailView =
        [[UIView alloc] initWithFrame:CGRectMake(0.0, kItemViewHeight, viewWidth, contentBottom)];
    [self.detailView setOpaque:YES];
    [self.detailView setBackgroundColor:[UIColor colorWithRed:g_dTranslucentAlpha
                                                        green:g_dTranslucentAlpha
                                                         blue:g_dTranslucentAlpha
                                                        alpha:1.0]];
    [self.detailView.layer setBorderColor:[UIColor colorWithWhite:kBorderWhite alpha:1.0].CGColor];
    [self.detailView setAutoresizingMask:kMaskFlexibleWidth];

    self.bannerView = [[StoreImageView alloc] initWithFrame:CGRectZero];
    [self.bannerView.layer setShouldRasterize:YES];
    [self.bannerView.layer setCornerRadius:kBannerCornerRadius];
    [self.bannerView setClipsToBounds:YES];
    [self.detailView addSubview:self.bannerView];

    const CGFloat descriptionHeight = contentBottom + kDescriptionHeightInset;
    self.descriptionTextView = [[UITextView alloc]
        initWithFrame:CGRectMake(kDescriptionInsetX,
                                 self.bannerView.frame.size.height + kDescriptionInsetX,
                                 viewWidth + kDetailWidthInset,
                                 descriptionHeight)];
    [self.bannerView setAutoresizingMask:kMaskFlexibleWidthTopBottom];
    [self.descriptionTextView setBackgroundColor:UIColor.clearColor];
    [self.descriptionTextView setEditable:NO];
    [self.descriptionTextView setScrollEnabled:NO];
    [self.descriptionTextView setFont:[UIFont systemFontOfSize:kDescriptionFontSize]];
    [self.descriptionTextView setAutoresizingMask:kMaskFlexibleWidthTopBottom];
    [self.detailView addSubview:self.descriptionTextView];

    // UIView(RB) -width reads the frame rather than the bounds.
    UIView *lineView = [[UIView alloc]
        initWithFrame:CGRectMake(0.0, descriptionHeight, self.view.width, kDividerHeight)];
    [lineView setBackgroundColor:[UIColor colorWithWhite:kLineViewWhite alpha:1.0]];
    [self.detailView addSubview:lineView];

    const CGFloat termsWidth = lineView.width + kDetailWidthInset;
    UILabel *termsLabel = [[UILabel alloc]
        initWithFrame:CGRectMake(kDescriptionInsetX, 0.0, termsWidth, kDividerHeight)];
    [termsLabel setFont:[UIFont systemFontOfSize:kTermsLinkFontSize]];
    [termsLabel setTextColor:[UIColor colorWithRed:0.0 green:kTermsTextWhite blue:1.0 alpha:1.0]];
    [termsLabel setTextAlignment:NSTextAlignmentLeft];
    [termsLabel setText:kTermsLinkText];
    [termsLabel setUserInteractionEnabled:YES];
    UITapGestureRecognizer *termsTap =
        [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(showTerm)];
    [termsLabel addGestureRecognizer:termsTap];
    [lineView addSubview:termsLabel];
    self.termLinkView = lineView;

    return descriptionHeight;
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    _closingFlag = NO;

    if (self.artworkView.loadedImage) {
        [self updateLayout];
        [self selfCheckButtonText];
        return;
    }

    [self.view setOpaque:YES];
    [self.view setAutoresizingMask:kMaskFlexibleWidthHeight];
    [self.view setBackgroundColor:UIColor.grayColor];

    self.mainView = [[UIScrollView alloc] initWithFrame:self.view.bounds];
    [self.mainView setScrollEnabled:YES];
    [self.mainView setAutoresizingMask:kMaskFlexibleWidthHeight];
    [self.view addSubview:self.mainView];

    UIImage *packBackground = [UIImage imageWithName:kDetailBackgroundImageName];

    self.itemView = [[UIView alloc]
        initWithFrame:CGRectMake(0.0, 0.0, self.view.bounds.size.width, kItemViewHeight)];
    [self.itemView setAutoresizingMask:kMaskFlexibleWidth];

    UIImageView *itemBackground = [[UIImageView alloc]
        initWithFrame:CGRectMake(0.0, 0.0, self.view.bounds.size.width, kItemViewHeight)];
    [itemBackground setImage:[packBackground stretchableImageWithLeftCapWidth:4 topCapHeight:4]];
    [itemBackground setAutoresizingMask:kMaskFlexibleWidthHeight];
    [self.itemView addSubview:itemBackground];

    [self buildArtworkAndSampleOverlay];
    [self buildItemLabels];
    [self buildActionButton];
    [self.mainView addSubview:self.itemView];
    [self buildSampleOverlay];

    self.iconNew = [[UIImageView alloc] initWithImage:[UIImage imageWithName:kNewBadgeImageName]];
    [self.itemView addSubview:self.iconNew];

    const CGFloat detailHeight = self.view.bounds.size.height + kDetailHeightInset;
    [self buildDetailCardBelow:detailHeight];
    [self.mainView addSubview:self.detailView];

    [self setExtendNoteInfo:self.info];
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    if (self.info != nil) {
        [self loadInfo];
    }
}

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
    (void)self.delegate; // Yes, the binary reads the delegate here and discards it.
}

- (void)viewDidDisappear:(BOOL)animated {
    [super viewDidDisappear:animated];
}

- (void)willAnimateRotationToInterfaceOrientation:(UIInterfaceOrientation)orientation
                                         duration:(NSTimeInterval)duration {
    [super willAnimateRotationToInterfaceOrientation:orientation duration:duration];
    [self updateLayout];
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)orientation {
    // The range test is unsigned (`cset w0,cc`), so an unknown orientation reports NO.
    // @ghidraAddress 0x1a9308
    return (NSUInteger)(orientation - kFirstSupportedOrientation) <
           (NSUInteger)kSupportedOrientationCount;
}

#pragma mark - Content

- (void)setExtendNoteInfo:(StoreExtendNoteInfo *)info {
    if (info == nil) {
        [self.labelMusicName setText:nil];
        [self.labelArtistName setText:nil];
        [self.labelLevel setText:nil];
        [self.artworkView setImage:[UIImage imageWithName:kArtworkPlaceholderImageName]];
        return;
    }

    self.info = info;
    [self.artworkView setImageURL:info.artworkURL];
    [self.labelMusicName setText:info.name];
    [self.labelArtistName setText:info.artist];
    [self.labelLevel setText:[NSString stringWithFormat:kLevelLabelFormat, info.difficulty]];
    [self selfCheckButtonText];
    [self.downloadBtn setTitle:info.getButtonName forState:kControlStateNormal];
    [self.downloadBtn setTag:self.workingIndex];
    [self.descriptionTextView setText:info.comment];
    [self updateLayout];
}

- (void)setDownloadFlag:(BOOL)downloadFlagValue {
    // Retained hook: the shipped build records nothing.
}

- (void)setPurchaseState:(BOOL)purchaseState {
    [self.downloadBtn setButtonColor:self.info.getButtonColor];
    [self.downloadBtn setTitle:self.info.getButtonName forState:kControlStateNormal];
}

- (BOOL)hasItem:(int)hasItem itemID:(int)itemID {
    if (hasItem == 0 && [[RBMusicManager getInstance] getMusicData:itemID] != nil) {
        NSString *path = [RBMusicManager getPathFromPurchesed:itemID];
        return [[NSFileManager defaultManager] fileExistsAtPath:path];
    }
    return NO;
}

- (void)showItemInfo {
    [self.downloadBtn setHidden:NO];
    [self.itemView setHidden:NO];
    [self.detailView setHidden:NO];
    if (!self.artworkView.loadedImage) {
        [self.artworkView startDownloadImage];
    }
    [self.iconNew setHidden:self.info.isNew ? NO : YES];
}

- (void)loadInfo {
    if (self.info != nil) {
        [self showItemInfo];
    }
}

- (void)itemInfoDownload {
    // Retained hook: the shipped build does nothing.
}

- (void)updateLayout {
    if (self.info == nil) {
        return;
    }

    NSString *musicName = self.labelMusicName.text;
    const CGFloat availableWidth = self.view.bounds.size.width + kLabelBlockRightInset;

    UIFont *fittedFont = nil;
    int attempt = 0;
    do {
        fittedFont = [UIFont boldSystemFontOfSize:(CGFloat)(kMusicLabelFontSize - (float)attempt)];
        CGSize fitted = [musicName sizeWithFont:fittedFont
                              constrainedToSize:CGSizeMake(availableWidth, MAXFLOAT)
                                  lineBreakMode:NSLineBreakByWordWrapping];
        ++attempt;
        if (fitted.width <= availableWidth && fitted.height <= kMusicLabelHeight) {
            break;
        }
    } while (attempt < kMusicLabelFitAttempts);
    [self.labelMusicName setFont:fittedFont];

    const CGRect musicFrame = self.labelMusicName.frame;
    [self.labelMusicName
        setFrame:CGRectMake(
                     musicFrame.origin.x, musicFrame.origin.y, availableWidth, kMusicLabelHeight)];
    [self.labelMusicName sizeToFit];

    // Snapshot the frames before -sizeToFit rewrites them.
    const CGRect bannerFrame = self.bannerView.frame;
    const CGFloat descriptionOriginX = self.descriptionTextView.frame.origin.x;
    const CGRect termsFrameBefore = self.termLinkView.frame;

    [self.descriptionTextView sizeToFit];
    [self.termLinkView sizeToFit];

    const CGFloat viewWidth = self.view.bounds.size.width;
    const CGFloat descriptionHeight = CGRectGetHeight(self.descriptionTextView.frame);
    const CGFloat descriptionTop = bannerFrame.origin.y + bannerFrame.size.height + kSeparatorTop;
    [self.descriptionTextView setFrame:CGRectMake(descriptionOriginX,
                                                  descriptionTop,
                                                  viewWidth + kDetailWidthInset,
                                                  descriptionHeight)];

    const CGFloat termsHeight = CGRectGetHeight(self.termLinkView.frame);
    const CGFloat descriptionBottom = descriptionTop + descriptionHeight + kSeparatorTop;
    const CGFloat cardHeight = self.view.bounds.size.height + kDetailHeightInset;

    CGFloat termsOriginY;
    CGFloat detailHeight;
    if (descriptionBottom + termsHeight < cardHeight) {
        termsOriginY = cardHeight - termsHeight;
        detailHeight = cardHeight;
    } else {
        termsOriginY = descriptionBottom;
        detailHeight = descriptionBottom + termsHeight;
    }
    [self.termLinkView setFrame:CGRectMake(termsFrameBefore.origin.x,
                                           termsOriginY,
                                           termsFrameBefore.size.width,
                                           termsHeight)];

    const CGRect detailFrame = self.detailView.frame;
    [self.detailView
        setFrame:CGRectMake(detailFrame.origin.x, detailFrame.origin.y, viewWidth, detailHeight)];

    [self.mainView setContentSize:CGSizeMake(self.mainView.frame.size.width,
                                             CGRectGetHeight(self.itemView.frame) +
                                                 CGRectGetHeight(self.detailView.frame))];
    [self.iconNew setHidden:!self.info.isNew];
}

#pragma mark - Action button

- (void)setButtonTextBuy {
    NSString *buyTitle = [NSString stringWithFormat:g_pLocalizedBuyFormat, @(self.info.price)];
    [self.downloadBtn setTitle:buyTitle forState:kControlStateNormal];
    [self.downloadBtn setEnabled:YES];
}

- (void)setButtonTextInstall {
    [self.downloadBtn setTitle:g_pLocalizedInstall forState:kControlStateNormal];
    [self.downloadBtn setEnabled:YES];
}

- (void)setButtonTextInstalling {
    [self.downloadBtn setTitle:g_pLocalizedInstalling forState:kControlStateDisabled];
    [self.downloadBtn setEnabled:NO];
}

- (void)setButtonTextInstalled {
    [self.downloadBtn setTitle:g_pLocalizedInstalled forState:kControlStateDisabled];
    [self.downloadBtn setEnabled:NO];
}

- (void)selfCheckButtonText {
    [self.downloadBtn setEnabled:YES];
    [self.downloadBtn setButtonColor:self.info.getButtonColor];
    [self.downloadBtn setTitle:self.info.getButtonName forState:kControlStateNormal];
    // The comparison is unsigned, so the error state (-1) also disables the button.
    [self.downloadBtn setEnabled:(unsigned int)self.info.getButtonState <
                                 (unsigned int)StoreExtendNoteButtonStateInstalled];
}

#pragma mark - Selection

- (void)selectButton {
    if (self.samplePlayedIndex != kNoSamplePlayedIndex) {
        [self sampleStop];
    }
    [self.delegate performSelector:@selector(selectButton:) withObject:@(self.info.pid)];
}

- (void)showTerm {
    RBTermPhoneViewController *termCtrl = [[RBTermPhoneViewController alloc] init];
    [termCtrl setViewTypeStore];
    [self.navigationController pushViewController:termCtrl animated:YES];
}

#pragma mark - Sample audio

- (void)sampleStart {
    if (self.sampleDownloader != nil) {
        NSData *data = self.sampleDownloader.getData;
        [[RBBGMManager getInstance] LoadMusicWithPush:data Loop:YES];
        [[RBBGMManager getInstance] PlayMusic:0.5];
        [self sampleViewPlaying];
    }
}

- (void)sampleStop {
    if (self.samplePlayedIndex != kNoSamplePlayedIndex) {
        if ([[RBBGMManager getInstance] isPushMusic]) {
            [[RBBGMManager getInstance] StopMusic:g_flFlashMinOpacity];
            [[RBBGMManager getInstance] popMusic];
        }
        [self sampleViewStop];
        self.samplePlayedIndex = kNoSamplePlayedIndex;
    }
    sampleStatus = SampleStatusIdle;
}

- (void)handleTapArtworkView {
    switch (sampleStatus) {
    case SampleStatusPlaying:
        if (self.sampleDownloader != nil) {
            [self.sampleDownloader cancel];
            self.sampleDownloader = nil;
        }
        [self sampleStop];
        break;
    case SampleStatusDownloading:
        if (self.sampleDownloader != nil) {
            [self.sampleDownloader cancel];
            self.sampleDownloader = nil;
        }
        [self sampleStop];
        break;
    case SampleStatusIdle:
        self.sampleDownloader =
            [[Downloader alloc] initWithURL:[NSURL URLWithString:self.info.sampleURL] save:nil];
        [self.sampleDownloader startDownloadingWithDelegate:self];
        [self sampleViewDownloading];
        break;
    default:
        break;
    }
}

- (void)sampleViewPlaying {
    [self.sampleView setAlpha:1.0];
    [self.indicatorSample stopAnimating];
    [self.playingView setHidden:NO];
    sampleStatus = SampleStatusPlaying;
}

- (void)sampleViewDownloading {
    [self.sampleView setAlpha:1.0];
    [self.indicatorSample startAnimating];
    [self.playingView setHidden:YES];
    sampleStatus = SampleStatusDownloading;
}

- (void)sampleViewStop {
    [self.sampleView setAlpha:0.0];
    [self.indicatorSample stopAnimating];
    [self.playingView setHidden:YES];
    sampleStatus = SampleStatusIdle;
}

- (void)finishBgm:(id)finishBgm {
    [self sampleStop];
}

#pragma mark - DownloaderDelegate

- (void)downloaderProceed:(Downloader *)downloader {
    // Intentionally empty.
}

- (void)downloaderFinished:(Downloader *)downloader {
    if (self.sampleDownloader == downloader) {
        if (sampleStatus == SampleStatusDownloading) {
            NSData *data = self.sampleDownloader.getData;
            [[RBBGMManager getInstance] LoadMusicWithPush:data Loop:YES];
            [[RBBGMManager getInstance] PlayMusic:0.0];
            [self sampleViewPlaying];
            self.samplePlayedIndex = 1;
        }
        self.sampleDownloader = nil;
    }
}

- (void)downloaderError:(Downloader *)downloader {
    if (self.sampleDownloader == downloader) {
        [self sampleStop];
        self.sampleDownloader = nil;
        [UIAlertView showNetworkErrorWithDelegate:nil];
    }
}

#pragma mark - UIAlertViewDelegate

- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex {
    // Intentionally empty.
}

- (void)alertView:(UIAlertView *)alertView didDismissWithButtonIndex:(NSInteger)buttonIndex {
    if (!_closingFlag && [self.delegate respondsToSelector:@selector(detailViewClose)]) {
        [self.delegate performSelector:@selector(detailViewClose)];
    }
}

- (void)alertView:(UIAlertView *)alertView willDismissWithButtonIndex:(NSInteger)buttonIndex {
    // Intentionally empty.
}

- (void)alertViewCancel:(UIAlertView *)alertView {
    if (_closingFlag && [self.delegate respondsToSelector:@selector(detailViewClose)]) {
        [self.delegate performSelector:@selector(detailViewClose)];
    }
}

- (void)didPresentAlertView:(UIAlertView *)alertView {
    UIView *presentedView =
        [UIApplication sharedApplication].keyWindow.rootViewController.presentedViewController.view;
    [UIAlertView setExclusiveTouchForView:presentedView];
}

#pragma mark - Artwork downloads

- (void)stopDownloadArtworks {
    if (self.artworkDownloaders.count != 0) {
        for (ImageDownloader *downloader in self.artworkDownloaders.objectEnumerator) {
            [downloader cancelDownload];
            [downloader setDelegate:nil];
        }
        [self.artworkDownloaders removeAllObjects];
    }
}

@end
