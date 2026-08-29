#import "RBBaseTabBarController.h"

#import "deviceenvironment.h"
#import "gamesystem.h"

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
