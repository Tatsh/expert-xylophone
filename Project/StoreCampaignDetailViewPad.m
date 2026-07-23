#import "StoreCampaignDetailViewPad.h"

#import <UIKit/UIKit.h>

#import "RBBGMManager.h"
#import "RBMusicManager.h"
#import "StoreButtonView.h"
#import "StoreCampaignItemInfo.h"
#import "StoreImageView.h"
#import "UIAlertView+RB.h"
#import "UIImage+RB.h"
#import "neEngineBridge.h"

// The informal close callback the overlay sends to its weak delegate (the campaign list page). The
// binary guards detailViewClose with respondsToSelector: before sending it.
@interface NSObject (StoreCampaignDetailPadDelegate)
- (void)detailViewClose;
- (void)pushCellButton:(nullable id)sender;
@end

// Layout metrics shared with the campaign list page, defined once in the binary as doubles.
extern const CGFloat g_dPopupBaseOriginYWide;         // @ghidraAddress 0x2eea38 (160.0)
extern const CGFloat g_dMascotMessageMaxWidthPad;     // @ghidraAddress 0x2ee930 (300.0)
extern const CGFloat g_dMascotMessageMaxWidthPhone;   // @ghidraAddress 0x2ee938 (200.0)
extern const CGFloat g_dSliderRowHeightWide;          // @ghidraAddress 0x2ee950 (40.0)
extern const CGFloat g_dLayoutMetricThirtyTwo;        // @ghidraAddress 0x2ee9b0 (32.0)
extern const CGFloat g_dRBWebViewGrayViewWhite;       // @ghidraAddress 0x2ec708 (0.6)
extern const CGFloat g_dTranslucentAlpha;             // @ghidraAddress 0x2ec6a0
extern const CGFloat g_dAudioManagerResumeFadeInTime; // @ghidraAddress 0x2ec718 (0.3)
extern const float g_flFlashMinOpacity;               // @ghidraAddress 0x2ec6b4 (0.0)

// The store loading-label text, defined in the store page module. @ghidraAddress 0x3cfca8
extern NSString *const g_pStoreLoadingTitle;

// The sample-download and playback state machine held in the (non-property) sampleStatus ivar.
typedef enum {
    StoreCampaignSampleStatusIdle = 0,        // No sample is loading or playing.
    StoreCampaignSampleStatusDownloading = 1, // The audio sample is being downloaded.
    StoreCampaignSampleStatusPlaying = 2,     // The audio sample is playing.
} StoreCampaignSampleStatus;

// The item hide mode; a value of one masks the item's name and identifier.
static const int kCampaignHideTypeSecret = 1;
// The item type that identifies a downloadable tune.
static const int kCampaignItemTypeTune = 0;
// The acquisition-button kind set once a download is in progress.
static const int kCampaignButtonDownloading = 1;

// Asset names loaded through UIImage+RB.
static NSString *const kItemPanelBackgroundName = @"09_store/store_pack_bg_2";
static NSString *const kSampleStopGlyphName = @"09_store/store_sample_1";
static NSString *const kSamplePlayGlyphName = @"09_store/store_sample_2";
static NSString *const kPlaceholderJacketName = @"09_store/store_jacket_110";

// Display formats.
static NSString *const kLevelFormat = @"LEVEL:  %d / %d / %d";
static NSString *const kIdFormat = @"%d";
// The masked name shown for a secret (hidden) item.
static NSString *const kSecretNameMask = @"？？？？？？";
// The external-link button title.
static NSString *const kLinkButtonTitle = @"詳しくはこちら";

