#import "StorePackDetailViewPad.h"

#import "AppDelegate.h"
#import "Downloader.h"
#import "RBBGMManager.h"
#import "RBPurchaseManager.h"
#import "StoreImageView.h"
#import "StoreMusicInfo.h"
#import "StorePackInfo.h"
#import "StorePackInfoDownloader.h"
#import "StorePackMusicView.h"
#import "StoreUtil.h"
#import "UIAlertView+RB.h"
#import "UIImage+RB.h"
#import "neEngineBridge.h"

// The localised store-loading title, reused from the store page. @ghidraAddress 0x3cfca8.
extern NSString *const g_pStoreLoadingTitle;

// The number of tune rows the panel always lays out, matching the pack tune-slot count.
static const NSInteger kMusicRowCount = 4;

// The sentinel stored in the playing-tune index when no sample is playing.
static const int kNoSamplePlaying = -1;

// The two tune rows per layout column, so a row's column is its index modulo this.
static const NSInteger kMusicRowsPerColumn = 2;

// Image asset names.
static NSString *const kStorePackBgImageName = @"09_store/store_pack_bg_2";
static NSString *const kStoreButtonNormalImageName = @"09_store/store_btn_normal_2";
static NSString *const kStoreButtonClickedImageName = @"09_store/store_btn_clicked_2";
static NSString *const kStoreButtonDisabledImageName = @"09_store/store_btn_disabled";
static NSString *const kStoreWebButtonImageName = @"09_store/store_web";

// The terms-and-precautions label, a fixed Japanese literal decoded from the binary's UTF-16 data.
// @ghidraAddress 0x358e20
static NSString *const kTermLabelText = @"規約等および各種注意事項";

// The buy-button title format ("BUY (%@)" catalogue key with one price argument).
// @ghidraAddress 0x3cfb78; reached through the engine bridge global.
// (See g_pLocalizedBuyFormat in neEngineBridge.h.)

// Container geometry (in points).
static const CGFloat kPackViewWidth = 650.0;
static const CGFloat kPackViewHeight = 226.0;

// Jacket artwork frame.
static const CGFloat kArtworkOriginX = 18.0;
static const CGFloat kArtworkOriginY = 35.0;
static const CGFloat kArtworkSide = 160.0;

// Pack name label frame.
static const CGFloat kNameOriginX = 195.0;
static const CGFloat kNameOriginY = 32.0;
static const CGFloat kNameHeight = 28.0;

// Pack comment label frame.
static const CGFloat kCommentOriginY = 76.0;
static const CGFloat kSideLabelWidth = 420.0;
static const CGFloat kCommentHeight = 90.0;

// Copyright text-view frame.
static const CGFloat kCopyrightOriginX = 157.0;
static const CGFloat kCopyrightOriginY = 167.0;
static const CGFloat kCopyrightWidth = 220.0;
static const CGFloat kCopyrightHeight = 50.0;

// Purchase button frame.
static const CGFloat kButtonOriginX = 480.0;
static const CGFloat kButtonOriginY = 167.0;
static const CGFloat kButtonWidth = 140.0;
static const CGFloat kButtonHeight = 30.0;

// Tune-row layout (in points): each row is a fixed-size tile, stepped horizontally per column and
// vertically per row-pair from a fixed top offset.
static const CGFloat kMusicRowStepX = 325.0;
static const CGFloat kMusicRowStepY = 212.0;
static const CGFloat kMusicRowTopOffset = 226.0;
static const CGFloat kMusicRowWidth = 325.0;
static const CGFloat kMusicRowHeight = 212.0;

// Web (artist-site) button vertical origin and its right-aligned x anchor.
static const CGFloat kWebButtonOriginY = 12.0;
static const CGFloat kWebButtonRightAnchor = 630.0;

// Loading label width, height, and the vertical offsets of the spinner and loading label about the
// panel centre.
static const CGFloat kLoadingLabelWidth = 200.0;
static const CGFloat kLoadingLabelHeight = 24.0;
static const CGFloat kIndicatorCentreYOffset = -15.0;
static const CGFloat kLoadingLabelCentreYOffset = 15.0;

// The bottom copyright-strip label frame and its font.
static const CGFloat kTermStripOriginX = 10.0;
static const CGFloat kTermLabelFontSize = 12.0;

