#import "RBResoureDownloadBGEffectView.h"

#import "RBResourceDownloadBGEffectPartView.h"

static NSString *const kRainbowImageBasePath = @"re_";
static NSString *const kRingImageBasePath = @"ring_";

@implementation RBResoureDownloadBGEffectView

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        // Spelled as super sends for fidelity; this class overrides neither setter.
        // @ghidraAddress 0x19be8
        // @ghidraAddress 0x19c10
        [super setRainbowImageBasePath:kRainbowImageBasePath];
        [super setRingImageBasePath:kRingImageBasePath];
    }
    return self;
}

- (void)setupView {
    [super setupRainbow];
    [self setupParticle];
}

- (void)setupParticle {
    for (int i = 0; i < self.EFFECT_NUM; ++i) {
        RBResourceDownloadBGEffectPartView *part =
            [[RBResourceDownloadBGEffectPartView alloc] init];
        [part setupView];
        [super.effList addObject:part]; // The binary reaches effList through the superclass.
        [self addSubview:part];
    }
}

@end
