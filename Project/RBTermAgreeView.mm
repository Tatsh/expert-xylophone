//
//  RBTermAgreeView.mm
//  REFLEC BEAT plus
//
//  Reconstructed from Ghidra project rb458, program rb458 (class RBTermAgreeView). This is an
//  Objective-C++ file because the send-agree completion reaches the C++ SoundEffectManager engine
//  singleton. The frame geometry in -setupView, -layoutSubviews, and -scrollViewDidScroll: was
//  recovered from the arm64 soft-float register moves that the decompiler folds into pseudo
//  doubles; the theme and iPad idiom branches are de-inlined into helpers below.
//

#import "RBTermAgreeView.h"

#import <math.h>

#import "AppDelegate.h"
#import "Downloader.h"
#import "NetworkUtil.h"
#import "RBUserSettingData.h"
#import "RBViewController.h"
#import "UIAlertView+RB.h"
#import "UIImage+RB.h"
#import "UIView+RB.h"
#import "neEngineBridge.h"

// The themed sound-effect slot played once the acceptance has been submitted (the unlock chime).
constexpr int kSoundEffectUnlocked = 9;

// The terms version this build submits and stores on acceptance.
static NSString *const kTermsVersion = @"1.0.0";

// Keys carried in the fetch and agree request payloads.
static NSString *const kParamUserID = @"user_id";
static NSString *const kParamTarget = @"target";
static NSString *const kParamTermsType = @"terms_type";
static NSString *const kParamTermsVersion = @"terms_version";
static NSString *const kResponseStatusKey = @"status";
static NSString *const kTermsContentsKey = @"contents";

// The POST body content type used by both the fetch and the agree requests.
// @ghidraAddress 0x364140
static NSString *const kJSONContentType = @"application/json";

// The alert tags that distinguish the two retry alerts in -alertView:clickedButtonAtIndex:.
constexpr NSInteger kAlertTagTermsFetch = 0;
constexpr NSInteger kAlertTagSendAgree = 1;

// A server status of zero means the acceptance succeeded.
constexpr int kServerStatusOK = 0;

// The mascot artwork frames, animated in two-frame loops while the reader scrolls.
static NSString *const kMascotFrame1Name = @"23_terms/as_mascot_01";
static NSString *const kMascotFrame2Name = @"23_terms/as_mascot_02";
static NSString *const kMascotFinishFrame1Name = @"23_terms/as_mascot_03";
static NSString *const kMascotFinishFrame2Name = @"23_terms/as_mascot_04";

// The scroll-progress track image, split into a track and a fill by -setupView.
static NSString *const kProgressTrackName = @"dl_info";

// The gradation overlay drawn over the content for the Limelight and Colette themes.
static NSString *const kGradationImageName = @"23_terms/tos_grad";

// Layout metrics recovered from the disassembly. The wide (default iPad idiom) and narrow
// (compact iPad idiom) layouts use different values, matching the two branches in -setupView.
constexpr CGFloat kMascotFrameDuration = 0.5;
constexpr CGFloat kHalf = 0.5;
constexpr CGFloat kButtonRowHeightWide = 40.0;
constexpr CGFloat kButtonRowHeightNarrow = 30.0;
constexpr CGFloat kPastelViewHeightWide = 96.0;    // @ghidraAddress 0x2ec6f0
constexpr CGFloat kPastelViewHeightNarrow = 140.0; // @ghidraAddress 0x2ec6c0
constexpr CGFloat kMascotXOffsetWide = -23.0;
constexpr CGFloat kMascotXOffsetNarrow = -46.0; // @ghidraAddress 0x310648
constexpr CGFloat kMascotWidthWide = 46.0;      // @ghidraAddress 0x301030
constexpr CGFloat kMascotHeightWide = 63.0;     // @ghidraAddress 0x301800
constexpr CGFloat kMascotWidthNarrow =
    46.0; // @ghidraAddress 0x301030 (via g_dMenuButtonWidthNarrow)