// Stretchable-image cap sizes.
static const NSInteger kPackBgCap = 4;
static const NSInteger kButtonBgCap = 6;

// Font point sizes.
static const CGFloat kNameFontSize = 22.0;
static const CGFloat kCommentFontSize = 13.0;
static const CGFloat kCopyrightFontSize = 10.0;
static const CGFloat kButtonTitleFontSize = 16.0;
static const CGFloat kLoadingLabelFontSize = 18.0;

// Name-label auto-shrink minimum scale factor.
static const CGFloat kNameMinimumScaleFactor = 18.0;

// Shadow and layer parameters.
static const CGFloat kPanelShadowRadius = 8.0;
static const CGFloat kPanelShadowOpacity = 0.5;
static const CGFloat kArtworkBorderWidth = 1.0;
static const CGFloat kArtworkShadowOffset = 2.0;
static const CGFloat kArtworkShadowRadius = 2.0;
static const CGFloat kArtworkShadowOpacity = 0.6;
static const CGFloat kTitleShadowOffsetY = -1.0;

// White / alpha colour components.
static const CGFloat kCommentTextWhite = 0.19607843458652496;
static const CGFloat kDisabledTitleWhite = 0.6196078658103943;
static const CGFloat kLoadedBackgroundWhite = 0.8629999756813049;
static const CGFloat kTermStripBackgroundWhite = 0.8629999756813049;
static const CGFloat kLoadingShadowAlpha = 0.4000000059604645;
static const CGFloat kTermLinkGreenBlue = 0.47843137254901963;

// The purchase-button title-shadow alpha, shared for the normal and disabled states.
static const CGFloat kButtonTitleShadowAlpha = 0.6000000238418579;

// The centre-scaling divisor used to place the spinner and loading label at the panel centre.
static const CGFloat kCentreScale = 0.5;

@implementation StorePackDetailViewPad {
    // The index of the tune whose sample is currently playing, or @c kNoSamplePlaying (-1) when none
    // is. This ivar has no property and keeps the binary's literal name (no leading underscore).
    int samplePlaying;
    // Whether @c showPackInfo has already populated the subviews. This ivar has no property and
    // keeps the binary's literal name (no leading underscore).
    BOOL isInfoLoaded;
}

#pragma mark - Initialisation