// Item-container geometry.
static const CGFloat kItemViewWidth = 650.0;
static const CGFloat kItemViewHeight = 284.0;
static const CGFloat kItemBackgroundStretchCap = 4.0;
static const CGFloat kTitleFontSize = 18.0;
static const CGFloat kTitleInset = 20.0;
static const CGFloat kItemNameFontSize = 22.0;
static const CGFloat kArtistFontSize = 18.0;
static const CGFloat kLevelsFontSize = 20.0;
static const CGFloat kLabelMinimumScaleFactor = 18.0;
static const CGFloat kArtworkOriginX = 18.0;
static const CGFloat kLabelNameOriginX = 195.0;
static const CGFloat kLabelNameOriginY = 76.0;
static const CGFloat kLabelNameWidth = 420.0;
static const CGFloat kLabelLineHeight = 28.0;
static const CGFloat kLabelArtistOriginY = 108.0;
static const CGFloat kLabelLevelsOriginY = 172.0;
static const CGFloat kLevelsVariantRed = 0.3333333333333333;
static const CGFloat kLevelsVariantGreen = 0.03529411926865578;
static const CGFloat kLevelsVariantBlue = 0.47058823529411764;
static const CGFloat kDownloadBtnOriginX = 470.0;
static const CGFloat kDownloadBtnOriginY = 234.0;
static const CGFloat kActionBtnHeight = 30.0;
static const CGFloat kActionBtnCornerRadius = 4.0;
static const CGFloat kActionBtnFontSizeWide = 16.0;
static const CGFloat kActionBtnFontSizeNarrow = 10.0;
static const CGFloat kSampleBtnOriginX = 595.0;
static const CGFloat kSampleBtnSize = 35.0;
static const CGFloat kSampleBtnGlyphSize = 20.0;
static const CGFloat kArtworkBorderWidth = 1.0;
static const CGFloat kArtworkShadowOffset = 2.0;
static const CGFloat kArtworkShadowRadius = 2.0;

// Panel and detail-pane geometry.
static const CGFloat kPanelShadowRadius = 8.0;
static const CGFloat kPanelShadowOpacity = 0.5;
static const CGFloat kInnerPanelShadowOffset = 1.0;
static const CGFloat kInnerPanelShadowRadius = 1.0;
static const CGFloat kDetailViewHeight = 366.0;
static const CGFloat kBannerCornerRadius = 8.0;
static const CGFloat kDetailContentInset = 10.0;
static const CGFloat kDetailStackSpacing = 5.0;
static const CGFloat kDescriptionOriginX = 10.0;
static const CGFloat kDescriptionOriginY = 10.0;
static const CGFloat kDescriptionWidth = 630.0;
static const CGFloat kDescriptionHeight = 316.0;
static const CGFloat kDescriptionFontSize = 18.0;
static const CGFloat kCopyrightFontSize = 16.0;
static const CGFloat kBottomCopyrightThreshold = 356.0;

// Loading label and indicator geometry.
static const CGFloat kLoadingLabelHeight = 24.0;
static const CGFloat kLoadingLabelFontSize = 18.0;
static const CGFloat kLoadingShadowWhite = 0.0;
static const CGFloat kLoadingLabelOffsetY = 15.0;

// setArtwork: sizing.
static const CGFloat kArtworkMarginX = 12.0;
static const CGFloat kArtworkMarginY = 10.0;
static const CGFloat kSquareArtworkSizeNarrow = 64.0;
static const CGFloat kSquareArtworkSizeWide = 110.0;
static const CGFloat kSquareArtworkVariantYInset = 2.0;
static const CGFloat kArtworkFadeInDuration = 0.2;

// Colours used for the item panel and buttons.
static const CGFloat kItemPanelBackgroundWhite = 0.8629999756813049;
static const CGFloat kFullAlpha = 1.0;

@interface StoreCampaignDetailViewPad ()
- (void)pushLink:(nullable id)sender;
- (void)pushSampleBtn;
- (void)sampleViewStop;
- (void)sampleViewDownloading;
- (void)sampleViewPlaying;
- (void)finishBgm:(nullable id)notification;
- (CGSize)getArtworkMargin:(BOOL)variant;
- (CGSize)getItemSize:(BOOL)variant;
@end

@implementation StoreCampaignDetailViewPad {
    // The audio-sample state machine; this ivar has no property and keeps its literal, non-prefixed
    // binary name.
    int sampleStatus;
    // Whether a sample download is currently in flight; keeps its literal, non-prefixed binary name.
    BOOL isDownloadingSample;
    // Whether the bound item reports itself as unlocked; keeps its literal binary name.
    BOOL bUnlock;
    // The item hide mode of the bound item; keeps its literal binary name.
    int hideType;
    // The acquisition-button kind of the bound item; keeps its literal binary name.
    int buttonType;
    // Whether the bound item's install has completed; keeps its literal binary name.
    BOOL downloadFlag;
}

#pragma mark - Lifecycle

