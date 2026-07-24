//
//  RBSearchMapViewController.mm
//  REFLEC BEAT plus
//
//  Reconstructed from Ghidra project rb458, program rb458 (class RBSearchMapViewController).
//  Verified against the arm64 disassembly: the controller builds a custom navigation bar, hosts a
//  tagged RBSearchMapView that it creates lazily on first appearance, and mirrors the map's
//  tracking state onto the current-location button.
//

#import "RBSearchMapViewController.h"

#import <UIKit/UIKit.h>

#import "UIImage+RB.h"

// SoundEffectManager::GetInstance()->PlayThemedSoundEffect(slot).
#import "neEngineBridge.h"

namespace {
// The back button plays the shared "cancel" sound-effect slot.
constexpr int kSoundEffectCancel = 4;
// The hosted RBSearchMapView is looked up in the controller's view by this tag.
constexpr NSInteger kSearchMapViewTag = 0x23d;
} // namespace

@implementation RBSearchMapViewController

- (instancetype)init {
    /** @ghidraAddress 0xe5748 */
    self = [super init];
    if (self) {
        UIImageView *titleView =
            [[UIImageView alloc] initWithImage:[UIImage imageWithName:@"06_search/sear_bar_1"]];
        [self.navigationItem setTitleView:titleView];

        UIButton *backButton = [UIButton buttonWithType:UIButtonTypeCustom];
        [backButton setImage:[UIImage imageWithName:@"06_search/sear_back"]
                    forState:UIControlStateNormal];
        [backButton setImage:[UIImage imageWithName:@"06_search/sear_back_eff"]
                    forState:UIControlStateHighlighted];
        [backButton addTarget:self
                       action:@selector(pushBarBtnBack:)
             forControlEvents:UIControlEventTouchUpInside];
        [backButton sizeToFit];
        UIBarButtonItem *backItem = [[UIBarButtonItem alloc] initWithCustomView:backButton];
        [self.navigationItem setLeftBarButtonItem:backItem];

        UIButton *locationButton = [UIButton buttonWithType:UIButtonTypeCustom];
        [locationButton setImage:[UIImage imageWithName:@"06_search/sear_me"]
                        forState:UIControlStateNormal];
        [locationButton setImage:[UIImage imageWithName:@"06_search/sear_me_eff"]
                        forState:UIControlStateSelected];
        [locationButton addTarget:self
                           action:@selector(pushCurrent:)
                 forControlEvents:UIControlEventTouchUpInside];
        [locationButton sizeToFit];
        UIBarButtonItem *locationItem = [[UIBarButtonItem alloc] initWithCustomView:locationButton];
        [self.navigationItem setRightBarButtonItem:locationItem];
        self.currentLocation = locationButton;
    }
    return self;
}

#pragma mark - View lifecycle

- (void)viewDidLoad {
    /** @ghidraAddress 0xe5bc8 */
    [super viewDidLoad];
    self.view.backgroundColor = UIColor.whiteColor;

    UIActivityIndicatorView *indicator = [[UIActivityIndicatorView alloc]
        initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleGray];
    [indicator startAnimating];
    indicator.center = CGPointMake(CGRectGetWidth(self.view.bounds) * 0.5,
                                   CGRectGetHeight(self.view.bounds) * 0.5);
    indicator.autoresizingMask = g_dwRBWebViewIndicatorAutoresizingMask;
    [self.view addSubview:indicator];
}

- (void)viewWillAppear:(BOOL)animated {
    /** @ghidraAddress 0xe5dd4 */
    [super viewWillAppear:animated];
    [self.navigationController setNavigationBarHidden:NO animated:YES];
    UINavigationBar *navigationBar = self.navigationController.navigationBar;
    if ([navigationBar respondsToSelector:@selector(setBackgroundImage:forBarMetrics:)]) {
        [navigationBar setBackgroundImage:[UIImage imageWithName:@"06_search/sear_bar_2"]
                            forBarMetrics:UIBarMetricsDefault];
    }
}

- (void)viewDidAppear:(BOOL)animated {
    /** @ghidraAddress 0xe5f40 */
    [super viewDidAppear:animated];
    RBSearchMapView *mapView = (RBSearchMapView *)[self.view viewWithTag:kSearchMapViewTag];
    if (!mapView) {
        mapView = [[RBSearchMapView alloc] initWithFrame:self.view.bounds];
        mapView.tag = kSearchMapViewTag;
        mapView.delegate = self;
        [self.view addSubview:mapView];
    }
    [mapView initialView];
}

- (void)viewDidDisappear:(BOOL)animated {
    /** @ghidraAddress 0xe60f0 */
    RBSearchMapView *mapView = (RBSearchMapView *)[self.view viewWithTag:kSearchMapViewTag];
    if (mapView) {
        [mapView viewDidDisappear];
        [(RBSearchMapView *)[self.view viewWithTag:kSearchMapViewTag] removeFromSuperview];
    }
    [super viewDidDisappear:animated];
}

#pragma mark - Actions

- (void)pushBarBtnBack:(id)sender {
    /** @ghidraAddress 0xe6238 */
    [self.navigationController setNavigationBarHidden:YES animated:YES];
    SoundEffectManager::GetInstance()->PlayThemedSoundEffect(kSoundEffectCancel);
    [self.navigationController popViewControllerAnimated:YES];
}

- (void)pushCurrent:(id)sender {
    /** @ghidraAddress 0xe6300 */
    RBSearchMapView *mapView = (RBSearchMapView *)[self.view viewWithTag:kSearchMapViewTag];
    if (mapView) {
        [mapView toggleTrackingMode];
    }
}

- (void)forceClose {
    /** @ghidraAddress 0xe63a0 */
    [self.navigationController setNavigationBarHidden:YES animated:NO];
    [self.navigationController popViewControllerAnimated:NO];
}

#pragma mark - SearchMapViewDelegate

- (void)didChangeUserTracking:(BOOL)tracking {
    /** @ghidraAddress 0xe6454 */
    self.currentLocation.selected = tracking;
}

@end
