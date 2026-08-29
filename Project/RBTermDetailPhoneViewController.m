#import "RBTermDetailPhoneViewController.h"

#import "AppDelegate.h"
#import "Downloader.h"
#import "NetworkUtil.h"
#import "RBUserSettingData.h"
#import "UIAlertView+RB.h"
#import "deviceenvironment.h"
#import "engineglobals.h"

enum {
    kTermViewTypeAgreement = 0,
    kTermViewTypeStore = 1,
};

static NSString *const kTermsRequestKeyTarget = @"target";
static NSString *const kTermsRequestKeyType = @"type";
static NSString *const kTermFieldContents = @"contents";

// @ghidraAddress 0x364140
static NSString *const kTermsRequestContentType = @"application/json";

static const CGFloat kTitleFontSize = 16.0;
static const float kIndicatorTransformScale = 1.5f;

static const CGFloat kTermBodyFontSize = 15.0;

static const CGFloat kTermTextInsetVertical = 10.0;
static const CGFloat kTermTextInsetHorizontal = 5.0;

static const CGFloat kColorAlphaHalf = 0.5;
static const CGFloat kColorAlphaOpaque = 1.0;

// @ghidraAddress 0x2eedc0 (g_dMascotMessageAnimDuration)
extern const double g_dMascotMessageAnimDuration;

// @ghidraAddress 0x2ec6a0 (g_dTranslucentAlpha)
extern const double g_dTranslucentAlpha;

// @ghidraAddress 0x310450 (g_dwAutoresizingMaskFlexibleAll)
static const UIViewAutoresizing kAutoresizingMaskFlexibleAll = (UIViewAutoresizing)0x3f;
// @ghidraAddress 0x310460 (g_dwRBWebViewIndicatorAutoresizingMask)
static const UIViewAutoresizing kIndicatorAutoresizingMask = (UIViewAutoresizing)0x2d;
static const UIViewAutoresizing kTermTextAutoresizingMask = (UIViewAutoresizing)0x32;

@implementation RBTermDetailPhoneViewController

#pragma mark Lifecycle