/** @ghidraAddress 0x423d8 */
- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self != nil) {
        if ([[UIScreen mainScreen] respondsToSelector:@selector(scale)] &&
            [self respondsToSelector:@selector(contentScaleFactor)]) {
            [self setContentScaleFactor:[[UIScreen mainScreen] scale]];
        }
        self.userInteractionEnabled = YES;
        self.opaque = YES;
        self.layer.shadowRadius = kPanelShadowRadius;
        self.layer.shadowOffset = CGSizeZero;
        self.layer.shadowOpacity = kPanelShadowOpacity;
        self.layer.shouldRasterize = YES;
        self.backgroundColor = [UIColor grayColor];

        UIImage *panelImage = [UIImage imageWithName:kItemPanelBackgroundName];
        BOOL isPad = IsPad();

        UIView *item =
            [[UIView alloc] initWithFrame:CGRectMake(0, 0, kItemViewWidth, kItemViewHeight)];
        self.itemView = item;

        UIImageView *background =
            [[UIImageView alloc] initWithFrame:CGRectMake(0, 0, kItemViewWidth, kItemViewHeight)];
        background.image = [panelImage stretchableImageWithLeftCapWidth:kItemBackgroundStretchCap
                                                           topCapHeight:kItemBackgroundStretchCap];
        [self.itemView addSubview:background];

        UIView *panel = [[UIView alloc] initWithFrame:self.bounds];
        panel.backgroundColor = [UIColor whiteColor];
        panel.layer.shadowOffset = CGSizeMake(0, kInnerPanelShadowOffset);
        panel.layer.shadowOpacity = kPanelShadowOpacity;
        panel.layer.shadowRadius = kInnerPanelShadowRadius;

        UILabel *title = [[UILabel alloc] initWithFrame:CGRectMake(kDetailContentInset,
                                                                   0,
                                                                   kItemViewWidth - kTitleInset,
                                                                   kItemViewHeight)];
        self.labelTitle = title;
        self.labelTitle.backgroundColor = [UIColor clearColor];
        self.labelTitle.font = [UIFont boldSystemFontOfSize:kTitleFontSize];
        self.labelTitle.textColor = [UIColor blackColor];
        self.labelTitle.textAlignment = NSTextAlignmentCenter;
        self.labelTitle.adjustsFontSizeToFitWidth = YES;
        [panel addSubview:self.labelTitle];
        [self.itemView addSubview:panel];

        StoreImageView *artwork =
            [[StoreImageView alloc] initWithFrame:CGRectMake(kArtworkOriginX,
                                                             g_dPopupBaseOriginYWide,
                                                             g_dPopupBaseOriginYWide,
                                                             g_dPopupBaseOriginYWide)];
        self.artworkView = artwork;
        self.artworkView.layer.borderWidth = kArtworkBorderWidth;
        self.artworkView.layer.borderColor = (__bridge id)[UIColor whiteColor].CGColor;
        self.artworkView.backgroundColor = [UIColor whiteColor];
        self.artworkView.layer.shadowOffset =
            CGSizeMake(kArtworkShadowOffset, kArtworkShadowOffset);
        self.artworkView.layer.shadowColor = (__bridge id)[UIColor blackColor].CGColor;
        self.artworkView.layer.shadowOpacity = g_dRBWebViewGrayViewWhite;
        self.artworkView.layer.shadowRadius = kArtworkShadowRadius;
        self.artworkView.layer.shouldRasterize = YES;
        [self.itemView addSubview:self.artworkView];

        UILabel *name = [[UILabel alloc] initWithFrame:CGRectMake(kLabelNameOriginX,
                                                                  kLabelNameOriginY,
                                                                  kLabelNameWidth,
                                                                  kLabelLineHeight)];
        self.labelItemName = name;
        self.labelItemName.backgroundColor = [UIColor clearColor];
        self.labelItemName.font = [UIFont boldSystemFontOfSize:kItemNameFontSize];
        self.labelItemName.adjustsFontSizeToFitWidth = YES;
        self.labelItemName.minimumScaleFactor = kLabelMinimumScaleFactor;
        [self.itemView addSubview:self.labelItemName];

        UILabel *artist = [[UILabel alloc] initWithFrame:CGRectMake(kLabelNameOriginX,
                                                                    kLabelArtistOriginY,
                                                                    kLabelNameWidth,
                                                                    kLabelLineHeight)];
        self.labelArtistName = artist;
        self.labelArtistName.backgroundColor = [UIColor clearColor];
        self.labelArtistName.font = [UIFont systemFontOfSize:kArtistFontSize];
        self.labelArtistName.adjustsFontSizeToFitWidth = YES;
        self.labelArtistName.minimumScaleFactor = kLabelMinimumScaleFactor;
        [self.itemView addSubview:self.labelArtistName];

        UILabel *levels = [[UILabel alloc] initWithFrame:CGRectMake(kLabelNameOriginX,
                                                                    kLabelLevelsOriginY,
                                                                    kLabelNameWidth,
                                                                    kLabelLineHeight)];
        self.labelLevels = levels;
        self.labelLevels.backgroundColor = [UIColor clearColor];
        self.labelLevels.font = [UIFont boldSystemFontOfSize:kLevelsFontSize];
        self.labelLevels.adjustsFontSizeToFitWidth = YES;
        self.labelLevels.minimumScaleFactor = kLabelMinimumScaleFactor;
        if (isPad) {
            self.labelLevels.textColor = [UIColor colorWithRed:kLevelsVariantRed
                                                         green:kLevelsVariantGreen
                                                          blue:kLevelsVariantBlue
                                                         alpha:kFullAlpha];
        }
        [self.itemView addSubview:self.labelLevels];

        StoreButtonView *download = [[StoreButtonView alloc]
            initWithFrame:CGRectMake(kDownloadBtnOriginX,
                                     kDownloadBtnOriginY,
                                     g_dPopupBaseOriginYWide + kLabelLineHeight,
                                     kActionBtnHeight)];
        self.downloadBtn = download;
        self.downloadBtn.disabledColor = [UIColor colorWithWhite:g_dRBWebViewGrayViewWhite
                                                           alpha:kFullAlpha];
        self.downloadBtn.cornerRadius = kActionBtnCornerRadius;
        self.downloadBtn.exclusiveTouch = YES;
        CGFloat actionBtnFontSize = isPad ? kActionBtnFontSizeWide : kActionBtnFontSizeNarrow;
        self.downloadBtn.titleLabel.font = [UIFont boldSystemFontOfSize:actionBtnFontSize];
        [self.downloadBtn setButtonColor:[StoreCampaignItemInfo getButtonColor:buttonType]];
        [self.downloadBtn setTitle:[StoreCampaignItemInfo getButtonName:buttonType]
                          forState:UIControlStateNormal];
        [self.downloadBtn setTitle:[StoreCampaignItemInfo getButtonName:kCampaignButtonDownloading]
                          forState:UIControlStateDisabled];
        [self.downloadBtn addTarget:self.delegate
                             action:@selector(pushCellButton:)
                   forControlEvents:UIControlEventTouchUpInside];
        [self.itemView addSubview:self.downloadBtn];

        StoreButtonView *link = [[StoreButtonView alloc]
            initWithFrame:CGRectMake(g_dMascotMessageMaxWidthPad,
                                     kDownloadBtnOriginY,
                                     g_dPopupBaseOriginYWide + kLabelLineHeight,
                                     kActionBtnHeight)];
        self.linkBtn = link;
        self.linkBtn.disabledColor = [UIColor colorWithWhite:g_dRBWebViewGrayViewWhite
                                                       alpha:kFullAlpha];
        [self.linkBtn setButtonColor:[UIColor colorWithRed:g_dTranslucentAlpha
                                                     green:g_dAudioManagerResumeFadeInTime
                                                      blue:g_dTranslucentAlpha
                                                     alpha:kFullAlpha]];
        self.linkBtn.cornerRadius = kActionBtnCornerRadius;
        self.linkBtn.exclusiveTouch = YES;
        self.linkBtn.titleLabel.font = [UIFont boldSystemFontOfSize:actionBtnFontSize];
        [self.linkBtn setTitle:kLinkButtonTitle forState:UIControlStateNormal];
        [self.linkBtn addTarget:self
                         action:@selector(pushLink:)
               forControlEvents:UIControlEventTouchUpInside];
        [self.itemView addSubview:self.linkBtn];

        UIButton *sample = [UIButton buttonWithType:UIButtonTypeCustom];
        self.sampleBtn = sample;
        self.sampleBtn.frame = CGRectMake(
            kSampleBtnOriginX, kLabelLevelsOriginY, g_dLayoutMetricThirtyTwo, kSampleBtnSize);
        self.sampleBtn.contentMode = UIViewContentModeScaleAspectFit;
        [self.sampleBtn setImage:[UIImage imageWithName:kSampleStopGlyphName]
                        forState:UIControlStateNormal];
        [self.sampleBtn addTarget:self
                           action:@selector(pushSampleBtn)
                 forControlEvents:UIControlEventTouchUpInside];

        UIActivityIndicatorView *sampleIndicator = [[UIActivityIndicatorView alloc]
            initWithFrame:CGRectMake(0, 0, kSampleBtnGlyphSize, kSampleBtnGlyphSize)];
        self.indicatorSample = sampleIndicator;
        // Yes, the binary reads sampleBtn's frame twice here and discards both results.
        (void)self.sampleBtn.frame;
        (void)self.sampleBtn.frame;
        self.indicatorSample.center =
            CGPointMake(kSampleBtnGlyphSize * 0.5, kSampleBtnGlyphSize * 0.5);
        self.indicatorSample.activityIndicatorViewStyle = UIActivityIndicatorViewStyleGray;
        self.indicatorSample.hidesWhenStopped = YES;
        [self.sampleBtn addSubview:self.indicatorSample];
        [self.itemView addSubview:self.sampleBtn];
        [self addSubview:self.itemView];

        UIScrollView *detail = [[UIScrollView alloc]
            initWithFrame:CGRectMake(0, kItemViewHeight, kItemViewWidth, kDetailViewHeight)];
        self.detailView = detail;
        self.detailView.opaque = YES;
        self.detailView.scrollEnabled = YES;
        self.detailView.decelerationRate = UIScrollViewDecelerationRateFast;
        self.detailView.bouncesZoom = NO;
        self.detailView.layer.borderColor =
            (__bridge id)[UIColor colorWithWhite:g_dAudioManagerResumeFadeInTime alpha:kFullAlpha]
                .CGColor;

        StoreImageView *banner = [[StoreImageView alloc] initWithFrame:CGRectZero];
        self.bannerView = banner;
        self.bannerView.layer.shouldRasterize = YES;
        self.bannerView.layer.cornerRadius = kBannerCornerRadius;
        self.bannerView.clipsToBounds = YES;
        [self.detailView addSubview:self.bannerView];

        UITextView *description = [[UITextView alloc] initWithFrame:CGRectMake(kDescriptionOriginX,
                                                                               kDescriptionOriginY,
                                                                               kDescriptionWidth,
                                                                               kDescriptionHeight)];
        self.descriptionTextView = description;
        self.descriptionTextView.backgroundColor = [UIColor clearColor];
        self.descriptionTextView.editable = NO;
        self.descriptionTextView.selectable = NO;
        self.descriptionTextView.scrollEnabled = NO;
        self.descriptionTextView.font = [UIFont systemFontOfSize:kDescriptionFontSize];
        [self.detailView addSubview:self.descriptionTextView];

        UITextView *copyright =
            [[UITextView alloc] initWithFrame:CGRectMake(kDescriptionOriginX,
                                                         kDescriptionHeight,
                                                         kDescriptionWidth,
                                                         g_dSliderRowHeightWide)];
        self.copyrightView = copyright;
        self.copyrightView.backgroundColor = [UIColor clearColor];
        self.copyrightView.editable = NO;
        self.copyrightView.font = [UIFont systemFontOfSize:kCopyrightFontSize];
        [self.detailView addSubview:self.copyrightView];
        [self addSubview:self.detailView];

        [self removeItemInfo];
        (void)self.frame; // Yes, the binary reads and discards its own frame here.

        UIActivityIndicatorView *indicator = [[UIActivityIndicatorView alloc]
            initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleWhiteLarge];
        self.indicator = indicator;
        self.indicator.frame = CGRectMake(
            kSampleBtnOriginX, kLabelLevelsOriginY, g_dLayoutMetricThirtyTwo, kSampleBtnSize);
        self.indicator.center = CGPointMake(kDescriptionWidth * 0.5,
                                            g_dSliderRowHeightWide * 0.5 - kLoadingLabelOffsetY);

        UILabel *loading = [[UILabel alloc]
            initWithFrame:CGRectMake(0, 0, g_dMascotMessageMaxWidthPhone, kLoadingLabelHeight)];
        self.labelLoading = loading;
        self.labelLoading.backgroundColor = [UIColor clearColor];
        self.labelLoading.font = [UIFont boldSystemFontOfSize:kLoadingLabelFontSize];
        self.labelLoading.textColor = [UIColor colorWithWhite:g_dRBWebViewGrayViewWhite
                                                        alpha:kFullAlpha];
        self.labelLoading.shadowColor = [UIColor colorWithWhite:kLoadingShadowWhite
                                                          alpha:g_dAudioManagerResumeFadeInTime];
        self.labelLoading.shadowOffset = CGSizeMake(0, -kInnerPanelShadowOffset);
        self.labelLoading.textAlignment = NSTextAlignmentCenter;
        self.labelLoading.text = g_pStoreLoadingTitle;
        self.labelLoading.center = CGPointMake(kDescriptionWidth * 0.5,
                                               g_dSliderRowHeightWide * 0.5 + kLoadingLabelOffsetY);

        sampleStatus = StoreCampaignSampleStatusIdle;
    }
    return self;
}

