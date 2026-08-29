#import "RBErosionMarkUpdaterAlertController.h"

#import "deviceenvironment.h"

@implementation RBErosionMarkUpdaterAlertController

- (instancetype)init {
    /** @ghidraAddress 0x142a00 */
    self = [super init];
    if (self != nil) {
        if (!IsPad()) {
            self.orientationMask = UIInterfaceOrientationMaskAll;
        } else {
            self.orientationMask =
                UIInterfaceOrientationMaskPortrait | UIInterfaceOrientationMaskPortraitUpsideDown;
        }
    }
    return self;
}

- (instancetype)initWithOrientationMask:(UIInterfaceOrientationMask)orientationMask {
    /** @ghidraAddress 0x142a98 */
    self = [super init];
    if (self != nil) {
        self.orientationMask = orientationMask;
    }
    return self;
}

- (UIInterfaceOrientationMask)supportedInterfaceOrientations {
    /** @ghidraAddress 0x142b1c */
    return self.orientationMask;
}

@end
