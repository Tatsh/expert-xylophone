//
//  neWindow.m
//  REFLEC BEAT plus
//
//  Reconstructed from Ghidra project rb458, program rb458 (class neWindow). This class does not
//  reach the C++ engine, so it is a plain Objective-C (.m) file.
//

#import "neWindow.h"

@implementation neWindow

/** @ghidraAddress 0x3d080 */
- (instancetype)initWithFrame:(CGRect)frame {
    return [super initWithFrame:frame];
}

#pragma mark - Touch handling

// The window deliberately swallows every touch phase: the engine's GL view reads input directly, so
// none of these are forwarded through the responder chain.

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
