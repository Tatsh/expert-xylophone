//
//  RBBaseTabBarController.mm
//  REFLEC BEAT plus
//
//  Reconstructed from Ghidra project rb458, program rb458 (class RBBaseTabBarController). Verified
//  against the arm64 disassembly: viewDidLoad clears tab bar translucency on iOS 7 and later, the
//  status-bar override returns a constant, and the rotation overrides gate on the region font
//  variant, the engine background-music flag, and the current interface orientation.
//

#import "RBBaseTabBarController.h"

// GameSystem::GetGameSystem() -> GameSystem* (with the background-music playback flag reported by
// GetBgmPlaying()) and IsPad(), which reports whether the region uses the wide
// (variant) font layout that also selects the constrained-rotation behaviour.
#import "deviceenvironment.h"
#import "gamesystem.h"

// The first system-software major version whose UITabBar defaults to a translucent bar; on it and
// later the store keeps the opaque bar the earlier layout assumed.
static const float kFirstTranslucentTabBarSystemVersion = 7.0f;

@implementation RBBaseTabBarController

- (void)viewDidLoad {
    /** @ghidraAddress 0x2029e4 */
    [super viewDidLoad];
    if (UIDevice.currentDevice.systemVersion.floatValue >= kFirstTranslucentTabBarSystemVersion) {
        self.tabBar.translucent = NO;
    }
}

- (BOOL)prefersStatusBarHidden {
    /** @ghidraAddress 0x202af8 */
    return YES;
}

- (BOOL)shouldAutorotate {
    /** @ghidraAddress 0x202b00 */
    if (!IsPad()) {
        return YES;
    }
    return !GameSystem::GetGameSystem()->GetBgmPlaying();
}

- (UIInterfaceOrientationMask)supportedInterfaceOrientations {
    /** @ghidraAddress 0x202b30 */
    if (!IsPad()) {
        return UIInterfaceOrientationMaskAll;
    }
    if (!GameSystem::GetGameSystem()->GetBgmPlaying()) {
        return UIInterfaceOrientationMaskPortrait | UIInterfaceOrientationMaskPortraitUpsideDown;
    }
    if (self.interfaceOrientation == UIInterfaceOrientationPortraitUpsideDown) {
        return UIInterfaceOrientationMaskPortraitUpsideDown;
    }
    return UIInterfaceOrientationMaskPortrait;
}

- (UIInterfaceOrientation)preferredInterfaceOrientationForPresentation {
    /** @ghidraAddress 0x202b8c */
    return UIInterfaceOrientationPortrait;
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
    /** @ghidraAddress 0x202b94 */
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
