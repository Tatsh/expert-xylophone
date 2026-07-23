//
//  RBCollectionView.m
//  REFLEC BEAT plus
//
//  Reconstructed from Ghidra project rb458, program rb458 (class RBCollectionView). The single
//  overridden method, -layoutSubviews, was recovered from the arm64 decompile and disassembly at
//  0x9d5d8; the weak customDelegate accessors are auto-synthesised from their getter/setter at
//  0x9d9b8/0x9d9d8.
//

#import "RBCollectionView.h"

@implementation RBCollectionView

- (void)layoutSubviews {
    if ([self.customDelegate respondsToSelector:@selector(willLayoutSubviews:)]) {
        [self.customDelegate willLayoutSubviews:self];
    }
    [super layoutSubviews];
    if ([self.customDelegate respondsToSelector:@selector(didLayoutSubviews:)]) {
        [self.customDelegate didLayoutSubviews:self];
    }
}

@end
