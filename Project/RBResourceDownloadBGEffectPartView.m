//
//  RBResourceDownloadBGEffectPartView.m
//  REFLEC BEAT plus
//
//  Reconstructed from Ghidra project rb458, program rb458 (class
//  RBResourceDownloadBGEffectPartView). Verified against the arm64 disassembly: -init chains to the
//  superclass through objc_msgSendSuper2, and every -setImage*Path: is likewise a super-send, so the
//  three artwork paths are seeded on the base class implementation.
//

#import "RBResourceDownloadBGEffectPartView.h"

// The three background artwork names seeded into the inherited base paths. The binary sends each
// setter to super, matching the fact that this class overrides none of them.
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
