//
//  RBBaseTableViewController.mm
//  REFLEC BEAT plus
//
//  Reconstructed from Ghidra project rb458, program rb458 (class RBBaseTableViewController).
//  Verified against the arm64 disassembly: viewDidLoad chains to super then whitens the table
//  background, the status-bar override returns a constant, and the rotation overrides gate on the
//  region iPad idiom and the engine's "background music playing" flag.
//

#import "RBBaseTableViewController.h"

// GameSystem::GetGameSystem() -> GameSystem* (with the fBgmPlaying playback flag reported by
// GetBgmPlaying()) and IsPad(), which reports whether the region uses the wide (variant) font
// layout that also selects the constrained-rotation behaviour.
#import "neEngineBridge.h"

@implementation RBBaseTableViewController

- (void)viewDidLoad {
    /** @ghidraAddress 0x20282c */
    [super viewDidLoad];
    self.tableView.backgroundColor = UIColor.whiteColor;
}

- (BOOL)prefersStatusBarHidden {
    /** @ghidraAddress 0x2028f8 */
    return YES;
}

- (BOOL)shouldAutorotate {
    /** @ghidraAddress 0x202900 */
    if (!IsPad()) {
        return YES;
    }
    return !GameSystem::GetGameSystem()->GetBgmPlaying();
}

- (UIInterfaceOrientationMask)supportedInterfaceOrientations {
    /** @ghidraAddress 0x202930 */
    if (!IsPad()) {
        return UIInterfaceOrientationMaskAll;
    }
    if (!GameSystem::GetGameSystem()->GetBgmPlaying()) {
        return UIInterfaceOrientationMaskPortrait | UIInterfaceOrientationMaskLandscapeLeft;
    }
    if (self.interfaceOrientation == UIInterfaceOrientationPortraitUpsideDown) {
        return UIInterfaceOrientationMaskLandscapeLeft;
    }
    return UIInterfaceOrientationMaskPortrait;
}

- (UIInterfaceOrientation)preferredInterfaceOrientationForPresentation {
    /** @ghidraAddress 0x20298c */
    return UIInterfaceOrientationPortrait;
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
    /** @ghidraAddress 0x202994 */
    if (!IsPad()) {
        return YES;
    }
    if (interfaceOrientation == UIInterfaceOrientationPortrait ||
        interfaceOrientation == UIInterfaceOrientationPortraitUpsideDown) {
        return !GameSystem::GetGameSystem()->GetBgmPlaying();
    }
    return NO;
}

@end