/** @ghidraAddress 0xf5cb8 */
- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self == nil) {
        return nil;
    }
    if ([[UIScreen mainScreen] respondsToSelector:@selector(scale)] &&
        [self respondsToSelector:@selector(contentScaleFactor)]) {
        self.contentScaleFactor = [UIScreen mainScreen].scale;
    }
    self.userInteractionEnabled = YES;
    self.opaque = YES;
    self.layer.shadowRadius = kPanelShadowRadius;
    self.layer.shadowOffset = CGSizeZero;
    self.layer.shadowOpacity = kPanelShadowOpacity;
    self.layer.shouldRasterize = YES;
    self.backgroundColor = UIColor.grayColor;

    UIImage *packBg = [UIImage imageWithName:kStorePackBgImageName];
    self.packView =
        [[UIView alloc] initWithFrame:CGRectMake(0.0, 0.0, kPackViewWidth, kPackViewHeight)];
    UIImageView *packBgView =
        [[UIImageView alloc] initWithFrame:CGRectMake(0.0, 0.0, kPackViewWidth, kPackViewHeight)];
    packBgView.image = [packBg stretchableImageWithLeftCapWidth:kPackBgCap topCapHeight:kPackBgCap];
    [self.packView addSubview:packBgView];

    self.packArtworkView = [[StoreImageView alloc]
        initWithFrame:CGRectMake(kArtworkOriginX, kArtworkOriginY, kArtworkSide, kArtworkSide)];
    self.packArtworkView.layer.borderWidth = kArtworkBorderWidth;
    self.packArtworkView.layer.borderColor = UIColor.whiteColor.CGColor;
    self.packArtworkView.backgroundColor = UIColor.whiteColor;
    self.packArtworkView.layer.shadowOffset =
        CGSizeMake(kArtworkShadowOffset, kArtworkShadowOffset);
    self.packArtworkView.layer.shadowColor = UIColor.blackColor.CGColor;
    self.packArtworkView.layer.shadowOpacity = kArtworkShadowOpacity;
    self.packArtworkView.layer.shadowRadius = kArtworkShadowRadius;
    self.packArtworkView.layer.shouldRasterize = YES;
    [self.packView addSubview:self.packArtworkView];

    self.labelPackName = [[UILabel alloc]
        initWithFrame:CGRectMake(kNameOriginX, kNameOriginY, kSideLabelWidth, kNameHeight)];
    self.labelPackName.backgroundColor = UIColor.clearColor;
    self.labelPackName.font = [UIFont boldSystemFontOfSize:kNameFontSize];
    self.labelPackName.adjustsFontSizeToFitWidth = YES;
    self.labelPackName.minimumScaleFactor = kNameMinimumScaleFactor;
    [self.packView addSubview:self.labelPackName];

    self.labelComment = [[UILabel alloc]
        initWithFrame:CGRectMake(kNameOriginX, kCommentOriginY, kSideLabelWidth, kCommentHeight)];
    self.labelComment.backgroundColor = UIColor.clearColor;
    self.labelComment.numberOfLines = 0;
    self.labelComment.baselineAdjustment = UIBaselineAdjustmentNone;
    self.labelComment.font = [UIFont systemFontOfSize:kCommentFontSize];
    self.labelComment.textColor = [UIColor colorWithWhite:kCommentTextWhite alpha:1.0];
    [self.packView addSubview:self.labelComment];

    self.copyrightView = [[UITextView alloc]
        initWithFrame:CGRectMake(
                          kCopyrightOriginX, kCopyrightOriginY, kCopyrightWidth, kCopyrightHeight)];
    self.copyrightView.backgroundColor = UIColor.clearColor;
    self.copyrightView.editable = NO;
    self.copyrightView.font = [UIFont systemFontOfSize:kCopyrightFontSize];
    [self.packView addSubview:self.copyrightView];

    self.buttonPurchase = [UIButton buttonWithType:UIButtonTypeCustom];
    self.buttonPurchase.frame =
        CGRectMake(kButtonOriginX, kButtonOriginY, kButtonWidth, kButtonHeight);
    UIImage *buttonNormal = [[UIImage imageWithName:kStoreButtonNormalImageName]
        stretchableImageWithLeftCapWidth:kButtonBgCap
                            topCapHeight:kButtonBgCap];
    [self.buttonPurchase setBackgroundImage:buttonNormal forState:UIControlStateNormal];
    UIImage *buttonClicked = [[UIImage imageWithName:kStoreButtonClickedImageName]
        stretchableImageWithLeftCapWidth:kButtonBgCap
                            topCapHeight:kButtonBgCap];
    [self.buttonPurchase setBackgroundImage:buttonClicked forState:UIControlStateHighlighted];
    UIImage *buttonDisabled = [[UIImage imageWithName:kStoreButtonDisabledImageName]
        stretchableImageWithLeftCapWidth:kButtonBgCap
                            topCapHeight:kButtonBgCap];
    [self.buttonPurchase setBackgroundImage:buttonDisabled forState:UIControlStateDisabled];
    self.buttonPurchase.exclusiveTouch = YES;
    self.buttonPurchase.adjustsImageWhenDisabled = NO;
    self.buttonPurchase.titleLabel.textColor = UIColor.whiteColor;
    self.buttonPurchase.titleLabel.font = [UIFont boldSystemFontOfSize:kButtonTitleFontSize];
    self.buttonPurchase.titleLabel.shadowOffset = CGSizeMake(0.0, kTitleShadowOffsetY);
    [self.buttonPurchase setTitleColor:UIColor.whiteColor forState:UIControlStateNormal];
    [self.buttonPurchase setTitleShadowColor:[UIColor colorWithWhite:0.0
                                                               alpha:kButtonTitleShadowAlpha]
                                    forState:UIControlStateNormal];
    [self.buttonPurchase setTitleColor:[UIColor colorWithWhite:kDisabledTitleWhite alpha:1.0]
                              forState:UIControlStateDisabled];
    [self.buttonPurchase setTitleShadowColor:[UIColor colorWithWhite:1.0
                                                               alpha:kButtonTitleShadowAlpha]
                                    forState:UIControlStateDisabled];
    [self.buttonPurchase addTarget:self
                            action:@selector(doPurchase:)
                  forControlEvents:UIControlEventTouchUpInside];
    [self.packView addSubview:self.buttonPurchase];
    [self addSubview:self.packView];

    self.musicViews = [NSMutableArray arrayWithCapacity:kMusicRowCount];
    for (NSInteger i = 0; i < kMusicRowCount; ++i) {
        CGRect rowFrame =
            CGRectMake((CGFloat)((i % kMusicRowsPerColumn) * (NSInteger)kMusicRowStepX),
                       (CGFloat)((i / kMusicRowsPerColumn) * (NSInteger)kMusicRowStepY +
                                 (NSInteger)kMusicRowTopOffset),
                       kMusicRowWidth,
                       kMusicRowHeight);
        [self.musicViews addObject:[[StorePackMusicView alloc] initWithFrame:rowFrame]];
        // Rows 0 and 1 use the light tune-cell background; rows 2 and 3 use the dark one.
        [self.musicViews[i] setBG:(i > 1)];
        [self.musicViews[i].buttonLink addTarget:self
                                          action:@selector(handleLink:)
                                forControlEvents:UIControlEventTouchUpInside];
        [self.musicViews[i].buttonSample addTarget:self
                                            action:@selector(handleSample:)
                                  forControlEvents:UIControlEventTouchUpInside];
        [self addSubview:self.musicViews[i]];
    }
    [self removePackInfo];

    self.indicator = [[UIActivityIndicatorView alloc]
        initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleWhite];
    self.indicator.frame = self.frame;
    self.indicator.center = CGPointMake(kMusicRowStepX * kCentreScale,
                                        kMusicRowStepY * kCentreScale + kIndicatorCentreYOffset);

    self.labelLoading = [[UILabel alloc]
        initWithFrame:CGRectMake(0.0, 0.0, kLoadingLabelWidth, kLoadingLabelHeight)];
    self.labelLoading.backgroundColor = UIColor.clearColor;
    self.labelLoading.font = [UIFont boldSystemFontOfSize:kLoadingLabelFontSize];
    self.labelLoading.textColor = UIColor.whiteColor;
    self.labelLoading.shadowColor = [UIColor colorWithWhite:0.0 alpha:kLoadingShadowAlpha];
    self.labelLoading.shadowOffset = CGSizeMake(0.0, kTitleShadowOffsetY);
    self.labelLoading.textAlignment = NSTextAlignmentCenter;
    self.labelLoading.text = g_pStoreLoadingTitle;
    self.labelLoading.center = CGPointMake(
        kMusicRowStepX * kCentreScale, kMusicRowStepY * kCentreScale + kLoadingLabelCentreYOffset);
    isInfoLoaded = NO;

    UIButton *webButton = [UIButton buttonWithType:UIButtonTypeCustom];
    webButton.backgroundColor = UIColor.clearColor;
    UIImage *webImage = [UIImage imageWithName:kStoreWebButtonImageName];
    [webButton setImage:webImage forState:UIControlStateNormal];
    [webButton sizeToFit];
    (void)webButton.frame; // Yes, the binary reads the frame here and discards it.
    CGSize webImageSize = webImage.size;
    webButton.frame = CGRectMake(kWebButtonRightAnchor - webImageSize.width,
                                 kWebButtonOriginY,
                                 webImageSize.width,
                                 webImageSize.height);
    [webButton addTarget:self
                  action:@selector(selectWebButton)
        forControlEvents:UIControlEventTouchUpInside];
    webButton.hidden = YES;
    [self.packView addSubview:webButton];
    self.artistSiteButton = webButton;

    // The binary reuses the pack-view width constant (650) for both this strip's y-origin and its
    // width.
    UIView *termStrip = [[UIView alloc]
        initWithFrame:CGRectMake(0.0, kPackViewWidth, kPackViewWidth, kButtonHeight)];
    termStrip.backgroundColor = [UIColor colorWithWhite:kTermStripBackgroundWhite alpha:1.0];
    [self addSubview:termStrip];

    UILabel *termLabel = [[UILabel alloc]
        initWithFrame:CGRectMake(kTermStripOriginX, 0.0, kWebButtonRightAnchor, kButtonHeight)];
    termLabel.font = [UIFont systemFontOfSize:kTermLabelFontSize];
    termLabel.textAlignment = NSTextAlignmentRight;
    termLabel.text = kTermLabelText;
    termLabel.textColor = [UIColor colorWithRed:0.0 green:kTermLinkGreenBlue blue:1.0 alpha:1.0];
    termLabel.userInteractionEnabled = YES;
    UITapGestureRecognizer *tap =
        [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(showTerm)];
    [termLabel addGestureRecognizer:tap];
    [termStrip addSubview:termLabel];

    return self;
}

