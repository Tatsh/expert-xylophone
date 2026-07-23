//
//  RecommendWebViewController.m
//  REFLEC BEAT plus
//
//  Reconstructed from Ghidra project rb458, program rb458.
//  See RecommendWebViewController.h for the class overview.
//

#import "RecommendWebViewController.h"

#import <UIKit/UIKit.h>

#import "RecommendCore.h"

// The redirect outcome returned by -[RecommendCore redirectViewContollerWithRequest:] that means the
// request's URL was rewritten in place (a "change destination" link), so the advert web view must be
// reloaded with the rewritten request.
static const int kRecommendRedirectReloadRequest = 2;

@interface RecommendWebViewController ()

// Overrides the private redirect hook inherited from RewardWebViewController so advert clicks route
// through RecommendCore instead of RewardCore.
- (int)redirectWithRequest:(NSURLRequest *)request;

// An empty override the binary defines to suppress the superview-detach behaviour on this
// controller. It shadows the inherited -[UIResponder] chain rather than -[UIView removeFromSuperview].
- (void)removeFromSuperview;

@end

@implementation RecommendWebViewController

#pragma mark - Lifecycle

// @ 0x100202f54
- (void)viewDidLoad {
    [super viewDidLoad];
}

// @ 0x100202f90
- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
}

// @ 0x100202fcc
- (void)viewDidUnload {
    [self.view removeFromSuperview];
    [super viewDidUnload];
}

// @ 0x100203110
- (void)dealloc {
    // The binary's -[super dealloc] is elided: ARC synthesises the superclass teardown.
}

#pragma mark - Redirect handling

// Routes the advert redirect through RecommendCore. When the core rewrites the request in place, the
// web view is reloaded with the rewritten request.
// @ 0x100203048
- (int)redirectWithRequest:(NSURLRequest *)request {
    int outcome = [[RecommendCore sharedInstance] redirectViewContollerWithRequest:request];
    if (outcome == kRecommendRedirectReloadRequest) {
        [self.webView loadRequest:request];
    }
    return outcome;
}

#pragma mark - View teardown

// An empty override: RecommendWebViewController deliberately suppresses the inherited
// -removeFromSuperview so a teardown invoked on the controller does not detach its own view.
// @ 0x10020310c
- (void)removeFromSuperview {
}

@end
