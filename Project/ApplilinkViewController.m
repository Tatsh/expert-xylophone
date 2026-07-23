//
//  ApplilinkViewController.m
//  REFLEC BEAT plus
//
//  Reconstructed from Ghidra project rb458, program rb458 (class ApplilinkViewController). This is
//  a plain Objective-C file: it drives a RotateStoreProductViewController and an ApplilinkIndicator
//  through ordinary message sends and stack blocks, so there is no C++.
//
//  ApplilinkViewController owns and presents the native App Store product page. It shows a loading
//  overlay while the product loads, is the product view controller's delegate, and forwards the App
//  Store opened, close, closed, and load-failure notices to its sdkDelegate.
//

#import "ApplilinkViewController.h"

#import <StoreKit/StoreKit.h>
#import <UIKit/UIKit.h>

#import "ApplilinkCore.h"
#import "ApplilinkIndicator.h"
#import "ApplilinkParameters.h"
#import "ApplilinkStore.h"

// RotateStoreProductViewController is a rotation-forcing SKStoreProductViewController subclass that
// the SDK instantiates here. It has not yet been reconstructed, so it is only forward-declared;
// every message the view controller sends it belongs to the SKStoreProductViewController API.
@class RotateStoreProductViewController;

@implementation ApplilinkViewController

#pragma mark - View lifecycle

// @ghidraAddress 0x21371c
- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
}

// @ghidraAddress 0x213758
- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
}

// @ghidraAddress 0x213794
- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
}

// @ghidraAddress 0x2137d0
- (void)viewDidDisappear:(BOOL)animated {
}

// @ghidraAddress 0x2137d4
- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
}

#pragma mark - Rotation

// @ghidraAddress 0x214384
- (BOOL)shouldAutorotate {
    return YES;
}

// @ghidraAddress 0x21438c
- (UIInterfaceOrientationMask)supportedInterfaceOrientations {
    return UIInterfaceOrientationMaskAll;
}

// @ghidraAddress 0x214394
- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
    return YES;
}

#pragma mark - Store presentation

// @ghidraAddress 0x213810
- (void)showSKStore:(NSString *)appStoreId
           appParam:(ApplilinkParameters *)appParam
           delegate:(id<SdkViewDelegate>)delegate {
    self.applilinkParams = appParam;
    self.sdkDelegate = delegate;

    self.view.frame = [UIScreen mainScreen].bounds;
    self.view.backgroundColor = [UIColor clearColor];

    RotateStoreProductViewController *storeViewController =
        [[RotateStoreProductViewController alloc] init];
    [storeViewController setDelegate:self];

    self.indicator = [[ApplilinkIndicator alloc] initWithFrame:self.view.bounds];
    [self.view addSubview:self.indicator];
    [self.indicator show];

    UIWindow *mainWindow = [ApplilinkCore mainWindow];
    if (mainWindow) {
        [mainWindow addSubview:self.view];
    }

    NSDictionary *parameters = @{SKStoreProductParameterITunesItemIdentifier: appStoreId};
    SEL openedNotice = @selector(appStoreOpenedNoticeWithAppParam:);
    SEL failLoadNotice = @selector(appStoreFailLoadNoticeWithError:appParam:);
    [storeViewController
        loadProductWithParameters:parameters
                  completionBlock:^(BOOL result, NSError *error) {
                      /** @ghidraAddress 0x213c18 */
                      if (!result) {
                          if (self.indicator) {
                              [self.indicator removeFromSuperview];
                          }
                          self.indicator = nil;
                          [self.view removeFromSuperview];
                          if (self.sdkDelegate &&
                              [self.sdkDelegate respondsToSelector:failLoadNotice]) {
                              ApplilinkParameters *params = self.applilinkParams;
                              [self.sdkDelegate appStoreFailLoadNoticeWithError:error
                                                                      appParam:params];
                          }
                          return;
                      }
                      [self presentViewController:storeViewController
                                         animated:YES
                                       completion:^{
                                           /** @ghidraAddress 0x213dd0 */
                                           if (self.indicator) {
                                               [self.indicator removeFromSuperview];
                                           }
                                           self.indicator = nil;
                                           if (self.sdkDelegate &&
                                               [self.sdkDelegate
                                                   respondsToSelector:openedNotice]) {
                                               [self.sdkDelegate appStoreOpenedNoticeWithAppParam:
                                                                     self.applilinkParams];
                                           }
                                       }];
                  }];
}

#pragma mark - SKStoreProductViewControllerDelegate

// @ghidraAddress 0x213f3c
- (void)productViewControllerDidFinish:(SKStoreProductViewController *)viewController {
    if (self.sdkDelegate &&
        [self.sdkDelegate respondsToSelector:@selector(appStoreCloseNoticeWithAppParam:)]) {
        [self.sdkDelegate appStoreCloseNoticeWithAppParam:self.applilinkParams];
    }
    SEL closedNotice = @selector(appStoreClosedNoticeWithAppParam:);
    [self dismissViewControllerAnimated:YES
                             completion:^{
                                 /** @ghidraAddress 0x21404c */
                                 [self.view removeFromSuperview];
                                 if (self.sdkDelegate &&
                                     [self.sdkDelegate respondsToSelector:closedNotice]) {
                                     [self.sdkDelegate
                                         appStoreClosedNoticeWithAppParam:self.applilinkParams];
                                 }
                             }];
}

// @ghidraAddress 0x214160
- (void)productViewControllerDidFinish {
    if (self.sdkDelegate &&
        [self.sdkDelegate respondsToSelector:@selector(appStoreCloseNoticeWithAppParam:)]) {
        [self.sdkDelegate appStoreCloseNoticeWithAppParam:self.applilinkParams];
    }
    SEL closedNotice = @selector(appStoreClosedNoticeWithAppParam:);
    [self dismissViewControllerAnimated:NO
                             completion:^{
                                 /** @ghidraAddress 0x214270 */
                                 [self.view removeFromSuperview];
                                 if (self.sdkDelegate &&
                                     [self.sdkDelegate respondsToSelector:closedNotice]) {
                                     [self.sdkDelegate
                                         appStoreClosedNoticeWithAppParam:self.applilinkParams];
                                 }
                             }];
}

@end
