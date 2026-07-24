//
//  RBTermPhoneViewController.mm
//  REFLEC BEAT plus
//
//  Reconstructed from Ghidra project rb458, program rb458 (class RBTermPhoneViewController). This is
//  an Objective-C++ file because -pushBarBtnBack: reaches the C++ SoundEffectManager engine
//  singleton. The -showTermsList button-row geometry was recovered from the arm64 soft-float
//  register moves that the decompiler folds into pseudo doubles; the theme and iPad idiom branches
//  were read from the disassembly.
//

#import "RBTermPhoneViewController.h"

#import "AppDelegate.h"
#import "Downloader.h"
#import "NetworkUtil.h"
#import "RBTermDetailPhoneViewController.h"
#import "RBUserSettingData.h"
#import "UIAlertView+RB.h"
#import "UIImage+RB.h"
#import "deviceenvironment.h"
#import "engineglobals.h"
#import "soundeffectmanager.h"

// The themed sound-effect slot played when the agreement view type is dismissed via "back".
constexpr int kSoundEffectCancel = 4;

// The view types stored in RBTermPhoneViewController.viewType. The agreement type restores the
// navigation bar chrome and plays the cancel sound; the store terms viewer leaves the bar as-is.
enum {
    kTermViewTypeAgreement = 0, // Terms-of-service agreement.
    kTermViewTypeStore = 1,     // Store terms viewer.
};

// Terms-request JSON keys and per-term response fields.
static NSString *const kTermsRequestKeyTarget = @"target";
static NSString *const kTermsResponseKeyList = @"list";
static NSString *const kTermFieldType = @"type";
static NSString *const kTermFieldTitle = @"title";
static NSString *const kTermFieldURL = @"url";

// The POST content type for the terms endpoint.
// @ghidraAddress 0x364140
static NSString *const kTermsRequestContentType = @"application/json";

// The navigation-bar title shown by this controller.
static NSString *const kTermsNavTitle = @"20歳未満";

// The term-button title format: the term's numeric tag rendered as a decimal string.
static NSString *const kTermTagFormat = @"%zd";

// The term-button artwork asset name.
static NSString *const kTermButtonImageName = @"23_terms/tos_btn";

// The music-menu popup fades over roughly a fifth of a second; this beat is reused throughout.
// @ghidraAddress 0x2eedc0 (the shared g_dMascotMessageAnimDuration engine constant, 0.2)
extern const double g_dMascotMessageAnimDuration;

// The dimming-overlay white component (0.6).
// @ghidraAddress 0x2ec708 (g_dRBWebViewGrayViewWhite)
extern const double g_dRBWebViewGrayViewWhite;

// The wide (iPad) fixed term-button width (300.0).
// @ghidraAddress 0x2ee930 (g_dMascotMessageMaxWidthPad)
extern const double g_dMascotMessageMaxWidthPad;

// The themed content top inset used for the list start-Y (32.0).
// @ghidraAddress 0x2ee9b0 (g_dLayoutMetricThirtyTwo)
extern const double g_dLayoutMetricThirtyTwo;

// The dark navigation-bar tint white component (14/255).
// @ghidraAddress 0x2eef50 (g_dRBNavBarTintWhite)
extern const double g_dRBNavBarTintWhite;

// The term-button row height (50.0).
// @ghidraAddress 0x2ec6e0 (g_dTermButtonRowHeight)
extern const double g_dTermButtonRowHeight;

// The pad list start-Y table indexed by (thema == classic): the themed themes start at 64.0, the
// classic theme at 32.0.
// @ghidraAddress 0x302d40 (g_adTermPhoneListStartYPad)
static const CGFloat kTermListStartYPadThemed = 64.0;
static const CGFloat kTermListStartYPadClassic = 32.0;

// The term button is centred on the content by shifting it left by half its (fixed 300pt) width.
// @ghidraAddress 0x30bf18 (g_dTermPhoneButtonHalfWidthNeg, -150.0)
static const CGFloat kTermButtonHalfWidthNegative = -150.0;

// Grey-scale alpha components used to build the view's translucent chrome.
static const CGFloat kColorAlphaHalf = 0.5;
static const CGFloat kColorAlphaOpaque = 1.0;

// The navigation-bar title font size and the loading spinner's layer scale.
static const CGFloat kTitleFontSize = 16.0;
static const float kIndicatorTransformScale = 1.5f;
static const CGFloat kHalf = 0.5;

