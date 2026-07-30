//
//  SFSafariViewController+RB.m
//  REFLEC BEAT plus
//
//  Reconstructed from Ghidra project rb458, program rb458 (category SFSafariViewController(RB)).
//  Verified against the arm64 disassembly: the whole body is mov w0,#0x1 followed by ret.
//

#import "SFSafariViewController+RB.h"

@implementation SFSafariViewController (RB)

- (BOOL)prefersStatusBarHidden {
    /** @ghidraAddress 0x20f48 */
    return YES;
}

@end
