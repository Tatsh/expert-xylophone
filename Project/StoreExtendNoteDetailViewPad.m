#import "StoreExtendNoteDetailViewPad.h"

#import <QuartzCore/QuartzCore.h>

#import "Downloader.h"
#import "RBBGMManager.h"
#import "RBMusicManager.h"
#import "StoreButtonView.h"
#import "StoreExtendNoteInfo.h"
#import "StoreImageView.h"
#import "UIAlertView+RB.h"
#import "UIImage+RB.h"
#import "deviceenvironment.h"
#import "engineglobals.h"

// @ghidraAddress 0x3cfca8

extern const double g_dMascotMessageMaxWidthPad;   // @ghidraAddress 0x2ee930 (300.0)
extern const double g_dMascotMessageMaxWidthPhone; // @ghidraAddress 0x2ee938 (200.0)
extern const double g_dLayoutMetricThirtyTwo;      // @ghidraAddress 0x2ee9b0 (32.0)

static NSString *const kStorePackBgImageName = @"09_store/store_pack_bg_2";
static NSString *const kStoreSampleStoppedImageName = @"09_store/store_sample_1";
static NSString *const kStoreSamplePlayingImageName = @"09_store/store_sample_2";
static NSString *const kStoreJacketPlaceholderImageName = @"09_store/store_jacket_110";

static const int kNoCampaign = -1;

static const double kCardWidth = 650.0;                   // @ghidraAddress 0x2eec30
static const double kCardHeight = 284.0;                  // @ghidraAddress 0x2eec38
static const double kTitleBarHeight = 44.0;               // @ghidraAddress 0x2eec40
static const double kTextColumnWidth = 420.0;             // @ghidraAddress 0x2eec60
static const double kButtonRowY = 234.0;                  // @ghidraAddress 0x2eec98
static const double kButtonWidth = 160.0;                 // @ghidraAddress 0x2eea38
static const double kCopyrightHeight = 40.0;              // @ghidraAddress 0x2ee950
static const double kDetailScrollHeight = 366.0;          // @ghidraAddress 0x2eecb0
static const double kDescriptionWidth = 630.0;            // @ghidraAddress 0x2ee978
static const double kDescriptionHeight = 316.0;           // @ghidraAddress 0x2ee928
static const double kCopyrightOriginY = 316.0;            // @ghidraAddress 0x2ee928
static const double kArtworkSideNarrow = 64.0;            // @ghidraAddress 0x2eecd8
static const double kArtworkSideWide = 110.0;             // @ghidraAddress 0x2eece0
static const double kArtworkFadeDuration = 0.2;           // @ghidraAddress 0x2eece8
static const double kArtworkShadowOpacity = 0.6;          // @ghidraAddress 0x2ec6b8
static const double kDetailBorderWhite = 143.0f / 255.0f; // @ghidraAddress 0x2ec730
static const double kLoadingShadowAlpha = 0.4;            // @ghidraAddress 0x2ec720
static const double kLevelColorRed = 85.0 / 255.0;        // @ghidraAddress 0x2eec78
static const double kLevelColorGreen = 9.0f / 255.0f;     // @ghidraAddress 0x2eec80
static const double kLevelColorBlue = 120.0 / 255.0;      // @ghidraAddress 0x2eec88
static const double kBackgroundDimWhite = 0.863f;         // @ghidraAddress 0x2eecd0
// Single-precision in the binary.
static const double kTermBarWhite = 0.90000003576278687;
static const double kLoadingTextWhite = 0.19999998807907104;

typedef enum {
    StoreSampleStatusStopped = 0,
    StoreSampleStatusDownloading = 1,
    StoreSampleStatusPlaying = 2,
} StoreSampleStatus;

@implementation StoreExtendNoteDetailViewPad {
    // buttonType, bUnlock, and hideType are unused.
    StoreSampleStatus sampleStatus;
    int buttonType;
    BOOL bUnlock;
    int hideType;
}

