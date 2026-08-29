#import "neWindow.h"

@implementation neWindow

/** @ghidraAddress 0x3d080 */
- (instancetype)initWithFrame:(CGRect)frame {
    return [super initWithFrame:frame];
}

#pragma mark - Touch handling

// The window swallows every touch phase: the engine's GL view reads input directly.

/** @ghidraAddress 0x3d0b4 */
- (void)touchesBegan:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
}

/** @ghidraAddress 0x3d0b8 */
- (void)touchesMoved:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
}

/** @ghidraAddress 0x3d0bc */
- (void)touchesEnded:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
}

/** @ghidraAddress 0x3d0c0 */
- (void)touchesCancelled:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
}

@end