constexpr CGFloat kMascotHeightNarrow = 126.0; // @ghidraAddress 0x301048
constexpr CGFloat kTrackClipWidthWide = 155.0; // @ghidraAddress 0x2ee9d8
constexpr CGFloat kTrackClipHeightWide = 7.0;
constexpr CGFloat kTrackClipHeightNarrow = 14.0;
constexpr CGFloat kPastelTopInset = 10.0;
constexpr CGFloat kSixths = 6.0;
constexpr CGFloat kProgressBarSegments = 4.0;

// The dimmed alpha used for buttons and mascot artwork before the reader reaches the bottom.
constexpr CGFloat kDimmedAlpha = 0.0;
constexpr CGFloat kFullAlpha = 1.0;

// The content-view background and popup background whites/alphas.
constexpr CGFloat kPopupBackgroundAlpha = 0.5;

// The terms text font sizes for the wide and narrow iPad idioms.
constexpr CGFloat kTermsFontSizeWide = 16.0;
constexpr CGFloat kTermsFontSizeNarrow = 15.0;

// The text-container inset applied to the terms text view (top/left/bottom/right = 10/5/10/5).
constexpr CGFloat kTermsTextInsetVertical = 10.0;
constexpr CGFloat kTermsTextInsetHorizontal = 5.0;

// The corner radius applied to the gradation overlay for each iPad idiom.
constexpr CGFloat kGradationCornerRadiusWide = 10.0;
constexpr CGFloat kGradationCornerRadiusNarrow = 5.0;

// The Classic-theme gradation overlay origin and the wide-variant title-bar drop.
constexpr CGFloat kGradationOriginX = 2.0;
constexpr CGFloat kGradationWideOriginYInset = 2.0;
constexpr CGFloat kClassicTitleDrop = 16.0;

// The show/hide transition durations. The show duration doubles as the show delay.
// @ghidraAddress 0x2eedc0 (the shared g_dMascotMessageAnimDuration engine constant)
constexpr NSTimeInterval kShowTransitionDuration = 0.2;
constexpr NSTimeInterval kHideTransitionDuration = 0.25;

// The activity-indicator scale applied to the loading spinner.
constexpr CGFloat kIndicatorScale = 1.5;

// The white and alpha of the popup dimming background and the grey loading overlay.
// @ghidraAddress 0x2eedc0 (background white), 0x2ec6f8 (grey-overlay white)
constexpr CGFloat kPopupBackgroundWhite = 0.2;
constexpr CGFloat kGrayViewWhite = 0.9;

// The origin-y baseline the wide Classic layout shifts the content panel up to.
// @ghidraAddress 0x2ec6f8 (g_dPopupWideContentOriginYBase)
constexpr CGFloat kPopupWideContentOriginYBase = 100.0;

@interface RBTermAgreeView ()

// Fade the popup out, tear it down, and clear the presenting controller's reference.
// @ghidraAddress 0x1c6a3c
- (void)_hideAnimation;

@end

@implementation RBTermAgreeView

#pragma mark Lifecycle

- (instancetype)initWithFrame:(CGRect)frame termType:(int)type {
    if ((self = [super initWithFrame:frame])) {
        [self setMusicMenuPopupViewType:RBMusicMenuPopupViewTypeTerms];
        self.terms = [NSMutableDictionary dictionary];
        self.type = type;
        [self setupView];
    }
    // The binary clears the view's own load flag unconditionally, even when super returned nil.
    self.isAnimating = NO;
    return self;
}

#pragma mark Setup