/** @ghidraAddress 0x47ac4 (.cxx_destruct handled by ARC) */

#pragma mark - Binding

/** @ghidraAddress 0x46280 */
- (void)setInfo:(nullable StoreCampaignItemInfo *)info tag:(NSInteger)tag {
    self.tag = tag;
    self.downloadBtn.tag = tag;
    self.linkBtn.tag = tag;

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
    self.campaignID = info.campaignID;
    buttonType = info.buttonType;

    self.labelTitle.text = info.campaignName;
    self.artworkView.image = nil;
    self.artworkView.imageURL = info.artworkURL;
    self.labelItemName.text = info.name;
    self.labelArtistName.text = info.artist;
    self.labelLevels.text =
        [NSString stringWithFormat:kLevelFormat, info.lvBasic, info.lvMedium, info.lvHard];
    self.labelID.text = [NSString stringWithFormat:kIdFormat, info.campaignID];

    downloadFlag = [self hasItem:info.itemType itemID:info.itemID];
    [self setDownloadFlag:downloadFlag];
    [self.downloadBtn setButtonColor:[StoreCampaignItemInfo getButtonColor:buttonType]];
    [self.downloadBtn setTitle:[StoreCampaignItemInfo getButtonName:buttonType]
                      forState:UIControlStateNormal];

    if (info.linkURL != nil) {
        self.linkBtn.alpha = kFullAlpha;
        self.linkBtn.hidden = NO;
    } else {
        self.linkBtn.alpha = 0.0;
        self.linkBtn.hidden = YES;
    }

    if (info.itemType == kCampaignItemTypeTune && hideType == kCampaignHideTypeSecret) {
        self.labelItemName.text = kSecretNameMask;
        self.labelID.text = nil;
    }

    self.bannerView.image = nil;
    self.bannerView.imageURL = info.campaignBannerURL;

    CGRect bannerFrame = self.bannerView.frame;
    CGRect descriptionFrame = self.descriptionTextView.frame;
    CGRect copyrightFrame = self.copyrightView.frame;

    self.descriptionTextView.text = info.campaignDescription;
    [self.descriptionTextView sizeToFit];
    CGFloat descriptionHeight = CGRectGetHeight(self.descriptionTextView.frame);
    CGFloat descriptionY =
        CGRectGetMinY(bannerFrame) + CGRectGetHeight(bannerFrame) + kDetailStackSpacing;
    self.descriptionTextView.frame = CGRectMake(CGRectGetMinX(descriptionFrame),
                                                descriptionY,
                                                CGRectGetWidth(descriptionFrame),
                                                descriptionHeight);

    self.copyrightView.text = info.copyright;
    [self.copyrightView sizeToFit];
    CGFloat copyrightHeight = CGRectGetHeight(self.copyrightView.frame);
    CGFloat copyrightY = descriptionY + descriptionHeight + kDetailStackSpacing;
    if (copyrightY + copyrightHeight < kBottomCopyrightThreshold) {
        // The copyright is short: pin it to the bottom of the detail pane instead.
        copyrightY = kDetailViewHeight - copyrightHeight - kDetailContentInset;
    }
    self.copyrightView.frame = CGRectMake(
        CGRectGetMinX(copyrightFrame), copyrightY, CGRectGetWidth(copyrightFrame), copyrightHeight);
    self.detailView.contentSize = CGSizeMake(CGRectGetWidth(copyrightFrame),
                                             copyrightHeight + copyrightY + kDetailContentInset);
}