#pragma mark - Loading

/** @ghidraAddress 0xf9330 */
- (void)loadInfo {
    if (self.packInfo == nil) {
        return;
    }
    [self.buttonPurchase setHidden:YES];
    [self.buttonPurchase setEnabled:NO];
    if (self.packInfo.musicInfos != nil) {
        [self.buttonPurchase setHidden:NO];
        [self.buttonPurchase setEnabled:YES];
        self.backgroundColor = [UIColor colorWithWhite:kLoadedBackgroundWhite alpha:1.0];
        [self showPackInfo];
        return;
    }
    self.backgroundColor = UIColor.grayColor;
    [self addSubview:self.indicator];
    [self addSubview:self.labelLoading];
    [self.indicator startAnimating];
    if (self.storePackInfoDownloader != nil) {
        [self.storePackInfoDownloader cancel];
        self.storePackInfoDownloader = nil;
    }
    StorePackInfoDownloader *downloader =
        [[StorePackInfoDownloader alloc] initWithStorePackInfo:self.packInfo];
    downloader.delegate = self;
    self.storePackInfoDownloader = downloader;
    [downloader downloadDetail:YES];
}

/** @ghidraAddress 0xf8a94 */
- (void)showPackInfo {
    if (isInfoLoaded) {
        return;
    }
    self.backgroundColor = [UIColor colorWithWhite:kLoadedBackgroundWhite alpha:1.0];
    [self.buttonPurchase setHidden:NO];
    [self.buttonPurchase setEnabled:YES];
    self.labelPackName.text = self.packInfo.packName;
    self.labelComment.text = self.packInfo.comment;
    self.copyrightView.text = self.packInfo.copyright;
    self.packArtworkView.image = nil;
    self.packArtworkView.imageURL = self.packInfo.artworkURL;
    [self selfCheckButtonText];
    self.packView.hidden = NO;

    NSArray<StoreMusicInfo *> *musicInfos = self.packInfo.musicInfos;
    for (NSInteger i = 0; i < kMusicRowCount; ++i) {
        if ((NSUInteger)i < musicInfos.count) {
            [self.musicViews[i] setInfo:musicInfos[i]];
            self.musicViews[i].hidden = NO;
        } else {
            [self.musicViews[i] setInfo:nil];
            self.musicViews[i].hidden = YES;
        }
        [self.musicViews[i] setParent:self];
    }
    [self.packArtworkView startDownloadImage];
    for (NSInteger i = 0; i < kMusicRowCount; ++i) {
        [self.musicViews[i].artworkView startDownloadImage];
    }
    self.artistSiteButton.hidden = (self.packInfo.artistURL == nil);
    isInfoLoaded = YES;
}