// The gradation overlay behind the terms content differs per theme: the Classic theme (theme 0)
// creates a fresh overlay image view; the Limelight and Colette themes reuse the base overlay and
// only re-clip it. Extracted from the two branches of -setupView.
- (void)setupGradationOverlay {
    UIImage *gradation = [UIImage imageWithName:kGradationImageName];
    RBUserSettingDataTheme theme = [RBUserSettingData sharedInstance].thema;
    CGFloat cornerRadius = !IsPad() ? kGradationCornerRadiusNarrow : kGradationCornerRadiusWide;
    if (theme == RBUserSettingDataThemeLimelight || theme == RBUserSettingDataThemeColette) {
        self.gradationImageView.image = nil;
        self.gradationImageView.image = gradation;
        self.gradationImageView.layer.cornerRadius = cornerRadius;
        self.gradationImageView.layer.masksToBounds = YES;
        self.gradationImageView.frame = CGRectMake(kTermsTextInsetVertical,
                                                   kTermsTextInsetVertical,
                                                   gradation.size.width,
                                                   gradation.size.height);
    } else if (theme == RBUserSettingDataThemeClassic) {
        self.gradationImageView = [[UIImageView alloc] initWithImage:gradation];
        self.gradationImageView.layer.cornerRadius = kGradationCornerRadiusNarrow;
        self.gradationImageView.autoresizingMask =
            UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight |
            UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleBottomMargin;
        self.gradationImageView.layer.masksToBounds = YES;
        CGFloat originY = !IsPad() ? kTermsTextInsetVertical + kGradationWideOriginYInset : 0.0;
        self.gradationImageView.frame =
            CGRectMake(kGradationOriginX, originY, gradation.size.width, gradation.size.height);
        [self.baseView addSubview:self.gradationImageView];
        [self.baseView bringSubviewToFront:self.titleImageView];
    }
}

// Builds the animated mascot, the scroll-progress track, and the progress fill inside pastelView.
// The wide and narrow iPad idioms use different frame metrics; extracted from the two branches
// of -setupView.
- (void)setupPastelArtwork {
    BOOL narrow = !IsPad();
    CGFloat mascotXOffset = narrow ? kMascotXOffsetNarrow : kMascotXOffsetWide;
    CGFloat mascotWidth = narrow ? kMascotWidthNarrow : kMascotWidthWide;
    CGFloat mascotHeight = narrow ? kMascotHeightNarrow : kMascotHeightWide;
    CGFloat trackClipHeight = narrow ? kTrackClipHeightNarrow : kTrackClipHeightWide;
    CGFloat pastelWidth = self.pastelView.width;

    UIImageView *mascot = [[UIImageView alloc] init];
    mascot.animationImages =
        @[ [UIImage imageWithName:kMascotFrame1Name], [UIImage imageWithName:kMascotFrame2Name] ];
    mascot.animationDuration = kMascotFrameDuration;
    mascot.animationRepeatCount = 0;
    mascot.frame =
        CGRectMake(pastelWidth / kSixths + mascotXOffset, 0.0, mascotWidth, mascotHeight);
    [self.pastelView addSubview:mascot];
    self.pastelImageView = mascot;

    UIImageView *mascotFinish = [[UIImageView alloc] init];
    mascotFinish.animationImages = @[
        [UIImage imageWithName:kMascotFinishFrame1Name],
        [UIImage imageWithName:kMascotFinishFrame2Name]
    ];
    mascotFinish.animationDuration = kMascotFrameDuration;
    mascotFinish.animationRepeatCount = 0;
    mascotFinish.frame =
        CGRectMake(pastelWidth / kSixths + mascotXOffset, 0.0, mascotWidth, mascotHeight);
    mascotFinish.alpha = kDimmedAlpha;
    [self.pastelView addSubview:mascotFinish];
    self.pastelImageFinishView = mascotFinish;

    UIImage *trackSource = [UIImage imageWithName:kProgressTrackName useCache:NO];
    UIImage *trackImage =
        [trackSource clipImageWithRect:CGRectMake(0.0, 0.0, kTrackClipWidthWide, trackClipHeight)];
    UIImage *fillImage = [trackSource
        clipImageWithRect:CGRectMake(0.0, trackClipHeight, kTrackClipWidthWide, trackClipHeight)];
    if (!narrow) {
        // The wide layout makes the fill resizable through -resizableImageWithCapInsets:. The exact
        // cap insets are a disasm-level blocker: setupView is ~2548 instructions and the decompiler
        // did not thread the inset arguments into this call, so they are not recovered here.
        fillImage = [fillImage resizableImageWithCapInsets:UIEdgeInsetsZero];
    }

    UIImageView *track = [[UIImageView alloc] initWithImage:trackImage];
    track.frame = CGRectMake(pastelWidth / kSixths,
                             mascotHeight,
                             (pastelWidth * kProgressBarSegments) / kSixths,
                             trackClipHeight);
    [self.pastelView addSubview:track];
    self.trackImageView = track;

    UIImageView *fill = [[UIImageView alloc] initWithImage:fillImage];
    fill.frame = CGRectMake(0.0, 0.0, fillImage.size.width, fillImage.size.height);
    fill.clipsToBounds = YES;
    [self.trackImageView addSubview:fill];
    self.progressImageView = fill;
}

