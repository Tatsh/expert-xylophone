//
//  RBTermView.m
//  REFLEC BEAT plus
//
//  Reconstructed from Ghidra project rb458, program rb458 (class RBTermView). Verified against the
//  arm64 disassembly: -setupView's and -showTermsList's theme- and font-variant-dependent frame
//  maths were recovered from the soft-float register moves that the decompiler folds into
//  pseudo-variables. This class does not reach the C++ engine, so it is a plain Objective-C (.m)
//  file.
//

#import "RBTermView.h"

#import "Downloader.h"
#import "NetworkUtil.h"
#import "RBUserSettingData.h"
#import "UIAlertView+RB.h"
#import "UIImage+RB.h"
#import "neEngineBridge.h"

// The view types stored in RBTermView.viewType. The agreement overlay defers dismissal to the base
// popup; the store terms viewer fades itself out and tears down the owning music-menu overlay.
enum {
    kTermViewTypeAgreement = 0, // Terms-of-service agreement overlay.
    kTermViewTypeStore = 1,     // Store terms viewer.
};

// The music-menu popup fades over roughly a fifth of a second; this beat is reused throughout.
static const NSTimeInterval kTermAnimationDuration = 0.2;

// Terms-request JSON keys and response fields.
static NSString *const kTermsRequestKeyTarget = @"target";
static NSString *const kTermsRequestKeyType = @"type";
static NSString *const kTermsResponseKeyList = @"list";
static NSString *const kTermFieldType = @"type";
static NSString *const kTermFieldTitle = @"title";
static NSString *const kTermFieldURL = @"url";
static NSString *const kTermFieldContents = @"contents";

// The POST content type for the terms endpoints.
static NSString *const kTermsRequestContentType = @"application/json";

// Terms artwork asset names.
static NSString *const kGradationImageName = @"23_terms/tos_grad";
static NSString *const kTermButtonImageName = @"23_terms/tos_btn";

// The default terms title shown before a term is selected.
static NSString *const kTermsDefaultTitle = @"規約等および";

// The term-button title format: the term's numeric tag rendered as a decimal string.
static NSString *const kTermTagFormat = @"%zd";

// Grey-scale colour components used to build the popup's translucent chrome.
static const CGFloat kColorWhitePanel = 0.2;    // The dark panel white component.
static const CGFloat kColorWhiteGray = 0.6;     // The dimming overlay white component.
static const CGFloat kColorWhiteTermText = 0.8; // The term body text colour white component.
static const CGFloat kColorAlphaHalf = 0.5;
static const CGFloat kColorAlphaOpaque = 1.0;

// Corner radii for the gradation overlay in the wide and themed layouts, and its inset in the
// themed (Colette/Limelight) wide layout.
static const CGFloat kGradationCornerRadiusWide = 10.0;
static const CGFloat kGradationCornerRadiusThemed = 5.0;
static const CGFloat kGradationInsetThemed = 2.0;

// The title label font size and the fraction of the title bar height its baseline is centred on.
static const CGFloat kTitleFontSize = 22.0;
static const CGFloat kTitleBarHeightFraction = 0.7; // 7.0 / 10.0.
static const CGFloat kHalf = 0.5;

// The classic-theme content-origin reference the popup content is pushed up by, and the wide
// classic fallback offset used when the base panel origin cannot be measured.
static const CGFloat kClassicContentTopReference = 188.0;
static const CGFloat kClassicContentFallbackOffset = 12.0;

// The content-view top inset applied to the list, body, and text views. It is theme- and
// font-variant-dependent: the wide layout insets the classic theme less than the themed skins;
// the tall layout insets only the themed skins.
static const CGFloat kContentTopInsetWideThemed = 64.0;  // Colette/Limelight wide.
static const CGFloat kContentTopInsetWideClassic = 32.0; // Classic wide.
static const CGFloat kContentTopInsetTallThemed = 32.0;  // Colette/Limelight tall.