- (instancetype)initWithID:(NSString *)termID title:(NSString *)title {
    self = [super init];
    if (self != nil) {
        self.ID = termID;
        self.terms = [[NSMutableDictionary alloc] init];
        self.viewType = kTermViewTypeAgreement;

        UILabel *titleLabel = [[UILabel alloc] initWithFrame:CGRectZero];
        titleLabel.font = [UIFont boldSystemFontOfSize:kTitleFontSize];
        titleLabel.textColor = UIColor.whiteColor;
        titleLabel.text = title;
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

// The binary's -dealloc only chains to super, which ARC does automatically.

- (void)viewDidLoad {
    [super viewDidLoad];

    if ([[AppDelegate appDelegate] getTermLastUpdateTimeString] != nil) {
        [RBUserSettingData sharedInstance].termLastReadTimeString =
            [[AppDelegate appDelegate] getTermLastUpdateTimeString];
    }
    [[RBUserSettingData sharedInstance] save];

    self.view.backgroundColor = [UIColor colorWithWhite:g_dMascotMessageAnimDuration
                                                  alpha:kColorAlphaOpaque];

    UIView *grayView = [[UIView alloc] initWithFrame:self.view.bounds];
    grayView.backgroundColor = [UIColor colorWithWhite:g_dRBWebViewGrayViewWhite
                                                 alpha:kColorAlphaHalf];
    grayView.hidden = YES;
    grayView.autoresizingMask = kAutoresizingMaskFlexibleAll;
    [self.view addSubview:grayView];
    self.grayView = grayView;

    UIActivityIndicatorView *indicator = [[UIActivityIndicatorView alloc] init];
    [indicator.layer setValue:@(kIndicatorTransformScale) forKeyPath:@"transform.scale"];
    indicator.center = self.view.center;
    indicator.autoresizingMask = kIndicatorAutoresizingMask;
    indicator.hidesWhenStopped = YES;
    [self.view addSubview:indicator];
    self.indicatorView = indicator;

    CGFloat contentWidth = self.view.frame.size.width;
    CGFloat contentHeight = self.view.frame.size.height;

    UIView *termView =
        [[UIView alloc] initWithFrame:CGRectMake(0.0, 0.0, contentWidth, contentHeight)];
    termView.alpha = 0.0;
    termView.autoresizingMask = kAutoresizingMaskFlexibleAll;
    [self.view addSubview:termView];
    self.termView = termView;

    UITextView *termTextView =
        [[UITextView alloc] initWithFrame:CGRectMake(0.0,
                                                     0.0,
                                                     self.termView.frame.size.width,
                                                     self.termView.frame.size.height)];
    termTextView.autoresizingMask = kTermTextAutoresizingMask;
    termTextView.textContainerInset = UIEdgeInsetsMake(kTermTextInsetVertical,
                                                       kTermTextInsetHorizontal,
                                                       kTermTextInsetVertical,
                                                       kTermTextInsetHorizontal);
    termTextView.textColor = [UIColor colorWithWhite:g_dTranslucentAlpha alpha:kColorAlphaOpaque];
    termTextView.backgroundColor = [UIColor colorWithWhite:g_dMascotMessageAnimDuration
                                                     alpha:kColorAlphaOpaque];
    [self.termView addSubview:termTextView];
    self.termTextView = termTextView;
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
    [self loadDetail];
}

- (void)viewDidDisappear:(BOOL)animated {
    [super viewDidDisappear:animated];
}

#pragma mark Configuration

- (void)setViewTypeStore {
    self.viewType = kTermViewTypeStore;
}

#pragma mark Networking

- (void)loadDetail {
    [self startLoadAnimation];

    NSDictionary *body = @{
        kTermsRequestKeyTarget : GetRegionCode(),
        kTermsRequestKeyType : @([self.ID integerValue])
    };
    NSData *postData = [Downloader dictionaryToJsonData:body];
    __weak RBTermDetailPhoneViewController *weakSelf = self;
    self.downloader = [[Downloader alloc] initWithURL:[NetworkUtil termFetch]
                                                 post:postData
                                          contentType:kTermsRequestContentType];
    [weakSelf.downloader
        startDownloadingWithProceed:^(Downloader *downloader) {
          /** @ghidraAddress 0x49684 */
        }
        success:^(Downloader *downloader) {
          /** @ghidraAddress 0x49688 */
          NSDictionary *data = [weakSelf.downloader getDataInJSON];
          if (data == nil) {
              dispatch_async(dispatch_get_main_queue(), ^{
                /** @ghidraAddress 0x498bc */
                [weakSelf endLoadAnimation];
              });
          } else {
              weakSelf.terms = [data mutableCopy];
              dispatch_async(dispatch_get_main_queue(), ^{
                /** @ghidraAddress 0x49860 */
                [weakSelf showTermView];
              });
          }
          dispatch_async(dispatch_get_main_queue(), ^{
            /** @ghidraAddress 0x49918 */
            [weakSelf endLoadAnimation];
          });
        }
        failure:^(Downloader *downloader) {
          /** @ghidraAddress 0x49988 */
          dispatch_async(dispatch_get_main_queue(), ^{
            /** @ghidraAddress 0x49a00 */
            [UIAlertView showNetworkErrorWithDelegate:weakSelf];
            [weakSelf endLoadAnimation];
          });
        }];
}

#pragma mark Presentation

- (void)showTermView {
    // The binary reads the theme here without using it, and both idiom branches are identical.
    if (!IsPad()) {
        (void)[RBUserSettingData sharedInstance].thema;
    } else {
        (void)[RBUserSettingData sharedInstance].thema;
    }

    __weak RBTermDetailPhoneViewController *weakSelf = self;

    self.termTextView.text = weakSelf.terms[kTermFieldContents];
    weakSelf.termTextView.font = [UIFont systemFontOfSize:kTermBodyFontSize];

    [UIView animateWithDuration:g_dMascotMessageAnimDuration
        delay:g_dMascotMessageAnimDuration
        options:UIViewAnimationOptionCurveEaseInOut
        animations:^{
          /** @ghidraAddress 0x49dc0 */
          weakSelf.termView.alpha = kColorAlphaOpaque;
        }
        completion:^(BOOL finished) {
          /** @ghidraAddress 0x49e58 */
          weakSelf.isAnimating = NO;
          dispatch_async(dispatch_get_main_queue(), ^{
            /** @ghidraAddress 0x49f0c */
            [weakSelf endLoadAnimation];
          });
        }];
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
    // @ghidraAddress 0x4a340
}

- (void)alertView:(UIAlertView *)alertView willDismissWithButtonIndex:(NSInteger)buttonIndex {
    // @ghidraAddress 0x4a344
}

- (void)alertViewCancel:(UIAlertView *)alertView {
    // @ghidraAddress 0x4a348
}

@end
