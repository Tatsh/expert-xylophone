#import "RBBaseTableViewController.h"

#import "deviceenvironment.h"
#import "gamesystem.h"

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
        return UIInterfaceOrientationMaskPortrait | UIInterfaceOrientationMaskPortraitUpsideDown;
    }
    if (self.interfaceOrientation == UIInterfaceOrientationPortraitUpsideDown) {
        return UIInterfaceOrientationMaskPortraitUpsideDown;
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