- (void)setupView {
    [super setupView];

    // Shift the content and background panels up for the wide layout of the Classic theme so the
    // taller terms text view fits; the other themes keep the base layout. The exact per-edge frame
    // arithmetic below the offset is a soft-float pattern recovered from the disassembly.
    CGFloat contentTopOffset = 0.0;
    if ([RBUserSettingData sharedInstance].thema == RBUserSettingDataThemeClassic && IsPad()) {
        contentTopOffset = self.baseView.y - kPopupWideContentOriginYBase;
        self.contentView.frame = CGRectMake(self.contentView.x,
                                            self.contentView.y - contentTopOffset,
                                            self.contentView.width,
                                            self.contentView.height);
        self.backgroundImageView.frame = CGRectMake(self.backgroundImageView.x,
                                                    self.backgroundImageView.y - contentTopOffset,
                                                    self.backgroundImageView.width,
                                                    self.backgroundImageView.height);
    }

    [self setupGradationOverlay];

    // Centre the title bar over the gradation overlay for the wide variant; the narrow variant only
    // nudges it down for the Classic theme.
    if (IsPad()) {
        int centerX = static_cast<int>(self.gradationImageView.width - self.titleImageView.width);
        int centerY = static_cast<int>(self.gradationImageView.height - self.titleImageView.height);
        self.titleImageView.frame = CGRectMake(
            centerX >> 1, centerY >> 1, self.titleImageView.width, self.titleImageView.height);
    } else if ([RBUserSettingData sharedInstance].thema == RBUserSettingDataThemeClassic) {
        self.titleImageView.frame =
            CGRectMake(self.titleImageView.x,
                       static_cast<int>(self.titleImageView.y + kClassicTitleDrop),
                       self.titleImageView.width,
                       self.titleImageView.height);
    } else {
        int centerX = static_cast<int>(self.gradationImageView.width - self.titleImageView.width);
        int centerY = static_cast<int>(self.gradationImageView.height - self.titleImageView.height);
        self.titleImageView.frame = CGRectMake(
            centerX >> 1, centerY >> 1, self.titleImageView.width, self.titleImageView.height);
    }

    self.backgroundColor = [UIColor colorWithWhite:kPopupBackgroundWhite
                                             alpha:kPopupBackgroundAlpha];
    self.contentView.backgroundColor = [UIColor colorWithWhite:kFullAlpha alpha:kFullAlpha];

    // The scrolling terms text view fills the content view below the shifted top.
    UIView *termView =
        [[UIView alloc] initWithFrame:CGRectMake(0.0,
                                                 contentTopOffset,
                                                 self.contentView.width,
                                                 self.contentView.height - contentTopOffset)];
    termView.alpha = kDimmedAlpha;
    [self.contentView addSubview:termView];
    self.termView = termView;

    // The grey loading overlay and the loading spinner span the whole popup.
    UIView *grayView = [[UIView alloc] initWithFrame:self.bounds];
    grayView.backgroundColor = [UIColor colorWithWhite:kGrayViewWhite alpha:kPopupBackgroundAlpha];
    grayView.hidden = YES;
    [self addSubview:grayView];
    self.grayView = grayView;

    UIActivityIndicatorView *indicator = [[UIActivityIndicatorView alloc] init];
    [indicator.layer setValue:@(kIndicatorScale) forKeyPath:@"transform.scale"];
    indicator.center = self.center;
    indicator.autoresizingMask =
        UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleLeftMargin |
        UIViewAutoresizingFlexibleBottomMargin | UIViewAutoresizingFlexibleRightMargin;
    indicator.hidesWhenStopped = YES;
    [self addSubview:indicator];
    self.indicatorView = indicator;

    CGFloat buttonRowHeight = !IsPad() ? kButtonRowHeightNarrow : kButtonRowHeightWide;

    // The Agree and Cancel buttons share a row along the bottom of the content view; the Agree
    // button starts disabled and dimmed until the reader scrolls to the bottom.
    UIButton *agree = [UIButton buttonWithType:UIButtonTypeRoundedRect];
    [agree setTitle:NSLocalizedString(@"OK", nil) forState:UIControlStateNormal];
    [agree addTarget:self
                  action:@selector(selectAgree)
        forControlEvents:UIControlEventTouchUpInside];
    agree.exclusiveTouch = YES;
    agree.userInteractionEnabled = YES;
    agree.enabled = NO;
    agree.alpha = kDimmedAlpha;
    [self.contentView addSubview:agree];
    self.agreeButton = agree;

    UIButton *cancel = [UIButton buttonWithType:UIButtonTypeRoundedRect];
    [cancel setTitle:NSLocalizedString(@"Cancel", nil) forState:UIControlStateNormal];
    [cancel addTarget:self
                  action:@selector(selectDisAgree)
        forControlEvents:UIControlEventTouchUpInside];
    cancel.exclusiveTouch = YES;
    cancel.userInteractionEnabled = YES;
    cancel.alpha = kDimmedAlpha;
    [self.contentView addSubview:cancel];
    self.disAgreeButton = cancel;

    // The terms text view fills the term view, leaving room for the button row.
    UITextView *textView =
        [[UITextView alloc] initWithFrame:CGRectMake(0.0,
                                                     contentTopOffset,
                                                     self.termView.width,
                                                     self.termView.height - buttonRowHeight)];
    textView.textContainerInset = UIEdgeInsetsMake(kTermsTextInsetVertical,
                                                   kTermsTextInsetHorizontal,
                                                   kTermsTextInsetVertical,
                                                   kTermsTextInsetHorizontal);
    textView.delegate = self;
    [self.termView addSubview:textView];
    self.termTextView = textView;

    // The mascot and scroll-progress artwork live in pastelView, laid out only for the narrow
    // iPad idiom.
    if (!IsPad()) {
        UIView *pastel = [[UIView alloc]
            initWithFrame:CGRectMake((self.contentView.width * kHalf) - self.width * kHalf,
                                     self.height + (self.contentView.height - self.width) * -kHalf +
                                         kPastelTopInset,
                                     self.contentView.width,
                                     kPastelViewHeightNarrow)];
        [self addSubview:pastel];
        self.pastelView = pastel;
        [self setupPastelArtwork];
    } else {
        UIView *pastel = [[UIView alloc]
            initWithFrame:CGRectMake((self.contentView.width * kHalf) - self.width * kHalf,
                                     self.height + (self.contentView.height - self.width) * -kHalf +
                                         kPastelTopInset,
                                     self.contentView.width,
                                     kPastelViewHeightWide)];
        [self addSubview:pastel];
        self.pastelView = pastel;
        [self setupPastelArtwork];
    }

    self.pastelView.alpha = kDimmedAlpha;
    [self loadDetail];
}