// The vertical gap between the list start-Y and the first term button, and between subsequent rows.
static const CGFloat kTermButtonTopGap = 30.0;
static const CGFloat kTermRowGap = 15.0;

// The term button's background cap-inset fraction and edge bias, and its title edge insets.
static const CGFloat kTermButtonCapFraction = 0.5;
static const CGFloat kTermButtonCapBias = -1.0;
static const CGFloat kTermButtonTitleInsetTop = 1.0;
static const CGFloat kTermButtonTitleInsetSide = 5.0;
static const CGFloat kTermButtonTitleInsetBottom = 8.0;

// The autoresizing mask applied to the term buttons, transcribed verbatim from the binary.
static const UIViewAutoresizing kTermButtonAutoresizingMask = (UIViewAutoresizing)0x25;

@implementation RBTermPhoneViewController

#pragma mark Lifecycle

- (instancetype)init {
    self = [super init];
    if (self != nil) {
        self.terms = [[NSMutableDictionary alloc] init];
        self.viewType = kTermViewTypeAgreement;

        UILabel *titleLabel = [[UILabel alloc] initWithFrame:CGRectZero];
        titleLabel.font = [UIFont boldSystemFontOfSize:kTitleFontSize];
        titleLabel.textColor = UIColor.whiteColor;
        titleLabel.text = kTermsNavTitle;
        [titleLabel sizeToFit];
        self.navigationItem.titleView = titleLabel;

        UIButton *backButton = [UIButton buttonWithType:UIButtonTypeSystem];
        [backButton setTitle:@"" forState:UIControlStateNormal];
        [backButton addTarget:self
                       action:@selector(pushBarBtnBack:)
             forControlEvents:UIControlEventTouchUpInside];
        [backButton sizeToFit];
        self.navigationItem.leftBarButtonItem =
            [[UIBarButtonItem alloc] initWithCustomView:backButton];
    }
    return self;
}

// The binary's -dealloc only chains to super; under ARC that teardown is automatic, so no explicit
// -dealloc is needed.

- (void)viewDidLoad {
    [super viewDidLoad];

    // Persist the last-read terms timestamp from the last downloaded update time, then save.
    if ([[AppDelegate appDelegate] getTermLastUpdateTimeString] != nil) {
        [RBUserSettingData sharedInstance].termLastReadTimeString =
            [[AppDelegate appDelegate] getTermLastUpdateTimeString];
    }
    [[RBUserSettingData sharedInstance] save];

    self.view.backgroundColor = [UIColor colorWithWhite:g_dMascotMessageAnimDuration
                                                  alpha:kColorAlphaOpaque];

    // The dimming overlay covers the content while loading; it starts hidden.
    UIView *grayView = [[UIView alloc] initWithFrame:self.view.bounds];
    grayView.backgroundColor = [UIColor colorWithWhite:g_dRBWebViewGrayViewWhite
                                                 alpha:kColorAlphaHalf];
    grayView.hidden = YES;
    grayView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [self.view addSubview:grayView];
    self.grayView = grayView;

    // The loading spinner, scaled up and centred, hidden while stopped.
    UIActivityIndicatorView *indicator = [[UIActivityIndicatorView alloc] init];
    [indicator.layer setValue:@(kIndicatorTransformScale) forKeyPath:@"transform.scale"];
    indicator.center = self.view.center;
    indicator.autoresizingMask =
        UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleLeftMargin |
        UIViewAutoresizingFlexibleRightMargin | UIViewAutoresizingFlexibleBottomMargin;
    indicator.hidesWhenStopped = YES;
    [self.view addSubview:indicator];
    self.indicatorView = indicator;

    CGFloat contentWidth = self.view.frame.size.width;
    CGFloat contentHeight = self.view.frame.size.height;

    // The scrolling terms list fills the view; it starts fully transparent.
    UIScrollView *termsListView =
        [[UIScrollView alloc] initWithFrame:CGRectMake(0.0, 0.0, contentWidth, contentHeight)];
    termsListView.alpha = 0.0;
    termsListView.autoresizingMask =
        UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [self.view addSubview:termsListView];
    self.termsListView = termsListView;

    // The term-body container occupies the same region, starting transparent.
    UIView *termView =
        [[UIView alloc] initWithFrame:CGRectMake(0.0, 0.0, contentWidth, contentHeight)];
    termView.alpha = 0.0;
    termView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [self.view addSubview:termView];
    self.termView = termView;

    [self loadList];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];

    [self.navigationController setNavigationBarHidden:NO animated:YES];
    UINavigationBar *navigationBar = self.navigationController.navigationBar;
    navigationBar.tintColor = nil;
    navigationBar.barTintColor = [UIColor colorWithRed:g_dRBNavBarTintWhite
                                                 green:g_dRBNavBarTintWhite
                                                  blue:g_dRBNavBarTintWhite
                                                 alpha:kColorAlphaOpaque];
    if ([navigationBar respondsToSelector:@selector(setBackgroundImage:forBarMetrics:)]) {
        [navigationBar setBackgroundImage:nil forBarMetrics:UIBarMetricsDefault];
    }
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    [self loadList];
}