#pragma mark - Construction

/** @ghidraAddress 0x22068 */
- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (!self) {
        return self;
    }

    if ([[UIScreen mainScreen] respondsToSelector:@selector(scale)] &&
        [self respondsToSelector:@selector(contentScaleFactor)]) {
        [self setContentScaleFactor:[[UIScreen mainScreen] scale]];
    }
    [self setUserInteractionEnabled:YES];
    [self setOpaque:YES];
    self.layer.shadowRadius = 8.0;
    self.layer.shadowOffset = CGSizeZero;
    self.layer.shadowOpacity = 0.5;
    self.layer.shouldRasterize = YES;
    [self setBackgroundColor:UIColor.grayColor];

    UIImage *packBg = [UIImage imageWithName:kStorePackBgImageName];
    const BOOL isWide = IsPad();

    self.noteView = [[UIView alloc] initWithFrame:CGRectMake(0.0, 0.0, kCardWidth, kCardHeight)];

    UIImageView *noteBg =
        [[UIImageView alloc] initWithFrame:CGRectMake(0.0, 0.0, kCardWidth, kCardHeight)];
    [noteBg setImage:[packBg stretchableImageWithLeftCapWidth:4 topCapHeight:4]];
    [self.noteView addSubview:noteBg];

    // The strip spans the card, not the panel. @ghidraAddress 0x2248c
    UIView *card = [[UIView alloc]
        initWithFrame:CGRectMake(0.0, 0.0, self.bounds.size.width, kTitleBarHeight)];
    [card setBackgroundColor:UIColor.whiteColor];
    card.layer.shadowOffset = CGSizeMake(0.0, 1.0);
    card.layer.shadowOpacity = 0.5;
    card.layer.shadowRadius = 1.0;

    self.labelTitle = [[UILabel alloc]
        initWithFrame:CGRectMake(10.0, 0.0, self.bounds.size.width - 20.0, kTitleBarHeight)];
    [self.labelTitle setBackgroundColor:UIColor.clearColor];
    [self.labelTitle setFont:[UIFont boldSystemFontOfSize:18.0]];
    [self.labelTitle setTextColor:UIColor.blackColor];
    [self.labelTitle setTextAlignment:NSTextAlignmentCenter];
    [self.labelTitle setAdjustsFontSizeToFitWidth:YES];
    [card addSubview:self.labelTitle];
    [self.noteView addSubview:card];

    self.artworkView =
        [[StoreImageView alloc] initWithFrame:CGRectMake(18.0, 79.0, kButtonWidth, kButtonWidth)];
    self.artworkView.layer.borderWidth = 1.0;
    self.artworkView.layer.borderColor = UIColor.whiteColor.CGColor;
    [self.artworkView setBackgroundColor:UIColor.whiteColor];
    self.artworkView.layer.shadowOffset = CGSizeMake(2.0, 2.0);
    self.artworkView.layer.shadowColor = UIColor.blackColor.CGColor;
    self.artworkView.layer.shadowOpacity = (float)kArtworkShadowOpacity;
    self.artworkView.layer.shadowRadius = 2.0;
    self.artworkView.layer.shouldRasterize = YES;
    [self.noteView addSubview:self.artworkView];

    self.labelMusicName =
        [[UILabel alloc] initWithFrame:CGRectMake(195.0, 76.0, kTextColumnWidth, 28.0)];
    [self.labelMusicName setBackgroundColor:UIColor.clearColor];
    [self.labelMusicName setFont:[UIFont boldSystemFontOfSize:22.0]];
    [self.labelMusicName setAdjustsFontSizeToFitWidth:YES];
    [self.labelMusicName setMinimumScaleFactor:18.0]; // Yes, the binary passes 18.0 here.
    [self.noteView addSubview:self.labelMusicName];

    self.labelArtistName =
        [[UILabel alloc] initWithFrame:CGRectMake(195.0, 108.0, kTextColumnWidth, 28.0)];
    [self.labelArtistName setBackgroundColor:UIColor.clearColor];
    [self.labelArtistName setFont:[UIFont systemFontOfSize:18.0]];
    [self.labelArtistName setAdjustsFontSizeToFitWidth:YES];
    [self.labelArtistName setMinimumScaleFactor:18.0];
    [self.noteView addSubview:self.labelArtistName];

    self.labelLevel =
        [[UILabel alloc] initWithFrame:CGRectMake(195.0, 172.0, kTextColumnWidth, 28.0)];
    [self.labelLevel setBackgroundColor:UIColor.clearColor];
    [self.labelLevel setFont:[UIFont boldSystemFontOfSize:20.0]];
    [self.labelLevel setAdjustsFontSizeToFitWidth:YES];
    [self.labelLevel setMinimumScaleFactor:18.0];
    if (isWide) {
        [self.labelLevel setTextColor:[UIColor colorWithRed:kLevelColorRed
                                                      green:kLevelColorGreen
                                                       blue:kLevelColorBlue
                                                      alpha:1.0]];
    }
    [self.noteView addSubview:self.labelLevel];

    const double buttonFontSize = isWide ? 18.0 : 10.0;

    self.downloadBtn =
        [[StoreButtonView alloc] initWithFrame:CGRectMake(470.0, kButtonRowY, kButtonWidth, 30.0)];
    [self.downloadBtn setDisabledColor:[UIColor colorWithWhite:g_dRBWebViewGrayViewWhite
                                                         alpha:1.0]];
    [self.downloadBtn setCornerRadius:4.0];
    [self.downloadBtn setExclusiveTouch:YES];
    [self.downloadBtn.titleLabel setFont:[UIFont boldSystemFontOfSize:buttonFontSize]];
    [self.downloadBtn setTitle:@"" forState:UIControlStateNormal];
    [self.downloadBtn addTarget:self.delegate
                         action:@selector(pushCellButton:)
               forControlEvents:UIControlEventTouchUpInside];
    [self.noteView addSubview:self.downloadBtn];

    self.linkBtn = [[StoreButtonView alloc]
        initWithFrame:CGRectMake(g_dMascotMessageMaxWidthPad, kButtonRowY, kButtonWidth, 30.0)];
    [self.linkBtn setDisabledColor:[UIColor colorWithWhite:g_dRBWebViewGrayViewWhite alpha:1.0]];
    [self.linkBtn setButtonColor:[UIColor colorWithRed:g_dTranslucentAlpha
                                                 green:g_dAudioManagerResumeFadeInTime
                                                  blue:g_dTranslucentAlpha
                                                 alpha:1.0]];
    [self.linkBtn setCornerRadius:4.0];
    [self.linkBtn setExclusiveTouch:YES];
    [self.linkBtn.titleLabel setFont:[UIFont boldSystemFontOfSize:buttonFontSize]];
    [self.linkBtn setTitle:@"16歳未満" forState:UIControlStateNormal];
    [self.linkBtn addTarget:self
                     action:@selector(pushLink:)
           forControlEvents:UIControlEventTouchUpInside];
    [self.noteView addSubview:self.linkBtn];

    self.sampleBtn = [UIButton buttonWithType:UIButtonTypeCustom];
    [self.sampleBtn setFrame:CGRectMake(595.0, 172.0, g_dLayoutMetricThirtyTwo, 35.0)];
    [self.sampleBtn setContentMode:UIViewContentModeCenter];
    [self.sampleBtn setImage:[UIImage imageWithName:kStoreSampleStoppedImageName]
                    forState:UIControlStateNormal];
    [self.sampleBtn addTarget:self
                       action:@selector(pushSampleBtn)
             forControlEvents:UIControlEventTouchUpInside];

    self.indicatorSample =
        [[UIActivityIndicatorView alloc] initWithFrame:CGRectMake(0.0, 0.0, 20.0, 20.0)];
    [self.indicatorSample setCenter:CGPointMake(CGRectGetWidth(self.sampleBtn.frame) * 0.5,
                                                CGRectGetHeight(self.sampleBtn.frame) * 0.5)];
    [self.indicatorSample setActivityIndicatorViewStyle:UIActivityIndicatorViewStyleGray];
    [self.indicatorSample setHidesWhenStopped:YES];
    [self.sampleBtn addSubview:self.indicatorSample];
    [self.noteView addSubview:self.sampleBtn];
    [self addSubview:self.noteView];

    self.detailView = [[UIScrollView alloc]
        initWithFrame:CGRectMake(0.0, kCardHeight, kCardWidth, kDetailScrollHeight)];
    [self.detailView setOpaque:YES];
    [self.detailView setScrollEnabled:YES];
    [self.detailView setDecelerationRate:UIScrollViewDecelerationRateFast];
    [self.detailView setBouncesZoom:NO];
    self.detailView.layer.borderColor =
        [UIColor colorWithWhite:kDetailBorderWhite alpha:1.0].CGColor;

    self.bannerView = [[StoreImageView alloc] initWithFrame:CGRectZero];
    self.bannerView.layer.shouldRasterize = YES;
    self.bannerView.layer.cornerRadius = 8.0;
    [self.bannerView setClipsToBounds:YES];
    [self.detailView addSubview:self.bannerView];

    self.descriptionTextView =
        [[UITextView alloc] initWithFrame:CGRectMake(10.0,
                                                     self.bannerView.frame.size.height + 10.0,
                                                     kDescriptionWidth,
                                                     kDescriptionHeight)];
    [self.descriptionTextView setBackgroundColor:UIColor.clearColor];
    [self.descriptionTextView setEditable:NO];
    [self.descriptionTextView setSelectable:NO];
    [self.descriptionTextView setScrollEnabled:NO];
    [self.descriptionTextView setFont:[UIFont systemFontOfSize:18.0]];
    [self.detailView addSubview:self.descriptionTextView];

    self.copyrightView = [[UITextView alloc]
        initWithFrame:CGRectMake(10.0, kCopyrightOriginY, kDescriptionWidth, kCopyrightHeight)];
    [self.copyrightView setBackgroundColor:UIColor.clearColor];
    [self.copyrightView setEditable:NO];
    [self.copyrightView setFont:[UIFont systemFontOfSize:16.0]];
    [self.detailView addSubview:self.copyrightView];
    [self addSubview:self.detailView];

    [self removeNoteInfo];

    self.indicator = [[UIActivityIndicatorView alloc]
        initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleWhite];
    [self.indicator setFrame:CGRectMake(0.0, 0.0, 24.0, 24.0)];
    [self.indicator setCenter:CGPointMake(CGRectGetWidth(self.frame) * 0.5,
                                          CGRectGetHeight(self.frame) * 0.5 - 15.0)];

    self.labelLoading =
        [[UILabel alloc] initWithFrame:CGRectMake(0.0, 0.0, g_dMascotMessageMaxWidthPhone, 24.0)];
    [self.labelLoading setBackgroundColor:UIColor.clearColor];
    [self.labelLoading setFont:[UIFont boldSystemFontOfSize:18.0]];
    [self.labelLoading setTextColor:[UIColor colorWithWhite:kLoadingTextWhite alpha:1.0]];
    [self.labelLoading setShadowColor:[UIColor colorWithWhite:0.0 alpha:kLoadingShadowAlpha]];
    [self.labelLoading setShadowOffset:CGSizeMake(0.0, -1.0)];
    [self.labelLoading setTextAlignment:NSTextAlignmentCenter];
    [self.labelLoading setText:g_pLocalizedLoadingMixed];
    [self.labelLoading setCenter:CGPointMake(CGRectGetWidth(self.frame) * 0.5,
                                             CGRectGetHeight(self.frame) * 0.5 + 15.0)];
    sampleStatus = StoreSampleStatusStopped;

    UIView *termBar = [[UIView alloc] initWithFrame:CGRectMake(0.0, kCardWidth, kCardWidth, 30.0)];
    [termBar setBackgroundColor:[UIColor colorWithWhite:kTermBarWhite alpha:1.0]];
    [self addSubview:termBar];

    UILabel *termLabel =
        [[UILabel alloc] initWithFrame:CGRectMake(10.0, 0.0, kDescriptionWidth, 30.0)];
    [termLabel setFont:[UIFont systemFontOfSize:12.0]];
    [termLabel setTextAlignment:NSTextAlignmentRight];
    [termLabel setText:@"規約等および各種注意事項"];
    [termLabel setTextColor:[UIColor colorWithRed:0.0 green:0.5 blue:1.0 alpha:1.0]];
    [termLabel setUserInteractionEnabled:YES];
    UITapGestureRecognizer *termTap =
        [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(showTerm)];
    [termLabel addGestureRecognizer:termTap];
    [termBar addSubview:termLabel];

    return self;
}