#pragma mark Layout

- (void)layoutSubviews {
    // Re-centre pastelView under the content view for the current iPad idiom, then fade it in
    // when it fits above the popup bottom and keep the terms text scrolled to its saved offset.
    CGFloat pastelHeight = !IsPad() ? kPastelViewHeightNarrow : kPastelViewHeightWide;
    self.pastelView.frame =
        CGRectMake((self.width - self.contentView.width) * kHalf,
                   self.height + (self.contentView.height - self.width) * -kHalf + kPastelTopInset,
                   self.contentView.width,
                   pastelHeight);
    self.pastelView.alpha =
        self.pastelView.bottom <= self.height ? kFullAlpha : self.pastelView.alpha;
    self.termTextView.contentOffset = self.termTextView.contentOffset;
}

#pragma mark Terms flow

- (void)showTermView {
    __weak RBTermAgreeView *weakSelf = self;
    CGFloat fontSize = !IsPad() ? kTermsFontSizeNarrow : kTermsFontSizeWide;
    weakSelf.termTextView.text = weakSelf.terms[kTermsContentsKey];
    weakSelf.termTextView.font = [UIFont systemFontOfSize:fontSize];
    // The scrollable overflow: the text laid out at unbounded height, minus the visible height.
    weakSelf.termTextViewHeight = static_cast<float>(
        [weakSelf.termTextView sizeThatFits:CGSizeMake(weakSelf.termTextView.width, HUGE_VALF)]
            .height -
        weakSelf.termTextView.frame.size.height);
    weakSelf.termTextView.text = weakSelf.terms[kTermsContentsKey];
    weakSelf.termTextView.font = [UIFont systemFontOfSize:fontSize];
    [UIView animateWithDuration:kShowTransitionDuration
        delay:kShowTransitionDuration
        options:UIViewAnimationOptionLayoutSubviews
        animations:^{
          /** @ghidraAddress 0x1c726c */
          weakSelf.termView.alpha = kFullAlpha;
          weakSelf.agreeButton.alpha = kFullAlpha;
          weakSelf.disAgreeButton.alpha = kFullAlpha;
          if (weakSelf.pastelView.bottom <= weakSelf.height) {
              weakSelf.pastelView.alpha = kFullAlpha;
          } else {
              weakSelf.pastelView.alpha = weakSelf.pastelView.alpha;
          }
          [weakSelf.pastelImageView startAnimating];
          [weakSelf.pastelImageFinishView startAnimating];
        }
        completion:^(BOOL finished) {
          /** @ghidraAddress 0x1c7574 */
          weakSelf.isAnimating = NO;
          dispatch_async(dispatch_get_main_queue(), ^{
            /** @ghidraAddress 0x1c7628 */
            [weakSelf endLoadAnimation];
          });
        }];
}