- (void)viewDidDisappear:(BOOL)animated {
    [super viewDidDisappear:animated];
}

#pragma mark Configuration

- (void)setViewTypeStore {
    self.viewType = kTermViewTypeStore;
}

#pragma mark Networking

- (void)loadList {
    // When the terms list is already populated, just reveal it and skip the download.
    if (self.termsList != nil && self.termsList.count != 0) {
        [self showTermsList];
        return;
    }

    [self startLoadAnimation];

    NSDictionary *body = @{kTermsRequestKeyTarget : GetRegionCode()};
    NSData *postData = [Downloader dictionaryToJsonData:body];
    __weak RBTermPhoneViewController *weakSelf = self;
    self.downloader = [[Downloader alloc] initWithURL:[NetworkUtil termList]
                                                 post:postData
                                          contentType:kTermsRequestContentType];
    [weakSelf.downloader
        startDownloadingWithProceed:^{
          /** @ghidraAddress 0x1703d8 */
          // Global no-op proceed block.
        }
        success:^{
          /** @ghidraAddress 0x1703dc */
          // Parse the JSON list into termsList, then show it (or the network-error alert) and stop
          // the spinner, all marshalled to the main queue.
          weakSelf.termsList = [weakSelf.downloader getDataInJSON][kTermsResponseKeyList];
          if (weakSelf.termsList == nil) {
              dispatch_async(dispatch_get_main_queue(), ^{
                /** @ghidraAddress 0x170654 */
                [UIAlertView showNetworkErrorWithDelegate:weakSelf];
              });
          } else {
              dispatch_async(dispatch_get_main_queue(), ^{
                /** @ghidraAddress 0x1705f8 */
                [weakSelf showTermsList];
              });
          }
          dispatch_async(dispatch_get_main_queue(), ^{
            /** @ghidraAddress 0x1706cc */
            [weakSelf endLoadAnimation];
          });
        }
        failure:^{
          /** @ghidraAddress 0x17073c */
          // Schedule the network-error alert and spinner stop on the main queue.
          dispatch_async(dispatch_get_main_queue(), ^{
            /** @ghidraAddress 0x1707b4 */
            [UIAlertView showNetworkErrorWithDelegate:weakSelf];
            [weakSelf endLoadAnimation];
          });
        }];
}

#pragma mark Presentation

- (void)showTermsList {
    // Fade the term body out if it is currently shown.
    if (self.termView.alpha == kColorAlphaOpaque) {
        [UIView animateWithDuration:g_dMascotMessageAnimDuration
                         animations:^{
                           /** @ghidraAddress 0x1712e0 */
                           self.termView.alpha = 0.0;
                         }];
    }

    // The list start-Y is theme- and idiom-dependent; the button width is a fixed 300 points.
    NSInteger thema = [RBUserSettingData sharedInstance].thema;
    CGFloat listStartY;
    if (!IsPad()) {
        listStartY = (thema != RBUserSettingDataThemeClassic) ? g_dLayoutMetricThirtyTwo : 0.0;
    } else {
        listStartY = (thema != RBUserSettingDataThemeClassic) ? kTermListStartYPadThemed :
                                                                kTermListStartYPadClassic;
    }

    CGFloat centreX = self.view.frame.size.width * kHalf;
    CGFloat buttonX = centreX + kTermButtonHalfWidthNegative;

    if (self.termsList != nil) {
        CGFloat currentY = listStartY;
        for (NSDictionary *term in self.termsList) {
            // Reuse an existing button in the list whose tag already matches this term's type,
            // otherwise build a new one.
            UIButton *button = nil;
            for (UIView *subview in self.termsListView.subviews) {
                if ([subview isKindOfClass:UIButton.class] &&
                    subview.tag == [term[kTermFieldType] integerValue]) {
                    button = (UIButton *)subview;
                    break;
                }
            }

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
                button.frame = CGRectMake(buttonX,
                                          currentY + kTermButtonTopGap,
                                          g_dMascotMessageMaxWidthPad,
                                          g_dTermButtonRowHeight);
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
                currentY += g_dTermButtonRowHeight + kTermRowGap;
            }

            [button setTitle:term[kTermFieldTitle] forState:UIControlStateNormal];
            [button setTitleColor:UIColor.whiteColor forState:UIControlStateNormal];
            self.termsListView.contentSize =
                CGSizeMake(self.termsListView.contentSize.width, currentY);
            self.termsListView.scrollEnabled = YES;
            self.termsListView.showsHorizontalScrollIndicator = YES;
        }
    }

    // Fade the list in after a short delay.
    [UIView animateWithDuration:g_dMascotMessageAnimDuration
        delay:g_dMascotMessageAnimDuration
        options:UIViewAnimationOptionCurveEaseInOut
        animations:^{
          /** @ghidraAddress 0x17134c */
          self.termsListView.alpha = kColorAlphaOpaque;
        }
        completion:^(BOOL finished) {
          /** @ghidraAddress 0x1713b8 */
          self.isAnimating = NO;
        }];
}