/** @ghidraAddress 0x45a38 */
- (void)showItemInfo {
    self.backgroundColor = [UIColor colorWithWhite:kItemPanelBackgroundWhite alpha:kFullAlpha];
    self.downloadBtn.hidden = NO;
    self.linkBtn.hidden = NO;
    self.itemView.hidden = NO;
    self.detailView.hidden = NO;
    [self.artworkView startDownloadImage];
}

/** @ghidraAddress 0x44f74 */
- (void)removeItemInfo {
    self.itemInfo = nil;
    self.backgroundColor = [UIColor grayColor];
    self.artworkView.imageURL = nil;
    self.labelItemName.text = nil;
    self.labelArtistName.text = nil;
    self.labelLevels.text = nil;
    self.copyrightView.text = nil;
    self.downloadBtn.hidden = YES;
    self.linkBtn.hidden = YES;
    self.campaignID = -1;
    self.itemView.hidden = YES;
    self.detailView.hidden = YES;
    if (self.sampleDownloader != nil) {
        [self.sampleDownloader cancel];
        self.sampleDownloader = nil;
    }
    [self sampleStop];
    if (self.indicator != nil) {
        [self.indicator stopAnimating];
        [self.indicator removeFromSuperview];
    }
    if (self.labelLoading != nil) {
        [self.labelLoading removeFromSuperview];
    }
    sampleStatus = StoreCampaignSampleStatusIdle;
}

