#import "RBCollectionView.h"

// The customDelegate accessors are auto-synthesised (getter 0x9d9b8, setter 0x9d9d8).
@implementation RBCollectionView

- (void)layoutSubviews {
    // @ghidraAddress 0x9d5d8
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