- (void)loadDetail {
    [self startLoadAnimation];
    __weak RBTermAgreeView *weakSelf = self;
    NSDictionary *params = @{kParamTarget : GetRegionCode(), kParamTermsType : @(self.type)};
    NSData *body = [Downloader dictionaryToJsonData:params];
    self.downloader = [[Downloader alloc] initWithURL:[NetworkUtil termFetch]
                                                 post:body
                                          contentType:kJSONContentType];
    [weakSelf.downloader startDownloadingWithProceed:nil
        success:^(id response) {
          /** @ghidraAddress 0x1c7cc0 */
          id json = [response getDataInJSON];
          if (json) {
              weakSelf.terms = json;
              dispatch_async(dispatch_get_main_queue(), ^{
                /** @ghidraAddress 0x1c7e60 */
                [weakSelf showTermView];
              });
          } else {
              dispatch_async(dispatch_get_main_queue(), ^{
                /** @ghidraAddress 0x1c7ebc */
                [UIAlertView showConnectRetryOrCancel:weakSelf].tag = kAlertTagTermsFetch;
              });
          }
          dispatch_async(dispatch_get_main_queue(), ^{
            /** @ghidraAddress 0x1c7f64 */
            [weakSelf endLoadAnimation];
          });
        }
        failure:^(id response) {
          /** @ghidraAddress 0x1c7fd4 */
          dispatch_async(dispatch_get_main_queue(), ^{
            /** @ghidraAddress 0x1c804c */
            [UIAlertView showConnectRetryOrCancel:weakSelf].tag = kAlertTagTermsFetch;
            [weakSelf endLoadAnimation];
          });
        }];
}