/** @ghidraAddress 0x271bc */
- (void)dealloc {
}

#pragma mark - Note loading

/** @ghidraAddress 0x2600c */
- (void)setInfo:(StoreExtendNoteInfo *)info {
    if (!info) {
        [self.labelMusicName setText:nil];
        [self.labelArtistName setText:nil];
        [self.labelLevel setText:nil];
        [self.artworkView setImage:[UIImage imageWithName:kStoreJacketPlaceholderImageName]];
        return;
    }
    self.noteInfo = info;
    [self.artworkView setImage:nil];
    self.artworkView.imageURL = info.artworkURL;
    [self.labelMusicName setText:info.name];
    [self.labelArtistName setText:info.artist];
    [self.labelLevel setText:[NSString stringWithFormat:@"LEVEL %d", info.difficulty]];
    [self.descriptionTextView setText:info.comment];
    [self selfCheckButtonText];
}

/** @ghidraAddress 0x2563c */
- (void)showNoteInfo {
    [self setBackgroundColor:[UIColor colorWithWhite:kBackgroundDimWhite alpha:1.0]];
    [self.artworkView setImage:nil];
    [self.downloadBtn setHidden:NO];
    if (self.noteInfo.linkURL) {
        [self.linkBtn setHidden:NO];
    }
    [self.noteView setHidden:NO];
    [self.detailView setHidden:NO];
    [self.artworkView startDownloadImage];
}

