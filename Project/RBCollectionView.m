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

- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event {
    /** @ghidraAddress 0x9d730 */
    [super touchesBegan:touches withEvent:event];
    if ([self.customDelegate
            respondsToSelector:@selector(touchesBeganFromRBCollectionView:withEvent:)]) {
        [self.customDelegate touchesBeganFromRBCollectionView:touches withEvent:event];
    }
}

- (void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event {
    /** @ghidraAddress 0x9d874 */
    [super touchesEnded:touches withEvent:event];
    if ([self.customDelegate
            respondsToSelector:@selector(touchesEndedFromRBCollectionView:withEvent:)]) {
        [self.customDelegate touchesEndedFromRBCollectionView:touches withEvent:event];
    }
}

@end
