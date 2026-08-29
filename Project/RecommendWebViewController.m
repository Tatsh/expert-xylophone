#import "RecommendWebViewController.h"

#import <UIKit/UIKit.h>

#import "RecommendCore.h"

static const int kRecommendRedirectReloadRequest = 2;

@interface RecommendWebViewController ()

// Overrides the private redirect hook inherited from RewardWebViewController.
- (int)redirectWithRequest:(NSURLRequest *)request;

// Shadows the inherited responder-chain method rather than -[UIView removeFromSuperview].
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

- (int)redirectWithRequest:(NSURLRequest *)request {
    /** @ghidraAddress 0x203048 */
    int outcome = [[RecommendCore sharedInstance] redirectViewContollerWithRequest:request];
    if (outcome == kRecommendRedirectReloadRequest) {
        [self.webView loadRequest:request];
    }
    return outcome;
}

#pragma mark - View teardown

// Deliberately empty; the binary defines it to suppress the inherited behaviour.
- (void)removeFromSuperview {
    /** @ghidraAddress 0x20310c */
}

@end
