/** @file
 * The phone extend-note detail view controller implementation. It presents a single extend note's
 * artwork, labels, description, and terms link, plays the sample BGM from a tap on the artwork,
 * and drives the purchase / download action button through its hosting page controller.
 *
 * Reconstructed from Ghidra project rb458, program rb458 (class
 * @c RBStoreExtendNoteDetailViewController, image base 0x100000000). @ghidraAddress values are
 * offsets relative to the image base.
 */

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
#import "neEngineBridge.h"

// The shared translucent-panel white value defined in another store screen; declared here rather
// than redefined, matching how the store page controller reaches it.
extern const CGFloat g_dRBWebViewGrayViewWhite; // @ghidraAddress 0x2ec708

// Runtime-populated localised NSString globals held in the application's __DATA segment
// (zero-initialised at link time and assigned during startup). They are declared here so the
// implementation can reference them by name; they are never defined in the reconstructed source.
extern NSString *const g_pStorePriceButtonFormat;    // @ghidraAddress 0x3cfb78 buy-price title.
extern NSString *const g_pStoreInstallButtonTitle;   // @ghidraAddress 0x3cfc00 "install" title.
extern NSString *const g_pStoreInstalledButtonTitle; // @ghidraAddress 0x3cfc08 "installed" title.
// @ghidraAddress 0x3cfc10 "installing" title.
extern NSString *const g_pStoreInstallingButtonTitle;

// The navigation-item title of the detail screen.
static NSString *const kDetailNavigationTitle = @"info";

// The difficulty-level label format.
static NSString *const kLevelLabelFormat = @"LEVEL %d";

// The terms-of-service link label text.
static NSString *const kTermsLinkText = @"Terms of Use";

// Sample-image asset names.
static NSString *const kArtworkPlaceholderImageName = @"09_store/store_jacket_80";
static NSString *const kSamplePlayGlyphImageName = @"09_store/store_play";
static NSString *const kNewBadgeImageName = @"09_store/store_new";
static NSString *const kDetailBackgroundImageName = @"09_store/store_pack_bg_2";

// The value the sample-play index holds when no sample has been queued.
static const int kNoSamplePlayedIndex = -1;

// The state machine driving the sample overlay, stored in the sampleStatus ivar.
typedef NS_ENUM(NSInteger, SampleStatus) {
    SampleStatusIdle = 0,        /*!< No sample is loaded. */
    SampleStatusDownloading = 1, /*!< The sample is being downloaded. */
    SampleStatusPlaying = 2,     /*!< The sample is playing. */
};

// UIControlState values passed to the action button.
static const NSUInteger kControlStateNormal = 0;
static const NSUInteger kControlStateDisabled = 2;

// The valid autorotation orientations: portrait (1) and portrait-upside-down (2) only.
static const NSInteger kFirstSupportedOrientation = 1;
static const NSInteger kSupportedOrientationCount = 2;