- (void)selectTerm:(id)sender {
    NSString *termID = [NSString stringWithFormat:kTermTagFormat, ((UIButton *)sender).tag];

    // Locate the tapped term, opening its external URL if it has one, or capturing its title.
    id termTitle = nil;
    if (self.termsList != nil) {
        for (NSDictionary *term in self.termsList) {
            if ([[term[kTermFieldType] stringValue] isEqualToString:termID]) {
                if (term[kTermFieldURL] != nil && [term[kTermFieldURL] length] != 0) {
                    [UIApplication.sharedApplication
                        openURL:[NSURL URLWithString:term[kTermFieldURL]]];
                    return;
                }
                termTitle = term[kTermFieldTitle];
            }
        }
    }

    // Otherwise push the term-detail controller for the body.
    RBTermDetailPhoneViewController *detail =
        [[RBTermDetailPhoneViewController alloc] initWithID:termID title:termTitle];
    [detail setViewTypeStore];
    detail.navigationItem.title = termTitle;
    [self.navigationController pushViewController:detail animated:YES];
}

#pragma mark Loading animation

- (void)startLoadAnimation {
    if (self.isUseGrayView) {
        self.grayView.hidden = NO;
    }
    self.indicatorView.hidden = NO;
    [self.indicatorView startAnimating];
}

- (void)endLoadAnimation {
    if (self.isUseGrayView) {
        self.grayView.hidden = YES;
    }
    [self.indicatorView stopAnimating];
}

#pragma mark Navigation

- (void)pushBarBtnBack:(id)sender {
    if (self.viewType == kTermViewTypeAgreement) {
        [self.navigationController setNavigationBarHidden:YES animated:YES];
        SoundEffectManager::GetInstance()->PlayThemedSoundEffect(kSoundEffectCancel);
    } else {
        UINavigationBar *navigationBar = self.navigationController.navigationBar;
        navigationBar.tintColor = nil;
        navigationBar.barTintColor = UIColor.whiteColor;
        if ([navigationBar respondsToSelector:@selector(setBackgroundImage:forBarMetrics:)]) {
            [navigationBar setBackgroundImage:nil forBarMetrics:UIBarMetricsDefault];
        }
    }
    [self.navigationController popViewControllerAnimated:YES];
}

- (void)forceClose {
    if (self.viewType == kTermViewTypeAgreement) {
        [self.navigationController setNavigationBarHidden:YES animated:NO];
    }
    [self.navigationController popViewControllerAnimated:NO];
}

#pragma mark Alert view delegate

- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex {
    if (self.isFirstRequest) {
        alertView.delegate = nil;
        [self forceClose];
    }
}

- (void)alertView:(UIAlertView *)alertView didDismissWithButtonIndex:(NSInteger)buttonIndex {
    // @ghidraAddress 0x171da8
    // The binary provides an empty implementation.
}

- (void)alertView:(UIAlertView *)alertView willDismissWithButtonIndex:(NSInteger)buttonIndex {
    // @ghidraAddress 0x171dac
    // The binary provides an empty implementation.
}

- (void)alertViewCancel:(UIAlertView *)alertView {
    // @ghidraAddress 0x171db0
    // The binary provides an empty implementation.
}

@end
