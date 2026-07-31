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

// The redirect outcome returned by -[RecommendCore redirectViewContollerWithRequest:] that means
// the request's URL was rewritten in place (a "change destination" link), so the advert web view
// must be reloaded with the rewritten request.
static const int kRecommendRedirectReloadRequest = 2;

@interface RecommendWebViewController ()

// Overrides the private redirect hook inherited from RewardWebViewController so advert clicks route
// through RecommendCore instead of RewardCore.
- (int)redirectWithRequest:(NSURLRequest *)request;

// An empty override the binary defines to suppress the superview-detach behaviour on this
// controller. It shadows the inherited -[UIResponder] chain rather than -[UIView
// removeFromSuperview].
- (void)removeFromSuperview;

@end

@implementation RecommendWebViewController

#pragma mark - Lifecycle

- (void)viewDidLoad {
    /** @ghidraAddress 0x202f54 */
    [super viewDidLoad];
}

- (void)didReceiveMemoryWarning {
    /** @ghidraAddress 0x202f90 */
    [super didReceiveMemoryWarning];
}

- (void)viewDidUnload {
    /** @ghidraAddress 0x202fcc */
    [self.view removeFromSuperview];
    [super viewDidUnload];
}

- (void)dealloc {
    /** @ghidraAddress 0x203110 */
    // The binary's -[super dealloc] is elided: ARC synthesises the superclass teardown.
}

#pragma mark - Redirect handling

// Routes the advert redirect through RecommendCore. When the core rewrites the request in place,
// the web view is reloaded with the rewritten request.
- (int)redirectWithRequest:(NSURLRequest *)request {
    /** @ghidraAddress 0x203048 */
    int outcome = [[RecommendCore sharedInstance] redirectViewContollerWithRequest:request];
    if (outcome == kRecommendRedirectReloadRequest) {
        [self.webView loadRequest:request];
    }
    return outcome;
}

#pragma mark - View teardown

// An empty override: RecommendWebViewController deliberately suppresses the inherited
// -removeFromSuperview so a teardown invoked on the controller does not detach its own view.
- (void)removeFromSuperview {
    /** @ghidraAddress 0x20310c */
}

@end
