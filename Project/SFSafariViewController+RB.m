#import "SFSafariViewController+RB.h"

@implementation SFSafariViewController (RB)

- (BOOL)prefersStatusBarHidden {
    /** @ghidraAddress 0x20f48 */
    return YES;
}

@end