/** @ghidraAddress 0x45364 */
- (void)cancelLoading {
    // The binary body is empty; the campaign overlay has no artwork or sample load to cancel here.
}

#pragma mark - Acquisition button

/** @ghidraAddress 0x46f48 */
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

/** @ghidraAddress 0x470d4 */
- (BOOL)hasItem:(int)hasItem itemID:(int)itemID {
    if (hasItem == kCampaignItemTypeTune) {
        if ([[RBMusicManager getInstance] getMusicData:itemID] != nil) {
            NSString *path = [RBMusicManager getPathFromPurchesed:itemID];
            return [[NSFileManager defaultManager] fileExistsAtPath:path];
        }
    }
    return NO;
}

#pragma mark - Link

/** @ghidraAddress 0x45bc8 */
- (void)pushLink:(id)sender {
    if (self.itemInfo.linkURL != nil) {
        [[UIApplication sharedApplication] openURL:self.itemInfo.linkURL];
    }
}

#pragma mark - Audio sample

/** @ghidraAddress 0x454d0 */
- (void)pushSampleBtn {
    switch (sampleStatus) {
    case StoreCampaignSampleStatusIdle: {
        Downloader *downloader =
            [[Downloader alloc] initWithURL:[NSURL URLWithString:self.itemInfo.thumbnailURL]
                                       save:nil];
        self.sampleDownloader = downloader;
        [self.sampleDownloader startDownloadingWithDelegate:self];
        [self sampleViewDownloading];
        break;
    }
    case StoreCampaignSampleStatusDownloading:
    case StoreCampaignSampleStatusPlaying:
        if (self.sampleDownloader != nil) {
            [self.sampleDownloader cancel];
            self.sampleDownloader = nil;
        }
        [self sampleStop];
        break;
    default:
        break;
    }
}