/** @ghidraAddress 0x24b78 */
- (void)removeNoteInfo {
    self.noteInfo = nil;
    [self setBackgroundColor:UIColor.grayColor];
    self.artworkView.imageURL = nil;
    [self.labelMusicName setText:nil];
    [self.labelArtistName setText:nil];
    [self.labelLevel setText:nil];
    [self.copyrightView setText:nil];
    [self.downloadBtn setHidden:YES];
    [self.linkBtn setHidden:YES];
    self.campaignID = kNoCampaign;
    [self.noteView setHidden:YES];
    [self.detailView setHidden:YES];
    if (self.sampleDownloader) {
        [self.sampleDownloader cancel];
        self.sampleDownloader = nil;
    }
    [self stopSample];
    if (self.indicator) {
        [self.indicator stopAnimating];
        [self.indicator removeFromSuperview];
    }
    if (self.labelLoading) {
        [self.labelLoading removeFromSuperview];
    }
    sampleStatus = StoreSampleStatusStopped;
}

/** @ghidraAddress 0x24f68 */
- (void)cancelLoading {
}

#pragma mark - Sample playback

/** @ghidraAddress 0x24f6c */
- (void)stopSample {
    if ([[RBBGMManager getInstance] isPushMusic]) {
        [[RBBGMManager getInstance] StopMusic:g_flFlashMinOpacity];
        [[RBBGMManager getInstance] popMusic];
    }
    if (self.sampleDownloader) {
        [self.sampleDownloader cancel];
        self.sampleDownloader = nil;
    }
    [self sampleViewStop];
}