// The loading spinner is scaled to 1.5x via its layer transform.
static const float kIndicatorTransformScale = 1.5f;

// The back button geometry: a fixed width, and a height inset below the gradation overlay.
static const CGFloat kBackButtonWidth = 100.0;
static const CGFloat kBackButtonHeightInset = -24.0;

// The term text view's container inset (top, left, bottom, right) and body font size.
static const CGFloat kTermTextInsetVertical = 10.0;
static const CGFloat kTermTextInsetHorizontal = 5.0;
static const CGFloat kTermBodyFontSize = 16.0;

// Terms-list button-row geometry. The wide (font-variant) layout uses larger metrics than the tall
// layout; the list content width is the content-view width divided by the visible fraction.
static const CGFloat kTermListStartYWide = 64.0;
static const CGFloat kTermListStartYTall = 32.0;
static const CGFloat kTermButtonWidthTall = 300.0;
static const CGFloat kTermButtonVisibleFraction = 0.8;
static const CGFloat kTermRowHeightWide = 60.0;
static const CGFloat kTermRowHeightTall = 50.0;
static const CGFloat kTermRowGapWide = 50.0;
static const CGFloat kTermRowGapTall = 30.0;

// The term button's background cap-inset fraction and edge bias, and its title edge insets.
static const CGFloat kTermButtonCapFraction = 0.5;
static const CGFloat kTermButtonCapBias = -1.0;
static const CGFloat kTermButtonTitleInsetTop = 1.0;
static const CGFloat kTermButtonTitleInsetSide = 5.0;
static const CGFloat kTermButtonTitleInsetBottom = 8.0;

// The autoresizing mask applied to the gradation overlay and term buttons, transcribed verbatim
// from the binary's raw flag values.
static const UIViewAutoresizing kGradationAutoresizingMask = (UIViewAutoresizing)0x3f;
static const UIViewAutoresizing kTermButtonAutoresizingMask = (UIViewAutoresizing)0x25;
static const UIViewAutoresizing kIndicatorAutoresizingMask = (UIViewAutoresizing)0x2d;

@implementation RBTermView

#pragma mark Lifecycle

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self != nil) {
        [self setMusicMenuPopupViewType:RBMusicMenuPopupViewTypeTerms];
        self.termsList = nil;
        self.terms = [[NSMutableDictionary alloc] init];
        [self setupView];
    }
    self.isFirstRequest = YES;
    self.isAnimating = NO;
    return self;
}

// The binary's -dealloc only chains to super; under ARC that teardown is automatic, so no explicit
// -dealloc is needed.

#pragma mark Configuration

- (void)setViewTypeStore {
    self.viewType = kTermViewTypeStore;
}

#pragma mark Layout