/** @ghidraAddress 0x45368 */
- (void)sampleStop {
    if ([[RBBGMManager getInstance] isPushMusic]) {
        [[RBBGMManager getInstance] StopMusic:g_flFlashMinOpacity];
        [[RBBGMManager getInstance] popMusic];
    }
    if (self.sampleDownloader != nil) {
        [self.sampleDownloader cancel];
        self.sampleDownloader = nil;
    }
    [self sampleViewStop];
}

/** @ghidraAddress 0x45748 */
- (void)sampleViewStop {
    [self.indicatorSample stopAnimating];
    [self.sampleBtn setImage:[UIImage imageWithName:kSampleStopGlyphName]
                    forState:UIControlStateNormal];
    sampleStatus = StoreCampaignSampleStatusIdle;
}

/** @ghidraAddress 0x45840 */
- (void)sampleViewDownloading {
    [self.indicatorSample startAnimating];
    [self.sampleBtn setImage:[UIImage imageWithName:kSampleStopGlyphName]
                    forState:UIControlStateNormal];
    sampleStatus = StoreCampaignSampleStatusDownloading;
}

/** @ghidraAddress 0x4593c */
- (void)sampleViewPlaying {
    [self.indicatorSample stopAnimating];
    [self.sampleBtn setImage:[UIImage imageWithName:kSamplePlayGlyphName]
                    forState:UIControlStateNormal];
    sampleStatus = StoreCampaignSampleStatusPlaying;
}