/** @ghidraAddress 0x250d4 */
- (void)pushSampleBtn {
    switch (sampleStatus) {
    case StoreSampleStatusStopped: {
        self.sampleDownloader =
            [[Downloader alloc] initWithURL:[NSURL URLWithString:self.noteInfo.sampleURL] save:nil];
        [self.sampleDownloader startDownloadingWithDelegate:self];
        [self sampleViewDownloading];
        break;
    }
    case StoreSampleStatusDownloading:
    case StoreSampleStatusPlaying: {
        if (self.sampleDownloader) {
            [self.sampleDownloader cancel];
            self.sampleDownloader = nil;
        }
        [self stopSample];
        break;
    }
    }
}

/** @ghidraAddress 0x2534c */
- (void)sampleViewStop {
    [self.indicatorSample stopAnimating];
    [self.sampleBtn setImage:[UIImage imageWithName:kStoreSampleStoppedImageName]
                    forState:UIControlStateNormal];
    sampleStatus = StoreSampleStatusStopped;
}

/** @ghidraAddress 0x25444 */
- (void)sampleViewDownloading {
    [self.indicatorSample startAnimating];
    [self.sampleBtn setImage:[UIImage imageWithName:kStoreSampleStoppedImageName]
                    forState:UIControlStateNormal];
    sampleStatus = StoreSampleStatusDownloading;
}