- (void)setupView {
    [super setupView];

    NSInteger thema = [RBUserSettingData sharedInstance].thema;

    // The content top inset the classic theme pushes the base panel, background, and content view
    // up by. For the classic theme it is measured from the base panel geometry (or a fixed
    // fallback when the panel origin is unavailable); the other themes leave it at zero.
    CGFloat contentTopInset = 0.0;
    if (thema == RBUserSettingDataThemeClassic) {
        if (GetFontVariantFlag() == kFontVariantDefault) {
            contentTopInset = kClassicContentFallbackOffset;
        } else {
            CGFloat baseY = self.baseView.frame.origin.y;
            CGRect background = self.backgroundImageView.frame;
            contentTopInset = kClassicContentTopReference - baseY;
            self.backgroundImageView.frame = CGRectMake(background.origin.x,
                                                        background.origin.y - contentTopInset,
                                                        background.size.width,
                                                        background.size.height);
            CGRect content = self.contentView.frame;
            self.contentView.frame = CGRectMake(content.origin.x,
                                                content.origin.y - contentTopInset,
                                                content.size.width,
                                                content.size.height);
        }
    }

    // The gradation overlay is drawn over the content. The Colette and Limelight themes reuse the
    // base popup's gradation view; the classic theme builds its own and raises the title bar.
    UIImage *gradationImage = [UIImage imageWithName:kGradationImageName];
    if (thema == RBUserSettingDataThemeLimelight || thema == RBUserSettingDataThemeColette) {
        self.gradationImageView.image = nil;
        self.gradationImageView.image = gradationImage;
        self.gradationImageView.layer.cornerRadius = kGradationCornerRadiusWide;
        self.gradationImageView.layer.masksToBounds = YES;
        self.gradationImageView.frame = CGRectMake(kGradationInsetThemed,
                                                   kGradationInsetThemed,
                                                   gradationImage.size.width,
                                                   gradationImage.size.height);
    } else if (thema == RBUserSettingDataThemeClassic) {
        self.gradationImageView = [[UIImageView alloc] initWithImage:gradationImage];
        self.gradationImageView.layer.cornerRadius = kGradationCornerRadiusThemed;
        self.gradationImageView.autoresizingMask = kGradationAutoresizingMask;
        self.gradationImageView.layer.masksToBounds = YES;
        self.gradationImageView.frame = CGRectMake(
            kGradationInsetThemed, 0.0, gradationImage.size.width, gradationImage.size.height);
        [self.baseView addSubview:self.gradationImageView];
        [self.baseView bringSubviewToFront:self.titleImageView];
    }

    // The title bar image is centred over the base panel; its origin is truncated to whole points.
    int titleXWhole =
        (int)(self.gradationImageView.frame.size.width - self.titleImageView.frame.size.width);
    int titleYWhole =
        (int)(self.gradationImageView.frame.size.height - self.titleImageView.frame.size.height);
    self.titleImageView.frame = CGRectMake((double)(titleXWhole >> 1),
                                           (double)(titleYWhole >> 1),
                                           self.titleImageView.frame.size.width,
                                           self.titleImageView.frame.size.height);
    self.titleImageView.alpha = 0.0;

    UILabel *titleLabel = [[UILabel alloc] initWithFrame:CGRectZero];
    titleLabel.font = [UIFont boldSystemFontOfSize:kTitleFontSize];
    titleLabel.textColor = UIColor.whiteColor;
    titleLabel.text = kTermsDefaultTitle;
    [titleLabel sizeToFit];
    titleLabel.frame =
        CGRectMake((self.titleImageView.frame.size.width - titleLabel.frame.size.width) * kHalf,
                   (self.titleImageView.frame.size.height * kTitleBarHeightFraction -
                    titleLabel.frame.size.height) *
                       kHalf,
                   titleLabel.frame.size.width,
                   titleLabel.frame.size.height);
    [self.baseView addSubview:titleLabel];
    self.titleView = titleLabel;

    self.backgroundColor = [UIColor colorWithWhite:kColorWhitePanel alpha:kColorAlphaHalf];

    // The content-view top inset used to position the list, body, and text views. The wide layout
    // uses a fixed inset per theme; the tall layout uses a smaller one for the themed skins.
    NSInteger themaInset = [RBUserSettingData sharedInstance].thema;
    CGFloat contentInset;
    if (GetFontVariantFlag() == kFontVariantDefault) {
        contentInset =
            (themaInset != RBUserSettingDataThemeClassic) ? kContentTopInsetTallThemed : 0.0;
    } else if (themaInset == RBUserSettingDataThemeClassic) {
        contentInset = kContentTopInsetWideClassic;
    } else {
        contentInset = kContentTopInsetWideThemed;
    }

    self.contentView.backgroundColor = [UIColor colorWithWhite:kColorWhitePanel
                                                         alpha:kColorAlphaOpaque];

    // The dimming overlay covers the content while loading; it starts hidden.
    self.grayView = [[UIView alloc] initWithFrame:self.bounds];
    self.grayView.backgroundColor = [UIColor colorWithWhite:kColorWhiteGray alpha:kColorAlphaHalf];
    self.grayView.hidden = YES;
    [self addSubview:self.grayView];

    // The loading spinner, scaled up and centred, hidden while stopped.
    self.indicatorView = [[UIActivityIndicatorView alloc] init];
    [self.indicatorView.layer setValue:@(kIndicatorTransformScale) forKeyPath:@"transform.scale"];
    self.indicatorView.center = self.center;
    self.indicatorView.autoresizingMask = kIndicatorAutoresizingMask;
    self.indicatorView.hidesWhenStopped = YES;
    [self addSubview:self.indicatorView];

    CGFloat contentWidth = self.contentView.frame.size.width;
    CGFloat contentHeight = self.contentView.frame.size.height;

    // The scrolling terms list fills the content below the inset; it starts fully transparent.
    self.termsListView = [[UIScrollView alloc]
        initWithFrame:CGRectMake(0.0, contentInset, contentWidth, contentHeight - contentInset)];
    self.termsListView.alpha = 0.0;
    [self.contentView addSubview:self.termsListView];

    // The term-body container occupies the same region, starting transparent.
    self.termView = [[UIView alloc]
        initWithFrame:CGRectMake(0.0, contentInset, contentWidth, contentHeight - contentInset)];
    self.termView.alpha = 0.0;
    self.termView.backgroundColor = [UIColor colorWithWhite:kColorWhitePanel
                                                      alpha:kColorAlphaOpaque];
    [self.contentView addSubview:self.termView];

    // The back button returns from a term body to the list; it starts hidden.
    self.backButton = [UIButton buttonWithType:UIButtonTypeSystem];
    [self.backButton setTitle:nil forState:UIControlStateNormal];
    [self.backButton sizeToFit];
    self.backButton.frame =
        CGRectMake(0.0,
                   0.0,
                   kBackButtonWidth,
                   self.gradationImageView.frame.size.height + kBackButtonHeightInset);
    [self.backButton addTarget:self
                        action:@selector(showTermsList)
              forControlEvents:UIControlEventTouchUpInside];
    self.backButton.exclusiveTouch = YES;
    self.backButton.hidden = YES;
    [self.baseView addSubview:self.backButton];

    // The term-body text view fills the body container, non-selectable, and reads back the classic
    // top inset measured above.
    self.termTextView =
        [[UITextView alloc] initWithFrame:CGRectMake(0.0,
                                                     contentTopInset,
                                                     self.termView.frame.size.width,
                                                     self.termView.frame.size.height)];
    self.termTextView.textContainerInset = UIEdgeInsetsMake(kTermTextInsetVertical,
                                                            kTermTextInsetHorizontal,
                                                            kTermTextInsetVertical,
                                                            kTermTextInsetHorizontal);
    self.termTextView.textColor = [UIColor colorWithWhite:kColorWhiteTermText
                                                    alpha:kColorAlphaOpaque];
    self.termTextView.backgroundColor = [UIColor colorWithWhite:kColorWhitePanel
                                                          alpha:kColorAlphaOpaque];
    self.termTextView.selectable = NO;
    [self.termView addSubview:self.termTextView];

    [self loadList];
}