/** @ghidraAddress 0xf8154 */
- (void)cancelLoading {
    if (self.storePackInfoDownloader != nil) {
        self.storePackInfoDownloader.delegate = self;
        [self.storePackInfoDownloader cancel];
        self.storePackInfoDownloader = nil;
    }
}

/** @ghidraAddress 0xf8238 */
- (void)stopSample {
    if ([RBBGMManager getInstance].isPushMusic) {
        [[RBBGMManager getInstance] StopMusic:g_flFlashMinOpacity];
        [[RBBGMManager getInstance] popMusic];
    }
    [self.sampleDownloader cancel];
    for (NSInteger i = 0; i < kMusicRowCount; ++i) {
        [self.musicViews[i] sampleStop];
    }
    samplePlaying = kNoSamplePlaying;
}

/** @ghidraAddress 0xf7ddc */
- (void)removePackInfo {
    self.packInfo = nil;
    self.backgroundColor = UIColor.grayColor;
    self.labelPackName.text = nil;
    self.labelComment.text = nil;
    self.copyrightView.text = nil;
    self.packArtworkView.imageURL = nil;
    self.packView.hidden = YES;
    self.artistSiteButton.hidden = YES;
    for (NSInteger i = 0; i < kMusicRowCount; ++i) {
        [self.musicViews[i] setInfo:nil];
        self.musicViews[i].hidden = YES;
    }
    [self.indicator stopAnimating];
    [self.indicator removeFromSuperview];
    [self.labelLoading removeFromSuperview];
    isInfoLoaded = NO;
}

