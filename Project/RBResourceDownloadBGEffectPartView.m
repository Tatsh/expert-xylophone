#import "RBResourceDownloadBGEffectPartView.h"

static NSString *const kImage1Path = @"bg_tex_05";
static NSString *const kImage2Path = @"bg_tex_03";
static NSString *const kImage3Path = @"bg_tex_01";

@implementation RBResourceDownloadBGEffectPartView

- (instancetype)init {
    self = [super init];
    if (self) {
        [super setImage1Path:kImage1Path];
        [super setImage2Path:kImage2Path];
        [super setImage3Path:kImage3Path];
    }
    return self;
}

@end
