//
//  RBNavigationController.m
//  REFLEC BEAT plus
//
//  Reconstructed from Ghidra project rb458, program rb458 (class RBNavigationController). Verified
//  against the arm64 disassembly: the rotation overrides forward to -visibleViewController and the
//  status-bar override returns a constant.
//

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

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
