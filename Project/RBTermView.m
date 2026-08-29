#import "RBTermView.h"

#import "Downloader.h"
#import "NetworkUtil.h"
#import "RBMenuView.h"
#import "RBUserSettingData.h"
#import "UIAlertView+RB.h"
#import "UIImage+RB.h"
#import "deviceenvironment.h"

enum {
    kTermViewTypeAgreement = 0,
    kTermViewTypeStore = 1,
};

static const NSTimeInterval kTermAnimationDuration = 0.2;

static NSString *const kTermsRequestKeyTarget = @"target";
static NSString *const kTermsRequestKeyType = @"type";
static NSString *const kTermsResponseKeyList = @"list";
static NSString *const kTermFieldType = @"type";
static NSString *const kTermFieldTitle = @"title";
static NSString *const kTermFieldURL = @"url";
static NSString *const kTermFieldContents = @"contents";

static NSString *const kTermsRequestContentType = @"application/json";

static NSString *const kGradationImageName = @"23_terms/tos_grad";
static NSString *const kTermButtonImageName = @"23_terms/tos_btn";

static NSString *const kTermsDefaultTitle = @"規約等および各種注意事項";

static NSString *const kTermTagFormat = @"%zd";

static const CGFloat kColorWhitePanel = 0.2;
static const CGFloat kColorWhiteGray = 0.6;
static const CGFloat kColorWhiteTermText = 0.8;
static const CGFloat kColorAlphaHalf = 0.5;
static const CGFloat kColorAlphaOpaque = 1.0;

static const CGFloat kGradationCornerRadiusWide = 10.0;
static const CGFloat kGradationCornerRadiusThemed = 5.0;
static const CGFloat kGradationInsetThemed = 2.0;

static const CGFloat kTitleFontSize = 22.0;
static const CGFloat kTitleBarHeightFraction = 0.7;
static const CGFloat kHalf = 0.5;

static const CGFloat kClassicContentTopReference = 188.0;
static const CGFloat kClassicContentFallbackOffset = 12.0;

static const CGFloat kContentTopInsetWideThemed = 64.0;
static const CGFloat kContentTopInsetWideClassic = 32.0;
static const CGFloat kContentTopInsetTallThemed = 32.0;

static const float kIndicatorTransformScale = 1.5f;

static const CGFloat kBackButtonWidth = 100.0;
static const CGFloat kBackButtonHeightInset = -24.0;

static const CGFloat kTermTextInsetVertical = 10.0;
static const CGFloat kTermTextInsetHorizontal = 5.0;
static const CGFloat kTermBodyFontSize = 16.0;

static const CGFloat kTermListStartYWide = 64.0;
static const CGFloat kTermListStartYTall = 32.0;
static const CGFloat kTermButtonWidthTall = 300.0;
static const CGFloat kTermButtonVisibleFraction = 0.8;
static const CGFloat kTermRowHeightWide = 60.0;
static const CGFloat kTermRowHeightTall = 50.0;
static const CGFloat kTermRowGapWide = 50.0;
static const CGFloat kTermRowGapTall = 30.0;

static const CGFloat kTermButtonCapFraction = 0.5;
static const CGFloat kTermButtonCapBias = -1.0;
static const CGFloat kTermButtonTitleInsetTop = 1.0;
static const CGFloat kTermButtonTitleInsetSide = 5.0;
static const CGFloat kTermButtonTitleInsetBottom = 8.0;

// Raw autoresizing flag values as the binary stores them.
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

#pragma mark Configuration

- (void)setViewTypeStore {
    self.viewType = kTermViewTypeStore;
}

#pragma mark Layout