/** @ghidraAddress 0x45d08 */
- (void)finishBgm:(id)notification {
    [self sampleStop];
}

#pragma mark - Downloader delegate

/** @ghidraAddress 0x45d24 */
- (void)downloaderFinished:(Downloader *)downloader {
    if (self.sampleDownloader == downloader) {
        if (sampleStatus == StoreCampaignSampleStatusDownloading) {
            [[RBBGMManager getInstance] LoadMusicWithPush:[self.sampleDownloader getData] Loop:YES];
            [[RBBGMManager getInstance] PlayMusic:0.0];
            [self sampleViewPlaying];
        }
        self.sampleDownloader = nil;
    }
}

/** @ghidraAddress 0x45ec4 */
- (void)downloaderError:(Downloader *)downloader {
    if (self.sampleDownloader == downloader) {
        [self sampleStop];
        self.sampleDownloader = nil;
        [UIAlertView showNetworkErrorWithDelegate:nil];
    }
}

/** @ghidraAddress 0x45f7c */
- (void)downloaderProceed:(Downloader *)downloader {
    // The binary body is empty; sample-download progress is not surfaced.
}

#pragma mark - Alert view delegate

/** @ghidraAddress 0x45f80 */
- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex {
    if ([self.delegate respondsToSelector:@selector(detailViewClose)]) {
        [self.delegate performSelector:@selector(detailViewClose)];
    }
}

/** @ghidraAddress 0x4605c */
- (void)alertView:(UIAlertView *)alertView didDismissWithButtonIndex:(NSInteger)buttonIndex {
    // The binary body is empty.
}

/** @ghidraAddress 0x46060 */
- (void)alertView:(UIAlertView *)alertView willDismissWithButtonIndex:(NSInteger)buttonIndex {
    // The binary body is empty.
}

/** @ghidraAddress 0x46064 */
- (void)alertViewCancel:(UIAlertView *)alertView {
    if ([self.delegate respondsToSelector:@selector(detailViewClose)]) {
        [self.delegate performSelector:@selector(detailViewClose)];
    }
}

/** @ghidraAddress 0x46140 */
- (void)didPresentAlertView:(UIAlertView *)alertView {
    [UIAlertView setExclusiveTouchForView:[[[[[UIApplication sharedApplication] keyWindow]
                                              rootViewController] presentedViewController] view]];
}

#pragma mark - Artwork

/** @ghidraAddress 0x471e8 */
- (CGSize)getArtworkMargin:(BOOL)variant {
    return CGSizeMake(kArtworkMarginX, kArtworkMarginY);
}

/** @ghidraAddress 0x471f4 */
- (CGSize)getItemSize:(BOOL)variant {
    return CGSizeMake(kItemViewWidth, kItemViewHeight);
}

/** @ghidraAddress 0x47208 */
- (void)setArtwork:(UIImage *)artwork {
    if (artwork == nil) {
        return;
    }
    if (artwork.size.width == artwork.size.height) {
        BOOL isPad = IsPad();
        CGSize margin = [self getArtworkMargin:isPad];
        CGFloat yInset = isPad ? 0.0 : kSquareArtworkVariantYInset;
        CGFloat size = isPad ? kSquareArtworkSizeWide : kSquareArtworkSizeNarrow;
        self.artworkView.frame = CGRectMake(margin.width, margin.height - yInset, size, size);
    } else {
        CGSize itemSize = [self getItemSize:IsPad()];
        self.artworkView.frame = CGRectMake(0, 0, itemSize.width, itemSize.height);
    }
    self.artworkView.image = artwork;

    __weak StoreCampaignDetailViewPad *weakSelf = self;
    [UIView animateWithDuration:kArtworkFadeInDuration
                     animations:^{
                       /** @ghidraAddress 0x47460 */
                       weakSelf.artworkView.alpha = kFullAlpha;
                     }];
}

@end