// Layout metrics (points), recovered from the __const double loads referenced by the disassembly.
static const CGFloat kArtworkOrigin = 8.0;             // Artwork frame origin (x and y).
static const CGFloat kArtworkSide = 80.0;              // Artwork square side.
static const CGFloat kItemViewHeight = 140.0;          // Upper card height.
static const CGFloat kLabelBlockRightInset = -104.0;   // Right-hand inset of the label block.
static const CGFloat kMusicLabelWidthBase = 96.0;      // Base width used for the music-name label.
static const CGFloat kLabelBlockOriginX = 96.0;        // X origin of the label block.
static const CGFloat kLabelRowStep = 50.0;             // Vertical step between label rows.
static const CGFloat kDetailWidthInset = -20.0;        // Detail-card content inset.
static const CGFloat kDescriptionInsetX = 10.0;        // Description text-view left inset.
static const CGFloat kSectionTopInset = 104.0;         // Content top offset for the detail card.
static const CGFloat kArtworkBorderWidth = 1.0;        // Artwork layer border width.
static const CGFloat kArtworkShadowOffset = 2.0;       // Artwork layer shadow offset (x and y).
static const CGFloat kArtworkShadowOpacity = 0.15;     // Artwork layer shadow opacity.
static const CGFloat kArtworkShadowRadius = 2.0;       // Artwork layer shadow radius.
static const CGFloat kMusicLabelFontSize = 18.0;       // Music-name label bold font size.
static const CGFloat kArtistLabelFontSize = 12.0;      // Artist-name label font size.
static const CGFloat kLevelLabelFontSize = 12.0;       // Difficulty-level label bold font size.
static const CGFloat kButtonFontSize = 10.0;           // Action-button title font size.
static const CGFloat kDescriptionFontSize = 12.0;      // Description text-view font size.
static const CGFloat kBannerCornerRadius = 8.0;        // Banner layer corner radius.
static const CGFloat kButtonCornerRadius = 4.0;        // Action-button corner radius.
static const CGFloat kSampleViewAlpha = 0.4;           // Sample dimming overlay alpha.
static const CGFloat kBorderWhite = 143.0 / 255.0;     // Detail-card border white.
static const CGFloat kLineViewWhite = 0.71;            // Divider-line white.
static const CGFloat kTermsTextWhite = 0.478431372549; // Terms-link label white.
static const CGFloat kDividerHeight = 30.0;            // Divider strip height.
static const CGFloat kSeparatorTop = 5.0;              // Vertical padding above wrapped rows.
static const CGFloat kTermsLinkFontSize = 10.0;        // Terms-link label font size.
static const CGFloat kBannerHeight = 25.0;             // Banner view height.
static const CGFloat kDescriptionTopInset = 34.0;      // Description/label left inset.

// The maximum number of font-shrink iterations tried while fitting the music-name label.
static const int kMusicLabelFitAttempts = 9;

// The autoresizing masks the binary assigns, named by their flag combinations.
static const UIViewAutoresizing kMaskFlexibleWidthHeight = 0x12;    // W|H centred.
static const UIViewAutoresizing kMaskFlexibleWidthTopBottom = 0x22; // W|Top|Bottom.

