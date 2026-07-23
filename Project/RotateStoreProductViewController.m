#import "RotateStoreProductViewController.h"

@implementation RotateStoreProductViewController

// @ghidraAddress 0x2416d4
- (instancetype)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil {
    return [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
}

// @ghidraAddress 0x24174c
- (void)viewDidLoad {
    [super viewDidLoad];
}

// @ghidraAddress 0x241788
- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
}

// @ghidraAddress 0x2417c4
- (BOOL)shouldAutorotate {
    return YES;
}

// @ghidraAddress 0x2417cc
- (UIInterfaceOrientationMask)supportedInterfaceOrientations {
    return UIInterfaceOrientationMaskAll;
}

// @ghidraAddress 0x2417d4
- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
    return YES;
}

@end