#pragma mark - Purchase button state

/** @ghidraAddress 0xf8400 */
- (BOOL)allDownloaded {
    if (self.packInfo != nil && self.packInfo.musicInfos != nil &&
        self.packInfo.musicInfos.count != 0) {
        return [self.packInfo allDownloaded];
    }
    return NO;
}

/** @ghidraAddress 0xf859c */
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

/** @ghidraAddress 0xf8714 */
- (void)setButtonTextBuy {
    [self.buttonPurchase
        setTitle:[NSString stringWithFormat:g_pLocalizedBuyFormat, self.packInfo.priceString]
        forState:UIControlStateNormal];
    [self.buttonPurchase setEnabled:YES];
}

/** @ghidraAddress 0xf8884 */
- (void)setButtonTextInstall {
    [self.buttonPurchase setTitle:g_pLocalizedInstall forState:UIControlStateNormal];
    [self.buttonPurchase setEnabled:YES];
}

/** @ghidraAddress 0xf8934 */
- (void)setButtonTextInstalling {
    [self.buttonPurchase setTitle:g_pLocalizedInstalling forState:UIControlStateDisabled];
    [self.buttonPurchase setEnabled:NO];
}

/** @ghidraAddress 0xf89e4 */
- (void)setButtonTextInstalled {
    [self.buttonPurchase setTitle:g_pLocalizedInstalled forState:UIControlStateDisabled];
    [self.buttonPurchase setEnabled:NO];
}

#pragma mark - Actions