/** @ghidraAddress 0x25540 */
- (void)sampleViewPlaying {
    [self.indicatorSample stopAnimating];
    [self.sampleBtn setImage:[UIImage imageWithName:kStoreSamplePlayingImageName]
                    forState:UIControlStateNormal];
    sampleStatus = StoreSampleStatusPlaying;
}

/** @ghidraAddress 0x259c4 */
- (void)finishBgm:(id)finishBgm {
    [self stopSample];
}

#pragma mark - Action button

/** @ghidraAddress 0x26824 */
- (void)setButtonTextInstalling {
    [self.downloadBtn setTitle:g_pLocalizedInstalling forState:UIControlStateNormal];
    [self.downloadBtn setEnabled:YES];
}

/** @ghidraAddress 0x268d4 */
- (void)setButtonTextInstalled {
    [self.downloadBtn setTitle:g_pLocalizedInstalled forState:UIControlStateDisabled];
    [self.downloadBtn setEnabled:NO];
}

/** @ghidraAddress 0x26984 */
- (void)selfCheckButtonText {
    [self.downloadBtn setEnabled:YES];
    [self.downloadBtn setButtonColor:[self.noteInfo getButtonColor]];
    [self.downloadBtn setTitle:[self.noteInfo getButtonName] forState:UIControlStateNormal];
    [self.downloadBtn
        setEnabled:[self.noteInfo getButtonState] < StoreExtendNoteButtonStateInstalled];
}

/** @ghidraAddress 0x26424 */
- (void)setDownloadFlag:(BOOL)downloadFlag {
}

#pragma mark - Purchase state

/** @ghidraAddress 0x26428 */
- (BOOL)hasItem:(int)hasItem itemID:(int)itemID {
    if (hasItem != 0) {
        return NO;
    }
    if (![[RBMusicManager getInstance] getMusicData:itemID]) {
        return NO;
    }
    NSString *path = [RBMusicManager getPathFromPurchesed:itemID];
    return [[NSFileManager defaultManager] fileExistsAtPath:path];
}

#pragma mark - Artwork

