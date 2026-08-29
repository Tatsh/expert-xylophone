#import "RBNavigationController.h"

@implementation RBNavigationController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.navigationBar.translucent = NO;
}

- (BOOL)prefersStatusBarHidden {
    return YES;
}

- (BOOL)shouldAutorotate {
    return self.visibleViewController.shouldAutorotate;
}

- (UIInterfaceOrientationMask)supportedInterfaceOrientations {
    return self.visibleViewController.supportedInterfaceOrientations;
}

@end