- (void)setupView {
    [super setupView];

    NSInteger thema = [RBUserSettingData sharedInstance].thema;

    CGFloat contentTopInset = 0.0;
    if (thema == RBUserSettingDataThemeClassic) {
        if (!IsPad()) {
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

    NSInteger themaInset = [RBUserSettingData sharedInstance].thema;
    CGFloat contentInset;
    if (!IsPad()) {
        contentInset =
            (themaInset != RBUserSettingDataThemeClassic) ? kContentTopInsetTallThemed : 0.0;
    } else if (themaInset == RBUserSettingDataThemeClassic) {
        contentInset = kContentTopInsetWideClassic;
    } else {
        contentInset = kContentTopInsetWideThemed;
    }

    self.contentView.backgroundColor = [UIColor colorWithWhite:kColorWhitePanel
                                                         alpha:kColorAlphaOpaque];

    UIView *grayView = [[UIView alloc] initWithFrame:self.bounds];
    grayView.backgroundColor = [UIColor colorWithWhite:kColorWhiteGray alpha:kColorAlphaHalf];
    grayView.hidden = YES;
    [self addSubview:grayView];
    self.grayView = grayView;

    UIActivityIndicatorView *indicatorView = [[UIActivityIndicatorView alloc] init];
    [indicatorView.layer setValue:@(kIndicatorTransformScale) forKeyPath:@"transform.scale"];
    indicatorView.center = self.center;
    indicatorView.autoresizingMask = kIndicatorAutoresizingMask;
    indicatorView.hidesWhenStopped = YES;
    [self addSubview:indicatorView];
    self.indicatorView = indicatorView;

    CGFloat contentWidth = self.contentView.frame.size.width;
    CGFloat contentHeight = self.contentView.frame.size.height;

    UIScrollView *termsListView = [[UIScrollView alloc]
        initWithFrame:CGRectMake(0.0, contentInset, contentWidth, contentHeight - contentInset)];
    termsListView.alpha = 0.0;
    [self.contentView addSubview:termsListView];
    self.termsListView = termsListView;

    UIView *termView = [[UIView alloc]
        initWithFrame:CGRectMake(0.0, contentInset, contentWidth, contentHeight - contentInset)];
    termView.alpha = 0.0;
    termView.backgroundColor = [UIColor colorWithWhite:kColorWhitePanel alpha:kColorAlphaOpaque];
    [self.contentView addSubview:termView];
    self.termView = termView;

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

    UITextView *termTextView =
        [[UITextView alloc] initWithFrame:CGRectMake(0.0,
                                                     contentTopInset,
                                                     self.termView.frame.size.width,
                                                     self.termView.frame.size.height)];
    termTextView.textContainerInset = UIEdgeInsetsMake(kTermTextInsetVertical,
                                                       kTermTextInsetHorizontal,
                                                       kTermTextInsetVertical,
                                                       kTermTextInsetHorizontal);
    termTextView.textColor = [UIColor colorWithWhite:kColorWhiteTermText alpha:kColorAlphaOpaque];
    termTextView.backgroundColor = [UIColor colorWithWhite:kColorWhitePanel
                                                     alpha:kColorAlphaOpaque];
    termTextView.selectable = NO;
    [self.termView addSubview:termTextView];
    self.termTextView = termTextView;

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
        startDownloadingWithProceed:^(Downloader *downloader) {
          /** @ghidraAddress 0x35d180 */
        }
        success:^(Downloader *downloader) {
          /** @ghidraAddress 0x111be8 */
          weakSelf.termsList = [weakSelf.downloader getDataInJSON][kTermsResponseKeyList];
          if (weakSelf.termsList == nil) {
              dispatch_async(dispatch_get_main_queue(), ^{
                /** @ghidraAddress 0x111e60 */
                [UIAlertView showNetworkErrorWithDelegate:weakSelf];
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
        failure:^(Downloader *downloader) {
          /** @ghidraAddress 0x111f48 */
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
        startDownloadingWithProceed:^(Downloader *downloader) {
          /** @ghidraAddress 0x35d370 */
        }
        success:^(Downloader *downloader) {
          /** @ghidraAddress 0x113468 */
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
        failure:^(Downloader *downloader) {
          /** @ghidraAddress 0x11380c */
          dispatch_async(dispatch_get_main_queue(), ^{
            /** @ghidraAddress 0x113884 */
            [UIAlertView showNetworkErrorWithDelegate:weakSelf];
            [weakSelf endLoadAnimation];
          });
        }];
}

#pragma mark Presentation

- (void)showTermsList {
    if (self.termView.alpha == kColorAlphaOpaque) {
        [UIView animateWithDuration:kTermAnimationDuration
                         animations:^{
                           /** @ghidraAddress 0x112ac4 */
                           self.termView.alpha = 0.0;
                           [self setTermsTitle:kTermsDefaultTitle];
                         }];
    }
    self.backButton.hidden = YES;

    BOOL isPad = IsPad();
    CGFloat listStartY = isPad ? kTermListStartYWide : kTermListStartYTall;
    int buttonWidth = kTermButtonWidthTall;
    if (!isPad) {
        buttonWidth = (int)(self.contentView.frame.size.width / kTermButtonVisibleFraction);
    }
    CGFloat rowHeight = isPad ? kTermRowHeightWide : kTermRowHeightTall;
    CGFloat rowGap = isPad ? kTermRowGapWide : kTermRowGapTall;

    if (self.termsList != nil) {
        CGFloat centreX = self.contentView.frame.size.width * kHalf;
        CGFloat currentY = listStartY;
        for (NSDictionary *term in self.termsList) {
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
    if (self.termsListView.alpha == kColorAlphaOpaque) {
        [UIView animateWithDuration:kTermAnimationDuration
                         animations:^{
                           /** @ghidraAddress 0x113fd0 */
                           self.termView.alpha = 0.0;
                         }];
    }
    (void)[RBUserSettingData sharedInstance].thema; // The binary discards this read.

    __weak RBTermView *weakSelf = self;

    if (self.termsList != nil) {
        for (NSDictionary *term in weakSelf.termsList) {
            if ([[term[kTermFieldType] stringValue] isEqualToString:termID]) {
                [self setTermsTitle:term[kTermFieldTitle]];
                break;
            }
        }
    }

    weakSelf.termTextView.text = weakSelf.terms[termID][kTermFieldContents];
    weakSelf.termTextView.font = [UIFont systemFontOfSize:kTermBodyFontSize];

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

    if (self.termsList != nil) {
        for (NSDictionary *term in self.termsList) {
            if ([[term[kTermFieldType] stringValue] isEqualToString:termID] &&
                term[kTermFieldURL] != nil && [term[kTermFieldURL] length] != 0) {
                [UIApplication.sharedApplication openURL:[NSURL URLWithString:term[kTermFieldURL]]];
                return;
            }
        }
    }

    if (self.terms[termID] == nil) {
        [self loadDetail:termID];
    } else {
        [self showTermView:termID];
    }
}

- (void)setTermsTitle:(id)termsTitle {
    if ([RBUserSettingData sharedInstance].thema == RBUserSettingDataThemeClassic) {
        (void)self.baseView.frame.origin.y; // The binary discards this read.
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
    // Gates on the base popup's animating flag, not RBTermView's own isAnimating.
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

/** @ghidraAddress 0x114848 */
- (void)alertView:(UIAlertView *)alertView didDismissWithButtonIndex:(NSInteger)buttonIndex {
    // The binary provides an empty implementation.
}

/** @ghidraAddress 0x11484c */
- (void)alertView:(UIAlertView *)alertView willDismissWithButtonIndex:(NSInteger)buttonIndex {
    // The binary provides an empty implementation.
}

/** @ghidraAddress 0x114850 */
- (void)alertViewCancel:(UIAlertView *)alertView {
    // The binary provides an empty implementation.
}

#pragma mark - Rotation

/** @ghidraAddress 0x114854 */
- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
    return interfaceOrientation == UIInterfaceOrientationPortrait ||
           interfaceOrientation == UIInterfaceOrientationPortraitUpsideDown;
}

/** @ghidraAddress 0x114864 */
- (UIInterfaceOrientationMask)supportedInterfaceOrientations {
    return UIInterfaceOrientationMaskPortrait | UIInterfaceOrientationMaskPortraitUpsideDown;
}

/** @ghidraAddress 0x11486c */
- (BOOL)shouldAutorotate {
    return YES;
}

@end