- (void)selectAgree {
    self.agreeButton.userInteractionEnabled = NO;
    self.disAgreeButton.userInteractionEnabled = NO;
    [self sendAgree];
}

- (void)selectDisAgree {
    self.agreeButton.userInteractionEnabled = NO;
    self.disAgreeButton.userInteractionEnabled = NO;
    [self _hideAnimation];
}

- (void)sendAgree {
    [self startLoadAnimation];
    __weak RBTermAgreeView *weakSelf = self;
    NSDictionary *params = @{
        kParamUserID : [AppDelegate getServerData][0],
        kParamTarget : GetRegionCode(),
        kParamTermsType : @(self.type),
        kParamTermsVersion : kTermsVersion
    };
    NSData *body = [Downloader dictionaryToJsonData:params];
    self.downloader = [[Downloader alloc] initWithURL:[NetworkUtil termAgree]
                                                 post:body
                                          contentType:kJSONContentType];
    [weakSelf.downloader startDownloadingWithProceed:nil
        success:^(id response) {
          /** @ghidraAddress 0x1c8540 */
          id json = [response getDataInJSON];
          if (json[kResponseStatusKey] && [json[kResponseStatusKey] intValue] == kServerStatusOK) {
              [RBUserSettingData sharedInstance].termVersion = weakSelf.terms[kParamTermsVersion];
              [[RBUserSettingData sharedInstance] save];
              [[AppDelegate appDelegate] setLatestTermsVersion:weakSelf.terms[kParamTermsVersion]];
              [[RBUserSettingData sharedInstance] save];
              dispatch_async(dispatch_get_main_queue(), ^{
                /** @ghidraAddress 0x1c8908 */
                SoundEffectManager::GetInstance()->PlayThemedSoundEffect(kSoundEffectUnlocked);
                [weakSelf endLoadAnimation];
                if (weakSelf.delegate) {
                    [weakSelf.delegate didFinishedSendAgree];
                }
                [weakSelf _hideAnimation];
              });
          } else {
              dispatch_async(dispatch_get_main_queue(), ^{
                /** @ghidraAddress 0x1c8a30 */
                [UIAlertView showConnectRetryOrCancel:weakSelf].tag = kAlertTagSendAgree;
                [weakSelf endLoadAnimation];
              });
          }
        }
        failure:^(id response) {
          /** @ghidraAddress 0x1c8b20 */
          dispatch_async(dispatch_get_main_queue(), ^{
            /** @ghidraAddress 0x1c8b98 */
            [UIAlertView showConnectRetryOrCancel:weakSelf].tag = kAlertTagSendAgree;
            [weakSelf endLoadAnimation];
          });
        }];
}

#pragma mark Loading indicator

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

#pragma mark Dismissal

// The superclass hideAnimation is intentionally overridden to do nothing: the terms popup dismisses
// itself through the private -_hideAnimation, which also tears down the parent controller's
// reference.
- (void)hideAnimation {
}

- (void)_hideAnimation {
    [self.pastelImageView stopAnimating];
    [self.pastelImageFinishView stopAnimating];
    self.animating = YES;
    __weak RBTermAgreeView *weakSelf = self;
    [UIView animateWithDuration:kHideTransitionDuration
        animations:^{
          /** @ghidraAddress 0x1c6b98 */
          weakSelf.alpha = kDimmedAlpha;
        }
        completion:^(BOOL finished) {
          /** @ghidraAddress 0x1c6bbc */
          weakSelf.alpha = kDimmedAlpha;
          weakSelf.parentViewController.termAgreeView = nil;
          [weakSelf removeFromSuperview];
        }];
}