/** @ghidraAddress 0x2655c */
- (void)setArtwork:(UIImage *)artwork {
    if (!artwork) {
        return;
    }
    if (artwork.size.width == artwork.size.height) {
        const BOOL isWide = IsPad();
        CGSize margin = [self getArtworkMargin:(IsPad())];
        const double topInset = isWide ? 0.0 : 2.0;
        const double side = isWide ? kArtworkSideWide : kArtworkSideNarrow;
        [self.artworkView setFrame:CGRectMake(margin.width, margin.height - topInset, side, side)];
    } else {
        CGSize itemSize = [self getItemSize:(IsPad())];
        [self.artworkView setFrame:CGRectMake(0.0, 0.0, itemSize.width, itemSize.height)];
    }
    [self.artworkView setImage:artwork];
    __weak StoreExtendNoteDetailViewPad *weakSelf = self;
    [UIView animateWithDuration:kArtworkFadeDuration
                     animations:^{
                       /** @ghidraAddress 0x267b4 */
                       [weakSelf.artworkView setAlpha:1.0];
                     }
                     completion:nil];
}

/** @ghidraAddress 0x2653c */
- (CGSize)getArtworkMargin:(BOOL)getArtworkMargin {
    return CGSizeMake(12.0, 10.0);
}

/** @ghidraAddress 0x26548 */
- (CGSize)getItemSize:(BOOL)getItemSize {
    return CGSizeMake(kCardWidth, kCardHeight);
}

#pragma mark - Delegate notifications

/** @ghidraAddress 0x25860 */
- (void)pushCellButton:(id)pushCellButton {
    if ([self.delegate respondsToSelector:@selector(selectButton:)]) {
        [self.delegate performSelector:@selector(selectButton:) withObject:@(self.noteInfo.pid)];
    }
}

/** @ghidraAddress 0x2585c */
- (void)pushLink:(id)pushLink {
}

/** @ghidraAddress 0x259e0 */
- (void)showTerm {
    if ([self.delegate respondsToSelector:@selector(showTerms)]) {
        [self.delegate performSelector:@selector(showTerms)];
    }
}

#pragma mark - DownloaderDelegate

/** @ghidraAddress 0x25ab0 */
- (void)downloaderFinished:(Downloader *)downloaderFinished {
    if (self.sampleDownloader != downloaderFinished) {
        return;
    }
    if (sampleStatus == StoreSampleStatusDownloading) {
        [[RBBGMManager getInstance] LoadMusicWithPush:[self.sampleDownloader getData] Loop:YES];
        [[RBBGMManager getInstance] PlayMusic:0.0f];
        [self sampleViewPlaying];
    }
    self.sampleDownloader = nil;
}

/** @ghidraAddress 0x25c50 */
- (void)downloaderError:(Downloader *)downloaderError {
    if (self.sampleDownloader != downloaderError) {
        return;
    }
    [self stopSample];
    self.sampleDownloader = nil;
    [UIAlertView showNetworkErrorWithDelegate:nil];
}

/** @ghidraAddress 0x25d08 */
- (void)downloaderProceed:(Downloader *)downloaderProceed {
}

#pragma mark - UIAlertViewDelegate

/** @ghidraAddress 0x25d0c */
- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)clickedButtonAtIndex {
    if ([self.delegate respondsToSelector:@selector(detailViewClose)]) {
        [self.delegate performSelector:@selector(detailViewClose)];
    }
}

/** @ghidraAddress 0x25de8 */
- (void)alertView:(UIAlertView *)alertView
    didDismissWithButtonIndex:(NSInteger)didDismissWithButtonIndex {
}

/** @ghidraAddress 0x25dec */
- (void)alertView:(UIAlertView *)alertView
    willDismissWithButtonIndex:(NSInteger)willDismissWithButtonIndex {
}

/** @ghidraAddress 0x25df0 */
- (void)alertViewCancel:(UIAlertView *)alertViewCancel {
    if ([self.delegate respondsToSelector:@selector(detailViewClose)]) {
        [self.delegate performSelector:@selector(detailViewClose)];
    }
}

/** @ghidraAddress 0x25ecc */
- (void)didPresentAlertView:(UIAlertView *)didPresentAlertView {
    [UIAlertView setExclusiveTouchForView:[[[[[UIApplication sharedApplication] keyWindow]
                                              rootViewController] presentedViewController] view]];
}

@end