#pragma mark Networking

- (void)loadList {
    [self startLoadAnimation];

    NSDictionary *body = @{kTermsRequestKeyTarget : GetRegionCode()};
    NSData *postData = [Downloader dictionaryToJsonData:body];
    __weak RBTermView *weakSelf = self;
    self.downloader = [[Downloader alloc] initWithURL:[NetworkUtil termList]
                                                 post:postData
                                          contentType:kTermsRequestContentType];
    [weakSelf.downloader
        startDownloadingWithProceed:^{
          /** @ghidraAddress 0x35d180 */
          // Global no-op proceed block.
        }
        success:^{
          /** @ghidraAddress 0x111be8 */
          // Parse the JSON list into termsList, then show it (or the network-error alert) and stop
          // the spinner, all marshalled to the main queue.
          NSDictionary *json = [weakSelf.downloader getDataInJSON];
          weakSelf.termsList = json[kTermsResponseKeyList];
          if (weakSelf.termsList == nil) {
              dispatch_async(dispatch_get_main_queue(), ^{
                /** @ghidraAddress 0x111e04 (error branch) */
                [UIAlertView showNetworkErrorWithDelegate:weakSelf];
                [weakSelf endLoadAnimation];
              });
          } else {
              dispatch_async(dispatch_get_main_queue(), ^{
                /** @ghidraAddress 0x111e04 */
                [weakSelf showTermsList];
              });
          }
          dispatch_async(dispatch_get_main_queue(), ^{
            /** @ghidraAddress 0x111ed8 */
            [weakSelf endLoadAnimation];
          });
        }
        failure:^{
          /** @ghidraAddress 0x111f48 */
          // Schedule the network-error alert and spinner stop on the main queue.
          dispatch_async(dispatch_get_main_queue(), ^{
            /** @ghidraAddress 0x111fc0 */
            [UIAlertView showNetworkErrorWithDelegate:weakSelf];
            [weakSelf endLoadAnimation];
          });
        }];
}