#pragma mark UIScrollViewDelegate

- (void)scrollViewDidScroll:(UIScrollView *)scrollView {
    // The scroll fraction (clamped to 0..1) drives the progress fill width and the mascot position.
    float fraction = static_cast<float>(scrollView.contentOffset.y / self.termTextViewHeight);
    if (fraction < 0.0f) {
        fraction = 0.0f;
    } else if (fraction > 1.0f) {
        fraction = 1.0f;
    }
    self.progressImageView.frame = CGRectMake(0.0,
                                              0.0,
                                              fraction * self.trackImageView.frame.size.width,
                                              self.trackImageView.frame.size.height);

    CGFloat pastelWidth = self.pastelView.width;
    CGFloat mascotX;
    if (!IsPad()) {
        mascotX = ((fraction * kProgressBarSegments + 1.0) / kSixths) * pastelWidth +
                  kMascotXOffsetNarrow;
    } else {
        mascotX =
            ((fraction * kProgressBarSegments + 1.0) / kSixths) * pastelWidth + kMascotXOffsetWide;
    }
    self.pastelImageView.frame = CGRectMake(
        mascotX, self.pastelImageView.y, self.pastelImageView.width, self.pastelImageView.height);
    self.pastelImageFinishView.frame = CGRectMake(
        mascotX, self.pastelImageView.y, self.pastelImageView.width, self.pastelImageView.height);

    // Enable the Agree button once the reader has scrolled to (or past) the bottom. The bottom test
    // (contentOffset.y + visible height > contentSize.height) was recovered from the disassembly,
    // where the decompiler folded the visible-height read into a duplicate contentSize term.
    if (!self.agreeButton.isEnabled) {
        if (scrollView.contentOffset.y + scrollView.frame.size.height >
            scrollView.contentSize.height) {
            self.agreeButton.enabled = YES;
        }
    }

    // Cross-fade the scrolling mascot to the finished mascot at the bottom.
    if (fraction == 1.0f) {
        self.pastelImageView.alpha = kDimmedAlpha;
        self.pastelImageFinishView.alpha = kFullAlpha;
    } else {
        self.pastelImageView.alpha = kFullAlpha;
        self.pastelImageFinishView.alpha = kDimmedAlpha;
    }
}

#pragma mark UIAlertViewDelegate

- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex {
    if (alertView.tag == kAlertTagTermsFetch) {
        if (buttonIndex == 0) {
            self.animating = NO;
            alertView.delegate = nil;
            [self _hideAnimation];
        } else {
            [self loadDetail];
        }
    } else if (alertView.tag == kAlertTagSendAgree) {
        if (buttonIndex == 0) {
            self.agreeButton.userInteractionEnabled = YES;
            self.disAgreeButton.userInteractionEnabled = YES;
        } else {
            [self sendAgree];
        }
    }
}

- (void)alertView:(UIAlertView *)alertView didDismissWithButtonIndex:(NSInteger)buttonIndex {
}

- (void)alertView:(UIAlertView *)alertView willDismissWithButtonIndex:(NSInteger)buttonIndex {
}

- (void)alertViewCancel:(UIAlertView *)alertView {
}

#pragma mark Rotation

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)orientation {
    return orientation == UIInterfaceOrientationPortrait ||
           orientation == UIInterfaceOrientationPortraitUpsideDown;
}

- (UIInterfaceOrientationMask)supportedInterfaceOrientations {
    return UIInterfaceOrientationMaskPortrait | UIInterfaceOrientationMaskPortraitUpsideDown;
}

- (BOOL)shouldAutorotate {
    return YES;
}

@end