/** @ghidraAddress 0xf9744 */
- (void)doPurchase:(id)doPurchase {
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

/** @ghidraAddress 0xf99e8 */
- (void)handleLink:(id)handleLink {
    NSInteger row = 0;
    while (self.musicViews[row].buttonLink != handleLink) {
        ++row;
        if (row > kMusicRowCount - 1) {
            return;
        }
    }
    NSString *itunesURL = self.packInfo.musicInfos[row].itunesURL;
    if (itunesURL == nil) {
        return;
    }
    if ([self.delegate respondsToSelector:@selector(storeDetailViewOpenItunesWithURL:)]) {
        [self.delegate performSelector:@selector(storeDetailViewOpenItunesWithURL:)
                            withObject:[NSURL URLWithString:itunesURL]];
    }
}

/** @ghidraAddress 0xf9c88 */
- (void)handleSample:(id)handleSample {
    for (NSInteger row = 0; row < kMusicRowCount; ++row) {
        if (self.musicViews[row].buttonSample != handleSample) {
            continue;
        }
        if (samplePlaying == (int)row) {
            if ([RBBGMManager getInstance].isPushMusic) {
                [[RBBGMManager getInstance] StopMusic:g_flFlashMinOpacity];
                [[RBBGMManager getInstance] popMusic];
            }
            [self.sampleDownloader cancel];
            [self.musicViews[samplePlaying] sampleStop];
            samplePlaying = kNoSamplePlaying;
            return;
        }
        if (samplePlaying >= 0) {
            if ([RBBGMManager getInstance].isPushMusic) {
                [[RBBGMManager getInstance] StopMusic:g_flFlashMinOpacity];
                [[RBBGMManager getInstance] popMusic];
            }
            [self.sampleDownloader cancel];
            [self.musicViews[samplePlaying] sampleStop];
        }
        StoreMusicInfo *info = self.packInfo.musicInfos[row];
        samplePlaying = (int)row;
        [self.musicViews[row] sampleDownloading];
        [self.sampleDownloader cancel];
        self.sampleDownloader = [[Downloader alloc] initWithURL:[NSURL URLWithString:info.sampleURL]
                                                           save:nil];
        [self.sampleDownloader startDownloadingWithDelegate:self];
        return;
    }
}

/** @ghidraAddress 0xfa270 */
- (void)selectWebButton {
    NSString *artistURL = self.packInfo.artistURL;
    if (artistURL != nil) {
        [[UIApplication sharedApplication] openURL:[NSURL URLWithString:artistURL]];
    }
}

/** @ghidraAddress 0xfa37c */
- (void)finishBgm:(id)finishBgm {
    for (NSInteger i = 0; i < kMusicRowCount; ++i) {
        [self.musicViews[i] sampleStop];
    }
    samplePlaying = kNoSamplePlaying;
}

/** @ghidraAddress 0xfa45c */
- (void)showTerm {
    if ([self.delegate respondsToSelector:@selector(showTerms)]) {
        [self.delegate performSelector:@selector(showTerms)];
    }
}

/** @ghidraAddress 0xfaea4 */
- (void)switchToSpecialStore:(NSNumber *)switchToSpecialStore {
    [self stopSample];
    [AppDelegate appDelegate].extendNotePIDForOpenStore =
        [NSString stringWithFormat:@"%d", switchToSpecialStore.intValue];
    [self.delegate performSelector:@selector(switchToSpecialStore)];
}

#pragma mark - DownloaderDelegate

/** @ghidraAddress 0xfa52c */
- (void)downloaderFinished:(Downloader *)downloaderFinished {
    if (self.sampleDownloader != downloaderFinished) {
        return;
    }
    if (samplePlaying >= 0) {
        NSData *data = [self.sampleDownloader getData];
        [[RBBGMManager getInstance] LoadMusicWithPush:data Loop:YES];
        [[RBBGMManager getInstance] PlayMusic:0.0];
        [self.musicViews[samplePlaying] samplePlaying];
    }
    self.sampleDownloader = nil;
}

/** @ghidraAddress 0xfa72c */
- (void)downloaderError:(Downloader *)downloaderError {
    if (self.sampleDownloader != downloaderError) {
        return;
    }
    if (samplePlaying >= 0) {
        [self.musicViews[samplePlaying] sampleStop];
        samplePlaying = kNoSamplePlaying;
    }
    self.sampleDownloader = nil;
    [UIAlertView showNetworkErrorWithDelegate:nil];
}

/** @ghidraAddress 0xfa868 */
- (void)downloaderProceed:(Downloader *)downloaderProceed {
}

#pragma mark - StorePackInfoDownloaderDelegate

/** @ghidraAddress 0xfa86c */
- (void)storePackInfoDownloaderFinished:(StorePackInfoDownloader *)storePackInfoDownloaderFinished {
    if ([storePackInfoDownloaderFinished getErrorMessage] != nil) {
        [self storePackInfoDownloaderError:storePackInfoDownloaderFinished];
        return;
    }
    if ([storePackInfoDownloaderFinished getPackInfo].musicInfos == nil) {
        [self storePackInfoDownloaderError:storePackInfoDownloaderFinished];
        return;
    }
    [self showPackInfo];
    [self.indicator stopAnimating];
    [self.indicator removeFromSuperview];
    [self.labelLoading removeFromSuperview];
    self.storePackInfoDownloader.delegate = nil;
    self.storePackInfoDownloader = nil;
}

/** @ghidraAddress 0xfaa58 */
- (void)storePackInfoDownloaderError:(StorePackInfoDownloader *)storePackInfoDownloaderError {
    [self.indicator stopAnimating];
    [self.indicator removeFromSuperview];
    [self.labelLoading removeFromSuperview];
    [UIAlertView showNetworkErrorWithDelegate:self];
    self.storePackInfoDownloader.delegate = nil;
    self.storePackInfoDownloader = nil;
}

#pragma mark - UIAlertViewDelegate

/** @ghidraAddress 0xfaba4 */
- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)clickedButtonAtIndex {
    if ([self.delegate respondsToSelector:@selector(detailViewClose)]) {
        [self.delegate performSelector:@selector(detailViewClose)];
    }
}

/** @ghidraAddress 0xfac80 */
- (void)alertView:(UIAlertView *)alertView
    didDismissWithButtonIndex:(NSInteger)didDismissWithButtonIndex {
}

/** @ghidraAddress 0xfac84 */
- (void)alertView:(UIAlertView *)alertView
    willDismissWithButtonIndex:(NSInteger)willDismissWithButtonIndex {
}

/** @ghidraAddress 0xfac88 */
- (void)alertViewCancel:(UIAlertView *)alertViewCancel {
    if ([self.delegate respondsToSelector:@selector(detailViewClose)]) {
        [self.delegate performSelector:@selector(detailViewClose)];
    }
}

/** @ghidraAddress 0xfad64 */
- (void)didPresentAlertView:(UIAlertView *)didPresentAlertView {
    [UIAlertView
        setExclusiveTouchForView:[UIApplication sharedApplication]
                                     .keyWindow.rootViewController.presentedViewController.view];
}

@end
