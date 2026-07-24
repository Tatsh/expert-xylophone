//
//  RBBaseViewController.mm
//  REFLEC BEAT plus
//
//  Reconstructed from Ghidra project rb458, program rb458 (class RBBaseViewController). Verified
//  against the arm64 disassembly: the rotation overrides gate on the region iPad idiom and the
//  engine's "background music playing" flag, and the status-bar override returns a constant.
//

#import "RBBaseViewController.h"

// GetGameSystem() -> GameSystem* (with the fBgmPlaying playback flag) and IsPad(),
// which reports whether the region uses the wide (variant) font layout that also selects the
// constrained-rotation behaviour.
#import "deviceenvironment.h"
#import "gamesystem.h"

@implementation RBBaseViewController

- (BOOL)prefersStatusBarHidden {
    /** @ghidraAddress 0x202740 */
    return YES;
}

- (BOOL)shouldAutorotate {
    /** @ghidraAddress 0x202748 */
    if (!IsPad()) {
        return YES;
    }
    return !GameSystem::GetGameSystem()->GetBgmPlaying();
}

- (UIInterfaceOrientationMask)supportedInterfaceOrientations {
    /** @ghidraAddress 0x202778 */
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
    /** @ghidraAddress 0x2027d4 */
    return UIInterfaceOrientationPortrait;
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
    /** @ghidraAddress 0x2027dc */
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