- (void)loadDetail:(id)termID {
    [self startLoadAnimation];

    NSDictionary *body = @{
        kTermsRequestKeyTarget : GetRegionCode(),
        kTermsRequestKeyType : @([termID integerValue])
    };
    NSData *postData = [Downloader dictionaryToJsonData:body];
    __weak RBTermView *weakSelf = self;
    self.downloader = [[Downloader alloc] initWithURL:[NetworkUtil termFetch]
                                                 post:postData
                                          contentType:kTermsRequestContentType];
    [weakSelf.downloader
        startDownloadingWithProceed:^{
          /** @ghidraAddress 0x35d370 */
          // Global no-op proceed block.
        }
        success:^{
          /** @ghidraAddress 0x113468 */
          // Cache the JSON body keyed by the term id and show it (or an error), then stop the
          // spinner, all on the main queue.
          NSDictionary *data = [weakSelf.downloader getDataInJSON];
          if (data == nil) {
              dispatch_async(dispatch_get_main_queue(), ^{
                /** @ghidraAddress 0x113700 */
                [weakSelf endLoadAnimation];
              });
          } else {
              weakSelf.terms[termID] = data;
              dispatch_async(dispatch_get_main_queue(), ^{
                /** @ghidraAddress 0x11365c */
                [weakSelf showTermView:termID];
              });
          }
          dispatch_async(dispatch_get_main_queue(), ^{
            /** @ghidraAddress 0x11375c */
            [weakSelf endLoadAnimation];
          });
        }
        failure:^{
          /** @ghidraAddress 0x11380c */
          // Schedule the terms network-error alert and spinner stop on the main queue.
          dispatch_async(dispatch_get_main_queue(), ^{
            /** @ghidraAddress 0x113884 */
            [UIAlertView showNetworkErrorWithDelegate:weakSelf];
            [weakSelf endLoadAnimation];
          });
        }];
}

#pragma mark Presentation