@interface RBStoreExtendNoteDetailViewController () <UIAlertViewDelegate> {
    // The sample overlay state machine (see SampleStatus).
    int sampleStatus;
    // Set while the sample audio is downloading. The shipped build never reads it.
    BOOL isDownloadingSample;
    // Retained hook flag written by -setDownloadFlag:.
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

// Builds and installs the artwork image view, its sample overlay (dimming view, spinner, and
// playing glyph), and the tap recogniser that toggles the sample BGM.
- (void)buildArtworkAndSampleOverlay {
    self.artworkView = [[StoreImageView alloc]
        initWithFrame:CGRectMake(kArtworkOrigin, kArtworkOrigin, kArtworkSide, kArtworkSide)];
    [self.artworkView.layer setBorderWidth:kArtworkBorderWidth];
    [self.artworkView.layer setBorderColor:[UIColor whiteColor].CGColor];
    [self.artworkView setBackgroundColor:[UIColor whiteColor]];
    [self.artworkView.layer setShadowOffset:CGSizeMake(kArtworkShadowOffset, kArtworkShadowOffset)];
    [self.artworkView.layer setShadowColor:[UIColor blackColor].CGColor];
    [self.artworkView.layer setShadowOpacity:kArtworkShadowOpacity];
    [self.artworkView.layer setShadowRadius:kArtworkShadowRadius];
    [self.artworkView.layer setShouldRasterize:YES];
    [self.itemView addSubview:self.artworkView];
}

// Builds the music-name, artist-name, and difficulty-level labels stacked below the artwork.
- (void)buildItemLabels {
    const CGFloat labelWidth = self.view.bounds.size.width + kLabelBlockRightInset;

    self.labelMusicName = [[UILabel alloc]
        initWithFrame:CGRectMake(
                          kLabelBlockOriginX, kArtworkOrigin, labelWidth, kMusicLabelWidthBase)];
    [self.labelMusicName setNumberOfLines:2];
    [self.labelMusicName setLineBreakMode:NSLineBreakByWordWrapping];
    [self.labelMusicName setFont:[UIFont boldSystemFontOfSize:kMusicLabelFontSize]];
    [self.labelMusicName setAutoresizingMask:kMaskFlexibleWidthTopBottom];
    [self.itemView addSubview:self.labelMusicName];

    const CGFloat artistY = kArtworkOrigin + kMusicLabelWidthBase + kLabelRowStep;
    self.labelArtistName = [[UILabel alloc]
        initWithFrame:CGRectMake(
                          kLabelBlockOriginX, artistY, labelWidth, kLevelLabelFontSize * 2.0)];
    [self.labelArtistName setFont:[UIFont systemFontOfSize:kArtistLabelFontSize]];
    [self.labelArtistName setAdjustsFontSizeToFitWidth:YES];
    [self.labelArtistName setAutoresizingMask:kMaskFlexibleWidthTopBottom];
    [self.itemView addSubview:self.labelArtistName];

    const CGFloat levelY = artistY + kLevelLabelFontSize * 2.0;
    self.labelLevel = [[UILabel alloc]
        initWithFrame:CGRectMake(
                          kLabelBlockOriginX, levelY, labelWidth, kLevelLabelFontSize * 2.0)];
    [self.labelLevel setFont:[UIFont boldSystemFontOfSize:kLevelLabelFontSize]];
    [self.labelLevel setAdjustsFontSizeToFitWidth:YES];
    [self.labelLevel setAutoresizingMask:kMaskFlexibleWidthTopBottom];
    [self.itemView addSubview:self.labelLevel];
}

// Builds the purchase / download action button beneath the labels. Its frame is provisional; it is
// re-laid out by -updateLayout once the label sizes are known.
- (void)buildActionButton {
    const CGFloat levelBottom =
        kArtworkOrigin + kMusicLabelWidthBase + kLabelRowStep + kLevelLabelFontSize * 2.0;
    const CGFloat buttonOriginX = levelBottom - kArtworkOrigin + kLabelRowStep;
    self.downloadBtn =
        [[StoreButtonView alloc] initWithFrame:CGRectMake(buttonOriginX,
                                                          g_dCustomizeLayoutMetric100,
                                                          kSectionTopInset,
                                                          kBannerHeight)];
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
    [self.downloadBtn setAutoresizingMask:UIViewAutoresizingFlexibleRightMargin];
    [self.itemView addSubview:self.downloadBtn];
}

// Builds the sample overlay glyphs (dimming view, spinner, and playing icon) over the artwork.
- (void)buildSampleOverlay {
    self.sampleView = [[UIView alloc] initWithFrame:self.artworkView.frame];
    [self.sampleView setOpaque:YES];
    [self.sampleView setAlpha:0.0];
    [self.sampleView setBackgroundColor:[UIColor colorWithWhite:0.0 alpha:kSampleViewAlpha]];

    const CGFloat centreX = (CGFloat)(float)(self.artworkView.frame.size.width * 0.5);
    const CGFloat centreY = (CGFloat)(float)(self.artworkView.frame.size.height * 0.5);

    self.indicatorSample = [[UIActivityIndicatorView alloc] initWithFrame:self.sampleView.frame];
    [self.indicatorSample setActivityIndicatorViewStyle:UIActivityIndicatorViewStyleWhite];
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

// Builds the lower detail card: the banner image, the description text view, the divider strip,
// and the terms-of-service link label.
- (CGFloat)buildDetailCardBelow:(CGFloat)contentBottom {
    self.detailView = [[UIView alloc]
        initWithFrame:CGRectMake(0.0, kItemViewHeight, self.view.bounds.size.width, contentBottom)];
    [self.detailView setOpaque:YES];
    [self.detailView setBackgroundColor:[UIColor colorWithRed:g_dTranslucentAlpha
                                                        green:g_dTranslucentAlpha
                                                         blue:g_dTranslucentAlpha
                                                        alpha:1.0]];
    [self.detailView.layer setBorderColor:[UIColor colorWithWhite:kBorderWhite alpha:1.0].CGColor];
    [self.detailView setAutoresizingMask:kMaskFlexibleWidthHeight];

    self.bannerView = [[StoreImageView alloc] initWithFrame:CGRectZero];
    [self.bannerView.layer setShouldRasterize:YES];
    [self.bannerView.layer setCornerRadius:kBannerCornerRadius];
    [self.bannerView setClipsToBounds:YES];
    [self.detailView addSubview:self.bannerView];

    const CGFloat descriptionHeight = contentBottom - kDividerHeight;
    self.descriptionTextView = [[UITextView alloc]
        initWithFrame:CGRectMake(kDescriptionTopInset,
                                 kDescriptionInsetX,
                                 self.view.bounds.size.width + kDetailWidthInset,
                                 descriptionHeight)];
    [self.bannerView setAutoresizingMask:kMaskFlexibleWidthTopBottom];
    [self.descriptionTextView setBackgroundColor:[UIColor clearColor]];
    [self.descriptionTextView setEditable:NO];
    [self.descriptionTextView setScrollEnabled:NO];
    [self.descriptionTextView setFont:[UIFont systemFontOfSize:kDescriptionFontSize]];
    [self.descriptionTextView setAutoresizingMask:kMaskFlexibleWidthTopBottom];
    [self.detailView addSubview:self.descriptionTextView];

    UIView *lineView = [[UIView alloc]
        initWithFrame:CGRectMake(
                          0.0, descriptionHeight, self.view.bounds.size.width, kBannerHeight)];
    [lineView setBackgroundColor:[UIColor colorWithWhite:kLineViewWhite alpha:1.0]];
    [self.detailView addSubview:lineView];

    UILabel *termsLabel =
        [[UILabel alloc] initWithFrame:CGRectMake(kDescriptionTopInset,
                                                  0.0,
                                                  lineView.frame.size.width + kDetailWidthInset,
                                                  kBannerHeight)];
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
        // The view hierarchy already exists; just refresh its layout and button.
        [self updateLayout];
        [self selfCheckButtonText];
        return;
    }

    [self.view setOpaque:YES];
    [self.view setAutoresizingMask:kMaskFlexibleWidthHeight];
    [self.view setBackgroundColor:[UIColor grayColor]];

    self.mainView = [[UIScrollView alloc] initWithFrame:self.view.bounds];
    [self.mainView setScrollEnabled:YES];
    [self.mainView setAutoresizingMask:kMaskFlexibleWidthHeight];
    [self.view addSubview:self.mainView];

    UIImage *packBackground = [UIImage imageWithName:kDetailBackgroundImageName];

    self.itemView = [[UIView alloc]
        initWithFrame:CGRectMake(0.0, 0.0, self.view.bounds.size.width, kItemViewHeight)];
    [self.itemView setAutoresizingMask:kMaskFlexibleWidthHeight];

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

    const CGFloat detailHeight = self.view.bounds.size.height + kSectionTopInset;
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
    if (self.packinfoDownloadAlertView != nil) {
        [self.packinfoDownloadAlertView dismissWithClickedButtonIndex:0 animated:NO];
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
    return (NSInteger)(orientation - kFirstSupportedOrientation) < kSupportedOrientationCount;
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
    const CGFloat availableWidth =
        self.view.bounds.size.width + kLabelBlockRightInset + kMusicLabelWidthBase;

    // Shrink the music-name font until the text fits two rows, up to nine attempts.
    UIFont *fittedFont = nil;
    int attempt = 0;
    do {
        fittedFont = [UIFont boldSystemFontOfSize:(CGFloat)(kMusicLabelFontSize - (float)attempt)];
        CGSize fitted = [musicName sizeWithFont:fittedFont
                              constrainedToSize:CGSizeMake(availableWidth, kMusicLabelWidthBase)
                                  lineBreakMode:NSLineBreakByWordWrapping];
        ++attempt;
        if (fitted.width <= availableWidth && fitted.height <= kMusicLabelWidthBase) {
            break;
        }
    } while (attempt < kMusicLabelFitAttempts);
    [self.labelMusicName setFont:fittedFont];

    const CGFloat labelWidth = self.view.bounds.size.width + kLabelBlockRightInset;
    CGRect musicFrame = self.labelMusicName.frame;
    musicFrame.size.width = labelWidth;
    [self.labelMusicName setFrame:musicFrame];
    [self.labelMusicName sizeToFit];

    [self.descriptionTextView sizeToFit];
    [self.termLinkView sizeToFit];

    // Stack the description text view below the music labels, then the terms link below it, and
    // finally grow the detail card and scroll content to fit.
    const CGFloat descriptionTop =
        self.labelMusicName.frame.size.height + kMusicLabelWidthBase + kSeparatorTop;
    CGRect descriptionFrame = self.descriptionTextView.frame;
    descriptionFrame.origin.y = descriptionTop;
    descriptionFrame.size.width = self.view.bounds.size.width + kDetailWidthInset;
    [self.descriptionTextView setFrame:descriptionFrame];

    const CGFloat descriptionBottom =
        descriptionTop + CGRectGetHeight(descriptionFrame) + kSeparatorTop;
    const CGFloat termsHeight = CGRectGetHeight(self.termLinkView.frame);
    CGRect termsFrame = self.termLinkView.frame;
    termsFrame.origin.y = descriptionBottom;
    termsFrame.size.width = self.view.bounds.size.width;
    termsFrame.size.height = termsHeight;
    [self.termLinkView setFrame:termsFrame];

    CGRect detailFrame = self.detailView.frame;
    detailFrame.size.height = descriptionBottom + termsHeight + kSectionTopInset;
    [self.detailView setFrame:detailFrame];

    [self.mainView setContentSize:CGSizeMake(self.view.bounds.size.width,
                                             CGRectGetMaxY(self.detailView.frame) +
                                                 CGRectGetMaxY(self.detailView.frame))];
    [self.iconNew setHidden:self.info.isNew ? NO : YES];
}

#pragma mark - Action button

- (void)setButtonTextBuy {
    NSString *buyTitle = [NSString stringWithFormat:g_pStorePriceButtonFormat, @(self.info.price)];
    [self.downloadBtn setTitle:buyTitle forState:kControlStateNormal];
    [self.downloadBtn setEnabled:YES];
}

- (void)setButtonTextInstall {
    [self.downloadBtn setTitle:g_pStoreInstallButtonTitle forState:kControlStateNormal];
    [self.downloadBtn setEnabled:YES];
}

- (void)setButtonTextInstalling {
    [self.downloadBtn setTitle:g_pStoreInstallingButtonTitle forState:kControlStateDisabled];
    [self.downloadBtn setEnabled:NO];
}

- (void)setButtonTextInstalled {
    [self.downloadBtn setTitle:g_pStoreInstalledButtonTitle forState:kControlStateDisabled];
    [self.downloadBtn setEnabled:NO];
}

- (void)selfCheckButtonText {
    [self.downloadBtn setEnabled:YES];
    [self.downloadBtn setButtonColor:self.info.getButtonColor];
    [self.downloadBtn setTitle:self.info.getButtonName forState:kControlStateNormal];
    // Every state except "installed" leaves the button enabled. The binary compares the state as
    // unsigned, so the error state (-1) also disables the button.
    [self.downloadBtn setEnabled:(unsigned int)self.info.getButtonState <
                                 (unsigned int)StoreExtendNoteButtonStateInstalled];
}

#pragma mark - Selection

- (void)selectButton {
    if (_samplePlayedIndex != kNoSamplePlayedIndex) {
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
    if (_samplePlayedIndex != kNoSamplePlayedIndex) {
        if ([[RBBGMManager getInstance] isPushMusic]) {
            [[RBBGMManager getInstance] StopMusic:g_flFlashMinOpacity];
            [[RBBGMManager getInstance] popMusic];
        }
        [self sampleViewStop];
        _samplePlayedIndex = kNoSamplePlayedIndex;
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
            _samplePlayedIndex = 1;
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
