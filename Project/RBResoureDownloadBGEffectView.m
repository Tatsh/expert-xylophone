//
//  RBResoureDownloadBGEffectView.m
//  REFLEC BEAT plus
//
//  Reconstructed from Ghidra project rb458, program rb458 (class RBResoureDownloadBGEffectView; the
//  "Resoure" misspelling is the binary's own). Verified against the arm64 disassembly:
//  initWithFrame: and setupView chain to the superclass via objc_msgSendSuper2, and setupParticle
//  re-reads EFFECT_NUM each iteration.
//

#import "RBResoureDownloadBGEffectView.h"

#import "RBResourceDownloadBGEffectPartView.h"

// The rainbow (bow) and ring artwork base names seeded into the inherited base paths. Each
// concrete frame name is these plus an index suffix.
static NSString *const kRainbowImageBasePath = @"re_";
static NSString *const kRingImageBasePath = @"ring_";

@implementation RBResoureDownloadBGEffectView

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        self.rainbowImageBasePath = kRainbowImageBasePath;
        self.ringImageBasePath = kRingImageBasePath;
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