- (void)showTermsList {
    // Fade the term body out if it is currently shown, and restore the default title.
    if (self.termView.alpha == kColorAlphaOpaque) {
        [UIView animateWithDuration:kTermAnimationDuration
                         animations:^{
                           /** @ghidraAddress 0x112ac4 */
                           self.termView.alpha = 0.0;
                           [self setTermsTitle:kTermsDefaultTitle];
                         }];
    }
    self.backButton.hidden = YES;

    // The list start Y and the term-button width, height, and row gap are font-variant-dependent.
    BOOL isFontVariant = GetFontVariantFlag() != kFontVariantDefault;
    CGFloat listStartY = isFontVariant ? kTermListStartYWide : kTermListStartYTall;
    int buttonWidth = kTermButtonWidthTall;
    if (!isFontVariant) {
        buttonWidth = (int)(self.contentView.frame.size.width / kTermButtonVisibleFraction);
    }
    CGFloat rowHeight = isFontVariant ? kTermRowHeightWide : kTermRowHeightTall;
    CGFloat rowGap = isFontVariant ? kTermRowGapWide : kTermRowGapTall;

    if (self.termsList != nil) {
        CGFloat centreX = self.contentView.frame.size.width * kHalf;
        CGFloat currentY = listStartY;
        for (NSDictionary *term in self.termsList) {
            // Reuse an existing button in the list whose tag already matches this term's type,
            // otherwise build a new one.
            UIButton *existing = nil;
            for (UIView *subview in self.termsListView.subviews) {
                if ([subview isKindOfClass:UIButton.class] &&
                    subview.tag == [term[kTermFieldType] integerValue]) {
                    existing = (UIButton *)subview;
                    break;
                }
            }

            UIButton *button = existing;
            if (button == nil) {
                button = [UIButton buttonWithType:UIButtonTypeSystem];
                UIImage *face = [UIImage imageWithName:kTermButtonImageName];
                face = [face
                    resizableImageWithCapInsets:UIEdgeInsetsMake(
                                                    face.size.height * kTermButtonCapFraction +
                                                        kTermButtonCapBias,
                                                    face.size.width * kTermButtonCapFraction +
                                                        kTermButtonCapBias,
                                                    face.size.height * kTermButtonCapFraction +
                                                        kTermButtonCapBias,
                                                    face.size.width * kTermButtonCapFraction +
                                                        kTermButtonCapBias)];
                [button setBackgroundImage:face forState:UIControlStateNormal];
                button.frame = CGRectMake(
                    centreX - (double)(buttonWidth >> 1), currentY, (double)buttonWidth, rowHeight);
                [button addTarget:self
                              action:@selector(selectTerm:)
                    forControlEvents:UIControlEventTouchUpInside];
                button.exclusiveTouch = YES;
                button.userInteractionEnabled = YES;
                button.autoresizingMask = kTermButtonAutoresizingMask;
                button.titleEdgeInsets = UIEdgeInsetsMake(kTermButtonTitleInsetTop,
                                                          kTermButtonTitleInsetSide,
                                                          kTermButtonTitleInsetBottom,
                                                          kTermButtonTitleInsetSide);
                [self.termsListView addSubview:button];
                button.tag = [term[kTermFieldType] integerValue];
                currentY += rowGap + rowHeight;
            }

            [button setTitle:term[kTermFieldTitle] forState:UIControlStateNormal];
            [button setTitleColor:UIColor.whiteColor forState:UIControlStateNormal];
        }

        self.termsListView.contentSize = CGSizeMake(self.termsListView.frame.size.width, currentY);
    }

    // Fade the list and title in after a short delay.
    [UIView animateWithDuration:kTermAnimationDuration
        delay:kTermAnimationDuration
        options:UIViewAnimationOptionCurveEaseInOut
        animations:^{
          /** @ghidraAddress 0x112b50 */
          self.termsListView.alpha = kColorAlphaOpaque;
          self.titleView.alpha = kColorAlphaOpaque;
        }
        completion:^(BOOL finished) {
          /** @ghidraAddress 0x112c08 */
          self.isAnimating = NO;
        }];
}

