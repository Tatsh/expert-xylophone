//
//  RBCharacterBase.m
//  REFLEC BEAT plus
//
//  Reconstructed from Ghidra project rb458, program rb458 (class RBCharacterBase).
//

#import "RBCharacterBase.h"

@implementation RBCharacterBase

#pragma mark - Lifecycle

- (instancetype)init {
    /** @ghidraAddress 0x19e5b0 */
    self = [super init];
    if (self) {
        [self setDefault];
    }
    return self;
}

- (void)setDefault {
    /** @ghidraAddress 0x19e608 */
    self.posX = 0.0f;
    self.posY = 0.0f;
    self.moveX = 0.0f;
    self.moveY = 0.0f;
    self.accX = 0.0f;
    self.accY = 0.0f;
    self.useLimit = 0;
    self.limitPosUp = 0.0f;
    self.limitPosRight = 0.0f;
    self.limitPosDown = 0.0f;
    self.limitPosLeft = 0.0f;
    self.limitMoveX = 0.0f;
    self.limitMoveY = 0.0f;
    self.limitAccX = 0.0f;
    self.limitAccY = 0.0f;
}

#pragma mark - Simulation

- (void)update {
    /** @ghidraAddress 0x19e748 */
    self.posX = self.moveX + self.posX;
    self.posY = self.moveY + self.posY;
    if (![self checkLimitType:RBCharacterLimitTypeClamp]) {
        return;
    }
    if (self.posX < self.limitPosLeft || self.limitPosRight < self.posX) {
        // The binary always snaps back to the left edge, even when the right edge was crossed.
        self.posX = self.limitPosLeft;
        if ([self checkLimitType:RBCharacterLimitTypeBounce]) {
            self.moveX = -self.moveX;
            self.accX = -self.accX;
        }
    }
    if (self.posY < self.limitPosUp || self.limitPosDown < self.posY) {
        // The binary always snaps back to the top edge, even when the bottom edge was crossed.
        self.posY = self.limitPosUp;
        if ([self checkLimitType:RBCharacterLimitTypeBounce]) {
            self.moveY = -self.moveY;
            self.accY = -self.accY;
        }
    }
}

- (BOOL)checkLimitType:(int)checkLimitType {
    /** @ghidraAddress 0x19e9e8 */
    return (self.useLimit & checkLimitType) == checkLimitType;
}

@end