- (void)showTermView:(id)termID {
    // Fade the list out if it is currently shown.
    if (self.termsListView.alpha == kColorAlphaOpaque) {
        [UIView animateWithDuration:kTermAnimationDuration
                         animations:^{
                           /** @ghidraAddress 0x113fd0 */
                           self.termView.alpha = 0.0;
                         }];
    }
    // The binary reads the current theme here without using the result.
    (void)[RBUserSettingData sharedInstance].thema;

    __weak RBTermView *weakSelf = self;

    // Set the title from the matching term descriptor.
    if (self.termsList != nil) {
        for (NSDictionary *term in weakSelf.termsList) {
            if ([[term[kTermFieldType] stringValue] isEqualToString:termID]) {
                [self setTermsTitle:term[kTermFieldTitle]];
                break;
            }
        }
    }

    // Load the cached body text and set the body font.
    weakSelf.termTextView.text = weakSelf.terms[termID][kTermFieldContents];
    weakSelf.termTextView.font = [UIFont systemFontOfSize:kTermBodyFontSize];

    // Fade the body and title in after a short delay.
    [UIView animateWithDuration:kTermAnimationDuration
        delay:kTermAnimationDuration
        options:UIViewAnimationOptionCurveEaseInOut
        animations:^{
          /** @ghidraAddress 0x11403c */
          weakSelf.termView.alpha = kColorAlphaOpaque;
          weakSelf.titleView.alpha = kColorAlphaOpaque;
        }
        completion:^(BOOL finished) {
          /** @ghidraAddress 0x114130 */
          weakSelf.isAnimating = NO;
          weakSelf.backButton.hidden = NO;
          dispatch_async(dispatch_get_main_queue(), ^{
            /** @ghidraAddress 0x114248 */
            [weakSelf endLoadAnimation];
          });
        }];
}

- (void)selectTerm:(id)sender {
    NSString *termID = [NSString stringWithFormat:kTermTagFormat, ((UIButton *)sender).tag];

    // If the matching term carries an external URL, open it and stop.
    if (self.termsList != nil) {
        for (NSDictionary *term in self.termsList) {
            if ([[term[kTermFieldType] stringValue] isEqualToString:termID] &&
                term[kTermFieldURL] != nil && [term[kTermFieldURL] length] != 0) {
                [UIApplication.sharedApplication openURL:[NSURL URLWithString:term[kTermFieldURL]]];
                return;
            }
        }
    }

    // Otherwise show the cached body, or fetch it when not yet cached.
    if (self.terms[termID] == nil) {
        [self loadDetail:termID];
    } else {
        [self showTermView:termID];
    }
}

- (void)setTermsTitle:(id)termsTitle {
    // The classic theme reads the base panel origin here without using the result.
    if ([RBUserSettingData sharedInstance].thema == RBUserSettingDataThemeClassic) {
        (void)self.baseView.frame.origin.y;
    }

    self.titleView.alpha = 0.0;
    self.titleView.text = termsTitle;
    [self.titleView sizeToFit];
    CGFloat titleBarWidth = self.titleImageView.frame.size.width;
    CGFloat titleBarHeight = self.titleImageView.frame.size.height;
    self.titleView.frame = CGRectMake(
        (titleBarWidth - self.titleView.frame.size.width) * kHalf,
        (titleBarHeight * kTitleBarHeightFraction - self.titleView.frame.size.height) * kHalf,
        self.titleView.frame.size.width,
        self.titleView.frame.size.height);
}

#pragma mark Loading animation

- (void)startLoadAnimation {
    if (self.isUseGrayView) {
        self.grayView.hidden = NO;
    }
    [self.indicatorView startAnimating];
}

- (void)endLoadAnimation {
    if (self.isUseGrayView) {
        self.grayView.hidden = YES;
    }
    [self.indicatorView stopAnimating];
}

#pragma mark Animation

- (void)hideAnimation {
    // This method gates on the base popup's animating flag, distinct from RBTermView's own
    // isAnimating flag that guards the list and body transitions.
    if (self.animating) {
        return;
    }
    if (self.viewType == kTermViewTypeAgreement) {
        [super hideAnimation];
        return;
    }
    self.animating = YES;
    [UIView animateWithDuration:kTermAnimationDuration
        animations:^{
          /** @ghidraAddress 0x1117fc */
          self.alpha = 0.0;
        }
        completion:^(BOOL finished) {
          /** @ghidraAddress 0x111820 */
          self.alpha = 0.0;
          [self removeFromSuperview];
          self.animating = NO;
          [self.musicMenuView setShowView:nil];
          self.musicMenuView = nil;
        }];
}

#pragma mark Alert view delegate

- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex {
    if (self.isFirstRequest) {
        self.animating = NO;
        alertView.delegate = nil;
        [self hideAnimation];
    }
}

@end
